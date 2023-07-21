#!/bin/sh

#  install.sh
#  V2rayU
#
#  Created by yanue on 2021/01/30.
#  Copyright © 2021 yanue. All rights reserved.

# remove old file
rm -fr ~/.V2rayU/v2ray-core
rm -fr ~/.V2rayU/pac

# root permission for change system proxy
cmd="./V2rayUTool"
sudo chown root:admin ${cmd}
sudo chmod a+rx ${cmd}
sudo chmod +s ${cmd}

# copy
\cp -rf ./pac  ~/.V2rayU/
\cp -rf ./unzip.sh  ~/.V2rayU/
\cp -rf ./v2ray-core  ~/.V2rayU/

# permission
sudo chown -R $USER  ~/.V2rayU/
sudo chmod -R 777 ~/.V2rayU/

# root permission
cd  ~/.V2rayU/

# for apple silicon replace v2ray
if [[ $(arch) == 'arm64' ]]; then
    \cp -rf ~/.V2rayU/v2ray-core/v2ray-arm64  ~/.V2rayU/v2ray-core/v2ray
fi

cmd="./unzip.sh"
sudo chown root:admin ${cmd}
sudo chmod a+rx ${cmd}
sudo chmod +s ${cmd}

echo 'done'

