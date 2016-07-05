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
VAMP_DRIVER_PREFIX=${VAMP_DRIVER_PREFIX:-""}

if [ "$VAMP_DRIVER" == "rancher" ]; then
  VAMP_DRIVER_ENV=${VAMP_DRIVER_URL}
  VAMP_DRIVER_URL="${CATTLE_URL}/projects/${VAMP_DRIVER_ENV}"
else 
  VAMP_DRIVER_URL=${VAMP_DRIVER_URL:-"unix:///var/run/docker.sock"}
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

      elasticsearch {
        url = "${VAMP_DB_URL}"
        response-timeout = 5 # seconds, timeout for elasticsearch operations
        index = "vamp-persistence"
      }
    }

    key-value-store {
      type = "${VAMP_KEY_TYPE}"  # zookeeper, etcd or consul
      base-path = "${VAMP_KEY_PATH}" # base path for keys, e.g. /vamp/...

      ${VAMP_KEY_TYPE} {
        servers = "${VAMP_KEY_SERVERS}"
        session-timeout = 5000
        connect-timeout = 5000
      }
    }
  }

  container-driver {
    type = "${VAMP_DRIVER}"
    response-timeout = 30 # seconds, timeout for container operations
    url = "${VAMP_DRIVER_URL}"
    user = "${VAMP_DRIVER_USER}"
    password = "${VAMP_DRIVER_PASS}"
    environment.name = "${VAMP_DRIVER_ENV}"
    environment.deployment.name-prefix = "${VAMP_DRIVER_PREFIX}"
  }

  dictionary {
    default-scale {
      instances: 1
      cpu: 1
      memory: 1GB
    }
    response-timeout = 5 # seconds, timeout for container operations
  }

  rest-api {
    interface = 0.0.0.0
    host = localhost
    port = ${VAMP_API_PORT}
    response-timeout = 10 # seconds, HTTP response time out
    sse {
      keep-alive-timeout = 15 # seconds, timeout after an empty comment (":\n") will be sent in order keep connection alive
    }
  }

  gateway-driver {
    host = "localhost" # note: host of cluster hosts will have this value (e.g. db.host)
    response-timeout = 30 # seconds, timeout for gateway operations

    haproxy {
      tcp-log-format  = """{\"ci\":\"%ci\",\"cp\":%cp,\"t\":\"%t\",\"ft\":\"%ft\",\"b\":\"%b\",\"s\":\"%s\",\"Tw\":%Tw,\"Tc\":%Tc,\"Tt\":%Tt,\"B\":%B,\"ts\":\"%ts\",\"ac\":%ac,\"fc\":%fc,\"bc\":%bc,\"sc\":%sc,\"rc\":%rc,\"sq\":%sq,\"bq\":%bq}"""
      http-log-format = """{\"ci\":\"%ci\",\"cp\":%cp,\"t\":\"%t\",\"ft\":\"%ft\",\"b\":\"%b\",\"s\":\"%s\",\"Tq\":%Tq,\"Tw\":%Tw,\"Tc\":%Tc,\"Tr\":%Tr,\"Tt\":%Tt,\"ST\":%ST,\"B\":%B,\"CC\":\"%CC\",\"CS\":\"%CS\",\"tsc\":\"%tsc\",\"ac\":%ac,\"fc\":%fc,\"bc\":%bc,\"sc\":%sc,\"rc\":%rc,\"sq\":%sq,\"bq\":%bq,\"hr\":\"%hr\",\"hs\":\"%hs\",\"r\":%{+Q}r}"""
    }

    logstash {
      index = "logstash-*"
    }

    kibana {
      enabled = true
      elasticsearch.url = "${VAMP_DB_URL}"
      synchronization.period = 5 # seconds, synchronization will be active only if period is greater than 0
    }

    aggregation {
      window = 30 # seconds, aggregation will be active only if than 0
      period = 5  # refresh period in seconds, aggregation will be active only if greater than 0
    }
  }

  pulse {
    elasticsearch {
      url = "${VAMP_DB_URL}"
      index {
        name = "vamp-pulse"
        time-format.event = "YYYY-MM-dd"
      }
    }
    response-timeout = 30 # seconds, timeout for pulse operations
  }

  operation {

    synchronization {
      initial-delay = 5 # seconds
      period = 4 # seconds, synchronization will be active only if period is greater than 0

      mailbox {
        // Until we get available akka.dispatch.NonBlockingBoundedMailbox
        mailbox-type = "akka.dispatch.BoundedMailbox"
        mailbox-capacity = 10
        mailbox-push-timeout-time = 0s
      }

      timeout {
        ready-for-deployment =  600 # seconds
        ready-for-undeployment =  600 # seconds
      }
    }

    gateway {
      port-range = 40000-45000
      response-timeout = 5 # seconds, timeout for container operations
    }

    sla.period = 5 # seconds, sla monitor period
    escalation.period = 5 # seconds, escalation monitor period

    workflow {
      http {
        timeout = 30 # seconds, maximal http request waiting time
      }
      info {
        timeout = 10 // seconds
        component-timeout = 5 // seconds
      }
    }
  }

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


