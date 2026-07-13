# Changelog

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
