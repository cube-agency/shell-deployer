# Shell Deployer

Bash deployment scripts for PHP, Laravel, WordPress and Node.js projects, made for GitLab CI/CD pipelines. Each deploy uploads a release to `DEPLOY_PATH/releases/<timestamp>` on the server and switches the `DEPLOY_PATH/current` symlink to it.

## Getting Started

Call the deploy script with `npx` from `.gitlab-ci.yml`.

### Node.js

```yaml
stages:
  - deploy

.deploy: &deploy
  image: node:20-bullseye
  stage: deploy
  allow_failure: false
  when: manual
  tags:
    - deploy
  script:
    - npx -y -p shell-deployer@3.0.0 deploy-nodejs dist/spa/ --with-build

deploy to staging:
  <<: *deploy
  environment:
    name: staging
    url: https://nodejs-project.example.com
  variables:
    DEPLOY_HOST: staging.example.com
    DEPLOY_USER: example_user
    DEPLOY_PATH: /home/example_user/app
    DEPLOY_SSH_KNOWN_HOSTS: $STAGING_DEPLOY_KNOWN_HOSTS
    DEPLOY_SSH_PRIVATE_KEY: $STAGING_DEPLOY_PRIVATE_KEY
```

### Laravel

```yaml
.deploy: &deploy
  stage: deploy
  allow_failure: false
  when: manual
  tags:
    - deploy
  script:
    - npx -y -p shell-deployer@3.0.0 deploy-laravel app.tgz --with-build

deploy to staging:
  <<: *deploy
  environment:
    name: staging
    url: https://laravel-project.example.com
  variables:
    DEPLOY_HOST: staging.example.com
    DEPLOY_USER: example_user
    DEPLOY_PHP_COMMAND: php8.3
    DEPLOY_PATH: /home/example_user/app
    DEPLOY_SSH_KNOWN_HOSTS: $STAGING_DEPLOY_KNOWN_HOSTS
    DEPLOY_SSH_PRIVATE_KEY: $STAGING_DEPLOY_PRIVATE_KEY
```

### WordPress

```yaml
.deploy: &deploy
  stage: deploy
  allow_failure: false
  when: manual
  tags:
    - deploy
  script:
    - npx -y -p shell-deployer@3.0.0 deploy-wordpress app.tgz --with-build

deploy to staging:
  <<: *deploy
  environment:
    name: staging
    url: https://wordpress-project.example.com
  variables:
    DEPLOY_HOST: staging.example.com
    DEPLOY_USER: example_user
    DEPLOY_PATH: /home/example_user/app
    DEPLOY_SSH_KNOWN_HOSTS: $STAGING_DEPLOY_KNOWN_HOSTS
    DEPLOY_SSH_PRIVATE_KEY: $STAGING_DEPLOY_PRIVATE_KEY
```

A generic PHP project builds its own `app.tgz` and deploys it with `deploy-php app.tgz`, using the same variables as the Laravel example minus the Laravel ones. PHP has no build convention, so `--with-build` exists for Laravel, WordPress and Node.js only.

## Scripts

| Script | What it does |
|---|---|
| `deploy-php` | Uploads an archive built by the project, extracts it into a new release, symlinks shared paths, runs `DEPLOY_COMMANDS`, switches `current`, runs `DEPLOY_FINALIZE_COMMANDS`. No shared paths unless configured. |
| `deploy-laravel` | `deploy-php` with Laravel shared-path defaults and `DEPLOY_ARTISAN_COMMANDS` run ahead of `DEPLOY_COMMANDS`. |
| `deploy-wordpress` | `deploy-php` with WordPress shared-path defaults. |
| `deploy-nodejs` | Uploads a built directory as a new release, runs `DEPLOY_COMMANDS`, switches `current`, runs `DEPLOY_FINALIZE_COMMANDS`. |
| `build-laravel`, `build-wordpress` | `composer install`, `npm i && npm run build`, then pack the project into `app.tgz`, excluding the paths listed in [.buildignore](https://github.com/cube-agency/shell-deployer/blob/master/.buildignore). A `.buildignore` in the project root takes precedence. |
| `build-nodejs` | `npm i && npm run build`. |

Arguments: the source path (an archive for PHP, a directory for Node.js) and the optional `--with-build` flag, which runs the matching build script first (Laravel, WordPress and Node.js).

## Environment Variables

### Required

- **DEPLOY_HOST**: server hostname or IP.
- **DEPLOY_USER**: SSH user.
- **DEPLOY_PATH**: deployment root on the server, holding `releases/`, `shared/` and `current`.

### Optional

- **DEPLOY_SSH_KNOWN_HOSTS**: known hosts entries appended to `$HOME/.ssh/known_hosts`, for CI runners without a persistent one.
- **DEPLOY_SSH_PRIVATE_KEY**: private key content, written to `DEPLOY_SSH_PRIVATE_KEY_PATH` with mode `600`.
- **DEPLOY_SSH_PRIVATE_KEY_BASE64**: the same key base64-encoded on a single line, so that it can be a GitLab **masked** variable. Set one of the two, not both.
- **DEPLOY_SSH_PRIVATE_KEY_PATH**: path of the key file. A provided key is written there (default `$HOME/.ssh/id_rsa`); set it without a provided key to use an existing key file.
- **DEPLOY_SSH_PORT**: SSH port. Default `22`.
- **DEPLOY_KEEP_RELEASES**: releases kept in `DEPLOY_PATH/releases`, the new one included. Default `2`.
- **DEPLOY_COMMANDS**: `;` separated commands run in the release directory before it becomes `current`.
- **DEPLOY_FINALIZE_COMMANDS**: `;` separated commands run in `DEPLOY_PATH/current` after the switch, for example `sudo systemctl reload php8.3-fpm`.

Commands run on the server with `bash -c`, so quoting, `$VARIABLES` and `$(subshells)` are evaluated there. A failing command stops the deployment.

### PHP shared paths

`;` separated paths relative to both `DEPLOY_PATH/shared` and the release, without `..` or trailing slashes. Whatever the archive contains at a shared path is replaced by the symlink, so a symlinked path may not lie inside another one. An empty value disables the option; the defaults apply when the variable is unset. `deploy-php` has no defaults.

| Variable | Effect | `deploy-laravel` default | `deploy-wordpress` default |
|---|---|---|---|
| `DEPLOY_SHARED_FILES` | symlinked into the release | `.env` | `.env` |
| `DEPLOY_SHARED_DIRECTORIES` | created in `shared`, symlinked into the release | `storage` | `wp-content/uploads;wp-content/languages` |
| `DEPLOY_SHARED_CREATE_DIRECTORIES` | created in `shared` | `storage/app/public;storage/framework/cache/data;storage/framework/views;storage/framework/sessions;storage/logs` | |
| `DEPLOY_SHARED_REQUIRED_PATHS` | must exist in `shared` before anything is uploaded | `.env` | `.env` |

### Laravel

- **DEPLOY_PHP_COMMAND**: PHP binary name or path on the server. Default `php`.
- **DEPLOY_ARTISAN_COMMANDS**: `;` separated artisan commands, each run as `DEPLOY_PHP_COMMAND artisan <command>` ahead of `DEPLOY_COMMANDS`. Default `storage:link;config:cache;migrate --force;view:cache;queue:restart`; an empty value runs none.

### Laravel and WordPress build

- **DEPLOY_REVISION**: written into the archive as `public/REVISION` (Laravel) or `REVISION` (WordPress). Default `dev`.
- **DEPLOY_ARCHIVE_MODE**: `tar --mode` spec applied to the archive so that deployed code is not group or world writable. Default `go-w` (`0644`/`0755`); `g-w,o-rwx` gives `0640`/`0750`; an empty value disables it.

## Miscellaneous

Known hosts value for `DEPLOY_SSH_KNOWN_HOSTS`:
`ssh-keyscan -p 22 HOST_OR_IP 2>/dev/null`

Dedicated deploy key pair:
`ssh-keygen -t ed25519 -C my-project-production-cd -f my-project-production-cd -N ''`

Single-line value for `DEPLOY_SSH_PRIVATE_KEY_BASE64`:
`base64 -i my-project-production-cd | tr -d '\n' | pbcopy`
