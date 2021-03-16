# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Changed
- Changed permission request buttons to "Continue" [#560](https://github.com/rokwire/safer-illinois-app/issues/560)
- Apply WWCL.Disclaimers in Safer app [#562](https://github.com/rokwire/safer-illinois-app/issues/562)
- Maine health history change [#563](https://github.com/rokwire/safer-illinois-app/issues/563)
- Check for start/stop exposure native service on revoking from background.

## [2.10.12] - 2021-03-05
### Fixed
- Explore Shibboleth login failure due to deleted UUID [#508](https://github.com/rokwire/safer-illinois-app/issues/508)
- OnBoardingHealthDisclosurePanel duplicated text [#490](https://github.com/rokwire/safer-illinois-app/issues/490)
- Apply nextStepDate in local time when making the calculations for displayNextStepDate.
- Extend Auth OIDC processing to handle external configurations.
- Fixed Counseling Center url [#512](https://github.com/rokwire/safer-illinois-app/issues/512).
- Fixed priority of "PCR.invalid" and "out-of-test-compliance" rules [#526](https://github.com/rokwire/safer-illinois-app/issues/526).
- Fixed passing status param in Connectivity.notifyStatusChanged notification.
- Fixed "Remove My Information" processing [#547](https://github.com/rokwire/safer-illinois-app/issues/547).

### Changed
- Updated app config format to refer 'oidc' instead of 'shibboleth', merge shibboleth url entries in app config into single one [#501](https://github.com/rokwire/safer-illinois-app/issues/501)
- Do not edit straightly roles from user data [#229](https://github.com/rokwire/illinois-app/issues/229).
- Increased connectivity plugin version [#519](https://github.com/rokwire/safer-illinois-app/issues/519).
- Updated spaces between texts in OnBoardingHealthDisclosurePanel [#488](https://github.com/rokwire/safer-illinois-app/issues/488).
- Make the points from the first section from OnBoardingHealthDisclosurePanel panel bold [#489](https://github.com/rokwire/safer-illinois-app/issues/489),
- Updated Positive IP & NIP step & explanation strings [#529](https://github.com/rokwire/safer-illinois-app/issues/529).
- Added camera usage mention in disclosure screen [#530](https://github.com/rokwire/safer-illinois-app/issues/530)
- Updated PCR.positive-NIP test rule [#532](https://github.com/rokwire/safer-illinois-app/issues/532)

### Added
- App Up time to exposure logs.
- Added progress indictors when processing QR image code from load/scan [#495](https://github.com/rokwire/safer-illinois-app/issues/495).
- Implemented PullToRefresh feature in Home panel [#544](https://github.com/rokwire/safer-illinois-app/issues/544).

## [2.10.11] - 2021-01-19
### Changed
- Changed interval between first and second test for Spring 2021 [#482](https://github.com/rokwire/safer-illinois-app/issues/482)
- Updated Next Steps for Two Test Spring 2021 event [#480](https://github.com/rokwire/safer-illinois-app/issues/480).
- Updated PCR.positive rule [#485](https://github.com/rokwire/safer-illinois-app/issues/485).

## [2.10.10] - 2021-01-18
### Changed
- Hide groups in Safer Illinois 2.10 [#475](https://github.com/rokwire/safer-illinois-app/issues/475).

### Added
- Added Onboarding Disclosure Panel [#477](https://github.com/rokwire/safer-illinois-app/issues/477]).

## [2.10.9] - 2021-01-15
### Added
- Added 'warningHtml' field to HealthStatus [#467](https://github.com/rokwire/safer-illinois-app/issues/467).
- Added 'release' action and status to health rules [#470](https://github.com/rokwire/safer-illinois-app/issues/470).

## [2.10.8] - 2020-12-23
### Added
- Added support of both authentication methods, use Rokmetro auth in Health BB API calls [#396](https://github.com/rokwire/safer-illinois-app/issues/396).

### Fixed
- Integrate Groups UI into the Safer app - Additional Fixes [#455](https://github.com/rokwire/safer-illinois-app/issues/455).

## [2.10.7] - 2020-12-22
### Changed
- Integrate Groups UI into the Safer app - Additional Fixes [#455](https://github.com/rokwire/safer-illinois-app/issues/455).

## [2.10.6] - 2020-12-21
### Added
- Integrate Groups UI into the Safer app [#455](https://github.com/rokwire/safer-illinois-app/issues/455).

## [2.10.5] - 2020-12-16
### Changed
- Speed up user history load [#449](https://github.com/rokwire/safer-illinois-app/issues/449).
- Encode health statuses in rules [#452](https://github.com/rokwire/safer-illinois-app/issues/452).

### Fixed
- Do not translate symptoms names transmitted to analytics [#447](https://github.com/rokwire/safer-illinois-app/issues/447).

## [2.10.4] - 2020-12-11
### Added
- Added map directions feature in iOS app [#446](https://github.com/rokwire/safer-illinois-app/issues/446).

## [2.10.3] - 2020-12-04
### Fixed
- Pass the right user UIN when creating debug events. [#441](https://github.com/rokwire/safer-illinois-app/issues/441).
- Fixed user details in Status panel when subaccount is selected. [#442](https://github.com/rokwire/safer-illinois-app/issues/442).

## [2.10.2] - 2020-12-03
### Added
- Added user subaccounts feature [#437](https://github.com/rokwire/safer-illinois-app/issues/437).

## [2.10.1] - 2020-12-01
### Changed
- Update user PII data from authentication/roster data [#432](https://github.com/rokwire/safer-illinois-app/issues/432).
- Added login widget in Home panel when user is not connected [#434](https://github.com/rokwire/safer-illinois-app/issues/434).

## [2.10.0] - 2020-11-30
### Fixed
- Fix FirebaseCrashlytics [#428](https://github.com/rokwire/safer-illinois-app/issues/428).
- CareTeamPanel fix semantics pronauncement for Mental Health button [#422](https://github.com/rokwire/safer-illinois-app/issues/422)

### Deleted
- Removed unused images from application project [#419](https://github.com/rokwire/safer-illinois-app/issues/419).

### Changed
- Health service reworked to permanantly cache all data necessary for status build.
- Use better naming in internal classes.

## [2.9.12] - 2021-02-09
### Changed
- Increased connectivity plugin version [#519](https://github.com/rokwire/safer-illinois-app/issues/519).

## [2.9.11] - 2021-02-08
### Changed
- Do not edit straightly roles from user data [#229](https://github.com/rokwire/illinois-app/issues/229).

### Fixed
- Fixed Counseling Center url [#512](https://github.com/rokwire/safer-illinois-app/issues/512).

## [2.9.10] - 2021-02-05
### Fixed
- Additional fix for refresh token and logout on 400, 401 or 403 erresponse code. [#508](https://github.com/rokwire/safer-illinois-app/issues/508)

## [2.9.9] - 2021-02-03
### Fixed
- Additional fix for refresh token and logout on 401 or 403 erresponse code. [#508](https://github.com/rokwire/safer-illinois-app/issues/508)

## [2.9.8] - 2021-02-01
### Fixed
- Explore Shibboleth login failure due to deleted UUID [#508](https://github.com/rokwire/safer-illinois-app/issues/508)
- Updated details of background permissions [#506](https://github.com/rokwire/safer-illinois-app/issues/506)
- Updated details of background permissions Explore Shibboleth login failure due to deleted UUID [#508](https://github.com/rokwire/safer-illinois-app/issues/508)

## [2.9.7] - 2021-01-26
### Fixed
- Updated order of panel shown during onboarding [#503](https://github.com/rokwire/safer-illinois-app/issues/503)
- Apply nextStepDate in local time when making the calculations for displayNextStepDate.

## [2.9.6] - 2021-01-22
### Fixed
- Updated Onboarding Disclosure Panel text. [#497](https://github.com/rokwire/safer-illinois-app/issues/497)

## [2.9.5] - 2021-01-20
### Changed
- Sync health.rules.json with latest 2.9 content on production
- Acknowledged "quarantine-on.reason" string entry in "health.rules.json".
- Port this fix as hotfix for 2.9 (Original title: Fix FirebaseCrashlytics) [#428](https://github.com/rokwire/safer-illinois-app/issues/428).
- Port fix: Added Onboarding Disclosure Panel [#477](https://github.com/rokwire/safer-illinois-app/issues/477]).
- Port fix: fixed grammer in Status Update String [#454](https://github.com/rokwire/safer-illinois-app/issues/454)

### Fixed
- Do not translate symptoms names transmitted to analytics [#447](https://github.com/rokwire/safer-illinois-app/issues/447).

## [2.9.4] - 2020-11-18
### Fixed
- Error message cannot be read if keyboard is up - please hide the keyboard after a send - see error_message_hidden.png [#414](https://github.com/rokwire/safer-illinois-app/issues/414).
- Change everywhere we have "Capitol Staff" to "Non University Member" - on boarding roles, messages etc [#412](https://github.com/rokwire/safer-illinois-app/issues/412).
- Updated Updated capitol staff persona icons.
- Make sure to display localized symptom name everywhere [#411](https://github.com/rokwire/safer-illinois-app/issues/411).

## [2.9.3] - 2020-11-17
### Added
- Implemented permanent muted audio playback in native iOS Exposure service [#407](https://github.com/rokwire/safer-illinois-app/issues/407).

## [2.9.2] - 2020-11-16
### Changed
- Show full name for Capitol Staff in the status card [#401](https://github.com/rokwire/safer-illinois-app/issues/401).

### Fixed
- iOS Crash while trying to retrieve device uuid from native part [#397](https://github.com/rokwire/safer-illinois-app/issues/397).
- Crashes with FCM notifications in Android [#394](https://github.com/rokwire/safer-illinois-app/issues/394).
- Do not show the wait time if the location is closed [#398](https://github.com/rokwire/safer-illinois-app/issues/398).

## [2.9.1] - 2020-11-12
### Changed
- Safer onboarding changes 11/12 [#390](https://github.com/rokwire/safer-illinois-app/issues/390).

## [2.9.0] - 2020-11-10
### Added
- A pull request template. [#324](https://github.com/rokwire/safer-illinois-app/issues/324)
- Contributor guidelines (CONTRIBUTING.md). [#322](https://github.com/rokwire/safer-illinois-app/issues/322).

## [2.8.13] - 2020-11-09
### Fixed
- Cannot confirm one time code [#379](https://github.com/rokwire/safer-illinois-app/issues/379).
- Added symptoms translations [#337](https://github.com/rokwire/safer-illinois-app/issues/337).

## [2.8.12] - 2020-11-06
### Fixed
- CareTeamPanel fix non student aditional message. [#269](https://github.com/rokwire/safer-illinois-app/issues/269).
- Build error related to ios app [#374](https://github.com/rokwire/safer-illinois-app/issues/374).
- Fixed the error related to app framework minimum os version [#375](https://github.com/rokwire/safer-illinois-app/issues/375).

## [2.8.11] - 2020-11-05
### Added
- Pass application id as header field in FCM API calls from sports service [#364](https://github.com/rokwire/safer-illinois-app/issues/364).

### Fixed
- Fixed various string entry translations [#364](https://github.com/rokwire/safer-illinois-app/issues/364).
- Fixed Initial loading screen [#366](https://github.com/rokwire/safer-illinois-app/issues/366).
- CareTeamPanel: update link urls [#269](https://github.com/rokwire/safer-illinois-app/issues/269).
- User is not able to Sign out successfully by tapping the Sign-out button on Personal Info screen [#303](https://github.com/rokwire/safer-illinois-app/issues/303).

## [2.8.10] - 2020-11-04
### Added
- Added ability to enable/disable capitol stuff from app config settings [#353](https://github.com/rokwire/safer-illinois-app/issues/353).
- Check if Capitol staff user has a roster UIN on app resume [#355](https://github.com/rokwire/safer-illinois-app/issues/355).

### Changed
- Acknowledge exposure log url from app config.
- Various strings updated [#357](https://github.com/rokwire/safer-illinois-app/issues/357), [#359](https://github.com/rokwire/safer-illinois-app/issues/359).

### Fixed
- Unable to save qr code during the onboarding process after fresh install [#361](https://github.com/rokwire/safer-illinois-app/issues/361).

## [2.8.9] - 2020-11-03
### Added
- Send additional exposure stats with processed test result analytics event [#332](https://github.com/rokwire/safer-illinois-app/issues/332).
- Implemented exclusive selection by group in role selection panels [#347](https://github.com/rokwire/safer-illinois-app/issues/347).
- More precise adjusting phone numbers with "+1" prefix [#350](https://github.com/rokwire/safer-illinois-app/issues/350).

## [2.8.8] - 2020-11-02
### Fixed
- Do not ignore unknown user roles [#343](https://github.com/rokwire/safer-illinois-app/issues/343).

## [2.8.7] - 2020-10-30
### Added
- Capitol Staff [#342](https://github.com/rokwire/safer-illinois-app/issues/342).
- Added FCM topics subscription support from health status [#339](https://github.com/rokwire/safer-illinois-app/issues/339).

## [2.8.6] - 2020-10-28
### Changed
- Prepare app for flexable health status codes, health status strings cleanup.

## [2.8.5] - 2020-10-27
### Fixed
- Home panel is not refreshing after successful login and/or private key entrance [#333](https://github.com/rokwire/safer-illinois-app/issues/333).

## [2.8.4] - 2020-10-23
### Added
- Added ability to refer local strings from rules and action texts.

### Fixed
- Fixed "force-test" rule behavior, step texts updated either.

## [2.8.3] - 2020-10-22
### Added
- Enable again Talent Chooser for Safer app [#306](https://github.com/rokwire/safer-illinois-app/issues/306).
- Multilanguage support in Health rules and action events [#308](https://github.com/rokwire/safer-illinois-app/issues/308).

### Fixed
- Fixed miscellaneous strings translation, display dates localized [#308](https://github.com/rokwire/safer-illinois-app/issues/308).

## [2.8.2] - 2020-10-21
### Added
- Added "force-test" rule status and action. [#319](https://github.com/rokwire/safer-illinois-app/issues/319).
- Added "referenceDate" origin when evaluating status. [#319](https://github.com/rokwire/safer-illinois-app/issues/319).

### Changed
- Apply rule status priority on status downgrade. [#319](https://github.com/rokwire/safer-illinois-app/issues/319).

### Fixed
- Unable to log in with iOS Default Browser changed [#315](https://github.com/rokwire/safer-illinois-app/issues/315).

## [2.8.1] - 2020-10-20
### Added
- Added ability to turn off multiple organizations support and build single organization app.
- Added backward support for single organization app upgrade.
- Log "exposure_score" in "check_exposures" analytics event [#309](https://github.com/rokwire/safer-illinois-app/issues/309).

### Changed
- Multiple organizations support - cleanup.

## [2.8.0] - 2020-10-19
### Added
- Multiple organizations support - first round.

## [2.7.9] - 2020-10-16
### Changed
- Covid19TestLocations panel: update unavailable waith time text [#279](https://github.com/rokwire/safer-illinois-app/issues/279)

## [2.7.8] - 2020-10-15
### Added
- Added encryption support to storage.

### Changed
- Log user UUID un-anonymously when launching RootPanel [#296](https://github.com/rokwire/safer-illinois-app/issues/296)
- Covid19TestLocations Update Wait time text [#279](https://github.com/rokwire/safer-illinois-app/issues/279)
- Store RSA private key separately for organization and environment (Android).

## [2.7.7] - 2020-10-14
### Changed
- Add external link icon for SettingsHomePanel buttons [#241](https://github.com/rokwire/safer-illinois-app/issues/241)
- Remove private params from the url. Additional fix [#110](https://github.com/rokwire/safer-illinois-app/issues/110).
- Add external link icon for SettingsHomePanel buttons [241](https://github.com/rokwire/safer-illinois-app/issues/241).
- Add building access status to the Home Status widget [#243](https://github.com/rokwire/safer-illinois-app/issues/243)
- Add building access status to the Home Status widget [#269](https://github.com/rokwire/safer-illinois-app/issues/269)
- Store RSA private key separately for organization and environment (iOS only for now).
- Show authorization panels in onboarding only when needed.

## [2.7.6] - 2020-10-13
### Changed
- Upgrade Flutter to v1.22.1 [#283](https://github.com/rokwire/safer-illinois-app/issues/283).
- Fixed environmnets switching from Debug panel.
- Internal cleanup.
- Updated rules [#281](https://github.com/rokwire/safer-illinois-app/issues/281).

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