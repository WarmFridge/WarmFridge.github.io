package io.github.warmfridge.sunup;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(PhoneAlarmPlugin.class); // reads the Clock app's alarm (see AlarmLog)
        super.onCreate(savedInstanceState);
    }
}
