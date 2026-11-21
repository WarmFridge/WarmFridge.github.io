#!/usr/bin/env node
/* Generates the static calendar files in /reminders.
   Run from the repo root:  node tools/build-reminders.js
   Static https links open straight into the iPhone/Android "Add to Calendar" screen,
   which is more reliable than in-app downloads. Times outside these ranges fall back
   to an in-app download (see ics.js). */
const fs = require('fs');
const path = require('path');
const ics = require('../ics.js');

const out = path.join(__dirname, '..', 'reminders');
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

let n = 0;
for (const kind of Object.keys(ics.RANGES)) {
  const r = ics.RANGES[kind];
  for (let mins = r.from; mins <= r.to; mins += r.step) {
    const hhmm = `${ics.pad(Math.floor(mins / 60))}:${ics.pad(mins % 60)}`;
    fs.writeFileSync(path.join(__dirname, '..', ics.staticPath(kind, hhmm)), ics.build(kind, hhmm));
    n++;
  }
}
console.log(`Wrote ${n} calendar files to /reminders`);
