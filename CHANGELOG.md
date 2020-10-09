# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [2.7.5] - 2020-10-09
### Added
- Added "INCONCLUSIVE" and "REJECTED" results to "COVID-19 PCR" test [#271](https://github.com/rokwire/safer-illinois-app/issues/271).
- StatusPanel content improvement for Accessibility Large Text [275](https://github.com/rokwire/safer-illinois-app/issues/275).

### Changed
- Updated "PCR.positive-NIP" status rule [#273](https://github.com/rokwire/safer-illinois-app/issues/273).

## [2.7.4] - 2020-10-08
### Added
- Added boolean getters for config environment [#266](https://github.com/rokwire/safer-illinois-app/issues/266).
- Added Debug button in Settings Home header bar for debug or dev builds only.

### Changed
- Environment radio buttons in SettingsDebugPanel replaced by dropdown, prompt user before switching [#266](https://github.com/rokwire/safer-illinois-app/issues/266).
- Refresh UI on config environment change [#266](https://github.com/rokwire/safer-illinois-app/issues/266).

## [2.7.3] - 2020-10-07
### Added
- Added "POSITIVE-IP" and "POSITIVE-NIP" results to "COVID-19 PCR" [#256](https://github.com/rokwire/safer-illinois-app/issues/256).

### Changed
- Updated rules negative PCR test to turn off the red status [#256](https://github.com/rokwire/safer-illinois-app/issues/256).

### Fixed
- Possible PII leak in logging for Submit Feedback [#110](https://github.com/rokwire/safer-illinois-app/issues/110).
- Android: Request for location services is shown too early [#261](https://github.com/rokwire/safer-illinois-app/issues/261).
- Update styling - padding, sizes etc for Next steps panel - Part 2 [#244](https://github.com/rokwire/safer-illinois-app/issues/244).

### Deleted
- Removed antibody test types from rules [#258](https://github.com/rokwire/safer-illinois-app/issues/258).

## [2.7.2] - 2020-10-06
### Changed
- Do not keep in Storage location permision promot flag.
- All Health2 classes renamed to regular Health classes and merged in Health model.
- Update next steps styling [#244](https://github.com/rokwire/safer-illinois-app/issues/244).
- Show status card screen panel slides on both sides [#239](https://github.com/rokwire/safer-illinois-app/issues/239).
- Remove duplicate instance of links to home screen on status card [#247](https://github.com/rokwire/safer-illinois-app/issues/247).

### Added
- Added "PCR.positive-IP" and "PCR.positive-NIP" statuses to rules. [#248](https://github.com/rokwire/safer-illinois-app/issues/248).
- Added eventExplanation to rules & user statuses. [#248](https://github.com/rokwire/safer-illinois-app/issues/248).

### Deleted
- Removed fixed timezone output support

## [2.7.1] - 2020-10-02
### Added
- Created "Dev" XCode build environment for dev builds.
- Enable http proxying in flutter env [#234](https://github.com/rokwire/safer-illinois-app/issues/234)

### Changed
- "ios/Runner/GoogleService-Info-Debug/Release.plist" secret file refs updated to "ios/Runner/GoogleService-Info-Dev/Prod.plist".
- Locale strings from net just override the built-in asset strings [236](https://github.com/rokwire/safer-illinois-app/issues/236).

### Deleted
- Removed unused debug stuff from SettingsDebugPanel.
- Removed unused stuff from Storage.


## [2.7.0] - 2020-09-30
### Changed
- Update NextSteps html text style [231](https://github.com/rokwire/safer-illinois-app/issues/231)

## [2.6.15] - 2020-09-29
### Changed
- Added more parameters to analytics health events [#178](https://github.com/rokwire/safer-illinois-app/issues/178).
- Green status from antibody test rules replaced with yellow [#227](https://github.com/rokwire/safer-illinois-app/issues/227).
- Wrong friendly date (Today, Tomorrow, day of week etc) [#229](https://github.com/rokwire/safer-illinois-app/issues/229).

## [2.6.14] - 2020-09-28
### Changed
- Added back "No symptoms" group, implemented inclusive selection [#213](https://github.com/rokwire/safer-illinois-app/issues/213).
- Fill UserTestMonitorInterval in Covid19DebugRulesPanel [#210](https://github.com/rokwire/safer-illinois-app/issues/210).
- Log building access updates [#208](https://github.com/rokwire/safer-illinois-app/issues/208).
- Format the date for {next_step_date} as friendly eg: Tomorrow. [#219](https://github.com/rokwire/safer-illinois-app/issues/219)
- Covid19GuidelinesPanel: Disable dropdown when single county available + color fix[221](https://github.com/rokwire/safer-illinois-app/issues/221)
- StatusInfoDialog: fix close button + remove green status[223](https://github.com/rokwire/safer-illinois-app/issues/223)

### Fixed
- Do not report user UUID in analytics [#216](https://github.com/rokwire/safer-illinois-app/issues/216).
- Display an error message to the user who submits the symptoms without checking any list on the Symptom Check-in [#174](https://github.com/rokwire/safer-illinois-app/issues/174)

## [2.6.13] - 2020-09-25
### Changed
- Create debug panel for editing Covid-19 rules [#205](https://github.com/rokwire/safer-illinois-app/issues/205)
- Log building access updates [#202](https://github.com/rokwire/safer-illinois-app/issues/202)

## [2.6.12] - 2020-09-24
### Changed
- Added analytics notifcation for processing test after exposure [#198](https://github.com/rokwire/safer-illinois-app/issues/198)
- Rollback temporary flutter_html to 0.11.1 due to accessibility issue [#195](https://github.com/rokwire/safer-illinois-app/issues/195)
- Update strings files [#193](https://github.com/rokwire/safer-illinois-app/issues/193)
- Apply user's test monitor interval when evaluating status, rules format updates [#192](https://github.com/rokwire/safer-illinois-app/issues/192).

## [2.6.11] - 2020-09-23
### Changed
- Check for negative PCR tests when reporting TEKs [#179](https://github.com/rokwire/safer-illinois-app/issues/179)
- Cache county rules [#179](https://github.com/rokwire/safer-illinois-app/issues/179)
- Cache user history [#179](https://github.com/rokwire/safer-illinois-app/issues/179)
- Removed unused rules v1 [#179](https://github.com/rokwire/safer-illinois-app/issues/179)
- Add role & student_level in analytics [#189](https://github.com/rokwire/safer-illinois-app/issues/189)
- Wrong phone auth after Student/Amployee selection during the onboarding flow [#183](https://github.com/rokwire/safer-illinois-app/issues/183)
- Improved semantics for StatusInfoDialog button [#157](https://github.com/rokwire/safer-illinois-app/issues/157)
- OnboardingGetStartedPanel: remove background image from the semantics tree [#159](https://github.com/rokwire/safer-illinois-app/issues/159)
- StatusInfoDialog: improve semantics [#155](https://github.com/rokwire/safer-illinois-app/issues/155)

### Fixed
- Fixed onboarding flow [#180](https://github.com/rokwire/safer-illinois-app/issues/180)

## [2.6.10] - 2020-09-22
### Changed
 - i-Card may not being updated if the last update time is greater than 24 hours [#175](https://github.com/rokwire/safer-illinois-app/issues/175)

## [2.6.9] - 2020-09-21
### Changes
 - Update "student_level" processing from AuthCard. [#172](https://github.com/rokwire/safer-illinois-app/issues/172)

## [2.6.8] - 2020-09-18
### Changed
 - Change wait time colors and labels [#167](https://github.com/rokwire/safer-illinois-app/issues/167).
 - Upgrade flutter for Safer Illinois to v. 1.20.4 [#82](https://github.com/rokwire/safer-illinois-app/issues/82).

## [2.6.7] - 2020-09-17
### Changed
 - Rework swiper and fix the VoiceOver accessibility [#158](https://github.com/rokwire/safer-illinois-app/issues/158)
 - Show wait time for each test location [#160](https://github.com/rokwire/safer-illinois-app/issues/160).

 
## [2.6.6] - 2020-09-16
### Changed
 - Load symptoms and rules from the new Health API [#152](https://github.com/rokwire/safer-illinois-app/issues/152).

## [2.6.3] - 2020-09-11
### Changed
 - Remove "ASAP" label in Next Steps panel [#143](https://github.com/rokwire/safer-illinois-app/issues/143).
 - Remove restriction for taking screenshots in Android [#138](https://github.com/rokwire/safer-illinois-app/issues/138).
 - Removed SAR status entries from sample health rules. Use PCR entries instead that actually contain the same status rules.
 - Integrate maps for test locations [#132](https://github.com/rokwire/safer-illinois-app/issues/132).
 - Use next step HTML in exposure rules [#133](https://github.com/rokwire/safer-illinois-app/issues/133).
 - Fixed warnings.
 - Various minor fixes.

### Added
 - Added 'test-user' condition [#125](https://github.com/rokwire/safer-illinois-app/issues/125).
 - Added 'next_step_html' to status rules and status blob. Acknowleged in Info and Next Steps panels. [#128](https://github.com/rokwire/safer-illinois-app/issues/128).
 - Added 'warning' to status rules and status blob. Acknowleged in Info panel. [#127](https://github.com/rokwire/safer-illinois-app/issues/127).
 
## [2.5.5] - 2020-09-04
### Changed
 - Updated health rules. [#107](https://github.com/rokwire/safer-illinois-app/issues/107)
 - Do not process pending events if we failed to load history. [#94](https://github.com/rokwire/safer-illinois-app/issues/94)
 - Mark pending event that persist in history table as processed.

### Fixed
 - Add null check before using instance props. [#119](https://github.com/rokwire/safer-illinois-app/pull/119)
 - Fix issue with _determineIsOpen not checking weekDay. [#111](https://github.com/rokwire/safer-illinois-app/pull/111)

## [2.4.5] - 2020-09-01
### Changed
 - Prevent screenshots. [#97](https://github.com/rokwire/safer-illinois-app/issues/97)
 - Acknowledged "covid19ExposureExpireDays" and "covid19ExposureActiveDays" in Exposure service [#100](https://github.com/rokwire/safer-illinois-app/issues/100)

### Deleted
 - Remove GoogleMaps, MapsIndoors and MicroBlink Android native side (unused). [#95](https://github.com/rokwire/safer-illinois-app/issues/95)

## [2.4.4] - 2020-08-31
### Changed
 - New symptoms and rules. [#84](https://github.com/rokwire/safer-illinois-app/issues/84)
 - Acknowledged "covid19ReportExposuresWhilePositive" settings flag for reporting red users after the date of becoming red. [#87](https://github.com/rokwire/safer-illinois-app/issues/87)

### Deleted
 - Unlink GoogleMaps and MapsIndoors pods from iOS native side (unused). [#90](https://github.com/rokwire/safer-illinois-app/issues/90)
 - Unlink Microblink pod from iOS native side (unused). [#92](https://github.com/rokwire/safer-illinois-app/issues/92)

## [2.4.3] - 2020-08-28
### Fixed
 - Fixed crash in Android [#61](https://github.com/rokwire/safer-illinois-app/issues/61)
 - Fixed crash in Android [#68](https://github.com/rokwire/safer-illinois-app/issues/68)
 - Fixed crash in Android when bluetooth is not turned on [#70](https://github.com/rokwire/safer-illinois-app/issues/70)
 - Fixed crash in Android - do not start exposure client service if it's not running [#74](https://github.com/rokwire/safer-illinois-app/issues/74)

### Changed
 - SettingsNewHomePanel and related child panels moved to settings2 section, class names updated to indicate the different panel group.
 - SettingsDebugPanel moved to debug section, MessagingPanel renamed to SettingsDebugMessagingPanel.

### Deleted
 - SettingsPrivacyCenterPanel (unused)
 - Covid19OnBoardingLoginNetIdPanel (unused)
 - Covid19OnBoardingLoginPhonePanel (unused)

## [2.4.2] - 2020-08-26
### Changed
 - Fixed Xcode name in README.md (#1)
 - Update test interval from 4 to 5 days (#52)
 - Change onboarding texts (#51)

### Fixed
 - Fixed crash in Consent onboarding panel when Accessibility is on (#55)

## [2.4.1] - 2020-08-25
### Fixed
 - Introduced scopes in HealthRuleIntInterval (#47)

## [2.4.0] - 2020-08-24
### Added
 - Show alert on no result (#35)

### Changed
 - Info.plist permission strings (#40)
 - Hide phone login from settings. (#39)
 - Handle deeplinks when the app was previously terminated. (#43)

### Deleted
 - Removed PrivacyData model class (unused).

### Fixed
 - Fix/location weekday rollover (#37)

## [2.3.6] - 2020-08-20
### Changed
 - Exposure iOS scanner updated into an intermittent scanner where the scanner works for at least 4 seconds and pause for 150 seconds and repeat.
 - Process exposure is now called every time the scanner is paused or stopped rather than periodically.
 - Ping exposure functionality is gone for iOS peripherals.
 - Exposure Screen lighting is done every time the phone's screen is turned off and the scanner is/starts scanning. 
 - Handle TEKs without expirestamp in ExposurePlugin.java
 - Updated "covid19ExposureServiceLogMinDuration" setting to default to 0.

## [2.3.5] - 2020-08-19
## Changed
 - Update description for camera usage. [#25](https://github.com/rokwire/safer-illinois-app/issues/25)

## [2.3.4] - 2020-08-19
### Added
 - Latest content from the private repository.
 - GitHub Issue templates.

### Changed
 - Update README and repository description.
 - Clean up CHANGELOG.
