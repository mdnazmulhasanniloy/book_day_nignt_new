// Fails fast (before any connection) unless TEST_DATABASE_URL names a *_test or *_rehearsal database.
const url = process.env.TEST_DATABASE_URL;
if (!url) { console.error('TEST_DATABASE_URL is not set'); process.exit(1); }
let name = '';
try { name = decodeURIComponent(new URL(url).pathname.replace(/^\//, '')); } catch { console.error('TEST_DATABASE_URL is not a valid URL'); process.exit(1); }
if (!/_(test|rehearsal)$/.test(name)) { console.error(`Refusing: database "${name}" must end in _test or _rehearsal`); process.exit(1); }
