FROM rawmind/alpine-jvm8:1.8.92-4
MAINTAINER Raul Sanchez <rawmind@gmail.com>

#Set environment
ENV SERVICE_NAME=vamp \
    SERVICE_VERSION=0.9.1 \
    SERVICE_REPO=https://bintray.com/artifact/download/magnetic-io/downloads/vamp \
    SERVICE_HOME=/opt/vamp \
    SERVICE_USER=vamp \
    SERVICE_UID=10006 \
    SERVICE_GROUP=vamp \
    SERVICE_GID=10006 
ENV SERVICE_RELEASE=vamp-${SERVICE_VERSION}.jar

RUN mkdir -p ${SERVICE_HOME}/logs ${SERVICE_HOME}/conf ${SERVICE_HOME}/jar && cd ${SERVICE_HOME}/jar \
  && wget ${SERVICE_REPO}/${SERVICE_RELEASE} \
  && addgroup -g ${SERVICE_GID} ${SERVICE_GROUP} \
  && adduser -g "${SERVICE_NAME} user" -D -h ${SERVICE_HOME} -G ${SERVICE_GROUP} -s /sbin/nologin -u ${SERVICE_UID} ${SERVICE_USER} 

# Adding files
ADD root /
RUN chmod +x ${SERVICE_HOME}/bin/*.sh \
  && chown -R ${SERVICE_USER}:${SERVICE_GROUP} ${SERVICE_HOME} /opt/monit 

USER $SERVICE_USER
WORKDIR $SERVICE_HOME

EXPOSE 8080