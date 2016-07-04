alpine-vamp
==============

This image is the alpine-vamp base. It comes from [alpine-jvm8][alpine-jvm8].

## Build

```
docker build -t rawmind/alpine-vamp:<version> .
```

## Versions

- `0.8.4` [(Dockerfile)](https://github.com/rawmind0/alpine-vamp/blob/0.8.4/Dockerfile)

## Configuration

This image runs [vamp][vamp] with monit. It is started with vamp user/group and 10006 uid/gid.

Besides, you can customize the configuration in several ways:

### Default Configuration

Vamp is installed with the default configuration and some parameters can be overrided with env variables:

- VAMP_API_PORT=${VAMP_API_PORT:-"8080"}
- VAMP_DB_TYPE=${VAMP_DB_TYPE:-"elasticsearch"} # elasticsearch or in-memory (no persistence)
- VAMP_DB_URL=${VAMP_DB_URL:-"http://elasticsearch:9200"}
- VAMP_KEY_TYPE=${VAMP_KEY_TYPE:-"zookeeper"}  # zookeeper, etcd or consul
- VAMP_KEY_PATH=${VAMP_KEY_PATH:-"/vamp"} # base path for keys, e.g. /vamp/...
- VAMP_KEY_SERVERS=${VAMP_KEY_SERVERS:-"zookeeper:2181"}
- VAMP_HEAP_OPTS=${VAMP_HEAP_OPTS:-"-Xmx1G -Xms1G"}
- VAMP_DRIVER_URL=${VAMP_DRIVER_URL:-"unix:///var/run/docker.sock"}

The service is started with monit. It's listening at port 8080.

[alpine-jvm8]: https://github.com/rawmind0/alpine-jvm8/
[vamp]: https://github.com/magneticio/vamp/