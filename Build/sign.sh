#!/bin/sh

#  sign.sh
#  V2rayU
#
#  Created by yanue on 2023/8/1.
#  Copyright © 2023 yanue. All rights reserved.

APP=$1
RELEASE_ID=$2
FILE=$3

SIGNATURE=$(./bin/sign_update ${FILE} | sed 's/[^"]*="\([^"]*\).*/\1/g')
TOKEN=$(security find-generic-password -gws "AppCenter Sparkle Token")
echo "Sign ${APP} release ${RELEASE_ID}, signature $SIGNATURE"

curl -X "PATCH" "https://api.appcenter.ms/v0.1/apps/${APP}/releases/${RELEASE_ID}" \
     -H "X-API-Token: $TOKEN" \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $"{
            \"metadata\": {
            \"ed_signature\": \"$SIGNATURE\"
          }
    }"
