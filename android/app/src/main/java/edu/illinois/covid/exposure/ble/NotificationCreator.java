package edu.illinois.covid.exposure.ble;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

import androidx.core.app.NotificationCompat;
import edu.illinois.covid.MainActivity;
import edu.illinois.covid.R;

class NotificationCreator {
    private static final int ONGOING_NOTIFICATION_ID = 1;
    private static final String CHANNEL_ID = "RokwireContactTracingNotificationChannel";
    private static Notification notification;

    static Notification getNotification(Context context) {
        if (context != null) {
            if (notification == null) {
                Intent notificationIntent = new Intent(context, MainActivity.class);
                PendingIntent pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        notificationIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT);

                NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                        .setContentTitle(context.getString(R.string.exposure_notification_title))
                        .setSmallIcon(R.drawable.app_icon)
                        .setContentIntent(pendingIntent)
                        .setTicker(context.getString(R.string.exposure_notification_ticker));

                notification = builder.build();
            }
        }
        return notification;
    }

    static String getChannelId() {
        return CHANNEL_ID;
    }

    static int getOngoingNotificationId() {
        return ONGOING_NOTIFICATION_ID;
    }
}
