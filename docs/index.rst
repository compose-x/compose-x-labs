.. meta::
    :description: Compose-X Labs
    :keywords: AWS, ECR, Docker, vulnerabilities, scan, serverless


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

.. toctree::
   :maxdepth: 1
   :caption: Usual Suspects

   apps/wordpress
   apps/grafana

.. toctree::
   :maxdepth: 1
   :caption: Kafka

   kafka/connect
   kafka/restproxy
   kafka/kafdrop

.. toctree::
    :caption: Monitoring
    :maxdepth: 1

    monitoring/ecs-containers-insights-prometheus



Indices and tables
==================
* :ref:`genindex`
* :ref:`search`


.. _requisites: https://docs.compose-x.io/requisites.html
.. _AWS SAR to install the Compose-X CloudFormation Macro: https://serverlessrepo.aws.amazon.com/applications/eu-west-1/518078317392/compose-x
