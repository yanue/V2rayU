#!/bin/sh

#  install.sh
#  V2rayU
#
#  Created by yanue on 2021/01/30.
#  Copyright © 2021 yanue. All rights reserved.

# replace V2rayUTool
rm -fr ~/.V2rayU/V2rayUTool
\cp -rf ./V2rayUTool  ~/.V2rayU/

# replace v2ray-core for new version
rm -fr ~/.V2rayU/v2ray-core
\cp -rf ./v2ray-core  ~/.V2rayU/

# copy pac file if not exists
if [ ! -d "~/.V2rayU/pac" ]; then
    \cp -rf ./pac  ~/.V2rayU/
fi

# permission
sudo chown -R $USER  ~/.V2rayU/
sudo chmod -R 777 ~/.V2rayU/

# root permission
cd  ~/.V2rayU/

# root permission for change system proxy
cmd="./V2rayUTool"
sudo chown root:admin ${cmd}
sudo chmod a+rxs ${cmd}

# for apple silicon replace v2ray
if [[ $(arch) == 'arm64' ]]; then
    \cp -rf ~/.V2rayU/v2ray-core/v2ray-arm64  ~/.V2rayU/v2ray-core/v2ray
fi

echo 'done'

