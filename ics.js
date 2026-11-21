/* Sunup — calendar reminder builder (.ics).
   Shared by the app (download fallback) and tools/build-reminders.js (static files). */
(function (root) {
  'use strict';

  var APP_URL = 'https://warmfridge.github.io/';

  function pad(n) { return String(n).padStart(2, '0'); }

  function text(s) {
    return String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
  }

  // RFC 5545: lines longer than 75 octets are folded (CRLF + space).
  function fold(line) {
    var enc = new TextEncoder();
    var out = '', cur = '', len = 0;
    for (var ch of line) {
      var n = enc.encode(ch).length;
      if (len + n > 74) { out += cur + '\r\n '; cur = ''; len = 1; }
      cur += ch; len += n;
    }
    return out + cur;
  }

  var BYDAY = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

  /**
   * kind: 'wake' (weekdays) or 'friday' (Fridays).
   * times: '07:25', or for 'wake' a map of weekday → time, e.g. {1:'07:25', 2:'06:25', …, 5:'07:25'}.
   * Times are "floating" (no time zone), so they follow the phone's local time.
   */
  function build(kind, times, appUrl) {
    var wake = kind === 'wake';
    var url = appUrl || APP_URL;
    var map = typeof times === 'string' ? (wake ? { 1: times, 2: times, 3: times, 4: times, 5: times } : { 5: times }) : times;
    var groups = {};
    Object.keys(map).sort().forEach(function (d) { (groups[map[d]] = groups[map[d]] || []).push(Number(d)); });
    var hhmms = Object.keys(groups).sort();

    var summary = wake ? '☀️ Sunup — get up! Up within 10 min = +10' : '🎁 Sunup — Friday check-in. Store is open!';
    var desc = wake
      ? 'Open Sunup and tap “I’m up”.\nUp within 10 min of your alarm = +10 · within 24 min = +5 · later = +1.\nThen keep moving: 10 min stuck before you’re done = −5.\n' + url
      : 'Open Sunup, collect your week of XP and cash out in the store. XP carries over.\n' + url;
    var alarm = wake ? 'Get up now — +10 for the next 10 minutes' : 'Friday check-in — collect your XP, the store is open';

    var lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Sunup//Morning XP//EN', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
    hhmms.forEach(function (hhmm) {
      var p = String(hhmm).split(':'), h = Number(p[0]) || 0, m = Number(p[1]) || 0;
      var days = groups[hhmm];
      // Anchor in the week of Mon 16 Nov 2026 on the first day of this group.
      var start = '202611' + pad(15 + days[0]) + 'T' + pad(h) + pad(m) + '00';
      lines.push(
        'BEGIN:VEVENT',
        'UID:sunup-' + kind + (hhmms.length > 1 ? '-' + pad(h) + pad(m) : '') + '@warmfridge.github.io',
        'DTSTAMP:20261121T000000Z',
        'DTSTART:' + start,
        'DURATION:PT15M',
        'RRULE:FREQ=WEEKLY;BYDAY=' + days.map(function (d) { return BYDAY[d]; }).join(','),
        'SUMMARY:' + text(summary),
        'DESCRIPTION:' + text(desc),
        'URL:' + url,
        'TRANSP:TRANSPARENT',
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:' + text(alarm),
        'TRIGGER:PT0S',
        'END:VALARM',
        'END:VEVENT'
      );
    });
    lines.push('END:VCALENDAR');
    return lines.map(fold).join('\r\n') + '\r\n';
  }

  // Static files shipped in /reminders cover these ranges (see tools/build-reminders.js).
  var RANGES = {
    wake: { from: 4 * 60, to: 11 * 60 + 55, step: 5 },
    friday: { from: 6 * 60, to: 22 * 60, step: 30 }
  };

  function staticPath(kind, hhmm) {
    var r = RANGES[kind];
    if (!r) return null;
    var p = String(hhmm).split(':');
    var mins = Number(p[0]) * 60 + Number(p[1]);
    if (!(mins >= r.from && mins <= r.to) || mins % r.step) return null;
    return 'reminders/' + kind + '-' + pad(p[0]) + pad(p[1]) + '.ics';
  }

  var api = { build: build, staticPath: staticPath, RANGES: RANGES, pad: pad };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.SunupICS = api;
})(this);
