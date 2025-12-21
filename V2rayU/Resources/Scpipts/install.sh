#!/bin/sh

#  install.sh
#  V2rayU
#
#  Created by yanue on 2021/01/30.
#  Copyright © 2021 yanue. All rights reserved.

# current file dir is: xxx/V2rayU.app/Resources

set -x

# replace V2rayUTool
rm -fr $HOME/.V2rayU/V2rayUTool
\cp -rf ./V2rayUTool  $HOME/.V2rayU/

# replace core for new version
rm -fr $HOME/.V2rayU/bin/
\cp -rf ./bin/  $HOME/.V2rayU/bin/

# copy pac files if not exists
if [ ! -d "$HOME/.V2rayU/pac" ]; then
    cp -rf ./pac "$HOME/.V2rayU/"
fi

sudo xattr -rd com.apple.quarantine "$HOME/.V2rayU/"


# permission
sudo chown -R $USER  $HOME/.V2rayU/
sudo chmod -R 777 $HOME/.V2rayU/

# remove quarantine flag
sudo /usr/bin/xattr -rd com.apple.quarantine $HOME/.V2rayU/

# root permission
cd  $HOME/.V2rayU/

# root permission for change system proxy
cmd="./V2rayUTool"
sudo chown root:admin ${cmd}
sudo chmod a+rxs ${cmd}

echo 'done'

