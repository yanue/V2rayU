#!/bin/sh

#  unzip.sh
#  V2rayU
#
#  Created by yanue on 2018/10/17.
#  Copyright © 2018 yanue. All rights reserved.

if [ ! -f "./v2ray-macos.zip" ]; then
  echo "文件不存在"
  exit
fi

rm -rf ./v2ray-core
unzip -o ./v2ray-macos.zip -d ./v2ray-core
\cp ./v2ray-core/xray ./v2ray-core/v2ray

if [[ $? == 0 ]]; then
    chmod +x ./v2ray-core/v2ray
    echo "unzip 成功".$?
else
    echo "unzip 失败".$?
fi
rm -f ./v2ray-macos.zip
