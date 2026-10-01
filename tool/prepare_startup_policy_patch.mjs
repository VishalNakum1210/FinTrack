import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Offline-only mechanical merge. Never deploy the repository's full hardened
// rules as a substitute for this small, backwards-compatible production patch.
export function patchStartupPolicy(before) {
  assert.ok(before?.rules && typeof before.rules === 'object', 'Missing rules object');
  assert.equal(before.rules['.read'], false, 'Root read access must remain denied');
  assert.equal(before.rules['.write'], false, 'Root write access must remain denied');
  const after = structuredClone(before);
  const config = after.rules.app_config ??= {};
  assert.ok(config['.write'] == null || config['.write'] === false,
    'An ancestor must not permit client policy writes');
  const minimum = config.min_version ??= {};
  minimum['.read'] = true;
  minimum['.write'] = false;
  const unchangedBefore = structuredClone(before);
  const unchangedAfter = structuredClone(after);
  delete unchangedBefore.rules.app_config;
  delete unchangedAfter.rules.app_config;
  assert.deepEqual(unchangedAfter, unchangedBefore, 'Unrelated rules must not change');
  return after;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [, , input, output] = process.argv;
  assert.ok(input && output, 'Usage: node tool/prepare_startup_policy_patch.mjs BEFORE_JSON AFTER_JSON');
  assert.notEqual(resolve(input), resolve(output), 'Never overwrite the rollback copy');
  assert.equal(dirname(resolve(input)), dirname(resolve(output)), 'Keep the patch beside its rollback copy');
  const before = JSON.parse(await readFile(input, 'utf8'));
  await writeFile(output, `${JSON.stringify(patchStartupPolicy(before), null, 2)}\n`, { flag: 'wx' });
  console.log('Prepared startup-only rule patch; no network requests or data migration performed.');
}
