#!/bin/sh

#  bump.sh
#  V2rayU
#
#  Created by yanue on 2018/10/22.
#  Copyright © 2018 yanue. All rights reserved.
PROJECT_DIR=$(pwd)/V2rayU
INFOPLIST_FILE="Info.plist"
buildString=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")
buildDate=$(echo $buildString | cut -c 1-8)
buildNumber=$(echo $buildString | cut -c 9-11)
today=$(date +'%Y%m%d')
if [[ $buildDate = $today ]]
then
buildNumber=$(($buildNumber + 1))
else
buildNumber=1
fi
buildString=$(printf '%s%03u' $today $buildNumber)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildString" "${PROJECT_DIR}/${INFOPLIST_FILE}"
