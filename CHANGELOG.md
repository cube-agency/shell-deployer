# Changelog

## 2.1.1

### Fixed

- Limit published package files to the shell scripts, `.buildignore` and
  documentation, excluding local editor and agent settings.

## 2.1.0

### Added

- **`DEPLOY_SHARED_REQUIRED_PATHS`** for Laravel deploys: a `;` separated list of
  files, directories or symlinks in `DEPLOY_PATH/shared` that must exist, replacing
  the hard-coded `.env` check. The default, `.env`, keeps the existing behavior. An
  empty value requires nothing.

### Changed

- The required-paths check runs before the release directory is created, so a
  deploy that stops there no longer leaves an empty `releases/<timestamp>` behind.
- An empty `DEPLOY_SHARED_STORAGE_DIRECTORIES` creates no storage directories
  instead of falling back to the Laravel defaults. Unset still uses the defaults.

## 2.0.0

### Breaking

- **Laravel builds now normalize archived file permissions by default.** The build
  archive is created with `tar --mode=go-w`, so deployed code lands as `0644` files /
  `0755` directories regardless of the CI runner umask. Previously the runner umask
  could leak group-writable (`0664`/`0775`) code into releases, letting the web-server
  user (e.g. `www-data`) modify application code.

  Code stays readable and executable by the web-server user (via group or other); only
  **write** is removed for group and other. The owner (deploy user) keeps write, so
  deploy-time artisan commands are unaffected.

  Override or opt out via the `DEPLOY_ARCHIVE_MODE` environment variable:
  - unset (default): `go-w` → `0644`/`0755`
  - `DEPLOY_ARCHIVE_MODE="g-w,o-rwx"`: stricter `0640`/`0750` (no access for "other")
  - `DEPLOY_ARCHIVE_MODE=""`: disable normalization (previous behavior)

  Only affects `build-laravel.sh`. WordPress and Node.js builds are unchanged.
