# Sunup ☀️

A simple, personal morning-routine game built for an ADHD brain.
Get up fast, keep moving, earn XP Monday–Friday, then check in and cash out in the store on Fridays.

**Live at:** https://warmfridge.github.io/

## The rules

| | |
|---|---|
| **+10 XP** | Up within 5 min of your alarm |
| **+5 XP** | Up within 10 min |
| **+1 XP** | Up later. It still counts |
| **−5 XP** | Stationary 10+ min before the routine is done (max once a morning) |

- Routine: 🛏️ Get out of bed → 💇 Hair → 🧼 Wash face → 🍳 Eat something. You can edit it in Settings.
- Tracked **Monday–Friday** only. Weekends never break your streak.
- **Friday check-in:** look back at the week and bank your XP.
- **Store opens on Fridays only.** XP carries over forever.

| Reward | Cost |
|---|---|
| 🍜 Food treat | 25 XP |
| 🧩 Toys & board games | 50 XP |
| 🫧 Anything sensory | 75 XP |
| 💵 $100 to spend on anything | 100 XP |

## Put it on your phone

- **iPhone:** open the site in Safari → Share → **Add to Home Screen**.
- **Android:** open in Chrome → ⋮ → **Install app**.

Once it's on your Home Screen it opens full-screen and works offline. On iPhone, notifications only work from the Home Screen version.

## Notifications

1. **Calendar alarms** (Settings → Reminders). These work even when Sunup is closed. One tap adds a Mon–Fri wake-up reminder and a Friday check-in reminder to your phone's calendar.
2. **Live nudges** while your routine is running: "1 min left for +10" and "2 min to dodge −5". You get a sound, a vibration and a banner, plus a phone notification if you allow it.

## Your data

Everything stays on your device (no account, no server). Use **Settings → Back up** now and then, and **Restore** if you switch phones.

## Files

- `index.html`, `styles.css`, `app.js`: the app (plain HTML/CSS/JS, no build step)
- `ics.js`: builds the calendar reminder files
- `reminders/`: pre-built calendar files. Regenerate them with `node tools/build-reminders.js`
- `sw.js`, `manifest.webmanifest`, `icons/`: offline support and install

When you change app files, bump `CACHE` in `sw.js` so installed copies pick up the update.
