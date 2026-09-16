import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/demo/demo_mode.dart';
import 'package:barrr/demo/demo_store.dart';
import 'package:barrr/models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _authOr = auth,
        _dbOr = db;

  final FirebaseAuth? _authOr;
  final FirebaseFirestore? _dbOr;

  FirebaseAuth get _auth => _authOr ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOr ?? FirebaseFirestore.instance;

  Stream<String?> get uidChanges {
    if (DemoMode.enabled) return DemoStore.instance.uidStream;
    return _auth.authStateChanges().map((u) => u?.uid);
  }

  String? get currentUid {
    if (DemoMode.enabled) return DemoStore.instance.currentUid;
    return _auth.currentUser?.uid;
  }

  Future<void> signIn(String email, String password) {
    if (DemoMode.enabled) {
      return DemoStore.instance.signIn(email, password);
    }
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    List<String> serviceIds = const [],
  }) async {
    if (DemoMode.enabled) {
      await DemoStore.instance.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
        serviceIds: serviceIds,
      );
      return;
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    final isTech = role == UserRole.technician;
    final user = AppUser(
      id: uid,
      role: role,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      serviceIds: isTech ? serviceIds : const [],
      isOnline: false,
      verified: false,
      verificationStatus:
          isTech ? VerificationStatus.pending : VerificationStatus.approved,
      walletBalance: 0,
    );
    await _db.collection(Cols.users).doc(uid).set(user.toMap());
  }

  Future<void> signOut() {
    if (DemoMode.enabled) return DemoStore.instance.signOut();
    return _auth.signOut();
  }
}
