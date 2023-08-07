#!/bin/sh

#  appdmg.sh
#  V2rayU
#
#  Created by yanue on 2023/7/10.
#  Copyright © 2023 yanue. All rights reserved.

# copy for arm64
#

#
## build for arm64
#rm -fr release/V2rayU.app
#mv -rf release/V2rayU.app-arm64 release/V2rayU.app
#rm -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray
#\mv -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray-arm64 release/V2rayU.app/Contents/Resources/v2ray-core/v2ray
#rm -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray-arm64
#
#echo "appdmg V2rayU-arm64.dmg"
#rm -f V2rayU-arm64.dmg
#appdmg appdmg.json "V2rayU-arm64.dmg"
#
#rm -fr release/V2rayU.app

echo "请选择build的版本 :"
options=("64" "arm64")
select target in "${options[@]}"
do
    case $target in
    "64")
        echo "你选择了: 64"
        # remove v2ray-arm64
#        rm -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray-arm64
        echo "appdmg V2rayU-64.dmg"
        rm -f V2rayU-64.dmg
        appdmg appdmg.json "V2rayU-64.dmg"
        #rm -fr release/V2rayU.app
        ./sign_update "V2rayU-64.dmg"

        break
        ;;
    "arm64")
        echo "你选择了: arm64"
        # replace v2ray-arm64 to v2ray
#        rm -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray
#        mv -f release/V2rayU.app/Contents/Resources/v2ray-core/v2ray-arm64 release/V2rayU.app/Contents/Resources/v2ray-core/v2ray
        echo "appdmg V2rayU-arm64.dmg"
        rm -f V2rayU-arm64.dmg
        appdmg appdmg.json "V2rayU-arm64.dmg"
                #rm -fr release/V2rayU.app
        ./sign_update "V2rayU-64.dmg"

        break
        ;;
    *) echo "请选择";;
    esac
done
