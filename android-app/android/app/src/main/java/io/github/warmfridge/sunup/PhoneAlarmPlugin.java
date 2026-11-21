package io.github.warmfridge.sunup;

import android.app.AlarmManager;
import android.content.Context;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import org.json.JSONException;
import org.json.JSONObject;

/** Lets the app read the phone's alarms: the next one, plus the mornings already recorded. */
@CapacitorPlugin(name = "PhoneAlarm")
public class PhoneAlarmPlugin extends Plugin {
    @PluginMethod
    public void read(PluginCall call) {
        Context ctx = getContext();
        JSONObject log = AlarmLog.capture(ctx);
        AlarmLog.scheduleNightly(ctx);
        JSObject result = new JSObject();
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        AlarmManager.AlarmClockInfo info = am != null ? am.getNextAlarmClock() : null;
        if (info != null) result.put("next", info.getTriggerTime());
        try {
            result.put("log", JSObject.fromJSONObject(log));
        } catch (JSONException e) {
            result.put("log", new JSObject());
        }
        call.resolve(result);
    }
}
