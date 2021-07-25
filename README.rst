====================
Compose-X Labs
====================

This repository aims to show-case Compose-X projects to deploy on AWS ECS (with many other AWS Services) well known
applications, CMS, and other more specialized applications.


Applications
=============

* ECS Compose-X (`Source <https://github.com/compose-x/ecs_composex>`__ | `Docs <https://docs.compose-x.io>`__ | `AWS SAR <https://serverlessrepo.aws.amazon.com/applications/eu-west-1/518078317392/compose-x>`__)
* ECS Files Composer (`Source <https://github.com/compose-x/ecs-files-composer>`__ | `Docs <https://docs.files-composer.compose-x.io>`__)
* ECR Scan Reporter (`Source <https://github.com/compose-x/ecr-scan-reporter>`__ | `Docs <https://ecr-scan-reporter.compose-x.io>`__ | `AWS SAR <https://serverlessrepo.aws.amazon.com/applications/eu-west-1/518078317392/ecr-scan-reporter>`__)

Pre-requisites
===============

Have an AWS Account and either configure a profile for it to use the CLI, or head to `AWS SAR to install the Compose-X
CloudFormation Macro`_

Use ECS Compose-X as CLI
--------------------------

.. code-block:: console

    # Install for you user
    python3 -m pip install ecs-composex --user

    # Install in a virtual environment
    python3 -m venv venv
    source venv/bin/activate
    python3 -m pip install ecs-composex

    # With docker
    docker run --rm -e AWS_PROFILE=$AWS_PROFILE -v $HOME/.aws/:/root/.aws public.ecr.aws/compose-x/compose-x

Initialize your AWS Account for ECS Compose-X (see `requisites`_)

.. code-block:: console

    ecs-compose-x init # Will create a default directory, enable ECS Features.

Applications examples
=======================

A majority of examples are taken from `awesome-compose`_ and otherwise well-known applications.
Having worked a lot recently with Kafka, a number of these examples will reflect work recently done to deploy kafka
applications as well.

.. _requisites: https://docs.compose-x.io/requisites.html
.. _AWS SAR to install the Compose-X CloudFormation Macro: https://serverlessrepo.aws.amazon.com/applications/eu-west-1/518078317392/compose-x
.. _awesome-compose: https://github.com/compose-x/awesome-compose
