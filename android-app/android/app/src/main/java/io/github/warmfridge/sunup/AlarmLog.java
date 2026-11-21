package io.github.warmfridge.sunup;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Remembers the phone's morning alarms (from the Clock app) by date, so Sunup can score
 * from the real alarm even after it has rung. Android only exposes the *next* alarm, so it
 * is sampled nightly, at boot, whenever it changes, and whenever the app opens.
 */
final class AlarmLog {
    static final String ACTION_NIGHTLY = "io.github.warmfridge.sunup.CHECK_PHONE_ALARM";
    private static final String PREFS = "sunup_phone_alarms";
    private static final String KEY_LOG = "log";
    private static final int NIGHTLY_REQUEST = 7700;
    private static final long DAY_MS = 24L * 60 * 60 * 1000;

    private AlarmLog() {}

    /** Record the next alarm against its date; forget upcoming ones that were switched off. */
    static synchronized JSONObject capture(Context ctx) {
        JSONObject log = read(ctx);
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        AlarmManager.AlarmClockInfo info = am != null ? am.getNextAlarmClock() : null;
        long now = System.currentTimeMillis();
        long next = info != null ? info.getTriggerTime() : Long.MAX_VALUE;

        List<String> drop = new ArrayList<>();
        Iterator<String> days = log.keys();
        while (days.hasNext()) {
            String day = days.next();
            long t = millisOf(day, log.optString(day, ""));
            boolean gone = t > now && t < next; // was still to come, but it's no longer the next alarm
            boolean old = t < now - 21 * DAY_MS;
            if (t < 0 || gone || old) drop.add(day);
        }
        for (String day : drop) log.remove(day);

        if (info != null) {
            Calendar c = Calendar.getInstance();
            c.setTimeInMillis(next);
            int hour = c.get(Calendar.HOUR_OF_DAY);
            if (hour >= 3 && hour < 12) { // morning alarms only
                String day = dayKey(c);
                long prev = millisOf(day, log.optString(day, ""));
                // Once a morning's alarm has rung, keep it: snoozing must not move the target.
                if (prev < 0 || prev > now) {
                    try {
                        log.put(day, String.format(Locale.US, "%02d:%02d", hour, c.get(Calendar.MINUTE)));
                    } catch (JSONException ignored) {
                        // keep the previous log
                    }
                }
            }
        }
        prefs(ctx).edit().putString(KEY_LOG, log.toString()).apply();
        return log;
    }

    static JSONObject read(Context ctx) {
        try {
            return new JSONObject(prefs(ctx).getString(KEY_LOG, "{}"));
        } catch (JSONException e) {
            return new JSONObject();
        }
    }

    /** Check again at 2:30 every night, before any morning alarm can ring. */
    static void scheduleNightly(Context ctx) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        Intent intent = new Intent(ctx, PhoneAlarmReceiver.class).setAction(ACTION_NIGHTLY);
        PendingIntent pi = PendingIntent.getBroadcast(
            ctx, NIGHTLY_REQUEST, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 2);
        c.set(Calendar.MINUTE, 30);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        if (c.getTimeInMillis() <= System.currentTimeMillis()) c.add(Calendar.DAY_OF_MONTH, 1);
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, c.getTimeInMillis(), pi);
    }

    private static SharedPreferences prefs(Context ctx) {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static String dayKey(Calendar c) {
        return String.format(Locale.US, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
    }

    private static long millisOf(String day, String hhmm) {
        try {
            String[] d = day.split("-");
            String[] t = hhmm.split(":");
            Calendar c = Calendar.getInstance();
            c.set(Integer.parseInt(d[0]), Integer.parseInt(d[1]) - 1, Integer.parseInt(d[2]),
                Integer.parseInt(t[0]), Integer.parseInt(t[1]), 0);
            c.set(Calendar.MILLISECOND, 0);
            return c.getTimeInMillis();
        } catch (RuntimeException e) {
            return -1;
        }
    }
}
