# Project settings
-include .env
PROJECT_NAME = ses-cognito-verification
AWS_PROFILE_PREFIX ?= learning
DEV_ARTIFACTS_BUCKET ?=learning-sandbox-us-west-2-code-artifacts
ARTIFACTS_BUCKET ?= learning-sandbox-us-west-2-code-artifacts
ARTIFACTS_PROFILE ?= learning-sandbox

all: export AWS_PROFILE = learning-sandbox
all: build test deploy integration

install:
	$(INFO) "Installing dev virtual environment..."
	pipenv sync --dev
	pipenv clean
# safety check

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

destroy: export AWS_PROFILE = learning-sandbox
destroy:
	$(INFO) "Deleting stack $(STACK_NAME) and associated artifacts..."
	sam delete --stack-name $(STACK_NAME) --no-prompts --region $$(aws configure get region)

kernel: install
	$(INFO) "Creating iPython kernel $(STACK_NAME)"
	ipython kernel install --user --name=$(STACK_NAME)
	$(INFO) "Kernel named $(STACK_NAME) now available in Jupyter"

jupyter:
	jupyter lab

publish/%:
	config=$$(yq e '. | select(.Template // "template.yaml" == "template.yaml")' config/$*.yaml)
	region=$$(yq e '.Region // "us-west-2"' - <<< "$$config")
	template=build/template.yaml
	$(INFO) "Publishing $$template"
	account=$$(aws sts get-caller-identity --profile learning-$* --query Account --output text)
	application_id=arn:aws:serverlessrepo:$$region:$$account:applications/$(PROJECT_NAME)
	$(INFO) "$$application_id"
	if version=$$(aws serverlessrepo get-application --profile learning-$* --application-id $$application_id --query Version.SemanticVersion --output text 2>/dev/null)
	then
		new_version=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".SemanticVersion' $$template)
		$(INFO) "Current version: $$version"
		if [ $$version != $$new_version ]
		then
			$(INFO) "Publishing new version: $$new_version"
			aws serverlessrepo create-application-version \
				--application-id $$application_id \
				--semantic-version $$(yq e '.Metadata."AWS::ServerlessRepo::Application".SemanticVersion' $$template) \
				--template-body file://$$template \
				--profile learning-$* | jq
		else
			$(INFO) "Skipping as current version is up to date"
		fi
	else
		$(INFO) "Creating new application..."
		author=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".Author' $$template)
		description=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".Description' $$template)
		semantic_version=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".SemanticVersion' $$template)
		home_page_url=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".HomePageUrl' $$template)
		source_code_url=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".SourceCodeUrl' $$template)
		license_url=$$(yq e '.Metadata."AWS::ServerlessRepo::Application".LicenseUrl' $$template)
		aws serverlessrepo create-application \
			--name "$(PROJECT_NAME)" --template-body file://$$template \
			--author "$$author" \
			--description "$$description" \
			--semantic-version "$$semantic_version" \
			--home-page-url "$$home_page_url" \
			--source-code-url "$$source_code_url" \
			--license-url "$$license_url" \
			--spdx-license-id MIT \
			--profile learning-$* | jq
	fi
	aws serverlessrepo put-application-policy \
		--region $$region \
		--application-id $$application_id	 \
		--statements Principals=*,Actions=Deploy \
		--profile learning-$*

# General settings
BRANCH_NAME != git rev-parse --abbrev-ref HEAD
BRANCH_ID ?= $(BRANCH_ID_CMD)
BRANCH_ID_CMD != echo $(BRANCH_NAME) | md5 | cut -c 1-7 -
STACK_NAME ?= $(if $(filter master main,$(BRANCH_NAME)),$(PROJECT_NAME),$(PROJECT_NAME)-$(BRANCH_ID))
MAP_TO_KV := jq -r 'select(.?)|to_entries[]|(.key|tostring)+"="+(.value//""|tostring)' | tr '\n' ' '

# Make settings
.PHONY: *
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
