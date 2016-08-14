#!/bin/bash

# Return reasonable JVM options to run inside a Docker container where memory and
# CPU can be limited with cgroups.
# https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/parallel.html

# Options:
#   JVM_HEAP_RATIO=0.5 Ratio of heap size to available memory

# If Xmx is not set the JVM will use by default 1/4th (in most cases) of the host memory
# This can cause the Kernel to kill the container if the JVM memory grows over the cgroups limit
# because the JVM is not aware of that limit and doesn't invoke the GC
# Setting it by default to 0.5 times the memory limited by cgroups, customizable with JVM_HEAP_RATIO
CGROUPS_MEM=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
MEMINFO_MEM=$(($(awk '/MemTotal/ {print $2}' /proc/meminfo)*1024))
MEM=$(($MEMINFO_MEM>$CGROUPS_MEM?$CGROUPS_MEM:$MEMINFO_MEM))
JVM_HEAP_RATIO=${JVM_HEAP_RATIO:-0.5}
XMX=$(awk '{printf("%d",$1*$2/1024^2)}' <<<" ${MEM} ${JVM_HEAP_RATIO} ")

# TODO handle cpu limits into -XX:ParallelGCThreads

echo "-Xmx${XMX}m"
