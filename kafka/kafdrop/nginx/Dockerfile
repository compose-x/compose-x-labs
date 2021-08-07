ARG BASE_IMAGE=public.ecr.aws/amazonlinux/amazonlinux:2
FROM $BASE_IMAGE

RUN yum upgrade -y ;\
    amazon-linux-extras install nginx1;\
    yum autoremove -y; yum clean packages;\
    yum clean headers; yum clean metadata; yum clean all; rm -rfv /var/cache/yum

ADD nginx.conf /etc/nginx/nginx.conf

STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
