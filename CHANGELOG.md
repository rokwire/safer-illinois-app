# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [2.4.2] - 2020-08-26
### Updated
Fixed Xcode name in README.md [#1](https://github.com/rokwire/safer-illinois-app/issues/1)
Update test interval from 4 to 5 days [#52](https://github.com/rokwire/safer-illinois-app/issues/52)
Change onboarding texts [#51](https://github.com/rokwire/safer-illinois-app/issues/51)

### Fixed
Fixed crash in Consent onboarding panel when Accessibility is on [#55](https://github.com/rokwire/safer-illinois-app/issues/55)

## [2.4.1] - 2020-08-25
### Fixed
Introduced scopes in HealthRuleIntInterval2 [#47](https://github.com/rokwire/safer-illinois-app/issues/47)

## [2.4.0] - 2020-08-24
### Added
Show alert on no result [#35](https://github.com/rokwire/safer-illinois-app/issues/35)

### Changed
Info.plist permission strings [#40](https://github.com/rokwire/safer-illinois-app/issues/40)
Hide phone login from settings. [#39](https://github.com/rokwire/safer-illinois-app/issues/39)
Handle deeplinks when the app was previously terminated. [#43](https://github.com/rokwire/safer-illinois-app/issues/42)

### Deleted
Removed PrivacyData model class (unused).

### Fixed
Fix/location weekday rollover [#37](https://github.com/rokwire/safer-illinois-app/issues/37)

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
