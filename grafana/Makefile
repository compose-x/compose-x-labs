################################################################################
#
# dora-dashboard
#
################################################################################

ifndef VERBOSE
.SILENT:
endif

SHELL					= /bin/bash
WATCH					= /usr/bin/watch
AWS						= aws

VENV					?= .venv
VENV_ACTIVATE			=. $(VENV)/bin/activate

STACK					:=cicd--deploy--sc-ce-dora-dashboard

all						: validate

pipeline                :
						$(AWS) cloudformation deploy --capabilities CAPABILITY_IAM 	\
                        --template-file cicd/release_pipeline.yml					\
                        --parameter-overrides file://cicd/pipeline.params.json 		\
                        --stack-name $(STACK)

ecr						:
						$(AWS) cloudformation deploy --template-file cicd/ecr_repository.yml 	\
						--parameter-overrides RepositoryName=sc-ce-dora-dashboard \
						--stack-name ecr-sc-ce-dora-dashboard

validate				:
						$(AWS) cloudformation validate-template \
                        --template-body file://cicd/release_pipeline.yml

events                  :
						$(AWS) cloudformation describe-stack-events \
                        --stack-name $(STACK) \
                        --region $(AWS_REGION)

watch                   :
						$(WATCH) --interval 1 "bash -c 'make events | head -40'"

.PHONY                  : all venv venv-install pipeline validate events watch
