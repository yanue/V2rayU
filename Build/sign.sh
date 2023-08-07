#!/bin/sh

#  sign.sh
#  V2rayU
#
#  Created by yanue on 2023/8/1.
#  Copyright © 2023 yanue. All rights reserved.
set -ex

TOKEN=$1
release_id=$2

echo "token $TOKEN, release ${RELEASE_ID}"

curl -X "PATCH" "https://api.appcenter.ms/v0.1/apps/yanue/V2rayU/releases/${release_id}" \
     -H "X-API-Token: $TOKEN" \
     -H 'Content-Type: application/json; charset=utf-8' \
     -d '{
    "release_notes": "test",
    "metadata": {
        "ed_signature": "PW8pDnr5VZkmC93gZjUDlHI8gkJSspPoDU3DdhsMkps"
    }
}'
