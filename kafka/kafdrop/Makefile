################################################################################
#
# kafdrop
#
################################################################################

ifndef VERBOSE
.SILENT:
endif

ifndef REPO_NAME
REPO_NAME               = sc-ce-kafdrop
endif

SHELL					= /bin/bash
WATCH					= /usr/bin/watch
AWS						= aws

VENV					?= .venv
VENV_ACTIVATE			=. $(VENV)/bin/activate

STACK					:=cicd--deploy--kafdrop

all						: validate

pipeline                :
						$(AWS) cloudformation create-stack --capabilities CAPABILITY_IAM 	\
                        --template-body file://cicd/release_pipeline.yml					\
                        --parameters file://cicd/pipeline.params.json 		\
                        --stack-name $(STACK)

ecr						:
						$(AWS) cloudformation deploy --template-file cicd/ecr_repository.yml 	\
						--parameter-overrides RepositoryName=$(REPO_NAME) \
						--stack-name ecr--$(REPO_NAME)

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
