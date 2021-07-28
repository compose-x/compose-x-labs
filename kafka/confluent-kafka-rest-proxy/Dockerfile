ARG BASE_IMAGE=public.ecr.aws/ews-network/confluentinc/cp-kafka-rest:6.2.0
FROM $BASE_IMAGE
WORKDIR /opt
COPY start.sh /opt/start.sh
ENTRYPOINT ["/bin/sh", "/opt/start.sh"]
