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

package edu.illinois.rokwire.exposure;

import edu.illinois.rokwire.Constants;

class ExposureRecord {
    private long timestampCreated;
    private long timestampUpdated;
    private int lastRssi;
    private long durationInterval;

    ExposureRecord(long timestamp, int rssi) {
        this.timestampCreated = timestamp;
        this.timestampUpdated = timestamp;
        this.lastRssi = rssi;
        this.durationInterval = 0;
    }

    void updateTimeStamp(long timestamp, int rssi) {
        int rssiMinValue = Constants.EXPOSURE_MIN_RSSI_VALUE;
        if (ExposurePlugin.getInstance() != null) {
            rssiMinValue = ExposurePlugin.getInstance().getExposureMinRssi();
        }
        if ((rssiMinValue <= lastRssi) && (lastRssi != Constants.EXPOSURE_NO_RSSI_VALUE)) {
            durationInterval += (timestamp - timestampUpdated);
        }
        lastRssi = rssi;
        timestampUpdated = timestamp;
    }

    /**
     * @return duration in milliseconds
     */
    long getDuration() {
        return durationInterval;
    }

    long getTimestampCreated() {
        return timestampCreated;
    }

    long getTimestampUpdated() {
        return timestampUpdated;
    }
}
