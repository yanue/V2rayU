#!/bin/bash

PROJECT=V2rayU
PROJECT_DIR=$HOME/swift/${PROJECT}
INFOPLIST_FILE="Info.plist"
ver=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PROJECT_DIR}/V2rayU/${INFOPLIST_FILE}")
releaseVersion=${ver}
echo ${ver}

#github-release release\
#	     	--user yanue\
#	        --repo ${PROJECT}\
#    		--tag ${releaseVersion}\
#    		--name "${PROJECT} ${releaseVersion}"\
#    		--description "${PROJECT} ${releaseVersion}"
#
#github-release upload
#            --user yanue
#            --repo ${PROJECT}
#            --tag ${releaseVersion}
#            --name ${PROJECT}.app.zip
#            --file ${PROJECT}.app.zip

#git add Build/appcast.xml
#git commit -a -m "update version: "${releaseVersion}
#git push