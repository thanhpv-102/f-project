#!/bin/bash

export FLEX_HOME='/flex-sdk'

curl -fL -o /tmp/flex-sdk.tar.gz http://apache.cbox.biz/flex/4.16.0/binaries/apache-flex-sdk-4.16.0-bin.tar.gz
tar -xzf /tmp/flex-sdk.tar.gz -C /tmp
mv /tmp/apache-flex-sdk-* $FLEX_HOME
cd $FLEX_HOME
ant -f installer.xml -Dair.sdk.version=2.6 \
	-Djava.awt.headless=true \
	-Dinput.air.download=y \
	-Dinput.fontswf.download=y \
	-Dinput.flash.download=y

export PATH="$FLEX_HOME/bin:$PATH"

curl -fL -o /tmp/flash_player.tar.gz https://fpdownload.macromedia.com/pub/flashplayer/updaters/27/flash_player_sa_linux_debug.x86_64.tar.gz
tar -xzf /tmp/flash_player.tar.gz -C /tmp
mv /tmp/flashplayerdebugger /usr/local/bin/
mkdir -p /usr/local/doc/flashplayerdebugger
mv /tmp/LGPL/* /usr/local/doc/flashplayerdebugger/
chown -R root:root /usr/local/bin/flashplayerdebugger /usr/local/doc/flashplayerdebugger

echo $DISPLAY

echo '#!/bin/sh' 											>> /usr/local/bin/xvfb
echo 'num=$(echo $DISPLAY | cut -d: -f2)'           		>> /usr/local/bin/xvfb
echo 'args="-screen 0 $RESOLUTION -ac +extension RANDR"' 	>> /usr/local/bin/xvfb
echo 'xvfb-run -e /dev/stderr -n $num -s "$args" "$@"' 		>> /usr/local/bin/xvfb
chmod +x /usr/local/bin/xvfb

export FLASH_PLAYER_EXE='/usr/local/bin/flashplayerdebugger'
#export DISPLAY=':99'
export RESOLUTION='1024x768x24'

