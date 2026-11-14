/**
 * اختبار دخان لقواعد Firestore بدون Emulator/Java.
 * يتحقق من وجود الحمايات الحرجة في النص.
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8');

describe('firestore.rules smoke', () => {
  it('declares rules_version 2', () => {
    assert.match(rules, /rules_version\s*=\s*'2'/);
  });

  it('admin wildcard is super-only; scoped adminPermissions helpers exist', () => {
    assert.match(rules, /function isAdmin\(\)/);
    assert.match(rules, /function isSuperAdmin\(\)/);
    assert.match(rules, /adminLevel',\s*''\)\s*==\s*'super'/);
    assert.match(rules, /function adminCanRead\(/);
    assert.match(rules, /function adminCanWrite\(/);
    assert.match(rules, /allow read, write:\s*if isSuperAdmin\(\)/);
    assert.match(rules, /adminPermissions/);
  });

  it('protects walletBalance and role on users', () => {
    assert.match(rules, /'walletBalance'/);
    assert.match(rules, /'role'/);
    assert.match(rules, /keepsProtectedFields/);
  });

  it('blocks ratingAvg and oilWorkshopTier on user create', () => {
    assert.match(rules, /'ratingAvg',\s*'oilWorkshopTier'/);
  });

  it('jobs create requires owning customerId', () => {
    assert.match(rules, /creatingOwnJob/);
    assert.match(rules, /allow create:\s*if creatingOwnJob\(\)/);
  });

  it('provider customer read requires active job slot', () => {
    assert.match(rules, /function providerActiveJobCustomer\(/);
    assert.match(rules, /providerActiveJobCustomer\(uid\)/);
  });

  it('jobs update allows assigned tech via assignedTechJobUpdate (not bare isCustomer)', () => {
    assert.match(rules, /function assignedTechJobUpdate\(\)/);
    assert.match(rules, /function customerCompleteParts\(\)/);
    assert.match(rules, /function customerCancel\(\)/);
    assert.match(rules, /function claimingOpenJob\(\)/);
    assert.match(
      rules,
      /allow update:\s*if claimingOpenJob\(\)[\s\S]*assignedTechJobUpdate\(\)/,
    );
    // يجب ألا يعود التحديث المفتوح القديم للعميل أو isTech() بلا قيود حقول.
    assert.doesNotMatch(
      rules,
      /allow update:\s*if isCustomer\(\)\s*\|\|\s*claimingOpenJob\(\)/,
    );
    assert.doesNotMatch(
      rules,
      /allow update:\s*if isCustomer\(\)\s*\|\|\s*isTech\(\)/,
    );
  });

  it('claimingOpenJob includes lastAssignedTechnicianId used by app', () => {
    assert.match(rules, /lastAssignedTechnicianId/);
    assert.match(rules, /assignedTechJobUpdate[\s\S]*commissionRate/);
  });

  it('assignedTechJobUpdate allows shippedPartImageUrl for parts shipping', () => {
    assert.match(rules, /assignedTechJobUpdate[\s\S]*shippedPartImageUrl/);
  });

  it('commission and price caps exist', () => {
    assert.match(rules, /function commissionAmountOk\(\)/);
    assert.match(rules, /function respectsPriceUpperCap\(\)/);
    assert.match(rules, /function maxJobMoney\(\)/);
  });

  it('assigned tech can read jobLocations', () => {
    assert.match(
      rules,
      /match \/jobLocations\/\{jobId\}[\s\S]*technicianId[\s\S]*== request\.auth\.uid/,
    );
  });

  it('customerWalletSettle bounds walletApplied/changeAmount and blocks replay', () => {
    assert.match(rules, /job\.walletApplied <= bill/);
    assert.match(rules, /job\.changeAmount <= job\.receivedAmount/);
    assert.match(rules, /job\.changeAmount <= bill/);
    assert.match(rules, /walletJobId',\s*''\)\s*!=\s*jobId/);
  });

  it('user delete is admin-only (self-delete via Admin SDK API)', () => {
    assert.match(
      rules,
      /match \/users\/\{uid\}[\s\S]*allow delete:\s*if adminCanWriteUserDoc\(\);/,
    );
  });

  it('disputes require open status and linked job', () => {
    assert.match(rules, /function disputeCreateOk\(\)/);
    assert.match(rules, /get\('status',\s*''\)\s*==\s*'open'/);
  });

  it('support tickets enforce payload size limits', () => {
    assert.match(rules, /subject\.size\(\)\s*<=\s*200/);
    assert.match(rules, /body\.size\(\)\s*<=\s*5000/);
  });
});
