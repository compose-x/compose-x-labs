

TLDR;
=========

You can very easily have separate pipelines to build and tests your services separately and merge them together
for integration testing.

Using cookiecutter to layout your initial repository and automation, combined with CICD pipelines, Docker-Compose and
ECS Compose-X can reduce the effort tremendously and allow for agile, speedy and reliable applications lifecycle.

Use-case
==========

In the world of microservices and CICD, one of the most common pattern to build, deploy, test and repeat is to have
multiple services split into multiple repositories of their own. This allows to keep the repositories light and you
can re-use the same automation you put in place for one service, with other services, and so on.

So today we are going to have 3 different services, which work together, which we would test locally together using
docker, and want to deploy to AWS ECS.

Hold on. Why not simply using AWS Copilot ?
-----------------------------------------------

Great question. AWS Copilot does indeed have a very neat support for doing what we are about to do today. However,
from the documentation, there is no evidence of support for multi-accounts deployment.

Also, AWS Copilot has **no support for docker-compose syntax**.

So you have to switch from a well-known, easy to distribute and use
"specification" / definition to (yet) a new one. Using ECS Compose-X, you can use docker-compose locally and instruct for
deployment to AWS without making any changes.


AWS Accounts structure
========================

We are going to have 3 accounts today. The first one, our "management" account, is where all the CICD is driven from

* CopePipeline services integration
* AWS CodeBuild projects (for build, test and generating our artifacts)
* AWS ECR repositories (we want the same image to be deployed in all environments).

Optionally, you might decide to use AWS CodeCommit to store the integration pipeline source code.

For today we will use GitHub as the VCS given that it is one (if not the ?) most used public Git repositories SaaS.

Just the one account. We will go through setting AWS CodeStar connection too in this blog post.


The services
=============

Very simple services today, as they are not quite the important piece of the puzzle for us.

We will have services we call *frontend*, *backend*, and finally *batch-processor*.
Frontend will receive API calls from the internet, placed behind an ALB.
Backend will receive API calls from *frontend*. Backend will post messages into SQS and our *batch-processor* service
will auto-scale based on the workload.


** INSERT DIAGRAM HERE **

Multi-Account setup
=======================

We will setup our multi-account necessary resources using the `ansible playbook that is explained here.`_

Replace the profile with existing AWS profiles you have configured on your machine.

.. code-block:: bash

    python -m venv ansible-venv
    source ansible-venv/bin/activate
    pip install pip -U
    pip install ansible==4.4.0
    ansible-galaxy collection install amazon.aws
    git clone https://github.com/compose-x/codepipline-orchestra.git
    cd codepipline-orchestra/aws_accounts_setup
    ansible-playbook playbook-cicd-01.yaml                  \
        -e cicd_account_profile=<cicd_profile>              \
        -e nonprod_account_profile=<nonprod_profile>        \
        -e prod_account_profile=<prod_profile>


It is important that we have AWS CloudFormation exports in place as the templates in the **cookiecutter** later
on will expect to be able to find these.


One more thing we will do in the console this time, is to set AWS CodeStar connection to GitHub. This will allow
us to have webhooks etc. in place without relying on a personal access token, which can cause access issues in organizations
when a person leaves, and you have to replace it all.

GitHub repositories
=====================

Today we will have 3 repositories, for each service

* `frontend repostory`_
* `backend repository`_
* `batch-processor repository`_


These are very basic and simple, simply to show-case what we are doing here rather than making the apps over complicated.



.. _ansible playbook that is explained here.: https://labs.compose-x.io/cicd/init_aws_accounts.html

