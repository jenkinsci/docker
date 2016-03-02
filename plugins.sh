#! /bin/bash

# Parse a support-core plugin -style txt file as specification for jenkins plugins to be installed
# in the reference directory, so user can define a derived Docker image with just :
#
# FROM jenkins
# COPY plugins.txt /plugins.txt
# RUN /usr/local/bin/plugins.sh /plugins.txt
#
# Note: Plugins already installed are skipped
#

set -e

if [ "$1" = "" ]; then
    echo "Usage: $0 filename"
    exit 1
fi

REF=/usr/share/jenkins/ref/plugins
mkdir -p $REF

TEMP_ALREADY_INSTALLED=/var/jenkins_home/preinstalled.plugins.txt
for i in `ls -pd1 /var/jenkins_home/plugins/*|egrep '\/$'`
do 
    PLUGIN=`basename $i`
    if egrep -i Plugin-Version "$i/META-INF/MANIFEST.MF"; then
        VER=`egrep -i Plugin-Version "$i/META-INF/MANIFEST.MF"|cut -d\: -f2|sed 's/ //'`
        echo "$PLUGIN:$VER"
    fi
done > $TEMP_ALREADY_INSTALLED

while read spec || [ -n "$spec" ]; do
    plugin=(${spec//:/ });
    [[ ${plugin[0]} =~ ^# ]] && continue
    [[ ${plugin[0]} =~ ^\s*$ ]] && continue
    [[ -z ${plugin[1]} ]] && plugin[1]="latest"

    if [ -z "$JENKINS_UC_DOWNLOAD" ]; then
      JENKINS_UC_DOWNLOAD=$JENKINS_UC/download
    fi

    if egrep "${plugin[0]}:${plugin[1]}" $TEMP_ALREADY_INSTALLED >/dev/null 2>&1; then
        echo "  ... skipping already installed:  ${plugin[0]}:${plugin[1]}"
    else
    	echo "Downloading ${plugin[0]}:${plugin[1]}"
        curl -sSL -f ${JENKINS_UC_DOWNLOAD}/plugins/${plugin[0]}/${plugin[1]}/${plugin[0]}.hpi -o $REF/${plugin[0]}.jpi
        unzip -qqt $REF/${plugin[0]}.jpi
    fi
done  < $1

#cleanup
rm $TEMP_ALREADY_INSTALLED

exit 0

# EOF
