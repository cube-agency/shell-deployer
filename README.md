# Shell Deployer

Shell Deployer is a simple bash shell based deployment tool designed to streamline the deployment process of Laravel and Node.js projects via GitLab CI/CD pipelines. It simplifies the deployment steps, making it easy to deploy projects to various environments with minimal configuration.

## Getting Started

To use deployer in your project, add npx deployment script call in your `.gitlab-ci.yml` file with the necessary configurations. Below are examples for both Laravel and Node.js projects.

### Node.js GitLab CI Example

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
    - npx -y -p shell-deployer@1.1.0 deploy-nodejs dist/spa/ --with-build

deploy to staging:
  <<: *deploy
  environment:
    name: staging
    url: https://example-nodejs-project.com
  variables:
    DEPLOY_HOST: staging.example.com
    DEPLOY_USER: example_user
    DEPLOY_PATH: /home/example_user/app
    DEPLOY_SSH_KNOWN_HOSTS: $STAGING_DEPLOY_KNOWN_HOSTS
    DEPLOY_SSH_PRIVATE_KEY: $STAGING_DEPLOY_PRIVATE_KEY
```

### Laravel GitLab CI Example
```yaml
.deploy: &deploy
  stage: deploy
  allow_failure: false
  when: manual
  tags:
    - deploy
  script:
    - npx --yes -p shell-deployer@1.1.0 deploy-laravel app.tgz --with-build

deploy to staging:
  <<: *deploy
  environment:
    name: staging
    url: https://example-laravel-project.com
  variables:
    DEPLOY_HOST: staging.example.com
    DEPLOY_USER: example_user
    DEPLOY_PHP_COMMAND: php8.3
    DEPLOY_PATH: /home/example_user/app
    DEPLOY_SSH_KNOWN_HOSTS: $STAGING_DEPLOY_KNOWN_HOSTS
    DEPLOY_SSH_PRIVATE_KEY: $STAGING_DEPLOY_PRIVATE_KEY
```

## Configuration

### Environment Variables

#### Required Environment Variables

- **DEPLOY_HOST**: The hostname or IP address of the server where the project will be deployed.
- **DEPLOY_USER**: The username used to log into the server.
- **DEPLOY_PATH**: The path on the server where the project should be deployed. This script uses this path to create a `releases` directory where each release will be stored in a timestamped subdirectory. Latest release will be symlinked to `current` directory.

#### Optional Environment Variables

- **DEPLOY_SSH_KNOWN_HOSTS**: If you need to bypass the SSH known hosts check or if you're deploying to a new server that isn't in your `known_hosts` file yet, you can specify the SSH known hosts directly with this variable. The script will append this information to the `known_hosts` file located at `$DEPLOY_SSH_PATH/known_hosts`.
- **DEPLOY_SSH_PRIVATE_KEY**: The actual SSH key as a string. This script dynamically creates an SSH key file at `DEPLOY_SSH_PRIVATE_KEY_PATH` and sets the correct permissions (`chmod 600`). This is useful for CI/CD environments where you might not want to store the private key on the filesystem or in the image.
- **DEPLOY_SSH_PORT**: The port to use for SSH connections. If not set, the default SSH port `22` is used. This allows flexibility for deployments to servers configured to use non-standard SSH ports.
- **DEPLOY_SSH_PRIVATE_KEY_PATH**: The path where the deployment script should store the SSH key used for the deployment. If not set, the script defaults to using `$HOME/.ssh/id_rsa`. This is critical if you're using a specific SSH key for deployment that isn't the default key.

#### Optional Laravel Environment Variables
- **DEPLOY_PHP_COMMAND**: PHP binary name on remote server. Either name (ex. `php8.3`) or full path (ex `/usr/bin/php8.3`) can be specified. If not set, the default name of `php` is used.
- **DEPLOY_SHARED_FILES**: List of `;` separated files in `DEPLOY_PATH/shared` directory to be symlinked against deployed release. If not set, the default value of `.env` is used.
- **DEPLOY_SHARED_DIRECTORIES**: List of `;` separated directories in `DEPLOY_PATH/shared` directory to be symlinked against deployed release. If not set, the default value of `storage` is used.
- **DEPLOY_SHARED_STORAGE_DIRECTORIES**: List of `;` separated directories in `DEPLOY_PATH/shared/storage` directory to be created. If not set, the default value of `app/public;framework/cache/data;framework/views;framework/sessions;logs` is used.
- **DEPLOY_ARTISAN_COMMANDS**: List of `;` separated artisan commands to be called to complete deployment process. If not set, the default value of `storage:link;config:cache;migrate --force;translator:flush;translator:load;view:cache;arbory:route-cache;queue:restart` is used.

#### Other Laravel configuration
When building Laravel deployment archive https://github.com/cube-agency/shell-deployer/blob/master/.buildignore is used.  
If there are need for customized list of ignorable files and directories, create `.buildignore` named file at the root of your project.

### Script Parameters

- **DEPLOYMENT_SOURCE_PATH**: This is a required positional argument that specifies the source directory or file of the deployment. It must be passed when invoking the script.
- **--with-build**: This optional flag can be added as the last argument to the script to indicate that a build process should occur as part of the deployment.

## Build process

Make sure that `npm run build` creates production build.   
It's same for both Node.js and Laravel deployments.