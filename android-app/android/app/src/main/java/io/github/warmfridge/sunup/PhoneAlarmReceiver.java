package io.github.warmfridge.sunup;

import android.app.AlarmManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Runs on the nightly check, after a reboot or app update, and when the next alarm changes. */
public class PhoneAlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : null;
        if (action == null) return;
        switch (action) {
            case AlarmLog.ACTION_NIGHTLY:
            case Intent.ACTION_BOOT_COMPLETED:
            case Intent.ACTION_MY_PACKAGE_REPLACED:
                AlarmLog.capture(context);
                AlarmLog.scheduleNightly(context);
                break;
            case AlarmManager.ACTION_NEXT_ALARM_CLOCK_CHANGED:
                AlarmLog.capture(context);
                break;
            default:
                break;
        }
    }
}
