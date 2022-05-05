.. meta::
    :description: ECS Compose-X Labs
    :keywords: AWS, AWS ECS, Docker, Compose, docker-compose, grafana, cognito, azure

=====================================
grafana with Azure and AWS Cognito
=====================================

Deploying Grafana in AWS these days, you might just want to use the managed service which also uses AWS SSO.
So instead of doing just that, let's look at deploying Grafana and use Azure SSO instead for authentication and
authorization.

.. tip::

    To use Grafana with CloudWatch for multiple accounts, create a read only role in your other accounts with the
    template **cross-account-cw-role.yaml**


Azure Configuration
=====================

.. image:: https://media.makeameme.org/created/hold-on-say-b5fc7ecda2.jpg

AZURE ?!? Why mate ?
Well, the truth of it is, a lot of businesses use Azure and Office 365 for managing their employees, and it is doing a
fine job at doing just that. Would I use it for anything else, no. MS Azure is not my cup of tea, but credits due when
due, its Users management and the Applications stuff is pretty good.

But, I need to do a big shout out to the Grafana documentation team who did an outstanding job at creating instructions
on using Azure as the IdP for users.

So head to the `Azure AD OAuth2 authentication`_ on the Grafana docs.

.. tip::

    To give all of the settings to Grafana, we create a secret in Secrets Manager that contains all of the settings
    grafana needs. To do so, use the `**azure-grafana-secrets.yaml**`_ template.

Once you have your secret created, we pass that secret to Grafana and provide each "key" of the JSON secret as an individual
environment variable

.. code-block:: yaml

    secrets:
      azureclient:
        x-secrets:
          Name: /azuread/ddbbcdaa-a07f-4b7a-a417-97e7cd2847f3 # Replace with your App ID from the secrets
          JsonKeys:
            - SecretKey: APP_ID
              VarName: GF_AUTH_AZUREAD_CLIENT_ID
            - SecretKey: CLIENT_SECRET
              VarName: GF_AUTH_AZUREAD_CLIENT_SECRET
            - SecretKey: AUTH_URL
              VarName: GF_AUTH_AZUREAD_AUTH_URL
            - SecretKey: TOKEN_URL
              VarName: GF_AUTH_AZUREAD_TOKEN_URL


After you configured that, at this point you have the ability to log into Grafana using your Azure credentials and profile.
But, is that necessarily enough ? Even though I have no doubt that Grafana's code is battletested, I would still like
an additional layer of security just before people get onto the Login page.

Basic Auth? Nahh.. Although efficient, you'd then need to let everyone in the business get credentials for that. Which is,
un-necessary overhead.

Given we already have everything configured in Azure AD for our grafana application, let's re-use that and use AWS Cognito
and AWS ALB integration to add this additional layer of authentication to ensure only people in the company get to the
Grafana login page.

.. hint::

    You could absolutely add CDN and/or WAF in front of the ALB, but for today we won't be doing that.


AWS Cognito Configuration
===========================

There are plenty of, mostly outdated due to Azure changing their interface every Monday, guides on how to configure Cognito
and Azure AD.

Here, instead of all that, we are going to use the CFN template **azure-cognito-saml.yaml** and run it twice:

* The first time, you won't have the information (such as CloudFront distribution domain)
* The second time, we update the stack with the new outputs.

.. attention::

    Some AD attributes might not be the same in all installations. For example, you might have to use the name attribute
    definition for the mail definition. This avoids the SAML Attribute error.

Once the DNS is in place and all is good, you can now create a new App Client which we will use for the ALB.

.. hint::

    This step is still manual, but you could re-use the template and add that resource to it.
    There is to date a Feature Request to generate that within `ECS Compose-X`_

ALB Configuration
==================

This is where ECS Compose-X will take care of configuring the Listener rules etc. for you and generate the appropriate CFN
templates.

.. code-block:: yaml

    x-elbv2:
      grafanaALB:
        Properties:
          Scheme: internet-facing
          Type: application
        MacroParameters:
          Ingress:
            ExtSources:
              - IPv4: 0.0.0.0/0
                Name: ANY
                Description: "ANY"
        Listeners:
          - Port: 80
            Protocol: HTTP
            DefaultActions:
              - Redirect: HTTP_TO_HTTPS
          - Port: 443
            Protocol: HTTPS
            Certificates:
              - x-acm: grafana-certs
            Targets:
              - name: grafana:grafana
                access: /
                AuthenticateCognitoConfig:
                  OnUnauthenticatedRequest: authenticate
                  Scope: openid
                  SessionCookieName: grafana
                  SessionTimeout: 3600
                  UserPoolArn: arn:aws:cognito-idp:eu-west-1:000000000000:userpool/eu-west-1_aeisnt # Replace
                  UserPoolClientId: qrspbawftgzxcvjleimnuyokh # Replace
                  UserPoolDomain: auth.grafana.prod.compose-x.io # Replace with your own domain

        Services:
          - name: grafana:grafana
            port: 3000
            protocol: HTTP
            healthcheck: 3000:HTTP:7:2:15:5:/api/health

Assuming you have set the right callback URL in Cognito and Reply URL in AzureAD for this application, you now have
to authenticate onto AzureAD before accessing the very login page.

Deployment to AWS
====================

Once you have ecs-compose-x installed, and got your AWS Credentials sorted, you can now very simply deploy all this
to AWS.

In this configuration, we are using AWS S3 to store Grafana images.

.. code-block:: yaml

    services:
      grafana:
        environment:
          GF_DATABASE_TYPE: mysql
          GF_EXTERNAL_IMAGE_PROVIDER_STORAGE_S3_REGION: "${AWS::Region}"
          GF_EXTERNAL_IMAGE_PROVIDER_STORAGE_S3_PATH: "/images"

.. code-block:: yaml

    x-s3:
      data-bucket:
        Properties:
          AccessControl: BucketOwnerFullControl
          BucketEncryption:
            ServerSideEncryptionConfiguration:
              - ServerSideEncryptionByDefault:
                  SSEAlgorithm: AES256
        Services:
          grafana:
            Access:
              bucket: ListOnly
              objects: RW
	    ReturnValues:
	      BucketName: GF_EXTERNAL_IMAGE_STORAGE_S3_BUCKET

Note that we are exposing the bucket name to the grafana service through Settings.EnvVars.GF_EXTERNAL_IMAGE_STORAGE_S3_BUCKET

We also use Aurora MySQL as database to store all our configuration and dashboards.

.. code-block:: yaml

    x-rds:
      grafana-db:
        Properties:
          Engine: "aurora-mysql"
          EngineVersion: "5.7"
          BackupRetentionPeriod: 1
          DatabaseName: grafana
          StorageEncrypted: True
        Services:
          grafana:
            Access:
	      DbCluster: RO
            SecretsMappings:
              Mappings:
                host: GF_DATABASE_HOST
                port: GF_DATABASE_PORT
                username: GF_DATABASE_USER
                password: GF_DATABASE_PASSWORD

.. tip::

    Here the database is created with the rest of the resources. If you run in production and want an extra decoupling
    to not compromise the database should something go wrong, create it separately and use `x-rds.Lookup`_ to use for your
    service

We also use EFS so that in case some files or content need sharing across multiple Grafana nodes, it is available to it.

.. code-block:: yaml

    volumes:
      grafana:
        x-efs:
          Properties:
            LifecyclePolicies:
            TransitionToIA: AFTER_14_DAYS
          MacroParameters:
            EnforceIamAuth: True

Here, in the override file aws.yaml, we define `x-efs`_ properties for the volume.

.. _Azure AD OAuth2 authentication: https://grafana.com/docs/grafana/latest/auth/azuread/#azure-ad-oauth2-authentication
.. _ECS Compose-X: https://github.com/compose-x/ecs_composex
.. _x-rds.Lookup: https://docs.compose-x.io/syntax/compose_x/rds.html#lookup
.. _x-efs: https://docs.compose-x.io/syntax/compose_x/efs.html
.. _**azure-grafana-secrets.yaml**: https://github.com/compose-x/compose-x-labs
