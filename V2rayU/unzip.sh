#!/bin/sh

#  unzip.sh
#  V2rayU
#
#  Created by yanue on 2018/10/12.
#  Copyright © 2018 yanue. All rights reserved.
# set +x

rm -rf ./v2ray-core
unzip -o ./v2ray-macos.zip -d ./v2ray-core

if [[ $? == 0 ]]; then
    chmod +x ./v2ray-core/v2ray
    chmod +x ./v2ray-core/v2ctl
    echo "unzip 成功".$?
else
    echo "unzip 失败".$?
fi
rm -f ./v2ray-macos.zip
