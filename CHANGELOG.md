# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Add packages checking support for Arch Linux.

## [1.2.0] - 2019-05-05
### Added
- New patches for following tools: aapt, aapt2 and aidl (including aidl-cpp).
- For maintainers: add a function to calculate MD5 hash of
  an Android.bp file, which excludes unnecessary characters.

### Changed
- New patching algorithm.
- New build algorithm.

## [1.1.0] - 2019-04-27
### Added
- Add a .deb package for easy dependencies install.
- Add alternative packages names support.

### Changed
- Ignore comments and empty lines of the patches.

### Fixed
- Correct associative arrays declaring.

## [1.0.1] - 2019-04-25
### Fixed
- Change an output directory for binaries.

## [1.0.0] - 2019-04-24
### Added
- First release.
