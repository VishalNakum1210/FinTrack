// Offline only: produces a reviewable database multi-path patch. It never
// connects to Firebase and does not infer ownership from a claimed phone.
import { readFile } from 'node:fs/promises';
const [, , exportFile, confirmedMapFile] = process.argv;
if (!exportFile || !confirmedMapFile) throw new Error('Usage: node tool/prepare_owner_migration.mjs database-export.json confirmed-owner-map.json');
const database = JSON.parse(await readFile(exportFile, 'utf8'));
const owners = JSON.parse(await readFile(confirmedMapFile, 'utf8'));
const updates = {};
const roots = ['Expenses', 'Friends', 'Trips', 'userUpdates', 'WriteOperations'];
for (const root of roots) {
  for (const phone of Object.keys(database[root] ?? {})) {
    if (!database.user_details?.[phone]) {
      throw new Error('Orphaned account data requires manual ownership reconciliation before migration');
    }
  }
}
const calendar = value => {
  const slash = /^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/.exec(String(value));
  const iso = /^(\d{4})-(\d{2})-(\d{2})(?:T.*)?$/.exec(String(value));
  if (!slash && !iso) throw new Error('A legacy date requires manual reconciliation');
  const [day, month, year] = slash
    ? [Number(slash[1]), Number(slash[2]), Number(slash[3])]
    : [Number(iso[3]), Number(iso[2]), Number(iso[1])];
  const epoch = Date.UTC(year, month - 1, day), parsed = new Date(epoch);
  if (year < 2000 || year > 9999 || parsed.getUTCFullYear() !== year ||
      parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day ||
      epoch > Date.now() + 50400000) throw new Error('Invalid/future legacy date requires manual reconciliation');
  return { canonical: `${day}/${month}/${year}`, date_year: year,
    date_month: month, date_day: day, date_epoch: epoch };
};
const prepareDate = (path, field, value) => {
  const { canonical, ...fields } = calendar(value);
  updates[`${path}/${field}`] = canonical;
  for (const [key, value] of Object.entries(fields)) updates[`${path}/${key}`] = value;
};
const categories = new Set(['Food', 'Shopping', 'Transport', 'Education', 'HealthCare', 'Entertainment', 'Add Money', 'Other']);
const modes = new Set(['Spent Cash', 'Spent Online', 'Add CASH', 'Add Online', 'Owed']);
const prepareRecord = (path, record, friend) => {
  const amount = String(record.Amount).trim();
  if (!/^(0|[1-9][0-9]{0,11})(\.\d{1,2})?$/.test(amount) || /^0(\.0{1,2})?$/.test(amount)) {
    throw new Error('Invalid legacy amount requires manual reconciliation');
  }
  const [whole, fraction = ''] = amount.split('.');
  updates[`${path}/Amount`] = `${whole}.${fraction.padEnd(2, '0')}`;
  const mode = String(record.Payment_Mode ?? '').startsWith('Owed to ') ? 'Owed' : record.Payment_Mode;
  if (!modes.has(mode)) throw new Error('Unsupported legacy payment mode requires manual reconciliation');
  updates[`${path}/Payment_Mode`] = mode;
  if (friend ? !['Give Money To Friend', 'Take Money From Friend'].includes(record.Type) : !categories.has(record.Category)) {
    throw new Error('Unsupported legacy transaction classification requires manual reconciliation');
  }
  if (typeof record.timestamp !== 'number' || record.timestamp < 946684800000 || record.timestamp > Date.now()) {
    throw new Error('A legacy timestamp requires manual reconciliation');
  }
  prepareDate(path, 'Date', record.Date);
};
for (const [phone, profile] of Object.entries(database.user_details ?? {})) {
  if (!/^\d{10}$/.test(phone)) throw new Error('Invalid exported account identifier');
  const uid = owners[phone];
  if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) throw new Error('Every legacy account needs an independently verified UID mapping');
  if (profile.owner_uid && profile.owner_uid !== uid) throw new Error('Existing owner conflicts with confirmed mapping');
  updates[`user_details/${phone}/owner_uid`] = uid;

  const groups = new Map();
  const link = (key, path, record) => {
    const branch = /^(.{20})_(?:expense_|debt_)?\d+$/.exec(key);
    const operation = record.split_id ?? branch?.[1] ?? key;
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(operation)) {
      throw new Error('An invalid operation identifier requires manual reconciliation');
    }
    const records = groups.get(operation) ?? [];
    records.push({ path, generated: Boolean(record.split_id || branch) });
    groups.set(operation, records);
  };
  for (const [key, record] of Object.entries(database.Expenses?.[phone] ?? {})) {
    const path = `Expenses/${phone}/${key}`;
    prepareRecord(path, record, false);
    link(key, path, record);
  }
  for (const [friend, details] of Object.entries(database.Friends?.[phone] ?? {})) {
    if (!/^\d{10}$/.test(friend) || friend === phone) throw new Error('Invalid legacy friend identifier');
    if (details.date != null) prepareDate(`Friends/${phone}/${friend}`, 'date', details.date);
    for (const [key, record] of Object.entries(details.Records ?? {})) {
      const path = `Friends/${phone}/${friend}/Records/${key}`;
      prepareRecord(path, record, true);
      link(key, path, record);
    }
  }
  for (const [operation, records] of groups) {
    // Retained markers also prevent resurrection of an older uncertain write.
    if (!database.WriteOperations?.[phone]?.[operation]) {
      updates[`WriteOperations/${phone}/${operation}`] = { timestamp: Date.now() };
    }
    if (records.length > 1 || records.some(record => record.generated)) {
      for (const record of records) updates[`${record.path}/split_id`] = operation;
    }
  }
}
process.stdout.write(`${JSON.stringify(updates, null, 2)}\n`);
