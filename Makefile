# Project settings
-include .env
PROJECT_NAME = ses-custom-resources
AWS_PROFILE_PREFIX ?= devfactory
DEV_ARTIFACTS_BUCKET ?=devfactory-sandbox-us-east-1-code-artifacts
ARTIFACTS_BUCKET ?= devfactory-sandbox-us-east-1-code-artifacts
ARTIFACTS_PROFILE ?= devfactory-sandbox

all: export AWS_PROFILE = devfactory-sandbox
all: build test deploy integration

install:
	$(INFO) "Installing dev virtual environment..."
	pipenv sync --dev
	pipenv clean
	safety check

build: clean install
	$(INFO) "Creating production build..."
	mkdir -p build/dependencies
	pipenv lock -r > build/dependencies/requirements.txt
	sam build --use-container --cached
	find .aws-sam/build -type d -name 'boto*' -exec rm -rf {} +
	$(INFO) "Build complete"

deploy: ARTIFACTS_PROFILE=
deploy: ARTIFACTS_BUCKET=$(DEV_ARTIFACTS_BUCKET)
deploy: DEPLOYMENT_PROFILE=
deploy: CONFIG=config.yaml
deploy: deploy/local

deploy/%:
	$(if $(and $(filter master main,$(BRANCH_NAME)),$(filter local,$*)),$(ERROR) "Cannot deploy from master branch",)
	config=$${CONFIG:-config/$*.yaml}
	profile=$${DEPLOYMENT_PROFILE-$(AWS_PROFILE_PREFIX)-$*}
	config_yaml=$$(yq e $$config)
	set -f; parsed=$$(eval "echo \"$$config_yaml\""); set +f
	params=($$(yq e '.Parameters' -j - <<< "$$parsed" | $(MAP_TO_KV)))
	tags=($$(yq e '.Tags' -j - <<< "$$parsed" | $(MAP_TO_KV)))

	$(INFO) "Packaging application using s3://$(ARTIFACTS_BUCKET)..."
	sam package --output-template-file build/template.yaml \
		--s3-bucket $(ARTIFACTS_BUCKET) \
		--s3-prefix $(STACK_NAME) \
		--output-template-file build/template.yaml \
		$${ARTIFACTS_PROFILE:+--profile $(ARTIFACTS_PROFILE)}
	cfn-lint -t build/template.yaml
	
	$(INFO) "Deploying application $(STACK_NAME)..."
	echo "=> Stack overrides: [$${params[@]}]"
	sam deploy --stack-name $(STACK_NAME) \
		--template-file build/template.yaml \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		$${params:+--parameter-overrides "$${params[@]}"} \
		$${tags:+--tags "$${tags[@]}"} \
		$${profile:+--profile $$profile} \
		--no-fail-on-empty-changeset

test:
	$(INFO) "Running tests..."
	mkdir -p build
	pytest --cov=src --cov-report term-missing --cov-report xml:build/coverage.xml --cov-report= tests/unit -vv

watch:
	ptw tests/unit src -- --last-failed --new-first -m 'not slow'

integration:
	$(INFO) "Running integration tests..."
	pytest tests/integration -vv

update: clean
	$(INFO) "Updating dependencies..."
	pipenv lock --dev
	pipenv sync --dev
	pipenv clean

clean:
	$(INFO) "Cleaning environment..."
	rm -rf build
	find . -type f -name '*.py[co]' -delete 
	find . -type d -name __pycache__ -exec rm -rf {} + 
	find . -type d -name .pytest_cache -exec rm -rf {} +

destroy: export AWS_PROFILE = devfactory-sandbox
destroy:
	$(INFO) "Deleting stack $(STACK_NAME) and associated artifacts..."
	sam delete --stack-name $(STACK_NAME) --no-prompts --region $$(aws configure get region)

kernel: install
	$(INFO) "Creating iPython kernel $(STACK_NAME)"
	ipython kernel install --user --name=$(STACK_NAME)
	$(INFO) "Kernel named $(STACK_NAME) now available in Jupyter"

jupyter:
	jupyter lab

# General settings
BRANCH_NAME != git rev-parse --abbrev-ref HEAD
BRANCH_ID ?= $(BRANCH_ID_CMD)
BRANCH_ID_CMD != echo $(BRANCH_NAME) | md5 | cut -c 1-7 -
STACK_NAME ?= $(if $(filter master main,$(BRANCH_NAME)),$(PROJECT_NAME),$(PROJECT_NAME)-$(BRANCH_ID))
MAP_TO_KV := jq -r 'select(.?)|to_entries[]|(.key|tostring)+"="+(.value//""|tostring)' | tr '\n' ' '

# Make settings
.PHONY: install build deploy test watch integration update clean destroy kernel jupyter
.ONESHELL:
.SILENT:
SHELL=pipenv
.SHELLFLAGS=run bash -ceo pipefail
YELLOW := "\e[1;33m"
RED := "\e[1;31m"
NC := "\e[0m"
INFO := bash -c 'printf $(YELLOW); echo "=> $$0"; printf $(NC)'
ERROR := bash -c 'printf $(RED); echo "ERROR: $$0"; printf $(NC); exit 1'
MAKEFLAGS += --no-print-directory
export
