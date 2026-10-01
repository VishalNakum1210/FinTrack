import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, set, get, update, remove, serverTimestamp } from 'firebase/database';

const phone = '9876543210', other = '9876500000';
const endpoint = process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000';
const endpointMatch = /^(127\.0\.0\.1|localhost):(\d+)$/.exec(endpoint);
const projectId = process.env.FINTRACK_RULES_PROJECT ?? 'demo-fintrack-audit';
if (!endpointMatch || Number(endpointMatch[2]) < 1 || Number(endpointMatch[2]) > 65535 ||
    !/^demo-[a-z0-9-]+$/.test(projectId)) {
  throw new Error('Destructive rules fixtures require a loopback emulator and demo project.');
}
let env;
const auth = (uid, number) => env.authenticatedContext(uid, {
  email: `${number}@fintrack.app`, firebase: { sign_in_provider: 'password' },
}).database();
const owner = () => auth('owner', phone);
const dateFields = value => {
  const [date_day, date_month, date_year] = value.split('/').map(Number);
  return { date_day, date_month, date_year, date_epoch: Date.UTC(date_year, date_month - 1, date_day) };
};
const expense = (extra = {}) => ({ Amount: '0.49', Category: 'Food', Date: '30/9/2026', ...dateFields(extra.Date ?? '30/9/2026'), Payment_Mode: 'Spent Cash', Description: 'Lunch', timestamp: serverTimestamp(), ...extra });
const friendRecord = (extra = {}) => ({ Amount: '0.49', Type: 'Give Money To Friend', Date: '30/9/2026', ...dateFields(extra.Date ?? '30/9/2026'), Payment_Mode: 'Spent Cash', Description: 'Lunch', timestamp: serverTimestamp(), ...extra });

before(async () => {
  env = await initializeTestEnvironment({ projectId, database: {
    host: endpointMatch[1], port: Number(endpointMatch[2]), rules: await readFile('database.rules.json', 'utf8'),
  } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database()), {
      user_details: { [phone]: { owner_uid: 'owner', phone_number: phone, name: 'Owner', email: '' } },
      Friends: { [phone]: { [other]: { friend_name: 'Friend', friend_number: other } } },
      app_config: { min_version: '2.2.0' },
    });
  });
});

test('new registration can read an empty profile and bind it to its UID', async () => {
  const db = auth('new-user', other);
  await assertSucceeds(get(ref(db, `user_details/${other}`)));
  await assertSucceeds(set(ref(db, `user_details/${other}`), { owner_uid: 'new-user', phone_number: other, name: 'New', email: '', created_at: serverTimestamp() }));
});
test('anonymous and cross-user reads and writes are denied', async () => {
  const anonymous = env.unauthenticatedContext().database();
  await assertFails(get(ref(anonymous, `user_details/${phone}`)));
  await assertFails(set(ref(anonymous, `Expenses/${phone}/r`), expense()));
  await assertFails(get(ref(auth('outsider', other), `Expenses/${phone}`)));
  await assertFails(set(ref(auth('outsider', other), `Expenses/${phone}/r`), expense()));
});
test('same synthetic email with a different UID cannot claim another account', async () => {
  const impostor = auth('impostor', phone);
  await assertFails(get(ref(impostor, `user_details/${phone}`)));
  await assertFails(set(ref(impostor, `Expenses/${phone}/r`), expense()));
  await assertFails(update(ref(owner(), `user_details/${phone}`), { owner_uid: 'impostor' }));
});
test('minimum version is public read-only', async () => {
  const db = env.unauthenticatedContext().database();
  await assertSucceeds(get(ref(db, 'app_config/min_version')));
  await assertFails(set(ref(owner(), 'app_config/min_version'), '0.0.0'));
});
test('positive decimal expenses can be created, edited, and deleted', async () => {
  const r = ref(owner(), `Expenses/${phone}/r`);
  await assertSucceeds(set(r, expense()));
  await assertSucceeds(update(r, { Amount: '0.01', Description: 'Corrected' }));
  await assertSucceeds(remove(r));
});
test('negative, zero, malformed, nonfinite, out-of-range and sub-paisa amounts are denied', async () => {
  for (const Amount of ['-1', '0', '0.00', 'NaN', 'Infinity', '1e10', '1000000000000', '0.001', 'abc', 12]) {
    await assertFails(set(ref(owner(), `Expenses/${phone}/r`), expense({ Amount })));
  }
});
test('unknown fields, invalid modes/categories/dates, and forged timestamps are denied', async () => {
  for (const extra of [{ admin: true }, { Payment_Mode: 'invalid' }, { Category: 'invalid' }, { Date: '31/2/2026' }, { Date: '29/2/2026' }, { timestamp: Date.now() + 86400000 }]) {
    await assertFails(set(ref(owner(), `Expenses/${phone}/r`), expense(extra)));
  }
});
test('friend records accept pennies but aggregates cannot be overwritten', async () => {
  await assertSucceeds(set(ref(owner(), `Friends/${phone}/${other}/Records/r`), friendRecord()));
  await assertFails(update(ref(owner(), `Friends/${phone}/${other}`), { total_get: 999 }));
  await assertFails(set(ref(owner(), `Friends/${phone}/${other}/Records/bad`), friendRecord({ Amount: '-1' })));
  await assertFails(set(ref(owner(), `Friends/${phone}/${other}/Records/bad`), friendRecord({ Type: 'invalid' })));
});
test('multi-location split succeeds atomically and one invalid branch rejects the whole write', async () => {
  const db = owner();
  await assertSucceeds(update(ref(db), {
    [`Expenses/${phone}/split`]: expense(),
    [`Friends/${phone}/${other}/Records/split`]: friendRecord(),
  }));
  await assertFails(update(ref(db), {
    [`Expenses/${phone}/bad`]: expense(),
    [`Friends/${phone}/${other}/Records/bad`]: friendRecord({ Amount: 'NaN' }),
  }));
  const snap = await get(ref(db, `Expenses/${phone}/bad`));
  if (snap.exists()) throw new Error('Partial split committed');
});
test('feedback validates fields and permits account data cleanup', async () => {
  const r = ref(owner(), `userUpdates/${phone}/r`);
  await assertSucceeds(set(r, { rating: 5, type: 'Suggestion', message: 'Hello', email: '', timestamp: serverTimestamp() }));
  await assertFails(update(r, { rating: 99 }));
  await assertSucceeds(remove(ref(owner(), `userUpdates/${phone}`)));
});

test('invalid century dates, future dates and contradictory calendar metadata are denied', async () => {
  for (const extra of [{ Date: '29/2/2100' }, { Date: '1/1/3000' },
      { date_epoch: 946684800000 }, { date_day: 1 }, { date_month: 0 },
      { date_year: 2026.5 }, { date_epoch: null }]) {
    await assertFails(set(ref(owner(), `Expenses/${phone}/invalid`), expense(extra)));
  }
  for (const Date of ['29/2/2000', '29/2/2004', '31/12/2025', '1/1/2000']) {
    await assertSucceeds(set(ref(owner(), `Expenses/${phone}/valid`), expense({ Date })));
  }
});

test('profile-only deletion and claiming orphaned financial roots are denied', async () => {
  await assertSucceeds(set(ref(owner(), `Expenses/${phone}/private`), expense()));
  await assertFails(remove(ref(owner(), `user_details/${phone}`)));
  await env.withSecurityRulesDisabled(async context => {
    await remove(ref(context.database(), `user_details/${phone}`));
  });
  const recreated = auth('recreated', phone);
  await assertFails(set(ref(recreated, `user_details/${phone}`), {
    owner_uid: 'recreated', phone_number: phone, name: 'New', email: '',
  }));
  await assertFails(get(ref(recreated, `Expenses/${phone}/private`)));
});

test('scrubbed account cleanup is retryable and safely permits a later UID', async () => {
  const cleanup = {
    [`Expenses/${phone}`]: null, [`Friends/${phone}`]: null,
    [`Trips/${phone}`]: null, [`userUpdates/${phone}`]: null,
    [`WriteOperations/${phone}`]: null,
    [`user_details/${phone}`]: { owner_uid: 'owner', phone_number: phone,
      name: 'Deleted account', email: '', deletion_pending: true },
  };
  await assertSucceeds(set(ref(owner(), `Expenses/${phone}/r`), expense()));
  await assertSucceeds(update(ref(owner()), cleanup));
  await assertSucceeds(update(ref(owner()), cleanup));
  const recreated = auth('recreated', phone);
  await assertSucceeds(get(ref(recreated, `user_details/${phone}`)));
  await assertSucceeds(set(ref(recreated, `user_details/${phone}`), {
    owner_uid: 'recreated', phone_number: phone, name: 'New', email: '',
  }));
  await assertFails(get(ref(owner(), `Expenses/${phone}`)));
});

test('deletion tombstone cannot be installed while financial history survives', async () => {
  await assertSucceeds(set(ref(owner(), `Expenses/${phone}/r`), expense()));
  await assertFails(set(ref(owner(), `user_details/${phone}`), {
    owner_uid: 'owner', phone_number: phone, name: 'Deleted account', email: '', deletion_pending: true,
  }));
});

test('immutable operation markers atomically reject a replay over an edited expense', async () => {
  const db = owner();
  const updates = { [`Expenses/${phone}/operation`]: expense(),
    [`WriteOperations/${phone}/operation`]: { timestamp: serverTimestamp() } };
  await assertSucceeds(update(ref(db), updates));
  await assertSucceeds(update(ref(db, `Expenses/${phone}/operation`), { Amount: '0.70' }));
  await assertFails(update(ref(db), updates));
  const snap = await get(ref(db, `Expenses/${phone}/operation/Amount`));
  if (snap.val() !== '0.70') throw new Error('Replay overwrote the edit');
  await assertFails(get(ref(auth('outsider', other), `WriteOperations/${phone}/operation`)));
});

test('linked split amounts/modes/links are protected and whole-bill deletion is atomic', async () => {
  const db = owner();
  const expensePath = `Expenses/${phone}/split`;
  const friendPath = `Friends/${phone}/${other}/Records/split_0`;
  await assertSucceeds(update(ref(db), {
    [expensePath]: expense({ Amount: '50.00', split_id: 'split' }),
    [friendPath]: friendRecord({ Amount: '50.00', split_id: 'split' }),
  }));
  await assertFails(update(ref(db, expensePath), { Amount: '70.00' }));
  await assertFails(update(ref(db, expensePath), { Payment_Mode: 'Spent Online' }));
  await assertFails(update(ref(db, expensePath), { split_id: null }));
  await assertFails(update(ref(db, friendPath), { Amount: '70.00' }));
  await assertSucceeds(update(ref(db, expensePath), { Description: 'Corrected note' }));
  await assertSucceeds(update(ref(db), { [expensePath]: null, [friendPath]: null }));
});

test('pending deletion prevents old tokens or queued writes from resurrecting financial history', async () => {
  const db = owner();
  await assertSucceeds(update(ref(db), {
    [`Friends/${phone}`]: null,
    [`user_details/${phone}`]: { owner_uid: 'owner', phone_number: phone,
      name: 'Deleted account', email: '', deletion_pending: true },
  }));
  await assertFails(set(ref(db, `Expenses/${phone}/late-write`), expense()));
  await assertFails(set(ref(db, `WriteOperations/${phone}/late-write`), { timestamp: serverTimestamp() }));
  await assertFails(update(ref(db, `user_details/${phone}`), { deletion_pending: null, name: 'Reactivated' }));
  await assertSucceeds(update(ref(db), { [`Expenses/${phone}`]: null, [`Friends/${phone}`]: null }));
});
