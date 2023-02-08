
.. meta::
    :description: ECS Compose-X - Fluent Bit mulit-account
    :keywords: Fluent-Bit, Observability, Multi-Account

.. hint::

    Difficulty: Easy

    Level: Mid/Advanced

    ECS Compose-X Version required: 0.23+

TL;DR
======

Using `Fluent-Bit`_, you can easily implement central logging for all your applications.
Deploying your services with `ECS Compose-X`_, takes care of all the configuration and permissions.

Introduction
===============

Are you looking for a lightweight, efficient and performant log collector to ingest and process data from any source and
ship it to your desired location? With Fluent-Bit, you can do just that, and more!

On AWS ECS, the default log driver used to collect your services logs is the `awslogs` driver, which is great,
but all it does is capture the containers output and ship it to Cloud Watch logs. With Fluent-Bit,
you can do more than just capture logs - you can also process and transform them.

AWS recently added new features that makes logs exploration across accounts even easier.
So, why should you use Fluent-Bit? Well let's find out!

The problem
============

The problem posed is that different companies have different monitoring and alerting applications/services and logging requirements,
and maintaining multiple techniques for collecting logs can become complicated.

Different microservices environments (AWS ECS, Kubernetes etc.) also will have different ways to capture logs, adding in complexity.

The solution proposed is to implement a solution that is easily extendable for future requirements and satisfies all business requirements.

Using Fluent-Bit for local and central logging
================================================

.. note::

    It is worth noting that it is highly encouraged to define a logging pattern across your business so that applications
    all produce logs in a similarly expected way, to simplify the log parsing and processing.

.. attention::

    For the Firehose Delivery streams in this example, we are not doing any log parsing to create bucket partitions.
    Feel free to `raise an issue to create a follow-up blog`_ post on how to do that and use Glue for automated partitioning
    with AWS Athena

Architecture
--------------

As described in the diagram below, we are going to demonstrate with a central account that will have

* 1 Central AWS Account, ID 111111111111
* 1 Example Application AWS Account, ID 222222222222

In the central account we have

* 1 Central logging bucket, which will be the destination of FireLens.
* 1 FireHose Delivery Stream **per application account** (allows to ensure only the source app account has access to it and avoids quotas conflicts)
* 1 IAM Role **per application account**, allowing IAM roles in the application account(s) to use ``sts:AssumeRole`` and is granted access to the delivery stream


In the application account(s) we will simply deploy our applications which ECS Compose-X will take care of setting things
up for us. In this demo we will use a very simple NGINX image as it is commonly used and very light.

.. image:: https://images.compose-x.io/labs/multi_accounts_logging_with_fluentbit/FluentBit-Firehose-CrossAccount.jpg

Implementation
----------------

With Fluent-Bit, we are going to be able to capture the logs from our containers. Fluent Bit is used via enabling the
Firelens feature available in ECS, but this is really "simply" a wrapper that you could implement yourself, which I do not
recommend.

Instead, the approach that ECS Compose-X takes is to insert configuration that will be taken into account by the
fluent-bit sidecar that runs alongside our containers.


First of all, we need to prepare our central account by creating our ingest S3 bucket, FireHose distributions, and the
IAM roles to allow the cross-account for fluent-bit to send logs to our Firehose streams.

You can find the necessary `CloudFormation templates here`_ or deploy directly to your account by using the links below.


* `Create the central logging S3 Bucket`_

* `Create the IAM role and FireHose delivery stream`_

.. hint::

    If you already have an existing bucket you wish to re-use, make sure to set the permissions accordingly if you use your own
    KMS Encryption key.

Once we have our resources created, take note of the ARNs (IAM Role and delivery stream). Now, we can move onto deploying
our services

Configure services logging with ECS Compose-X
----------------------------------------------

Now we have the receiving infrastructure in place, we can start configure our service with compose-x to do all this.

.. note::

    This is something you could all configure yourself manually, but can be daunting to implement depending on your
    level of experience with ECS & Fluent-Bit configuration.

First, we create the `x-logging.Firelens`_ section in the service we want to use Firelens with. Remember that this uses
Fluent-Bit behind the scenes.

.. code-block:: yaml

    services:
      my-web-application:
        logging:
          driver: awsfirelens # We say we want to use firelens driver
          options:
            Name: cloudwatch # We output logs to CloudWatch by default
        x-logging:
          FireLens:
            Advanced:
              EnableApiHeathCheck: true # Enable active healthcheck on the fluent-bit container
              GracePeriod: 60 # How long after receiving SIGTERM to wait before quitting. Ensures all logs are sent.
              ComposeXManagedAwsDestinations:
                - delivery_stream: arn:aws:firehose:eu-west-1:111111111111:deliverystream/central-logging # Stream in central account
                  role_arn: arn:aws:iam::111111111111:role/222222222222_central-logging # Role in central account to assume to publish logs


Deployment
---------------

.. warning::

    Make sure to have your AWS Profile set to using the application account, in our examples, 222222222222

    .. code-block:: bash

        # Set AWS_PROFILE to be sure to use your application account
        # export AWS_PROFILE=<application-account-profile>

.. code-block:: bash

    # Check you have version 0.23+
    ecs-compose-x --version

    # If this is your first time using ecs-compose-x, run init to ensure your AWS Account settings are good
    ecs-compose-x init

    # Try to render the files - This will simulate a dry-run
    ecs-compose-x render \
        -d templates \
        -p demo-cross-account-fluentbit \
        -f docker-compose.yaml \
        -f aws.yaml

    # If successful, deploy
    ecs-compose-x up \
        -d templates \
        -p demo-cross-account-fluentbit \
        -f docker-compose.yaml \
        -f aws.yaml

A few benefits to using FireLens and FluentBit with AWS ECS
===========================================================

Fluent Bit will capture your logs and send them to the outputs you've set up, most likely CloudWatch logs.
The Firelens "wrapper" adds extra data to the logs such as the task definition, ECS Cluster, container ID, and more.
This makes it easier to identify which version of your ECS Service created the logs, allowing you to quickly troubleshoot applications.
Additionally, since the logs are in JSON, CloudWatch log query makes it easy to perform queries with these parameters.
You can add as much meta-data as you'd like to the logs and it's straightforward to do so.

How can I extend this architecture?
=======================================

You can use FireHose to log all the information into a S3 bucket and enforce a logging format.
This will enable you to ingest the logs into S3 automatically and create "partitions" for faster research and discovery
with other AWS Services such as Glue & Athena.

This has been working well for us, and we can quickly query any of the logs for our applications.

When multiple applications depend on a central resource, having a central logging query system in place can help identify
affected services in a single query.

You can also have Fluent-Bit send the data to an OpenSearch (previously known as ElasticSearch) cluster, as part of your existing ELK stack.
Alternatively, you could set up Fluent-Bit to send the logs directly to OpenSearch.
However, it is advisable to make this the responsibility of Firehose to limit the risks of failures withing your log collector container,
which could take down your application.



.. _x-logging.Firelens: https://docs.compose-x.io/syntax/compose_x/ecs.details/x_logging_firelens.html
.. _Fluent-Bit: https://fluentbit.io/
.. _ECS Compose-X: https://docs.compose-x.io
.. _raise an issue to create a follow-up blog: https://github.com/compose-x/compose-x-labs/issues
