# Sunup ☀️

A simple, personal morning-routine game built for an ADHD brain.
Get up fast, keep moving, earn XP Monday–Friday, then check in and cash out in the store on Fridays.

**Live at:** https://warmfridge.github.io/

## The rules

| | |
|---|---|
| **+10 XP** | Up within 10 min of that day's alarm (7:25 alarm → by 7:35) |
| **+5 XP** | Up by 7:49 |
| **+1 XP** | 7:50 or later. It still counts |
| **+3 XP** | 💇 Hair (done or not) |
| **+3 XP** | 🧼 Wash face |
| **+3 XP** | 🪥 Brush teeth |
| **+2 XP** | 🍳 Eat something |
| **−5 XP** | Stationary 10+ min before the routine is done (max once a morning) |

A perfect morning is **21 XP**, so a perfect week is **105 XP**. Cash out $100 and 5 XP carries over.

- Routine: 🛏️ Get out of bed → 💇 Hair → 🧼 Wash face → 🪥 Brush teeth → 🍳 Eat something. Steps and their points can be edited in Settings.
- Each weekday has its own alarm (e.g. 7:25 or 6:25), set in Settings. On a morning that's different, tap 6:25 / 7:25 on the Today screen.
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

## Android app (APK)

Download the latest build: **https://github.com/WarmFridge/WarmFridge.github.io/releases/latest/download/sunup.apk**

Open that link on your Android phone, allow your browser to "install unknown apps" when asked, then tap Install.
The app version has real reminders that ring even when Sunup is closed. These are the wake-up at your alarm time, "1 minute left for +10", keep-moving nudges during the routine, and the Friday check-in.

The APK is built automatically by GitHub Actions (`.github/workflows/android.yml`) every time the app changes.
The Android project lives in `android-app/` (Capacitor). `npm run sync` copies the web app into it.

**Updates without reinstalling:** Android only installs an update over an existing app if both are signed with the same key.
To make that permanent, add these repository secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
Without them, each build is signed with its own key. Back up in the app, uninstall, install the new APK, then restore.

## Notifications (website)

1. **Calendar alarms** (Settings → Reminders). These work even when Sunup is closed. One tap adds a Mon–Fri wake-up reminder and a Friday check-in reminder to your phone's calendar.
2. **Live nudges** while your routine is running: "1 min left for +10" and "2 min to dodge −5". You get a sound, a vibration and a banner, plus a phone notification if you allow it.

## Your data

Everything stays on your device (no account, no server). Use **Settings → Back up** now and then, and **Restore** if you switch phones.

## Files

- `index.html`, `styles.css`, `app.js`: the app (plain HTML/CSS/JS, no build step)
- `ics.js`: builds the calendar reminder files
- `reminders/`: pre-built calendar files. Regenerate them with `node tools/build-reminders.js`
- `sw.js`, `manifest.webmanifest`, `icons/`: offline support and install
- `android-app/`: Android wrapper (Capacitor). `native-src.js` adds scheduled notifications, the back button and backup sharing

When you change app files, bump `CACHE` in `sw.js` so installed copies pick up the update.
