FROM public.ecr.aws/ews-network/confluentinc/cp-kafka-connect:6.2.0

USER root
ADD https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem /etc/ssl/certs/
RUN openssl x509 -outform der -in /etc/ssl/certs/rds-combined-ca-bundle.pem -out /etc/ssl/certs/rds-combined-ca-bundle.der && \
    ls -lR /etc/ssl/certs/ && \
    keytool -importcert -file /etc/ssl/certs/rds-combined-ca-bundle.pem \
    -keystore cacerts -storepass changeit -trustcacerts -noprompt ;\
    yum upgrade -y && yum clean all && rm -rfv /var/cache/yum

USER appuser
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.1.1 ;\
    confluent-hub install --no-prompt mongodb/kafka-connect-mongodb:1.5.0 ;\
    confluent-hub install --no-prompt confluentinc/kafka-connect-s3:latest;\
    confluent-hub install --no-prompt confluentinc/kafka-connect-replicator:6.2.0
COPY start.sh /etc/confluent/docker/start.sh
ENTRYPOINT ["/etc/confluent/docker/start.sh"]
