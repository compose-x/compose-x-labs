
.. meta::
    :description: Compose-X Labs - Traefik part 2
    :keywords: AWS, docker, compose, traefik, ECS Anywhere

#############################################
AWS ECS & Traefik - Part 2
#############################################

****************************
Introduction
****************************

In the previous lab article we went over deploying `traefik`_ to AWS ECS and run it in AWS Fargate,
behind a NLB.

This time, with the release of ECS Compose-X 0.18 (and onwards), we are going to deploy traefik into `AWS ECS Anywhere`_

============================
What is AWS ECS Anywhere
============================

AWS ECS is the control plane service that allows you today to create your Task Definitions, Service definition, scheduled
tasks etc. and deploy these into clusters.

The clusters rely on either a `Capacity Provider`_ such as AWS Fargate or AWS EC2 to provide the IaaS layers (compute,
networking, storage etc.) to run your containers into.

AWS ECS Anywhere is an extension of the ECS Control plane which allows you to register on-premise ECS Instances.
These can be bare-metal machines, Virtual Machines, or using `AWS Outposts`_ to run the containers onto.

How does it work ?
----------------------

We won't go into deep details, as many already covered this very well in `other blog posts`_. In a nutshell, your
machine (virtual or physical) is registered in AWS SSM, then your machine is registered into an AWS Cluster as an
ECS Instance.

And yes, that simple. Later we will go over a brief checklist of things to have in place to provide remote access
as here traefik will be the entrypoint into other services.

.. attention::

    As said, the installation of the necessary software and tools are out of scope of this article.
    Proceeding forward, we assume that you have already gotten one or more working ECS Instances on-premise.


The architecture
------------------

The example is fairly straightforward. We have an ECS Instance running on a RaspberryPi 4 with 4GB of RAM.
We installed docker onto it and ran the ECS Anywhere install scripts, and there it is, registered into our ECS Cluster

.. code-block:: bash

    aws ecs list-container-instances --cluster ANewCluster
    {
        "containerInstanceArns": [
            "arn:aws:ecs:eu-west-1:373709687836:container-instance/ANewCluster/dfc804e50f7f445f9fbe3fae775997a6"
        ]
    }

The full details are very long about the instance itself, so let's highlight just a few of them

.. code-block::

      "registeredResources": [
        {
          "name": "CPU",
          "type": "INTEGER",
          "doubleValue": 0.0,
          "longValue": 0,
          "integerValue": 4096
        },
        {
          "name": "MEMORY",
          "type": "INTEGER",
          "doubleValue": 0.0,
          "longValue": 0,
          "integerValue": 3795
        },
        {
          "name": "PORTS",
          "type": "STRINGSET",
          "doubleValue": 0.0,
          "longValue": 0,
          "integerValue": 0,
          "stringSetValue": [
            "22",
            "2376",
            "2375",
            "51678",
            "51679"
          ]
        },
        {
          "name": "PORTS_UDP",
          "type": "STRINGSET",
          "doubleValue": 0.0,
          "longValue": 0,
          "integerValue": 0,
          "stringSetValue": []
        }
      ],
      "status": "ACTIVE",
      "agentConnected": true,
      "runningTasksCount": 0,
      "pendingTasksCount": 0,

This tells us that the agent registered in the cluster that it has 4096 CPU cycles (docker unit for vCPU),
3795MB of RAM, and reserved a few ports so that nothing will be published on this machine that listens on these ports.

.. note::

    If you plan to have ECS Instances running with an ARM processor, such as a raspberry pi, make sure that the image
    you will use is either a list that contains ARM images, or that the image you pick was built for it.



*************************
Services deployment
*************************

We are in fact going to take the docker-compose of the part 1 again, and very simply just re-use it.
Only a few changes will be made this time.

The only real change we are going to do, is to tell ECS Compose-X it should be configuring the ECS Task and
Service definitions to use ``EXTERNAL`` compute mode. That will indicate ECS Cluster, than when provisioning the service
it should run it on an ECS instance that is registered with that attribute.

So, let's have our docker-compose.yaml file.

.. literalinclude:: docker-compose.yaml
    :language: yaml

