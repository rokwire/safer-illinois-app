# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- Latest content from the private repository.
- GitHub Issue templates.

### Changed
- Exposure iOS scanner updated into an intermittent scanner where the scanner works for at least 4 seconds and pause for 150 seconds and repeat.
- Process exposure is now called every time the scanner is paused or stopped rather than periodically.
- Ping exposure functionality is gone for iOS peripherals.
- Exposure Screen lighting is done every time the phone's screen is turned off and the scanner is/starts scanning. 
- Handle TEKs without expirestamp in ExposurePlugin.java
- Updated "covid19ExposureServiceLogMinDuration" setting to default to 0.
- Update README and repository description.
- Clean up CHANGELOG.
