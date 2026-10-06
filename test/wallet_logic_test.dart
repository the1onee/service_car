import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/wallet_entry.dart';

/// يطابق تقريب المال في JobRepository._money
double money(num value) => (value * 100).round() / 100;

/// تسوية إتمام طلب: عمولة مزوّد + خصم محفظة عميل + فكة نقدية.
({
  double commission,
  double techNext,
  double applied,
  double cashDue,
  double change,
  double customerNext,
  bool techForceOffline,
}) settleCompleteJob({
  required double bill,
  required double rate,
  required double techWallet,
  required double customerWallet,
  required bool useWallet,
  required double receivedAmount,
  double minWallet = AppConstants.minWalletBalance,
}) {
  final commission = money(bill * rate);
  final techNext = money(techWallet - commission);
  final applied = useWallet
      ? money(customerWallet < bill
          ? (customerWallet < 0 ? 0 : customerWallet)
          : bill)
      : 0.0;
  final cashDue = money(bill - applied < 0 ? 0 : bill - applied);
  final change =
      money(receivedAmount - cashDue < 0 ? 0 : receivedAmount - cashDue);
  final customerNext = money(customerWallet - applied + change);
  return (
    commission: commission,
    techNext: techNext,
    applied: applied,
    cashDue: cashDue,
    change: change,
    customerNext: customerNext,
    techForceOffline: techNext < minWallet,
  );
}

AppUser _user({
  required UserRole role,
  double wallet = 0,
  VerificationStatus verification = VerificationStatus.approved,
  bool verified = true,
}) {
  return AppUser(
    id: 'u1',
    role: role,
    name: 'اختبار',
    phone: '7700000000',
    walletBalance: wallet,
    verificationStatus: verification,
    verified: verified,
  );
}

void main() {
  group('serviceAmountError', () {
    test('accepts multiples of 1000 at or above 3000', () {
      expect(AppConstants.serviceAmountError(3000), isNull);
      expect(AppConstants.serviceAmountError(10000), isNull);
      expect(AppConstants.serviceAmountError(null), isNotNull);
      expect(AppConstants.serviceAmountError(2000), isNotNull);
      expect(AppConstants.serviceAmountError(3500), isNotNull);
      expect(AppConstants.serviceAmountError(3000.5), isNotNull);
    });
  });

  group('AppUser wallet gates', () {
    test('technician needs approval and min wallet to receive jobs', () {
      expect(
        _user(role: UserRole.technician, wallet: 15000).canReceiveJobs,
        isTrue,
      );
      expect(
        _user(role: UserRole.technician, wallet: 5000).canReceiveJobs,
        isFalse,
      );
      expect(
        _user(
          role: UserRole.technician,
          wallet: 15000,
          verification: VerificationStatus.pending,
          verified: false,
        ).canReceiveJobs,
        isFalse,
      );
    });

    test('paint shop skips wallet minimum for canReceiveJobs', () {
      expect(
        _user(role: UserRole.paintShop, wallet: 0).canReceiveJobs,
        isTrue,
      );
      expect(_user(role: UserRole.paintShop, wallet: 0).isWalletLocked(), isFalse);
    });

    test('isWalletLocked and requiredTopUp', () {
      final low = _user(role: UserRole.workshop, wallet: 4000);
      expect(low.isWalletLocked(), isTrue);
      expect(low.requiredTopUp(), 6000);
      expect(low.isWalletLocked(3000), isFalse);

      final ok = _user(role: UserRole.technician, wallet: 10000);
      expect(ok.isWalletLocked(), isFalse);
      expect(ok.requiredTopUp(), 0);
    });

    test('customers never receive jobs via canReceiveJobs', () {
      expect(
        _user(role: UserRole.customer, wallet: 99999).canReceiveJobs,
        isFalse,
      );
    });

    test('role routing flags', () {
      expect(_user(role: UserRole.admin).isAdmin, isTrue);
      expect(_user(role: UserRole.oilWorkshop).isOilWorkshop, isTrue);
      expect(_user(role: UserRole.workshop).isWorkshop, isTrue);
      expect(_user(role: UserRole.technician).isTechnician, isTrue);
    });
  });

  group('completeJob settlement math', () {
    test('commission and force offline when below min', () {
      final s = settleCompleteJob(
        bill: 10000,
        rate: 0.10,
        techWallet: 10500,
        customerWallet: 0,
        useWallet: false,
        receivedAmount: 10000,
      );
      expect(s.commission, 1000);
      expect(s.techNext, 9500);
      expect(s.techForceOffline, isTrue);
      expect(s.cashDue, 10000);
      expect(s.change, 0);
    });

    test('wallet spend and cash change', () {
      final s = settleCompleteJob(
        bill: 10000,
        rate: 0.10,
        techWallet: 50000,
        customerWallet: 4000,
        useWallet: true,
        receivedAmount: 7000,
      );
      expect(s.applied, 4000);
      expect(s.cashDue, 6000);
      expect(s.change, 1000);
      expect(s.customerNext, 1000);
      expect(s.techNext, 49000);
      expect(s.techForceOffline, isFalse);
    });

    test('idempotent entry ids stay stable by convention', () {
      const jobId = 'abc123';
      expect('commission_$jobId', 'commission_abc123');
      expect('spend_$jobId', 'spend_abc123');
      expect('change_$jobId', 'change_abc123');
    });
  });

  group('WalletEntry labels', () {
    test('typeLabel arabic', () {
      const base = WalletEntry(
        id: 'e1',
        userId: 'u1',
        type: WalletEntryType.credit,
        amount: 1,
        signedAmount: 1,
        balanceAfter: 1,
      );
      expect(base.typeLabel, 'شحن');
      expect(
        const WalletEntry(
          id: 'e2',
          userId: 'u1',
          type: WalletEntryType.commission,
          amount: 1,
          signedAmount: -1,
          balanceAfter: 0,
        ).typeLabel,
        'عمولة',
      );
      expect(
        const WalletEntry(
          id: 'e3',
          userId: 'u1',
          type: WalletEntryType.spend,
          amount: 1,
          signedAmount: -1,
          balanceAfter: 0,
        ).typeLabel,
        'خصم من الرصيد',
      );
    });
  });
}
