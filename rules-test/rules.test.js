/**
 * اختبارات قواعد Firestore — تُشغَّل عبر:
 *   npm test
 * (firebase emulators:exec --only firestore)
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8');

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let testEnv;

async function seed(data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, value] of Object.entries(data)) {
      await setDoc(doc(db, path), value);
    }
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-barrr',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('Firestore rules', () => {
  it('admin can read and write any user doc', async () => {
    await seed({
      'users/admin1': {
        role: 'admin',
        name: 'Admin',
        phone: '7700000001',
        walletBalance: 0,
      },
    });
    const admin = testEnv.authenticatedContext('admin1');
    const db = admin.firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/tech1'), {
        role: 'technician',
        name: 'فني',
        phone: '7700000002',
        walletBalance: 0,
        verified: false,
        verificationStatus: 'pending',
        ratingCount: 0,
      }),
    );
    await assertSucceeds(getDoc(doc(db, 'users/tech1')));
  });

  it('user cannot change protected walletBalance', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '7700000003',
        walletBalance: 1000,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const customer = testEnv.authenticatedContext('c1');
    const db = customer.firestore();
    await assertFails(
      updateDoc(doc(db, 'users/c1'), { walletBalance: 99999 }),
    );
  });

  it('user cannot change own role', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '7700000003',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const customer = testEnv.authenticatedContext('c1');
    await assertFails(
      updateDoc(doc(customer.firestore(), 'users/c1'), { role: 'admin' }),
    );
  });

  it('signed-in user can read public provider profile', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '1',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
      'users/t1': {
        role: 'technician',
        name: 'فني',
        phone: '2',
        walletBalance: 20000,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const customer = testEnv.authenticatedContext('c1');
    await assertSucceeds(getDoc(doc(customer.firestore(), 'users/t1')));
  });

  it('customer can create own job in dispatching', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '1',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const customer = testEnv.authenticatedContext('c1');
    await assertSucceeds(
      setDoc(doc(customer.firestore(), 'jobs/j1'), {
        customerId: 'c1',
        status: 'dispatching',
        serviceId: 'wash',
        technicianId: null,
      }),
    );
  });

  it('other user cannot create job for someone else', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '1',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
      'users/c2': {
        role: 'customer',
        name: 'آخر',
        phone: '2',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const other = testEnv.authenticatedContext('c2');
    await assertFails(
      setDoc(doc(other.firestore(), 'jobs/j2'), {
        customerId: 'c1',
        status: 'dispatching',
        serviceId: 'wash',
        technicianId: null,
      }),
    );
  });

  it('unauthenticated cannot read user doc', async () => {
    await seed({
      'users/c1': {
        role: 'customer',
        name: 'عميل',
        phone: '1',
        walletBalance: 0,
        verified: true,
        verificationStatus: 'approved',
        ratingCount: 0,
      },
    });
    const anon = testEnv.unauthenticatedContext();
    await assertFails(getDoc(doc(anon.firestore(), 'users/c1')));
  });
});

// sanity: file loaded
assert.ok(rules.includes('rules_version'));
