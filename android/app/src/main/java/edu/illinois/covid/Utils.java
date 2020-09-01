/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package edu.illinois.covid;

import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.text.format.DateUtils;
import android.util.Log;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Formatter;
import java.util.HashMap;
import java.util.Locale;

public class Utils {

    public static void showDialog(Context context, String title, String message,
                                  DialogInterface.OnClickListener positiveListener, String positiveText,
                                  DialogInterface.OnClickListener negativeListener, String negativeText,
                                  boolean cancelable) {
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setTitle(title);
        builder.setMessage(message);
        builder.setCancelable(cancelable);

        if (positiveListener != null)
            builder.setPositiveButton(positiveText, positiveListener);

        if (negativeListener != null)
            builder.setNegativeButton(negativeText, negativeListener);

        AlertDialog alertDialog = builder.create();
        alertDialog.show();
    }

    public static void enabledBluetooth() {
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter != null) {
            bluetoothAdapter.enable();
        }
    }

    public static class DateTime {

        static Date getDateTime(String dateTimeString) {
            if (dateTimeString == null || dateTimeString.isEmpty()) {
                return null;
            }
            SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault());
            Date dateTime = null;
            try {
                dateTime = dateFormat.parse(dateTimeString);
            } catch (ParseException e) {
                Log.e("Error", "Failed to parse '" + dateTimeString + "' to date time");
                e.printStackTrace();
            }
            return dateTime;
        }

        static String formatEventTime(Context context, Date dateTime) {
            if (dateTime == null) {
                return null;
            }
            Calendar calendarDate = Calendar.getInstance();
            int minutes = calendarDate.get(Calendar.MINUTE);
            Calendar today = Calendar.getInstance();
            calendarDate.setTime(dateTime);
            boolean zeroMins = (minutes == 0);
            boolean currentYear = calendarDate.get(Calendar.YEAR) == today.get(Calendar.YEAR);
            final String defaultStringFormat = String.format("%sMMM dd h%s a", (currentYear ? "" : "yy, "), (zeroMins ? "" : ":mm"));
            String defaultValue = new SimpleDateFormat(defaultStringFormat, Locale.getDefault()).format(dateTime);
            SimpleDateFormat dateFormat;
            String datePrefix;
            String timeSuffix;
            String format = zeroMins ? "h a" : "h:mm a";
            dateFormat = new SimpleDateFormat(format, Locale.getDefault());
            timeSuffix = dateFormat.format(dateTime);
            boolean isToday = DateUtils.isToday(dateTime.getTime());
            if (isToday) {
                datePrefix = context.getString(R.string.today) + " " + context.getString(R.string.at);
            } else if (calendarDate.after(today)) {
                int dateDayOfYear = calendarDate.get(Calendar.DAY_OF_YEAR);
                int todayDateOfYear = today.get(Calendar.DAY_OF_YEAR);
                int dateDiff = (dateDayOfYear - todayDateOfYear);
                boolean sameYear = (today.get(Calendar.YEAR) == calendarDate.get(Calendar.YEAR));
                if ((dateDiff == 1) && sameYear) {
                    datePrefix = context.getString(R.string.tomorrow) + " " + context.getString(R.string.at);
                } else if ((dateDiff < 7) && sameYear) {
                    dateFormat = new SimpleDateFormat("EEEE", Locale.getDefault());
                    datePrefix = dateFormat.format(dateTime) + " " + context.getString(R.string.at);
                } else {
                    return defaultValue;
                }
            } else {
                return defaultValue;
            }
            return String.format("%s %s", datePrefix, timeSuffix);
        }

        public static long getCurrentTimeMillisSince1970() {
            return System.currentTimeMillis();
        }
    }

    public static class Map {

        public static String getValueFromPath(Object object, String path, String defaultValue) {
            Object valueObject = getValueFromPath(object, path);
            return (valueObject instanceof String) ? (String)valueObject : defaultValue;
        }

        public static int getValueFromPath(Object object, String path, int defaultValue) {
            Object valueObject = getValueFromPath(object, path);
            return (valueObject instanceof Integer) ? (Integer) valueObject : defaultValue;
        }

        public static long getValueFromPath(Object object, String path, long defaultValue) {
            Object valueObject = getValueFromPath(object, path);
            return (valueObject instanceof Long) ? (Long) valueObject : defaultValue;
        }

        public static double getValueFromPath(Object object, String path, double defaultValue) {
            Object valueObject = getValueFromPath(object, path);
            return (valueObject instanceof Double) ? (Double) valueObject : defaultValue;
        }

        public static boolean getValueFromPath(Object object, String path, boolean defaultValue) {
            Object valueObject = getValueFromPath(object, path);
            return (valueObject instanceof Boolean) ? (Boolean) valueObject : defaultValue;
        }

        private static Object getValueFromPath(Object object, String path) {
            if (!(object instanceof java.util.Map) || Str.isEmpty(path)) {
                return null;
            }
            java.util.Map map = (java.util.Map) object;
            int dotFirstIndex = path.indexOf(".");
            while (dotFirstIndex != -1) {
                String subPath = path.substring(0, dotFirstIndex);
                path = path.substring(dotFirstIndex + 1);
                Object innerObject = (map != null) ? map.get(subPath) : null;
                map = (innerObject instanceof HashMap) ? (HashMap) innerObject : null;
                dotFirstIndex = path.indexOf(".");
            }
            Object generalValue = (map != null) ? map.get(path) : null;
            return getPlatformValue(generalValue);
        }

        private static Object getPlatformValue(Object object) {
            if (object instanceof HashMap) {
                HashMap hashMap = (HashMap) object;
                return hashMap.get("android");
            } else {
                return object;
            }
        }
    }

    public static class Str {
        public static boolean isEmpty(String value) {
            return (value == null) || value.isEmpty();
        }

        public static String nullIfEmpty(String value) {
            if (isEmpty(value)) {
                return null;
            }
            return value;
        }

        public static byte[] hexStringToByteArray(String s) {
            if(s != null) {
                int len = s.length();
                byte[] data = new byte[len / 2];
                for (int i = 0; i < len; i += 2) {
                    data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                            + Character.digit(s.charAt(i + 1), 16));
                }
                return data;
            }
            return null;
        }

        public static String byteArrayToHexString(byte[] bytes){
            if(bytes != null) {
                Formatter formatter = new Formatter();
                for (byte b : bytes) {
                    formatter.format("%02x", b);
                }
                return formatter.toString();
            }
            return null;
        }

    }

    public static class Base64 {

        public static byte[] decode(String value) {
            if (value != null) {
                return android.util.Base64.decode(value, android.util.Base64.NO_WRAP);
            } else {
                return null;
            }
        }

        public static String encode(byte[] bytes) {
            if (bytes != null) {
                return android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP);
            } else {
                return null;
            }
        }
    }

    public static class BackupStorage {

        public static String getString(Context context, String fileName, String key) {
            if ((context == null) || Str.isEmpty(fileName) || Str.isEmpty(key)) {
                return null;
            }
            SharedPreferences sharedPreferences = context.getSharedPreferences(fileName, Context.MODE_PRIVATE);
            return sharedPreferences.getString(key, null);
        }

        public static void saveString(Context context, String fileName, String key, String value) {
            if ((context == null) || Str.isEmpty(fileName) || Str.isEmpty(key)) {
                return;
            }
            SharedPreferences sharedPreferences = context.getSharedPreferences(fileName, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.putString(key, value);
            editor.apply();
            AppBackupAgent.requestBackup(context);
        }

        public static void remove(Context context, String fileName, String key) {
            if ((context == null) || Str.isEmpty(fileName) || Str.isEmpty(key)) {
                return;
            }
            SharedPreferences sharedPreferences = context.getSharedPreferences(fileName, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.remove(key);
            editor.apply();
            AppBackupAgent.requestBackup(context);
        }
    }
}
