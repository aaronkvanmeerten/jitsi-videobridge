#!/bin/bash

# script that creates an archive in current folder
# containing the heap and thread dump and the current log file

JVB_HEAPDUMP_PATH="/tmp/java_*.hprof"
STAMP=`date +%Y-%m-%d-%H%M`
PID_PATH="/var/run/jitsi-videobridge.pid"

RUNNING=""
unset PID

[ -e $PID_PATH ] && PID=$(cat $PID_PATH)
if [ ! -z $PID ]; then
   ps -p $PID | grep -q java
   [ $? -eq 0 ] && RUNNING="true"
fi
if [ ! -z $RUNNING ]; then
    echo "Jvb at pid $PID"
    THREADS_FILE="/tmp/stack-${STAMP}-${PID}.threads"
    HEAP_FILE="/tmp/heap-${STAMP}-${PID}.bin"

    # If the JVB has crashed (with OOM, for example), the JVM might be
    # configured to take a heap dump. This is configured with the HeapDumpPath
    # VM option. The HeapDumpPath is a manageable VM option and the default
    # path format is java_pidXXXX.hprof.
    #
    # During the time the JVM is taking a heap dump, the process will appear
    # running, but the JVM won't allow us to connect to it and take a
    # heap/thread dump.  Briefly, we want to make sure we grab the java heap
    # dump, even if the process appears to be running.

    HEAPDUMP_FILE="/tmp/java_pid${PID}.hprof"

    # Wait for the JVM to finish writing the heapdump.
    while lsof ${HEAPDUMP_FILE}; do sleep 1; done

    sudo -u jvb jstack ${PID} > ${THREADS_FILE}
    sudo -u jvb jmap -dump:live,format=b,file=${HEAP_FILE} ${PID}
    tar zcvf jvb-dumps-${STAMP}-${PID}.tgz ${THREADS_FILE} ${HEAP_FILE} ${HEAPDUMP_FILE} /var/log/jitsi/jvb.log
    rm ${HEAP_FILE} ${THREADS_FILE}
else
    ls $JVB_HEAPDUMP_PATH >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "JVB not running, but previous heap dump found."
        tar zcvf jvb-dumps-${STAMP}-crash.tgz $JVB_HEAPDUMP_PATH /var/log/jitsi/jvb.log
        rm ${JVB_HEAPDUMP_PATH}
    else
        echo "JVB not running."
    fi
fi
