# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-29

### Added

- Weighted permits: `acquire(weight: N)` to acquire multiple permits at once
- FIFO fairness mode: `Counter.new(permits: N, fair: true)` for guaranteed ordering
- Dynamic permit adjustment: `resize(new_permits)` to change total permits at runtime
- Full README compliance with 8 badges, Support section, and all standard sections
- GitHub issue templates, dependabot config, and PR template

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.0] - 2026-03-22

### Added

- Initial release
- Counting semaphore with configurable permits
- Blocking `acquire` with automatic release via block
- Timeout-based `try_acquire` with deadline support
- FIFO fairness via ConditionVariable
- Thread-safe permit tracking
