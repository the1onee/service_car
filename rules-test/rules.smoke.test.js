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

  it('jobs create requires owning customerId', () => {
    assert.match(rules, /creatingOwnJob/);
    assert.match(rules, /allow create:\s*if creatingOwnJob\(\)/);
  });

  it('provider public profile read helper', () => {
    assert.match(rules, /isPublicProviderProfile/);
  });

  it('jobs update allows assigned tech via assignedTechJobUpdate (not bare isCustomer)', () => {
    assert.match(rules, /function assignedTechJobUpdate\(\)/);
    assert.match(rules, /function customerJobUpdate\(\)/);
    assert.match(rules, /function openJobLifecycleUpdate\(\)/);
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

  it('assigned tech can read jobLocations', () => {
    assert.match(
      rules,
      /match \/jobLocations\/\{jobId\}[\s\S]*technicianId[\s\S]*== request\.auth\.uid/,
    );
  });

  it('customerWalletSettle bounds walletApplied/changeAmount', () => {
    assert.match(rules, /job\.walletApplied <= bill/);
    assert.match(rules, /job\.changeAmount <= job\.receivedAmount/);
  });
});
