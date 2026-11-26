#!/usr/bin/env node
/**
 * Feature parity check: what does the website use that the Flutter app does not?
 *
 *   node mobile/tool/parity.js                      # server/ and client/ next to mobile/
 *   node mobile/tool/parity.js --server <dir> --client <dir/src> [--json] [--strict]
 *
 * Reads every route the Express server mounts (server/app.js + routes/*.js),
 * the API calls the website makes (client/src) and the ones the app makes
 * (mobile/lib), and lists the endpoints the website calls and the app does not.
 * Endpoints that should stay web-only are listed, with a reason, in
 * parity_ignore.json. --strict exits with code 1 when something is missing (CI).
 */
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const mobileDir = path.resolve(__dirname, '..');
const serverDir = path.resolve(opt('--server') || path.join(mobileDir, '..', 'server'));
const clientDir = path.resolve(opt('--client') || path.join(serverDir, '..', 'client', 'src'));
const asJson = args.includes('--json');
const strict = args.includes('--strict');

const read = (p) => fs.readFileSync(p, 'utf8');
function walk(dir, exts, out = []) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) walk(p, exts, out);
        else if (exts.some((x) => p.endsWith(x))) out.push(p);
    }
    return out;
}
const join = (a, b) => ('/' + a + '/' + b).replace(/\/+/g, '/').replace(/(.)\/$/, '$1');

// ---- 1. Server endpoints ---------------------------------------------------
const appJs = read(path.join(serverDir, 'app.js'));
const endpoints = [];
const mountRe = /app\.use\(\s*['"`]([^'"`]+)['"`]\s*,[^;]*?require\(\s*['"`]\.\/routes\/([^'"`]+)['"`]\s*\)/g;
for (const m of appJs.matchAll(mountRe)) {
    const base = m[1].replace(/^\/api\/v1/, '');
    const file = m[2].replace(/\.js$/, '') + '.js';
    const src = read(path.join(serverDir, 'routes', file));
    for (const r of src.matchAll(/router\.(get|post|put|patch|delete)\(\s*['"`]([^'"`]+)['"`]/g)) {
        endpoints.push({ method: r[1].toUpperCase(), path: join(base, r[2]), file: `routes/${file}` });
    }
}

// ---- 2. Calls made by the app and by the website ---------------------------
// `.get(` / `.post(` ... calls (Dio, axios), fetch(`${API_BASE_URL}/...`) and
// '/api/v1/...' links (pictures, downloads: GET). Anything built from a
// variable becomes the segment ":x".
function normalise(raw) {
    let p = raw
        .replace(/\$\{[^}]*BASE[^}]*\}/g, '')
        .replace(/\$\{[^}]*\}|\$[A-Za-z_]\w*/g, ':x')
        .split('?')[0];
    p = p.replace(/^.*?\/api\/v1/, '');
    return p.startsWith('/') ? p.replace(/(.)\/$/, '$1') : null;
}
const LITERAL = /'([^'\r\n]*)'|"([^"\r\n]*)"|`([^`]*)`/g;
const literals = (text) => [...text.matchAll(LITERAL)].map((m) => m[1] ?? m[2] ?? m[3]);

function scan(files, base) {
    const out = [];
    for (const f of files) {
        const raw = read(f);
        const rel = path.relative(base, f).replace(/\\/g, '/');
        // Paths kept in a name (String get _base => '/x/${id}'; const p = '/x'):
        // put the value in place of the name, so calls like .put(_base) count.
        let src = raw;
        for (const m of raw.matchAll(/([A-Za-z_]\w*)\s*(?:=>|=)\s*(['"`])(\/[^'"`\r\n]*)\2/g)) {
            const [, name, , value] = m;
            src = src.split('${' + name + '}').join(value).split('$' + name + '/').join(value + '/');
            src = src.replace(new RegExp('(\\.(?:get|post|put|patch|delete)\\(\\s*)' + name + '\\b', 'g'), (_, head) => `${head}'${value}'`);
        }
        // path: '/x' parameters of widgets that load an endpoint (GET).
        for (const m of src.matchAll(/\bpath:\s*(['"`])(\/[^'"`]*)\1/g)) {
            const p = normalise(m[2]);
            if (p) out.push({ method: 'GET', path: p, file: rel });
        }
        for (const m of src.matchAll(/\.(get|post|put|patch|delete)\(\s*([^,;]*?)(?:,|\)\s*[;.\n)])/g)) {
            for (const lit of literals(m[2])) {
                const p = normalise(lit);
                if (p) out.push({ method: m[1].toUpperCase(), path: p, file: rel });
            }
        }
        for (const m of src.matchAll(/fetch\(\s*`([^`]+)`([\s\S]{0,200})/g)) {
            const p = normalise(m[1]);
            const method = ((m[2].match(/method:\s*['"](\w+)['"]/) || [])[1] || 'GET').toUpperCase();
            if (p) out.push({ method, path: p, file: rel });
        }
        for (const lit of literals(src)) {
            if (lit.includes('/api/v1/')) {
                const p = normalise(lit);
                if (p) out.push({ method: 'GET', path: p, file: rel });
            }
        }
    }
    return out;
}

const appCalls = scan(walk(path.join(mobileDir, 'lib'), ['.dart']), mobileDir);
const webCalls = fs.existsSync(clientDir)
    ? scan(walk(clientDir, ['.js', '.jsx']).filter((f) => !/\.test\.jsx?$/.test(f)), clientDir)
    : null;

// Same method, same number of segments; ":param" / ":x" match anything.
function matches(ep, call) {
    if (ep.method !== call.method) return false;
    const a = ep.path.split('/');
    const b = call.path.split('/');
    return a.length === b.length && a.every((s, i) => s.startsWith(':') || b[i].startsWith(':') || s === b[i]);
}
const usedBy = (calls) => endpoints.filter((ep) => calls.some((c) => matches(ep, c)));

const ignore = JSON.parse(read(path.join(__dirname, 'parity_ignore.json')));
const ignored = (ep) => ignore.some((i) => i.method === ep.method && i.path === ep.path);

const appUsed = usedBy(appCalls);
const webUsed = webCalls ? usedBy(webCalls) : endpoints;
const missing = webUsed.filter((ep) => !appUsed.includes(ep) && !ignored(ep));
const webOnly = webUsed.filter((ep) => !appUsed.includes(ep) && ignored(ep));
const unusedEverywhere = endpoints.filter((ep) => !appUsed.includes(ep) && !webUsed.includes(ep));
const stale = ignore.filter((i) => !endpoints.some((ep) => ep.method === i.method && ep.path === i.path));

if (asJson) {
    console.log(JSON.stringify({ endpoints: endpoints.length, website: webUsed.length, app: appUsed.length, missing, webOnly, unusedEverywhere, stale }, null, 2));
} else {
    console.log(`Server endpoints: ${endpoints.length}   used by the website: ${webUsed.length}   used by the app: ${appUsed.length}   web-only by choice: ${webOnly.length}`);
    if (missing.length) {
        console.log(`\nOn the website but not in the app (${missing.length}):`);
        for (const m of missing) console.log(`  ${m.method.padEnd(6)} /api/v1${m.path}   (${m.file})`);
        console.log('\nAdd them to the app, or list them in mobile/tool/parity_ignore.json with a reason.');
    } else {
        console.log('\nThe app has everything the website uses (apart from the web-only list).');
    }
    if (unusedEverywhere.length) {
        console.log(`\nCalled by neither (internal or legacy): ${unusedEverywhere.map((e) => `${e.method} ${e.path}`).join(', ')}`);
    }
    if (stale.length) console.log(`\nNo longer on the server (remove from parity_ignore.json): ${stale.map((s) => `${s.method} ${s.path}`).join(', ')}`);
}
process.exit(strict && missing.length ? 1 : 0);
