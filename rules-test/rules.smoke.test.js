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
});
