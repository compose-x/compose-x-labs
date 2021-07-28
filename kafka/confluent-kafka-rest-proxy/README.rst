.. meta::
    :description: ECS Compose-X Labs
    :keywords: AWS, AWS ECS, Docker, Compose, docker-compose, kafka, connect, confluent

.. highlight:: shell

=============================
Kafka Rest Proxy  - Confluent
=============================

Kafka Rest proxy is another Confluent software in their ecosystem that allows to make API calls to an endpoint
that will automatically write the payload as a message in kafka topic, or allow to read.

Now, the use-cases for these can be plural, but generally from using it, would only recommend to use it as a producer
and only rely on the native kafka APIs to consume from topics. But that is something for you to know and decide.

In this small example, we consider the rest proxy to be an application like any other for kafka and deploy it, behind
a network load-balancer.

The use-case
=============

Recently our engineers wanted a 3rd party partner, which is sadly incapable of using Kafka native API.
But given that all the backend applications consume from kafka, we needed to allow the 3rd party to simply
publish data to us via HTTP. Given the API calls for Kafka rest proxy are well documented and a lot of the complexity
of such application is dealt with by the Kafka rest proxy, this was an easy win for us.

But then, authentication came in .... and it is either basic auth or mTLS. Neither though would work for our InfoSec.
So, this is where we came up with the ID to use AWS API Gateway to deal with the authentication workflow.

The 3rd party client would go to our IdP with the secret credentials provided, retrieve a JWT token, and then go to API
Gateway with the token. With a Lambda Authorizer, we validate the JWT token with the IdP and if all good, would pass on the
request to the Rest Proxy.

Conveniently that also allowed engineers to validate that the content of the payload is conform to formats and headers
for the rest proxy to work properly.

That is why in this deployment we use the AWS Network Load Balancer: API Gateway in REST mode only connects to NLBs,
where HTTP mode could have allowed us to use Service Discovery, but the devs decided REST was better for this use-case.

.. seealso::

    AWS API Gateway `REST vs API`_ compatibility matrix

Implementation
===============

Kafka access
-------------

But first, we need some credentials to give to our kafka rest proxy. To do that, we are going to use the standard template
**sasl_client.yaml** which will create a new secret in AWS Secrets manager for us. Once you obtained the credentials,
fill in the CFN parameters with appropriate values.

.. tip::

    I recommend you create a whole separate kafka user for this, also called service account in Confluent cloud.
    That way the ACLs you set for the kafka rest proxy are following a least privileges principal and not shared
    credentials with your other applications.

Once that is done, update in the aws.yaml file, the name of the secret

.. code-block::

    secrets:
      KAFKA_CREDS:
        x-secrets:
          Name: /kafka/eu-west-1/zzzzz/kafka-rest-proxy

Now, unless you found the way to rebuild the image etc. from confluent, the easiest way to deploy the rest proxy is to
use Confluent docker image.

.. hint::

    If you are getting rate limited, you can get the images from AWS Public ECR `here <https://gallery.ecr.aws/ews-network/>`__
    These are replicated as-is from dockerhub.

Making it work anywhere
--------------------------

Now, we are adding a small startup script to the original docker image simply to define some environment variables
that are dynamic and only true within the container.

.. literalinclude:: ../../kafka/confluent-kafka-rest-proxy/start.sh

Now, using CICD or even just locally, build the new image and publish it to your registry (CICD examples will be in a dedicated
section of the site).

.. tip::

    Alternatively you could use `ecs-files-composer`_ to pull down a startup script, load it to a locally shared docker volume,
    and change the entrypoint of the kafka-rest-proxy image.

Prepare for deployment
-------------------------

So we have a basic docker-compose file that describes our service and its constant settings.

.. literalinclude:: ../../kafka/confluent-kafka-rest-proxy/docker-compose.yaml

We then create an override file, which can contain our usual docker-compose elements, such as secrets, volumes etc.
We add a few things to plug-and-play to AWS, via Lookup, such as networking settings (VPC, DNS, ECS Cluster) and then add
the NLB via x-elbv2.

Through x-secrets, we define how to export secrets to the container in a way that kafka rest proxy understands.

.. literalinclude:: ../../kafka/confluent-kafka-rest-proxy/aws.yaml

Lift off!
----------

We are ready to deploy. Let's recap what commands we need to run to build and deploy our kafka rest proxy image

.. code-block:: bash

    # Optionally install packages into a virtual environment
    python3 -m venv venv
    source venv/bin/activate
    pip install docker-compose -U
    pip install ecs_composex>=0.15.0

    # Define settings related to our AWS Account
    if [ -z ${AWS_ACCOUNT_ID+x} ]; then AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account); fi
    REGISTRY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION:-$AWS_DEFAULT_REGION}.amazonaws.com/0
    aws ecr get-login-password --region ${AWS_REGION:-$AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${REGISTRY_URI}

    # Define a new docker image tag
    COMMIT_HASH=${CODEBUILD_RESOLVED_SOURCE_VERSION::7}
    EPOCH=`date +'%s'`
    IMAGE_TAG=${COMMIT_HASH:=$EPOCH}
    echo Docker repository $REGISTRY_URI
    echo Docker image tag $IMAGE_TAG

    # Build and push the image to your repository
    docker-compose build
    docker-compose push

    # Init allows to make sure ECS is configured properly in our account and we have a bucket to store templates into
    ecs-compose-x init
    if ! [ -d outputs ]; then mkdir -p outputs; else find outputs -type f -print -delete ; fi

    # This creates a Recursive ChangeSet and lets you know what's about to change, before you deploy
    ecs-compose-x plan -n ${DEPLOYMENT_NAME:-kafka-rest-proxy} -d outputs/  -f docker-compose.yaml -f aws.yaml


.. _ECS ComposeX: https://docs.compose-x.io
.. _REST vs API: https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html
.. _ecs-files-composer: https://docs.files-composer.compose-x.io

