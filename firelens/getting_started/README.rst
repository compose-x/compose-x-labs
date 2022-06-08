
################################################
FireLens - Getting Started
################################################

.. hint::

    Difficulty: Easy

    Level: Mid/Advanced

    ECS Compose-X Version required: 0.21+

TLDR;
======================

Skip to :ref:`getting_started_example`

You should strongly consider using FireLens + Fluent Bit to ship your logs as an alternative to awslogs agent.

Welcome to FireLens
====================

In ECS Compose-X, the default logging driver is ``awslogs``, which sends all the logs of your container to AWS CloudWatch,
and makes it very easy for users to search through the logs that way. Plus, you can use these logs to create alarms,
and create log subscriptions to further process the logs in different streams.

However, it might be beneficial to use a different logger, and a very popular couple is FluentD and Fluent Bit.
They are very performant (one can find a lot of benchmark, here we won't be dwelling into that), lightweight, and
have a lot of plugins that allow you to capture, filter, modify, and send your logs to different destinations, all at once.

But, why ?
-------------

For those who know me, going outside of the AWS Box is not the natural instinct, especially as the awslogs logger
is very performant, requires very little configuration, and it comes "out of the box" on all platforms (EC2, Fargate, ECS Anywhere).

The world of tech changes continuously, but there are key components of what the IT Crowd always have and will need: logs.

For audits, troubleshooting, collecting information and metrics, you name it. People want log, all the time, to know what's
going on. And being able to search efficiently through these logs is absolute key to better and faster resolution.

`FluentD`_ and `FluentBit`_ have been created to help answer the question of performing on-the-fly log manipulation and collection,
to many different destinations, such as AWS, Splunk, and other 3rd party logging services.

FluentD and FluentBit can be used "anywhere", on-prem, cloud, AWS or not. And being able to configure the logging format
of all of this the same way, everywhere, can be very valuable to Ops.

But then, you need to go over the docs (which to be honest, is remarkable for FluentBit, IMHO), and configure your ECS Services
with all the right things.

And this is where FireLens comes into play.

Basic usage
=============

So to use FireLens in ECS, you will need to add a sidecar container, which we will call the ``log_router`` for the rest
of this article, and we will use FluentBit, because that's what's currently supported in Compose-X (yes, this is a support
to the people writing code in C, but also because it just works).

You would then add ``log_router`` container to your task definition, set ``FirelensConfiguration`` to tell ECS that's
your FluentBit log router, and configure the `LogConfiguration`_ of your other containers to use FluentBit.

FireLens is not a driver in itself, it is a configuration wrapper: it will understand from the `LogConfiguration`_
of your application container, the configuration to automatically generate in FluentBit to make the log collection work.

Now, there are `way better explanations`_ and examples than that in the `AWS official FireLens example repository`_
and `excellent recordings`_ explaining how it works.

.. _getting_started_example:

NGINX & random logger example
==================================

So for today very simple example, we are going at how to configure things very simply with ECS Compose-X to leverage
FireLens with our container.


First, let's install ecs-composex

.. code-block:: bash
    :caption: Install ECS compose-x

    python3 -m venv compose-x
    source compose-x/bin/activate; pip install pip -U
    pip install "ecs-compose-x>=0.21"

NGINX and logger, "as-is"
--------------------------

By default, if the `logging`_ section of the docker-compose file you use is not set whilst using ECS Compose-X,
it will default to using `awslogs`_ driver, and take care of everything for you (permissions, creation of the group, etc.).

Here is your baseline docker compose file

.. literalinclude:: ../../firelens/getting_started/docker-compose.yaml
    :language: yaml

So, let's deploy it, then we will update it with our extension files.

.. code-block:: bash

    ecs-compose-x up -d templates -f docker-compose.yaml -n getting-started-with-firelens


Switching to  FireLens
^^^^^^^^^^^^^^^^^^^^^^^^^^

Now that our stack is up, the logs look the way we are used to, we are going use the ``basic_firelens.yaml`` extension file to make a few tweaks.

.. literalinclude:: ../../firelens/getting_started/basic_firelens.yaml
    :language: yaml
    :caption: extension file to enable FireLens

For the frontend container, we simply change the logging driver and option.

.. hint::

    If you don't set some settings, such as ``region`` for FireLens, ECS Compose-X will automatically set that for you.
    For the region, it assumes to use the same region as the one the stack is started into.

As for the random-logs container definition, we just instruct compose-x to switch the current settings, and use
FireLens instead.

This will instruct compose-x to replace the configuration for the ``awslogs`` driver with the appropriate ones for ``awsfirelens``.
We very much recommend to use that as a starting point if that's the first time you use FireLens.

.. code-block:: yaml

    x-logging:
      FireLens:
        Shorthands:
          ReplaceAwsLogs: true


.. tip::

    You can have containers in the same container definition that will use different log drivers.
    For example, by default, ECS Compose-X log the fluentbit logs in CloudWatch, to ensure to have them in case
    it failed itself. Otherwise, we could not know what's happening if it does fail.



So, let's deploy that and see what logs we get.

.. code-block:: bash

    ecs-compose-x up -d templates -f docker-compose.yaml -f basic_firelens.yaml -n getting-started-with-firelens

Running ApacheBench against the container, I can now see the following logs

.. code-block:: json
    :caption: NGINX Logs

    {
        "container_id": "6423836e5a643259ede1cd56f085b114d23a14a14fe9f305f0285e1acd3e5ca0",
        "container_name": "/ecs-web-41-frontend-c0dfd1978deed9ddfb01",
        "ecs_cluster": "ANewCluster",
        "ecs_task_arn": "arn:aws:ecs:eu-west-1:373709687837:task/ANewCluster/f72654d4b1ff42669fb1eee9c110dac0",
        "ecs_task_definition": "web:42",
        "log": "192.168.77.31 - - [08/Jun/2022:21:51:27 +0000] \"GET / HTTP/1.0\" 200 615 \"-\" \"ApacheBench/2.3\" \"-\"",
        "source": "stdout"
    }


.. code-block:: json
    :caption: random logger logs.

    {
        "container_id": "677a1638f1594cbd29029c1dd60d90bdd3636a67ab5c263a0bc6646ea33f2103",
        "container_name": "/ecs-web-41-random-logs-8ae2e9f7eecae5d78801",
        "ecs_cluster": "ANewCluster",
        "ecs_task_arn": "arn:aws:ecs:eu-west-1:373709687837:task/ANewCluster/f72654d4b1ff42669fb1eee9c110dac0",
        "ecs_task_definition": "web:42",
        "log": "2022-06-08T21:47:56+0000 DEBUG This is a debug log that shows a log that can be ignored.",
        "source": "stdout"
    }

Transform NGINX request fields to JSON format
------------------------------------------------------

Great, so we now have both our containers logs shipped into AWS CloudWatch, but we already could do that with ``awslogs``.
At most now, we have added some metadata around the logs, but what if we could do something even better ?

NGINX is a very widely used HTTP Server, often used as reverse-proxy, and its logging pattern is very well known.
In fact, so well known that there is a pre-build parser in FluentBit that will automatically parse the logs, and transform
these into JSON.

So let's see what modifications we need to do.

Extend the FluentBit configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

So, without getting into too many details in this article, we are going to insert a configuration file that
FireLens will use as well as what it will define on its own. Here, the configuration is very simple:

.. literalinclude:: ../../firelens/getting_started/extra.conf

.. hint::

    The content of this file is stored into AWS SSM Parameter. It is then used by `Files Composer`_ to load the file
    into a local docker volume, shared with the ``log_router``, that will use it as an extension configuration.


Using x-logging.FireLens.Advanced
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: yaml
    :caption: Instruct to use x-logging.FireLens.Advanced

    x-logging:
      FireLens:
        Advanced:
          SourceFile: extra.conf
          EnableApiHeathCheck: true
          GracePeriod: 60

.. hint::

    This default nginx parser won't work if you change the log format in your NGINX instance.
    You should create a new parser, with a new regexp, to capture additional fields.

Now we deploy with the advanced configuration, which enables NGINX parsing.

.. code-block:: bash

    ecs-compose-x up -d templates -f docker-compose.yaml -f nginx_parser.yaml -n getting-started-with-firelens

As a result of that configuration change, we now get the NGINX logs with the following format:

.. code-block:: json

    {
        "agent": "ApacheBench/2.3",
        "code": "200",
        "container_id": "bea4eea2635b7c0b007052bb84dae4e6080be34cae3eec60842682138130376f",
        "container_name": "/ecs-web-43-frontend-82dc90fac39f91b54700",
        "ecs_cluster": "ANewCluster",
        "ecs_task_arn": "arn:aws:ecs:eu-west-1:373709687837:task/ANewCluster/1d40d1eb9d64471db28c7e0cb32434b2",
        "ecs_task_definition": "web:43",
        "host": "-",
        "method": "GET",
        "path": "/",
        "referer": "-",
        "remote": "192.168.77.31",
        "size": "615",
        "source": "stdout",
        "user": "-"
    }

As you can see, FluentBit parser has created new fields in the JSON document, corresponding to each "section" of what
we normally have as the logging line.

Summary
========

So, this is all great, but why would I change from raw logs to this new format ?

Well, using something like CloudWatch Logs Insights for example, if you have tens, hundreds of containers running,
in different clusters, different versions, having that little extra metadata allows you to make requests on fields.

In the NGINX example, I can now go to CloudWatch Logs Insights, and make a query on what is now a field, instead of
having to do the parsing on the raw string of the message.

.. code-block::

    fields @timestamp, @message
    | filter remote like /192.168.77.31/
    | sort @timestamp desc
    | limit 20

will return all of the queries with the field ``remote`` value equal to ``192.168.77.31``. This could be very
valuable to quickly identify mis-behaving clients, and makes the search even more so efficient.

Now, on top of that, it is possible as we will see in future blog posts with FireLens, there are many ways
to make FluentBit work for us in very intelligent ways.

In future examples, we will add more in-depth examples, still very much using NGINX and well known applications.


.. _FluentD: https://docs.fluentd.org/
.. _FluentBit: https://docs.fluentbit.io/manual/
.. _LogConfiguration: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ecs-taskdefinition-containerdefinitions-logconfiguration.html
.. _AWS official FireLens example repository: https://github.com/aws-samples/amazon-ecs-firelens-examples
.. _logging: https://docs.docker.com/compose/compose-file/compose-file-v3/#logging
.. _awslogs: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html
.. _Files Composer: https://docs.files-composer.compose-x.io/
.. _way better explanations: https://aws.amazon.com/blogs/containers/under-the-hood-firelens-for-amazon-ecs-tasks/
.. _excellent recordings: https://www.youtube.com/watch?v=HaT9Yc1g170
