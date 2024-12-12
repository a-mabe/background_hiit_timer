# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2024-12-11

### Changed

- Fixed blank sound not playing to keep background process alive.
- Example app background process will now stop on app close for Android.

## [1.0.1] - 2024-12-07

### Changed

- Avoid repeat audio file loads. Once an audio file has been loaded into the soundpool, its ID is tracked.

## [1.0.0] - 2024-11-10

### Changed
- Refactored to use a SQFlite database.
- Implemented IntervalType class - requires a list of intervals to be passed.
- Added skip next and skip previous functions.
- Simplified implementation.

## [1.0.0-dev.6] - 2024-08-10

### Changed

- Removed dependency on `flutter_fgbg`.

## [1.0.0-dev.5] - 2024-08-10

### Changed

- Simplified timer restart.

### Fixed

- Fixed sound attempting to play when set to `none`.

## [1.0.0-dev.4] - 2024-07-31

### Added

- Volume control for timer audio.

## [1.0.0-dev.3] - 2024-06-23

### Changed

- Upgraded dependencies.

## [1.0.0-dev.2] - 2024-06-10

## Changed

- Upgraded dependencies.

## [1.0.0-dev.1] - 2024-04-13

### Added

- This CHANGELOG file to hopefully serve as an evolving example of a
  standardized open source project CHANGELOG.
- Initial version of the package.