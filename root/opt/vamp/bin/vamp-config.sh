#!/usr/bin/env bash

VAMP_API_PORT=${VAMP_API_PORT:-"8080"}
VAMP_DB_TYPE=${VAMP_DB_TYPE:-"elasticsearch"} # elasticsearch or in-memory (no persistence)
VAMP_DB_PORT=${VAMP_DB_PORT:-"9200"}
VAMP_DB_URL=${VAMP_DB_URL:-"http://"${VAMP_DB_TYPE}":"${VAMP_DB_PORT}}
VAMP_KEY_TYPE=${VAMP_KEY_TYPE:-"zookeeper"}  # zookeeper, etcd or consul
VAMP_KEY_PATH=${VAMP_KEY_PATH:-"/vamp"} # base path for keys, e.g. /vamp/...
VAMP_KEY_PORT=${VAMP_KEY_PORT:-"2181"}
VAMP_KEY_SERVERS=${VAMP_KEY_SERVERS:-${VAMP_KEY_TYPE}":"${VAMP_KEY_PORT}}
VAMP_HEAP_OPTS=${VAMP_HEAP_OPTS:-"-Xmx1G -Xms1G"}
VAMP_DRIVER=${VAMP_DRIVER:-"docker"}
VAMP_DRIVER_USER=${CATTLE_ACCESS_KEY:-""}
VAMP_DRIVER_PASS=${CATTLE_SECRET_KEY:-""}
VAMP_DRIVER_ENV=${VAMP_DRIVER_ENV:-""}
VAMP_DRIVER_PREFIX=${VAMP_DRIVER_PREFIX:-"vamp/workflow-"}
VAMP_WAIT_FOR=${VAMP_DB_URL}"/_template/logstash"

CONTAINER_DRIVER_VALUE="container-driver {
    type = \"${VAMP_DRIVER}\"
    response-timeout = 30 # seconds, timeout for container operations
    ${VAMP_DRIVER} {"

if [ "$VAMP_DRIVER" == "rancher" ]; then
  VAMP_DRIVER_ENV=${VAMP_DRIVER_URL}
  VAMP_DRIVER_URL="${CATTLE_URL}/projects/${VAMP_DRIVER_ENV}"
  CONTAINER_DRIVER_VALUE="$CONTAINER_DRIVER_VALUE
      url = \"${VAMP_DRIVER_URL}\"
      user = \"${VAMP_DRIVER_USER}\"
      password = \"${VAMP_DRIVER_PASS}\"
      workflow-name-prefix = \"vamp-workflow-\"
      environment {
        name = \"vamp\"
        deployment.name-prefix = \"${VAMP_DRIVER_PREFIX}\"
      }
    }
  }
"
elif [ "$VAMP_DRIVER" == "mesos" ]; then
  VAMP_DRIVER_URL=${VAMP_DRIVER_URL:-"mesos-master:5050"}
  MARATHON_URL=${MARATHON_URL:-"marathon.marathon:8080"}
  CONTAINER_DRIVER_VALUE="$CONTAINER_DRIVER_VALUE
      url = \"http://${VAMP_DRIVER_URL}\"
    }
    marathon {
      user = \"\"
      password = \"\"
      url = \"http://${MARATHON_URL}\"
      sse = true
      workflow-name-prefix = \"vamp-workflow-\"
    }
  }
"
elif [ "$VAMP_DRIVER" == "docker" ]; then 
  VAMP_DRIVER_URL=${VAMP_DRIVER_URL:-"unix:///var/run/docker.sock"}
  CONTAINER_DRIVER_VALUE="$CONTAINER_DRIVER_VALUE
      workflow-name-prefix = \"vamp-workflow-\"
      repository {
        email = \"\"
        username = \"\"
        password = \"\"
        server-address = \"\"
      }
    }
  }
"
elif [ "$VAMP_DRIVER" == "kubernetes" ]; then 
  VAMP_DRIVER_URL=${VAMP_DRIVER_URL:-${KUBERNETES_SERVICE_HOST}":"${KUBERNETES_PORT_443_TCP_PORT}}
  CONTAINER_DRIVER_VALUE="$CONTAINER_DRIVER_VALUE
      url = \"https://${VAMP_DRIVER_URL}\"
      workflow-name-prefix = \"vamp-workflow-\"
      service-type = \"NodePort\"
      create-services = true
      vamp-gateway-agent-id = \"vamp-gateway-agent\"
      token = \"/var/run/secrets/kubernetes.io/serviceaccount/token\"
    }
  }
"
else
  CONTAINER_DRIVER_VALUE=""
fi

if [ "$VAMP_KEY_TYPE" == "zookeeper" ]; then
  KEY_VALUE_DATA="key-value-store {
      type = \"${VAMP_KEY_TYPE}\"  # zookeeper, etcd or consul
      base-path = \"${VAMP_KEY_PATH}\" # base path for keys, e.g. /vamp/...

      ${VAMP_KEY_TYPE} {
        servers = \"${VAMP_KEY_SERVERS}\"
        session-timeout = 5000
        connect-timeout = 5000
      }
    }
"
else
  KEY_VALUE_DATA="key-value-store {
      type = \"${VAMP_KEY_TYPE}\"  # zookeeper, etcd or consul
      base-path = \"${VAMP_KEY_PATH}\" # base path for keys, e.g. /vamp/...

      ${VAMP_KEY_TYPE} {
        url = \"http://${VAMP_KEY_SERVERS}\"
      }
    }
"
fi

cat << EOF > ${SERVICE_HOME}/conf/application.conf
vamp {

  info {
    message = "Hi, I'm Vamp! How are you?"
    timeout = 3 # seconds, response timeout for each component (e.g. Persistance, Container Driver...)
  }

  persistence {
    response-timeout = 5 # seconds

    database {
      type = "${VAMP_DB_TYPE}" # elasticsearch or in-memory (no persistence)

      ${VAMP_DB_TYPE} {
        url = "${VAMP_DB_URL}"
        response-timeout = 5 # seconds, timeout for elasticsearch operations
        index = "vamp-persistence"
      }
    }

    ${KEY_VALUE_DATA}
  }

  ${CONTAINER_DRIVER_VALUE}

  http-api.ui {
    directory = "${SERVICE_HOME}/ui"
    index = \${vamp.http-api.ui.directory}"/index.html"
  }

  gateway-driver {
    logstash.host = "logstash"
    kibana.elasticsearch.url = \${vamp.pulse.elasticsearch.url}
  }

  workflow-driver {
    type = "${VAMP_DRIVER}"
    vamp-url = "http://vamp:8080"

    workflow {
      deployables = {
        "application/javascript" = {
          type = "container/docker"
          definition = "magneticio/vamp-workflow-agent:katana"
        }
      }
      environment-variables = [
        "VAMP_KEY_VALUE_STORE_TYPE=${VAMP_KEY_TYPE}",
        "VAMP_KEY_VALUE_STORE_CONNECTION=${VAMP_KEY_SERVERS}"
        "WORKFLOW_EXEUTION_PERIOD=0"
        "WORKFLOW_EXEUTION_TIMEOUT=0"
      ]
      scale {
        instances = 1
        cpu = 0.1
        memory = 128MB
      }
      network = "managed"
    }
  }

  pulse.elasticsearch.url = "${VAMP_DB_URL}"

  operation {

    synchronization.period = 3 seconds

    deployment {
      scale {
        instances: 1
        cpu: 0.2
        memory: 256MB
      }
      arguments: [
        "privileged=true"
      ]
    }
  }

  lifter.artifact.resources = [
    "breeds/health.js",
    "workflows/health.yml",
    "breeds/metrics.js",
    "workflows/metrics.yml",
    "breeds/kibana.js",
    "workflows/kibana.yml"
  ]
}
EOF

cat << EOF > ${SERVICE_HOME}/conf/logback.xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%cyan(%d{HH:mm:ss.SSS}) %highlight(| %-5level | %-40.40logger{40} | %-40.40X{akkaSource} | %msg%n)</pattern>
        </encoder>

        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>INFO</level>
        </filter>
    </appender>

    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${SERVICE_LOG_FILE}</file>

        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>TRACE</level>
        </filter>

        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>vamp.%d{yyyy-MM-dd}.log</fileNamePattern>
            <maxHistory>7</maxHistory>
        </rollingPolicy>

        <encoder>
            <pattern>%d{HH:mm:ss.SSS} | %-5level | %-40.40logger{40} | %-40.40X{akkaSource} | %msg%n</pattern>
        </encoder>
    </appender>

    <logger name="io.vamp" level="TRACE"/>
    <logger name="scala.slick" level="WARN"/>
    <logger name="io.vamp.persistence.slick.components" level="INFO" />

    <root level="INFO">
        <appender-ref ref="STDOUT"/>
        <appender-ref ref="FILE" />
    </root>

</configuration>
EOF


