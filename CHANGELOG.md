# Changelog

## 3.0.0

### Breaking

- **`DEPLOY_CUSTOM_COMMANDS` is renamed to `DEPLOY_COMMANDS`.** The old name is not
  read anymore; update CI variables before upgrading.
- **`DEPLOY_SHARED_STORAGE_DIRECTORIES` is removed.** Shared paths are `;` separated
  lists relative to both `DEPLOY_PATH/shared` and the release directory, with the same
  meaning for every PHP deploy. Laravel's storage subdirectories moved to
  `DEPLOY_SHARED_CREATE_DIRECTORIES` with the `storage/` prefix spelled out (default
  `storage/app/public;storage/framework/cache/data;storage/framework/views;storage/framework/sessions;storage/logs`).
  WordPress's shared `wp-content` directories moved to `DEPLOY_SHARED_DIRECTORIES` with
  the `wp-content/` prefix spelled out (default `wp-content/uploads;wp-content/languages`).
- **An empty list value disables the option** for `DEPLOY_SHARED_FILES`,
  `DEPLOY_SHARED_DIRECTORIES` and `DEPLOY_ARTISAN_COMMANDS`; unset still applies the
  defaults. `DEPLOY_COMMANDS` no longer disables `DEPLOY_ARTISAN_COMMANDS`, set
  `DEPLOY_ARTISAN_COMMANDS=""` instead.
- **Node.js deploys run `DEPLOY_COMMANDS` before the release is symlinked to
  `current`**, matching PHP deploys. Commands that need the new release to be live
  belong in `DEPLOY_FINALIZE_COMMANDS`.
- **Shared paths replace whatever the archive contains at the same path.** A directory
  such as `storage` or `wp-content/uploads` shipped inside the archive is removed from
  the release before the symlink is created. Shared paths must be relative, without
  `..` or trailing slashes, and a symlinked path may not lie inside another one; the
  deploy stops before uploading otherwise.
- **WordPress builds normalize archived file modes** with `tar --mode=go-w` like Laravel
  builds. `DEPLOY_ARCHIVE_MODE` applies to both.

### Added

- **`deploy-php`**: framework-agnostic deploy of a project-built PHP archive.
  `deploy-laravel` and `deploy-wordpress` are thin wrappers that set defaults and run
  it. `--with-build` stays specific to Laravel, WordPress and Node.js and fails with a
  clear message elsewhere.
- **`DEPLOY_FINALIZE_COMMANDS`** for PHP and Node.js deploys: a `;` separated list of
  commands run in `DEPLOY_PATH/current` after the release has been symlinked to it and
  before old releases are cleaned up.
- **`DEPLOY_KEEP_RELEASES`**: number of releases kept on the server, default `2`.
- WordPress deploys support `DEPLOY_COMMANDS`, `DEPLOY_FINALIZE_COMMANDS` and
  `DEPLOY_SHARED_REQUIRED_PATHS`, and check the required paths before creating the
  release directory.

### Fixed

- `DEPLOY_SSH_PRIVATE_KEY_PATH` is honored when writing the key; previously the key
  was always written to `$HOME/.ssh/id_rsa`.
- Command list entries containing quotes or `$(...)` reach the server verbatim and are
  evaluated by `bash -c`; previously they broke the remote script.
- Node.js deploys split `DEPLOY_COMMANDS` on `;`. Previously the list was split on
  whitespace, so only single-word commands worked.
- `--with-build` given without a source path reports the usage instead of treating the
  flag as the source path.

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
