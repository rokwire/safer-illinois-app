# Pull request: 

This pull request adds a new way to measure the attenuation of Bluetooth signal as described by Google: https://developers.google.com/android/exposure-notifications/ble-attenuation-overview. This method helps us find attenuation values without the need of Tx_power of host devices. 
This PR aims to replace the MinRSSI filtering you've included in earlier versions. (included in this PR) With the RSSI values we can also use it as a rough approximation of distance and improve the exposure scoring function. (not included in this PR)

Related change: 

1. RSSI values are stored in exposure data structures in both native and flutter. We collect average and maximum RSSI but used only maximum RSSI. This decision is made to better comply with the cumulative scoring method. 
2. We use the first btye of the AEM region to share the calibration values as mentioned in Google documentation. Since Apple devices' Tx_power has very small variation, we hardcoded this value to be -12 (value of CBAdvertisementDataTxPowerLevelKey) for iOS. 
3. RPI matching method is changed. Before this RPI || AEM is compared. We change the matching to compare RPI only.
4. We set the minimum attenuation to be +72 as described by Corona-Warn App. This value has a similar effect as MinRSSI = -90. This is subject to change when more real-world data and testing is available.
5. New columns added to the local database in Flutter. To include this change at testing, the uninstallation of an older version app is needed. Please help us handle this change to avoid uninstallation for users.
6. In order to match each device with a calibration value, Google documentation has provided a table of measurements: https://developers.google.com/android/exposure-notifications/files/en-calibration-2020-08-12.csv. We implemented the server-side for your reference: https://github.com/lijianw97/cotracker_backend_testingFramework/commit/e8f35b01f02038bd26122914d81db71b16f0291b. The table of measurements is copied into the server-side database. In addition, one endpoint is introduced where the server provides calibration value given device OEM and model. 

# Files changed: 

## ExposurePlugin.m & ExposureRecord.java & ExposurePlugin.java

- Include calibration value in AEM
- Change channel method 'tekRPIs' to support for RPI matching
- Collect RSSI related values

## Exposure.dart 

- Change local database to store RSSI value
- Introduced function to decrypt AEM region when checking for exposure
- Update the RPI matching and attenuation filtering when checking for exposure
- Request the server to find the calibration value for the host device

## Server

