import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, get, set } from 'firebase/database';
import { patchStartupPolicy } from '../../tool/prepare_startup_policy_patch.mjs';

const endpoint = process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000';
const match = /^(127\.0\.0\.1|localhost):(\d+)$/.exec(endpoint);
assert.ok(match && Number(match[2]) > 0 && Number(match[2]) < 65536, 'Loopback emulator required');
const baseline = process.env.FINTRACK_STARTUP_RULES_BEFORE
  ? JSON.parse(await readFile(process.env.FINTRACK_STARTUP_RULES_BEFORE, 'utf8'))
  : { rules: { '.read': false, '.write': false, Expenses: {
    '$phoneNumber': { '.read': "auth != null && auth.token.email == ($phoneNumber + '@fintrack.app')",
      '.write': "auth != null && auth.token.email == ($phoneNumber + '@fintrack.app')" },
  } } };
let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fintrack-startup-policy',
    database: { host: match[1], port: Number(match[2]), rules: JSON.stringify(patchStartupPolicy(baseline)) },
  });
  await env.clearDatabase();
});
after(async () => { if (env) await env.cleanup(); });

test('startup-only patch leaves every unrelated rule unchanged', () => {
  const patched = patchStartupPolicy(baseline);
  const original = structuredClone(baseline);
  delete patched.rules.app_config;
  delete original.rules.app_config;
  assert.deepEqual(patched, original);
});

test('unset and configured version are readable without login', async () => {
  const db = env.unauthenticatedContext().database();
  assert.equal((await assertSucceeds(get(ref(db, 'app_config/min_version')))).exists(), false);
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database(), 'app_config/min_version'), '2.2.0');
  });
  assert.equal((await assertSucceeds(get(ref(db, 'app_config/min_version')))).val(), '2.2.0');
});

test('anonymous and authenticated clients cannot change the version', async () => {
  for (const db of [env.unauthenticatedContext().database(),
    env.authenticatedContext('qa-owner', { email: '9876543210@fintrack.app' }).database()]) {
    await assertFails(set(ref(db, 'app_config/min_version'), '0.0.0'));
    await assertFails(set(ref(db, 'app_config/min_version'), null));
  }
});

test('parent configuration and private records remain unreadable anonymously', async () => {
  const db = env.unauthenticatedContext().database();
  await assertFails(get(ref(db, 'app_config')));
  await assertFails(get(ref(db, 'Expenses/9876543210')));
  await assertFails(set(ref(db, 'Expenses/9876543210/probe'), { Amount: '1' }));
});
