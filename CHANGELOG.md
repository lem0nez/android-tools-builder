# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Add packages checking support for Arch Linux.

## [1.3.0] - 2020-02-07
### Added
- Add option to set a branch name manually.

## [1.2.3] - 2019-05-09
### Fixed
- Fix "invalid ELF header" for zipalign and aidl.

## [1.2.2] - 2019-05-07
### Fixed
- Fix androidfw patch.
- Value "all" for tools and architectures now also saves in configuration file.
- An output directory name definition.

## [1.2.1] - 2019-05-06
### Changed
- List of excluded tools will print only if it exists.

### Fixed
- Fix removing of duplicate tools in patching function.
- Fix aapt2 patch.

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
