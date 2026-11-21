/* Native (Android) bridge for Sunup. Bundled into www/native.js by scripts/prepare-www.js.
   app.js uses window.SunupNative when it exists; the website never loads this file. */
import { Capacitor, SystemBars, SystemBarsStyle, registerPlugin } from '@capacitor/core';
import { LocalNotifications } from '@capacitor/local-notifications';
import { App } from '@capacitor/app';
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem';
import { Share } from '@capacitor/share';

// Our own plugin (android/app/src/main/java/…/PhoneAlarmPlugin.java): reads the Clock app's alarm.
const PhoneAlarm = registerPlugin('PhoneAlarm');

const CHANNEL = 'sunup-reminders';
let channelReady = null;
function ensureChannel() {
  if (!channelReady) {
    channelReady = LocalNotifications.createChannel({
      id: CHANNEL,
      name: 'Sunup reminders',
      description: 'Wake-up, keep-moving and Friday check-in nudges',
      importance: 5,
      visibility: 1,
      vibration: true,
      lights: true,
      lightColor: '#8B7CFF',
    }).catch(() => {});
  }
  return channelReady;
}

async function exactAllowed() {
  try {
    const s = await LocalNotifications.checkExactNotificationSetting();
    return s.exact_alarm === 'granted';
  } catch (e) {
    return true; // older Android: always allowed
  }
}

window.SunupNative = {
  isNative: Capacitor.isNativePlatform(),

  async permission() {
    try { return (await LocalNotifications.checkPermissions()).display; } catch (e) { return 'denied'; }
  },
  async requestPermission() {
    try { return (await LocalNotifications.requestPermissions()).display; } catch (e) { return 'denied'; }
  },

  /** Replace every pending Sunup notification with `list` ([{id, at, title, body}]). */
  async schedule(list) {
    await ensureChannel();
    const pending = await LocalNotifications.getPending();
    if (pending.notifications.length) {
      await LocalNotifications.cancel({ notifications: pending.notifications.map((n) => ({ id: n.id })) });
    }
    if (!list.length) return { count: 0, exact: true };
    // Never let the plugin bounce the user to the "Alarms & reminders" screen on every reschedule:
    // ask for exact timing only when Android already allows it (USE_EXACT_ALARM covers Android 13+).
    const exact = await exactAllowed();
    await LocalNotifications.schedule({
      notifications: list.map((n) => ({
        id: n.id,
        title: n.title,
        body: n.body,
        channelId: CHANNEL,
        smallIcon: 'ic_stat_sunup',
        iconColor: '#8B7CFF',
        autoCancel: true,
        isExactNotification: exact,
        schedule: { at: new Date(n.at), allowWhileIdle: true },
      })),
    });
    return { count: list.length, exact };
  },

  /** The phone's alarms: { next: epoch ms (if any), log: { 'YYYY-MM-DD': 'HH:MM' } } of mornings seen. */
  async phoneAlarms() {
    try { return await PhoneAlarm.read(); } catch (e) { return null; }
  },

  clearDelivered() {
    LocalNotifications.removeAllDeliveredNotifications().catch(() => {});
  },

  onBack(fn) { App.addListener('backButton', fn); },
  onResume(fn) { App.addListener('appStateChange', (s) => { if (s.isActive) fn(); }); },
  exit() { App.exitApp(); },

  async setBarStyle(darkTheme) {
    try { await SystemBars.setStyle({ style: darkTheme ? SystemBarsStyle.Dark : SystemBarsStyle.Light }); } catch (e) { /* cosmetic */ }
  },

  /** Save text to a file and open the Android share sheet (Drive, Files, email…). */
  async shareFile(name, text) {
    const r = await Filesystem.writeFile({ path: name, data: text, directory: Directory.Cache, encoding: Encoding.UTF8 });
    await Share.share({ title: name, dialogTitle: 'Save your Sunup backup', files: [r.uri] });
  },
};
