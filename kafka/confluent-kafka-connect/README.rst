.. meta::
    :description: ECS Compose-X Labs
    :keywords: AWS, AWS ECS, Docker, Compose, docker-compose, kafka, connect, confluent

=============================
Kafka Connect  - Confluent
=============================

In this example we are going to deploy to AWS ECS a Connect Cluster using Confluent base image.

Connectors are a very powerful tool that allows to re-use some of the most useful service-to-service integrations,
for examples, from Topic to AWS S3 or Kinesis, from DB to topics, the list goes on.

Here we are not going to go over the deployments of the connectors themselves but only focus on the deployment of
the connect cluster to AWS ECS.

.. note::

    All the following extracts come from the docker-compose.yaml and aws.yaml files.

Network configuration and requirements
========================================

Connnect cluster needs access to Kafka in order to store the connectors configurations, offsets and other kind of information.
So make sure that you kafka cluster has ingress rules to allow kafka connections from the connect security group.

In order to work as a group, the nodes also use a heartbeat mechanism, hence why we have

.. code-block:: yaml

    services:
      connect:
        x-network:
          x-cloudmap: PrivateNamespace
          Ingress:
            Myself: True

    x-cloudmap:
      PrivateNamespace:
        Name: kafka.internal

This will allow ingress from the connect nodes to talk to each other, and register `connect.kafka.internal` in a new
AWS CloudMap private namespace.

.. tip::

    Later on to make API calls to the connect cluster, ensure to add Ingress rules to the security group.
    See `Ingress`_ for more details.


Compute settings & Auto-Scaling
=================================

As per confluence (and from running it in production) the connect nodes are not so CPU hungry. So, so long as you are
not heavy compression or files conversions, the CPU requirements are rather small.
With that said, it is Java, so at startup time it definitely tries to use as much CPU as you will give it.

However, they get memory hungry as more messages are to process and more connectors are deployed.
Therefore, we want to give these nodes a comfortable amount of RAM.

To do this in ECS with a valid Fargate profile, simply assign the **deploy.resources** to the service as you would in
docker compose

.. code-block:: yaml

    deploy:
      resources:
        reservations:
          cpus: "2.0"
          memory: "4G"
      labels:
        ecs.task.family: connect

Auto scaling works like a charm with this application: given that the nodes distribute tasks and consumers change offset
as the application successfully processes messages, it is fault tolerant. Scaling in and out works very well.

Given that we know we are more memory bound than CPU bound, we are going to use a predefined autoscaling rule focusing
on the RAM average across the service nodes

.. code-block:: yaml

    x-scaling:
      Range: "1-6"
      TargetScaling:
        MemoryTarget: 75

CPU & RAM monitoring
======================

With that said, we want still to monitor both CPU and RAM to make sure that overall everything is healthy.
But given that we did define autoscaling, there is no reason to shout out for resources issues before we reach the maximum
number of nodes in the service. We then use the following predefined alarms:

.. code-block:: yaml

    x-alarms:
      Predefined:
        HighCpuUsageAndMaxScaledOut:
          Topics:
            - x-sns: connect-alarms
          Settings:
            CPUUtilization: 85
            RunningTaskCount: 6
            Period: 60
            EvaluationPeriods: 15
            DatapointsToAlarm: 5
        HighRamUsageAndMaxScaledOut:
          Topics:
            - x-sns: connect-alarms
          Settings:
            MemoryUtilization: 80
            RunningTaskCount: 6
            Period: 60
            EvaluationPeriods: 15
            DatapointsToAlarm: 5

Additional files and configuration
=====================================

In case you are connecting to a Kafka cluster that requires SSL Authentication for the connect cluster to work, you will
need additional files to connect: your Java Keystores, or JKS.

Best practices on using Docker is to avoid storing any kind of credentials, and in this case, our private key used for
client auth.

So, we are going to create a S3 bucket, put a password on our JKS and store these in S3.

.. tip::

    For added security, use a non-default KMS key to encrypt these objects in your bucket.

Retrieval of files and config
-------------------------------

To retrieve our JKS we are going to use `ecs-files-composer`_ (`GH Repo <https://github.com/compose-x/ecs-files-composer>`__).
This will be a light sidecar container that will start prior to connect starting.

The only mission for it is to retrieve the files and store them into a docker volume shared between the two containers.

So we start by creating the volume and adding it to the containers volumes.

.. code-block:: yaml

    volumes:
      connect: {}

    services:
      connect-files:
        image: public.ecr.aws/compose-x/ecs-files-composer:latest
        volumes:
        - connect:/opt/connect
        deploy:
          labels:
            ecs.task.family: connect
            ecs.depends.condition: SUCCESS
          resources:
            reservations:
              memory: "128M"

      connect:
        volumes:
        - connect:/opt/connect
        depends_on:
          - connect-files

Now we provide ecs-files-composer instructions through an environment variable on how to retrieve such
files and store them.

.. code-block:: yaml

    services:
      connect-files:
        environment:
          ENV: dev
          ECS_CONFIG_CONTENT: |

            files:
              /opt/connect/truststore.jks:
                mode: 555
                source:
                  S3:
                    BucketName: ${!CONNECT_BUCKET}
                    Key: truststore.jks
              /opt/connect/core.jks:
                mode: 555
                source:
                  S3:
                    BucketName: ${!CONNECT_BUCKET}
                    Key: {!ENV}.jks


.. note::

    The notation **${!ENV_VAR}** is not supported by docker-compose natively. Make sure to set these only for compose-x
    override files.

Now, on start of a new ECS Task, the connect-files container will run first, and only if the execution is successful
will the main container, *connect*, start.

Deployment
============

In the cicd folder you will find a baseline AWS CodePipeline that would trigger from your repository and a sample
buildspec.yml that is used by AWS CodeBuild. That is if you want to deploy this via CICD.

In case you simply want to test this out for yourselves, adapt the content of the aws.yaml file to match your need.

Pre-requisites
---------------

Before you go ahead and deploy this stack, make sure that you have

* Created a new secret in AWS Secret manager using the CloudFormation template, secrets/connect-cluster.yaml
* If you need a JKS to connect, store the JKS secret in Secrets Manager equally
* Ensure you linked these secrets to your connect service.

.. code-block:: yaml

    services:
      connect:
        secrets:
          - CONNECT_CREDS

    secrets:
      CONNECT_CREDS:
        x-secrets:
            Name: /kafka/cluster-id/connect-cluster-creds


If you use a JKS, create the credentials in Secrets Manager with the secrets/client_jks.yaml template.
The similarly to the example above, simply link the secret to connect. Make sure to adopt the configuration environment
variables for connect to use these JKS appropriately.

To ECS!
---------

Assuming you already have access to a kafka cluster from an exisitng VPC in the cloud, we are going to plug-and-play to
that VPC, using `x-vpc`_.

For example, if you have tags on your VPC and subnets, you could use the following

.. code-block:: yaml

    x-vpc:
      Lookup:
        VpcId:
          Tags:
            - Name: vpc--nonprod
        PublicSubnets:
          Tags:
            - vpc::usage: public
        AppSubnets:
          Tags:
            - vpc::usage: "application"
            - vpc::internal: "false"
        StorageSubnets:
          Tags:
            - vpc::usage: storage
        InternalSubnets:
          Tags:
            - vpc::usage: "application"
            - vpc::internal: "true"
        - vpc::primary: "false"

.. tip::

    If you already have an ECS Cluster and EC2 nodes that you wish to deploy to, simply specify that ecs cluster to use.
    For example, if your cluster is called **test**

    .. code-block::

        x-cluster:
          Lookup:
            ClusterName: test

Now, to deploy, you could simply build the docker image for connect, publish to an ECR repository, and deploy

.. code-block:: console

    mkdir outputs
    if [ -z ${AWS_ACCOUNT_ID+x} ]; then export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account); fi
    export REGISTRY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION:-$AWS_DEFAULT_REGION}.amazonaws.com/
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${REGISTRY_URI}
    docker-compose build
    docker-compose push
    ecs-compose-x plan -d outputs -n ${STACK_NAME:-kafka-connect} -f docker-compose.yml -f aws.yml


.. _Ingress: https://docs.compose-x.io/syntax/compose_x/ecs.details/network.html#ingress-definition
.. _ecs-files-composer: https://docs.files-composer.compose-x.io/
.. _x-vpc: https://docs.compose-x.io/syntax/compose_x/vpc.html
