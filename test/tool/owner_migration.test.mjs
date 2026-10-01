import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { spawnSync } from 'node:child_process';

const phone = '9876543210', friend = '9876500000';
const profile = { phone_number: phone, name: 'Owner', email: '' };
const record = { Amount: '0.49', Category: 'Food', Date: '01/01/2000',
  Payment_Mode: 'Spent Cash', timestamp: 946684800000 };
async function run(database, owners = { [phone]: 'owner' }) {
  const directory = await mkdtemp(join(tmpdir(), 'fintrack-migration-test-'));
  try {
    const exportFile = join(directory, 'synthetic-export.json');
    const ownerFile = join(directory, 'synthetic-owners.json');
    await writeFile(exportFile, JSON.stringify(database));
    await writeFile(ownerFile, JSON.stringify(owners));
    return spawnSync(process.execPath, ['tool/prepare_owner_migration.mjs', exportFile, ownerFile], { encoding: 'utf8' });
  } finally {
    // Generated synthetic fixture directory only; never a user/workspace root.
    const expectedPrefix = resolve(tmpdir()) + sep + 'fintrack-migration-test-';
    if (!resolve(directory).startsWith(expectedPrefix)) throw new Error('Unsafe fixture cleanup target');
    await rm(directory, { recursive: true, force: true });
  }
}
test('offline patch includes verified ownership and canonical date/amount metadata', async () => {
  const result = await run({ user_details: { [phone]: profile }, Expenses: { [phone]: { r: record } } });
  assert.equal(result.status, 0, result.stderr);
  const patch = JSON.parse(result.stdout);
  assert.equal(patch[`user_details/${phone}/owner_uid`], 'owner');
  assert.equal(patch[`Expenses/${phone}/r/Date`], '1/1/2000');
  assert.equal(patch[`Expenses/${phone}/r/date_epoch`], 946684800000);
  assert.equal(patch[`Expenses/${phone}/r/Amount`], '0.49');
  assert.ok(patch[`WriteOperations/${phone}/r`]);
});
test('orphaned history cannot be assigned to a freshly claimed identifier', async () => {
  const result = await run({ Expenses: { [phone]: { r: record } } });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /manual ownership reconciliation/);
});
test('conflicting or missing independently verified ownership fails closed', async () => {
  for (const owners of [{}, { [phone]: 'different' }]) {
    const result = await run({ user_details: { [phone]: { ...profile, owner_uid: 'owner' } } }, owners);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
  }
});
test('invalid century date and future history fail without emitting a partial patch', async () => {
  for (const Date of ['29/2/2100', '1/1/3000']) {
    const result = await run({ user_details: { [phone]: profile }, Expenses: { [phone]: { r: { ...record, Date } } } });
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
  }
});
test('known split IDs and legacy owed modes are normalized without changing amounts', async () => {
  const id = '01234567890123456789';
  const result = await run({ user_details: { [phone]: profile },
    Expenses: { [phone]: { [id]: { ...record, Payment_Mode: 'Owed to Friend' } } },
    Friends: { [phone]: { [friend]: { friend_name: 'Friend', friend_number: friend,
      Records: { [`${id}_0`]: { ...record, Type: 'Take Money From Friend' } } } } },
  });
  assert.equal(result.status, 0, result.stderr);
  const patch = JSON.parse(result.stdout);
  assert.equal(patch[`Expenses/${phone}/${id}/Payment_Mode`], 'Owed');
  assert.equal(patch[`Expenses/${phone}/${id}/split_id`], id);
  assert.equal(patch[`Friends/${phone}/${friend}/Records/${id}_0/split_id`], id);
});
