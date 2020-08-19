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

import android.app.backup.BackupAgentHelper;
import android.app.backup.BackupManager;
import android.app.backup.SharedPreferencesBackupHelper;
import android.content.Context;
import android.util.Log;

public class AppBackupAgent extends BackupAgentHelper {
    private static final String PREFS_BACKUP_KEY = "prefs";

    @Override
    public void onCreate() {
        SharedPreferencesBackupHelper healthHelper = new SharedPreferencesBackupHelper(this, Constants.HEALTH_SHARED_PREFS_FILE_NAME);
        addHelper(PREFS_BACKUP_KEY, healthHelper);

        SharedPreferencesBackupHelper exposureTeksHelper = new SharedPreferencesBackupHelper(this, Constants.EXPOSURE_TEKS_SHARED_PREFS_FILE_NAME);
        addHelper(PREFS_BACKUP_KEY, exposureTeksHelper);
    }

    public static void requestBackup(Context context) {
        Log.i("AppBackupAgent", "requestBackup");
        BackupManager backupManager = new BackupManager(context);
        backupManager.dataChanged();
    }
}
