# Changelog

All notable changes to Chuff are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-10-21

First release.

### Added

- A menu bar status light for Railway's platform status: green, amber, red, or
  grey when the data is stale or unavailable.
- A dropdown listing Railway's component groups, each expandable to its
  components, with a link to status.railway.com.
- Per-group tracking, so only the groups you use affect the icon.
- Settings for the refresh interval (1, 3, 5, or 10 minutes), monochrome
  icons, and Open at Login.
- Polling that pauses while the display sleeps and refreshes on wake.
- Self-updates through Sparkle, verified against an EdDSA signature.

[Unreleased]: https://github.com/mercuxio/Chuff/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mercuxio/Chuff/releases/tag/v1.0.0
