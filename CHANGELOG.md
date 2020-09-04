# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Fixed
 - Add null check before using instance props. [#119](https://github.com/rokwire/safer-illinois-app/pull/119)


## [2.5.2] - 2020-09-03
### Changed
 - Updated health rules. [#107](https://github.com/rokwire/safer-illinois-app/issues/107)
 - Do not process pending events if we failed to load history. [#94](https://github.com/rokwire/safer-illinois-app/issues/94)
 - Mark pending event that persist in history table as processed.

### Fixed
 - Fixed CHANGELOG format. [#79](https://github.com/rokwire/safer-illinois-app/issues/79)
 - Fix issue with _determineIsOpen not checking weekDay. [#111](https://github.com/rokwire/safer-illinois-app/pull/111)
 
### Changed
 - Prevent screenshots in Android. [#97](https://github.com/rokwire/safer-illinois-app/issues/97)
- Acknowledged "covid19ExposureExpireDays" and "covid19ExposureActiveDays" in Exposure service [#100](https://github.com/rokwire/safer-illinois-app/issues/100)

### Changed
 - New symptoms and rules. [#84](https://github.com/rokwire/safer-illinois-app/issues/84)
 - Acknowledged "covid19ReportExposuresWhilePositive" settings flag for reporting red users after the date of becoming red. [#87](https://github.com/rokwire/safer-illinois-app/issues/87)

### Removed
 - Removed MapsIndoors library from native sides [#108](https://github.com/rokwire/safer-illinois-app/issues/108).

## [2.5.1] - 2020-08-28
### Fixed
- Fixed crash in Android [#68](https://github.com/rokwire/safer-illinois-app/issues/68)
- Fixed crash in Android when bluetooth is not turned on [#70](https://github.com/rokwire/safer-illinois-app/issues/70)
- Fixed crash in Android - do not start exposure client service if it's not running [#74](https://github.com/rokwire/safer-illinois-app/issues/74)

### Changed
- SettingsNewHomePanel and related child panels moved to settings2 section, class names updated to indicate the different panel group.
- SettingsDebugPanel moved to debug section, MessagingPanel renamed to SettingsDebugMessagingPanel.

### Removed
- SettingsPrivacyCenterPanel (unused)
- Covid19OnBoardingLoginNetIdPanel (unused)
- Covid19OnBoardingLoginPhonePanel (unused)

## [2.5.0] - 2020-08-27
### Fixed
- Fixed crash in Android [#61](https://github.com/rokwire/safer-illinois-app/issues/61)

## [2.4.2] - 2020-08-26
### Changed
- Fixed Xcode name in README.md [#1](https://github.com/rokwire/safer-illinois-app/issues/1)
- Update test interval from 4 to 5 days [#52](https://github.com/rokwire/safer-illinois-app/issues/52)
- Change onboarding texts [#51](https://github.com/rokwire/safer-illinois-app/issues/51)

### Fixed
- Fixed crash in Consent onboarding panel when Accessibility is on [#55](https://github.com/rokwire/safer-illinois-app/issues/55)

## [2.4.1] - 2020-08-25
### Fixed
- Introduced scopes in HealthRuleIntInterval2 [#47](https://github.com/rokwire/safer-illinois-app/issues/47)

## [2.4.0] - 2020-08-24
### Added
- Show alert on no result [#35](https://github.com/rokwire/safer-illinois-app/issues/35)

### Changed
- Info.plist permission strings [#40](https://github.com/rokwire/safer-illinois-app/issues/40)
- Hide phone login from settings. [#39](https://github.com/rokwire/safer-illinois-app/issues/39)
- Handle deeplinks when the app was previously terminated. [#43](https://github.com/rokwire/safer-illinois-app/issues/42)

### Removed
- Removed PrivacyData model class (unused).

### Fixed
- Fix/location weekday rollover [#37](https://github.com/rokwire/safer-illinois-app/issues/37)

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
