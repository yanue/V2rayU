#!/bin/bash

#  publish.sh
#  V2rayU
#
#  Created by yanue on 2019/7/18.
#  Copyright © 2019 yanue. All rights reserved.

read -p "请输入版本描述: " release_note
#pushRelease ${release_note}
generateAppcast ${release_note}

echo "Done"
