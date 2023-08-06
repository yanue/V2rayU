#!/bin/sh

#  sign.sh
#  V2rayU
#
#  Created by yanue on 2023/8/1.
#  Copyright © 2023 yanue. All rights reserved.

TOKEN=$1
RELEASE_ID=$2

echo "release ${RELEASE_ID}, token $TOKEN"

curl -X "PATCH" "https://api.appcenter.ms/v0.1/apps/V2rayU/releases/${RELEASE_ID}" \
     -H "X-API-Token: $TOKEN" \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d $"{
            \"metadata\": {
            \"ed_signature\": \"PW8pDnr5VZkmC93gZjUDlHI8gkJSspPoDU3DdhsMkps\"
          }
    }"
