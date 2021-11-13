# Ses Custom Resources

This is repository was created from the [SAM python](https://github.com/trilogy-group/sam-python) cookie cutter template, which provides an opinionated workflow to deploy Serverless Apps based on [Serverless Application Model (SAM)](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) and Python.

## Features

- [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) for packaging and deploying serverless infrastructure
- [Pipenv](https://pipenv-fork.readthedocs.io/en/latest/) to manage virtual environment and dependencies
- [pytest](https://docs.pytest.org/) for unit and integration testing
- Deployable and tested [starter app](./src/app/__init__.py)
- Unit test starter [mocks](./tests/unit/conftest.py) and [tests](./tests/unit/test_app.py)
- Integration test starter [fixtures](./tests/integration/conftest.py) and [tests](./tests/integration/test_app.py)
- Creates a Lambda layer for dependencies
- Optimizes Lambda layer bundle size to remove boto3/botocore libraries already included in the AWS Lambda runtime environment
- Separate [config file](./config.yaml) for defining input parameters and stack tags
- [Multiple environment](./config) deployment support
- Support for multiple feature branches
- Jupyter notebook support
- AWS X-Ray integration
- [async and worker decorators](./src/utils/aio.py) to provide simple async support for Lambda functions

## Requirements

- [Python 3.x installed](https://github.com/pyenv/pyenv)
- [Pipenv](https://pipenv.readthedocs.io/en/latest/)
- [make v4.x or higher](https://formulae.brew.sh/formula/make)
- [yq v4 or higher](https://mikefarah.gitbook.io/yq/)
- [jq v1.6 or higher](https://stedolan.github.io/jq/download/)

You will also need to set up your AWS profiles according to the following naming convention:

`<aws-profile-prefix>-<environment>`

For example, if you configure your AWS profile prefix as `learning`, you might set up the following profiles:

- learning-sandbox
- learning-staging
- learning-production

Note that the `environment` value is used both for deployment and defining environment configurations:

- config.yaml (used for local development)
- config/sandbox.yaml (used to deploy master branch into sandbox environment)
- config/staging.yaml (used to deploy master branch into staging environment)
- config/production.yaml (used to deploy master branch into production environment)

Typically the "sandbox" profile is used for local development.

## Local Development

All development occurs on a feature branch.

After checking out a new branch, you should first deploy using the `make` command, which will build, test, deploy and run integration tests for the sample application:

```
$ export AWS_PROFILE=learning-sandbox
$ make
...
...
```

This will deploy a CloudFormation stack to AWS with a stack name of `<project-name>-<branch-id>`, where `branch-id` is a hash value generated from the branch name.

e.g. `cenpro-15930-abc1234`

Once deployed, you can write new code, tests, make changes to infrastructure and re-deploy using the `make` command.

### Workflow

This repository is based upon a feature-branch continuous delivery methodology, where all development and QA occurs on a feature branch.

Once development and QA is complete, a pull request for the feature branch is created that is subject to final technical review and acceptance.

Once a PR is merged, the intention is that the master branch is automatically deployed in production.

## Jupyter Notebooks

To work with Jupyter notebooks you first need to create a kernel by running `make kernel`:

```
$ make kernel
...
...
=> Creating iPython kernel cenpro-15930
Installed kernelspec cenpro-15930 in /Users/jmenga/Library/Jupyter/kernels/cenpro-15930
=> Kernel named cenpro-15930 now available in Jupyter
```

This will create a kernel named using your project name, which operates from your local development virtual environment.

> You only need to run `make kernel` once per local environment

You can now start up a Jupyter notebook server by running `make jupyter`.

When creating Jupyter notebooks, select the kernel you created previously to access your local development virtual environment.
