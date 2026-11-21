#!/usr/bin/env node
/* Copies the Sunup web app (repo root) into android-app/www and bundles the native bridge. */
const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');

const app = path.join(__dirname, '..');
const root = path.join(app, '..');
const www = path.join(app, 'www');

fs.rmSync(www, { recursive: true, force: true });
fs.mkdirSync(path.join(www, 'icons'), { recursive: true });

for (const f of ['styles.css', 'app.js', 'ics.js']) fs.copyFileSync(path.join(root, f), path.join(www, f));
for (const f of ['icon.svg', 'icon-192.png']) fs.copyFileSync(path.join(root, 'icons', f), path.join(www, 'icons', f));

// Same page as the website, plus the native bridge loaded before app.js.
let html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const tag = '<script src="ics.js" defer></script>';
if (!html.includes(tag)) throw new Error('index.html changed: could not find the ics.js script tag');
html = html
  .replace(tag, '<script src="native.js" defer></script>\n  ' + tag)
  .replace(/\s*<link rel="manifest"[^>]*>/, '');
fs.writeFileSync(path.join(www, 'index.html'), html);

esbuild.buildSync({
  entryPoints: [path.join(app, 'native-src.js')],
  bundle: true,
  format: 'iife',
  target: 'es2019',
  minify: true,
  outfile: path.join(www, 'native.js'),
  logLevel: 'warning',
});
console.log('www ready:', fs.readdirSync(www).join(', '));
