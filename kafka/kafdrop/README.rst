.. meta::
    :description: ECS Compose-X Labs
    :keywords: AWS, AWS ECS, Docker, Compose, docker-compose, kafka, kafdrop

.. highlight:: shell

=========
Kafdrop
=========

.. seealso::

    `All the source files to deploy this solution using ECS Compose-X can be found here.`_


The situation
==============

; TLDR: need an easy way to visualize messages payload in kafka, in read only

There are a number of tools that allow users to visualize the messages and configurations of Kafka topics.
Confluent has their Control Center which is very comprehensive and has a lot of features.
But, it has a major flow for me: it requires pretty much admin level of access and unless you have it deployed yourself,
implementing RBAC for it is pityful, and very limited in actual roles assignments. And, **no read-only mode...**

But forget about Confluent for a minute, generally speaking, providing access to users to productions clusters can be a risk:

* The information in the topics might contain PPI, very sensitive
* You want people to be able to visualize the information but not alter it, if there is no need for it.

So I looked at alternatives and directed to using `Kafdrop`_

The documentation is not the most comprehensive but it does the job and although I would have preferred a solution
which could take all the settings from environment variables and not in b64, kafdrop does a really good job at doing
what I needed it to do.

Deployment
==============

I want to use an ALB and cognito + Azure SAML provider. So I set everything up to be ready for it, which I won't cover it
here, and in the example files, I commented out the Cognito configuration for you to be able to deploy it without worrying
about it.

However, I will be having NGINX in front of it to have TLS termination between the ALB and kafdrop. This also allows
me to add HSTS to it, for some extra security.

NGINX will be here as a simple reverse proxy, but one could add settings or features to it to and really anything you'd
want that NGINX can do for you.

I could have re-use the original NGINX image provided on Dockerhub or AWS ECR Public, but, for this one I want to use
Amazon Linux as the base OS, so I am building that image myself.

For kafdrop itself, there also is a docker image published on dockerhub, but I preferred to re-compile it and host the
jar on S3 and that helps me test out further `Files Composer`_.

.. hint::

    For NGINX and kadrop, feel free to re-use the images from dockerhub, this would work in the same way, totally up
    to your preference.


Files and config in docker volumes
-----------------------------------

We are going to need two volumes: one for NGINX configuration, and one for kafdrop JAR and configuration.

.. attention::

    Although I am doing this here on purpose for testing reasons, I do not recommend to have your application files,
    here the kafdrop JAR, outside of the docker image, to respect the principle of immutability of the application.

We then indicate how we are going to mount them in our services. First container starting, files-composer, will retrieve
the various files, **generate the self-signed certificates** for NGINX to use, and on success, exit successfully (return 0).

.. tip::

    Only if the retrieval of the files and generating configurations, certificates etc, will then the other containers start.
    That is achieved with the deploy.labels **ecs.depends.condition: SUCCESS** property.

So let's have a look at our volumes and services using them.

.. code-block:: yaml

    volumes:
      nginx:
      kafdrop:

    services:
      files-composer:
        volumes:
        - kafdrop:/app
        - nginx:/etc/nginx

      nginx:
        volumes:
        - nginx:/etc/nginx/ssl:ro

      kafdrop:
        volumes:
        - kafdrop:/app:ro

.. note::

    We only mount them in the files-composer container with RW access, but the other two containers shan't modify
    files in these mount paths, so we mount them in *read only*

So all we have to make sure of is that the configuration files for NGINX and the config etc. for startup script of kafdrop
are in the right path.

NGINX Configuration and files
------------------------------

For NGINX we generated our certificates via

.. code-block:: yaml

    files:
      /etc/nginx/dhparam.pem:
        source:
          S3:
            BucketName: files.compose-x.io
            Key: labs/files-composer/dhkeys/dhparam_9.pem
        mode: 600

    certificates:
      x509:
        /etc/nginx:
          keyFileName: nginx.key
          certFileName: nginx.crt

.. hint::

    I pre-generated the DH key because that operation can take a long time and that would further delay the start
    of the container. I highly recommend to generate your own and re-use them across your applications.

We generated all these files in the **/etc/nginx** path on the files composer, but, we want to mount them in
**/etc/nginx/ssl** on the NGINX container, as the **/etc/nginx** path contains already our nginx.conf and other
default NGINX config that we do not want to alter.

We reflect that path in the NGINX configuration

.. code-block:: conf

      server {
        listen 443 ssl;
        server_name _;
        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_dhparam /etc/nginx/ssl/dhparam.pem;
        ssl_ecdh_curve secp384r1;
        location / {
          proxy_pass http://kafdrop;
          add_header Strict-Transport-Security "max-age=16156800; includeSubDomains" always;
        }
      }

Kafdrop configuration
----------------------

For Kafdrop, we are doing the unusual thing that is to pull the JAR for it and use that. That is pretty much as if we
used *COPY* or *ADD* and built a dedicate image for it. So if you prefer to, simply use the image kafdrop maintainers
published, the only thing for you to do is replace the image URL.

Now for the connection to our kafka cluster, we created a new kafka user, which principal we will dub to *kafdrop*.

.. tip::

    For ACLs required for kafdrop to work, have a look at `acls.yaml`_. Note that topic are set to ANY (*) which is only
    here for convenience, please do set ACLs properly for your needs.

Here, I am going to assume that your kafka cluster is using SASL to connect, therefore re-use this `kafka credentials template`_.

We expose that secret to both files-composer and the kafdrop container.

.. code-block:: yaml

    secrets:
      KAFKA_CREDS:
        x-secrets:
          Name: kafka/eu-west-1/lkc-z6v51/kafdrop.prod
          JsonKeys:
            - SecretKey: BOOTSTRAP_SERVERS
            - SecretKey: SASL_USERNAME
            - SecretKey: SASL_PASSWORD
            - SecretKey: SCHEMA_REGISTRY_URL
            - SecretKey: SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO

For files-composer, that will allow to generate a small bash script with all the configuration needed for kafdrop to work
and the kafka.properties file

.. code-block:: yaml

    services:
      files-composer:
        secrets:
          - KAFKA_CREDS
        environment:
          ECS_CONFIG_CONTENT: |

            files:
              /app/kafka.properties:
                content: |
                  # Properties
                  ssl.endpoint.identification.algorithm=https
                  sasl.mechanism=PLAIN
                  sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"{{ default | env_override('SASL_USERNAME') }}\" password=\"{{ default | env_override('SASL_PASSWORD') }}\";
                  security.protocol=SASL_SSL
                  # EOF

                mode: 644
                context: jinja2

              /app/start.sh:
                content: |

                  echo ${!PWD}
                  echo {{ default | env_override('BOOTSTRAP_SERVERS') }}
                  echo {{ default | env_override('SCHEMA_REGISTRY_URL') }}
                  ls -l /app
                  cd /app
                  echo ${!PWD}

                  java --add-opens=java.base/sun.nio.ch=ALL-UNNAMED                                           \
                    -jar /app/kafdrop.jar                                                                     \
                    --kafka.brokerConnect={{ default | env_override('BOOTSTRAP_SERVERS') }}                   \
                    --schemaregistry.connect={{ default | env_override('SCHEMA_REGISTRY_URL') }}              \
                    --schemaregistry.auth={{ default | env_override('SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO') }}\
                    --topic.deleteEnabled=false                                                               \
                    --topic.createEnabled=false
                mode: 755
                context: jinja2

              /app/kafdrop.jar:
                source:
                  S3:
                    BucketName: files.compose-x.io
                    Key: app-demos/kafdrop/kafdrop-3.28.0-SNAPSHOT.jar
                mode: 644

The above configuration will instruct files-composer to create 3 files:

* /app/kafka.properties the kafka properties which include our SASL username and password
* /app/start.sh which is the script we will use as entrypoint to get kafdrop started
* /app/kafdrop.jar the application jar

.. tip::

    As mentioned above, you could use the kafdrop image from dockerhub, just make sure to have the **kafka.properties** file
    mounted in the right location for kafdrop to find it, and pass on the BOOTSTRAP/Schema registry parameters.

And that's it for the services configuration part. This might feel a little overwhelming, but all together this is very
standard to what you would need to do for most services.

The AWS configurations
=======================

Let's get the network part out of the way. In my case, I already have a VPC and network infrastructure, so I simply perform
a lookup to identify these using AWS Tags

.. code-block:: yaml

    x-vpc:
      Lookup:
        VpcId:
          Tags:
            - Name: vpc--composex-prod
        InternalSubnets :
          Tags:
            - vpc::usage: application
            - vpc::internal: "true"
            - vpc::primary: "false"
        AppSubnets:
          Tags:
            - vpc::usage: application
            - vpc::internal: "false"
            - vpc::primary: "true"
        PublicSubnets:
          Tags:
            - vpc::usage: public
        StorageSubnets:
          Tags:
            - vpc::usage: storage

Then our SSL certificates for our ALB, plus DNS, which will create a DNS record pointing at our ALB

.. code-block:: yaml

    x-dns:
      PublicZone:
        Name: prod.compose-x.io
        Lookup:
          RoleArn: ${PROD_RO_ROLE_ARN}
      PrivateNamespace:
        Name: prod.compose-x.internal
        Lookup:
          RoleArn: ${PROD_RO_ROLE_ARN}
      Records:
        - Properties:
            Name: kafdrop.prod.compose-x.io
            Type: A
          Target: x-elbv2::kafdrop-cc-scAlb

    x-acm:
      kafdrop-certs:
        MacroParameters:
          DomainNames:
        - kafdrop.prod.compose-x.io

And finally, our ALB

.. code-block:: yaml

    x-elbv2:
      kafdrop-cc-scAlb:
        Settings:
          Subnets: PublicSubnets
        Properties:
          Scheme: internet-facing
          Type: application
        MacroParameters:
          Ingress:
            ExtSources:
              - IPv4: 0.0.0.0/0
                Name: ANY
                Description: ANY
        Listeners:
          - Port: 80
            Protocol: HTTP
            DefaultActions:
              - Redirect: HTTP_TO_HTTPS
          - Port: 443
            Protocol: HTTPS
            SslPolicy: ELBSecurityPolicy-FS-1-2-Res-2020-10
            Certificates:
              - x-acm: kafdrop-certs
            Targets:
              - name: kafdrop:nginx
                access: kafdrop.prod.compose-x.io/

        Services:
          - name: kafdrop:nginx
            port: 443
            protocol: HTTPS
            healthcheck: 443:HTTPS:4:2:10:5:/actuator:200


As you can see, we are pointing the load balancer to send the traffic to our NGINX container, not the kafdrop one, by
defining that our service is **kafdrop:nginx**

.. seealso::

    The full configuration with support for cognito is available `here <https://github.com/compose-x/compose-x-labs/tree/main/kafka/kafdrop/envs/aws.yaml>`__


Deploy to AWS
===============

So now, we have a `docker-compose.yaml`_ file and configuration that represents our production environment, `aws.yaml`_ and we
are going to deploy this to AWS.

.. attention::

    We assume that you already have some form of access to AWS credentials to interact with your AWS account.

.. code-block:: console

    # If you have not yet install ecs-compose-x
    python -m pip install pip -U
    python -m pip install ecs-composex>=0.15.7

    # Initialize some settings
    AWS_PROFILE=${AWS_PROFILE:-default} ecs-compose-x init
    if [ -z ${AWS_ACCOUNT_ID+x} ]; then AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account); fi
    REGISTRY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION:-$AWS_DEFAULT_REGION}.amazonaws.com/
    # If the repository does not exist in ECR, create
    aws ecr describe-repositories --repository-name kafdrop-nginx 2>/dev/null
    if [ "$?" -ne 0 ]; then REPO_NAME=kafdrop-nginx make ecr ; fi
    docker-compose build
    docker-compose push
    AWS_PROFILE=${AWS_PROFILE:-default} ecs-compose-x plan -n kafdrop-prod -f docker-compose.yaml -f aws.yaml

.. code-block:: console

Conclusion
==========

Using docker volumes and `Files Composer`_ we generated all the files necessary by our applications, NGINX and kafdrop,
to start with the wanted configuration and settings, with 0 code and only some configuration to deloy it to AWS ECS.


.. _Files Composer: https://ecr-files-composer.compose-x.io
.. _All the source files to deploy this solution using ECS Compose-X can be found here.: https://github.com/compose-x/compose-x-labs/tree/main/kafka/kafdrop
.. _acls.yaml: https://github.com/compose-x/compose-x-labs/tree/main/kafka/kafdrop/acls.yaml
.. _kafka credentials template: https://github.com/compose-x/compose-x-labs/blob/main/kafka/confluent-kafka-rest-proxy/sasl_client.yaml
.. _docker-compose.yaml: https://github.com/compose-x/compose-x-labs/tree/main/kafka/kafdrop/docker-compose.yaml
.. _aws.yaml: https://github.com/compose-x/compose-x-labs/tree/main/kafka/kafdrop/aws.yaml
