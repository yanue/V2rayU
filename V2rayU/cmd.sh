#!/bin/sh

#  cmd.sh
#  V2rayU
#
#  Created by yanue on 2018/12/19.
#  Copyright © 2018 yanue. All rights reserved.

cd `dirname "${BASH_SOURCE[0]}"`

cmd="./V2rayUTool"

sudo chown root:admin ${cmd}
sudo chmod a+rx ${cmd}
sudo chmod +s ${cmd}

cmd="./V2rayUHelper"

sudo chown root:admin ${cmd}
sudo chmod a+rx ${cmd}
sudo chmod +s ${cmd}

echo 'done'
