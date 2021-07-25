#!/bin/bash

export CONNECT_REST_ADVERTISED_HOST_NAME=$(hostname)
echo $CONNECT_REST_ADVERTISED_HOST_NAME
echo $HOSTNAME
ls -l /opt/connect/
/etc/confluent/docker/run
