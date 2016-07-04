#!/usr/bin/env bash

SERVICE_LOG_DIR=${SERVICE_LOG_DIR:-${SERVICE_HOME}"/logs"}
SERVICE_PID_FILE=${SERVICE_PID_FILE:-${SERVICE_LOG_DIR}"/vamp.pid"}
SERVICE_STDOUT=${SERVICE_STDOUT:-"/proc/1/fd/1"}
SERVICE_HEAP_OPTS=${VAMP_HEAP_OPTS:-"-Xmx1G -Xms1G"}
export SERVICE_LOG_FILE=${SERVICE_LOG_FILE:-${SERVICE_LOG_DIR}"/vamp.out"}

function log {
        echo `date` $ME - $@
}

function serviceConfig {
    log "[ Generating ${SERVICE_NAME} configuration... ]"
    ${SERVICE_HOME}/bin/vamp-config.sh
}

function serviceLog {
    log "[ Redirecting ${SERVICE_NAME} log to stdout... ]"
    if [ ! -L ${SERVICE_LOG_FILE} ]; then
        rm ${SERVICE_LOG_FILE}
        ln -sf ${SERVICE_STDOUT} ${SERVICE_LOG_FILE}
    fi

    if [ ! -L ${SERVICE_HOME}/nohup.out ]; then
        rm ${SERVICE_HOME}/nohup.out
        ln -sf ${SERVICE_STDOUT} ${SERVICE_HOME}/nohup.out
    fi
}

function serviceStart {
    log "[ Starting ${SERVICE_NAME}... ]"
    serviceConfig
    serviceLog
    nohup java ${SERVICE_HEAP_OPTS} -Dlogback.configurationFile=${SERVICE_HOME}/conf/logback.xml -Dconfig.file=${SERVICE_HOME}/conf/application.conf -jar ${SERVICE_HOME}/jar/${SERVICE_RELEASE} &
    echo $! > ${SERVICE_PID_FILE}
}

function serviceStop {
    log "[ Stoping ${SERVICE_NAME}... ]"

    if [ -f ${SERVICE_PID_FILE} ]; then
        pid=$(cat ${SERVICE_PID_FILE})
        rm ${SERVICE_PID_FILE}
    else 
        pid=$(ps -ef | grep -w `java` | grep -w ${SERVICE_HOME}'/jar/'${SERVICE_RELEASE} | grep -v grep | awk '{print $1}')
    fi

    if [ "x$pid" != "x" ]; then 
        kill -SIGTERM $pid
        sleep 2

        killed=$(ps -ef | grep -w $pid | grep -v grep ; echo $?)
        while [ $killed -ne 1 ]; do
            kill -SIGTERM $pid
            sleep 2
            killed=$(ps -ef | grep -w $pid | grep -v grep ; echo $?)
        done
    fi
}


function serviceRestart {
    log "[ Restarting ${SERVICE_NAME}... ]"
    serviceStop
    serviceStart
    /opt/monit/bin/monit reload
}

case "$1" in
        "start")
            serviceStart &> ${SERVICE_STDOUT}
        ;;
        "stop")
            serviceStop &> ${SERVICE_STDOUT}
        ;;
        "restart")
            serviceRestart &> ${SERVICE_STDOUT}
        ;;
        *) 
            echo "Usage: $0 restart|start|stop"
            exit 1
        ;;

esac

exit 0
