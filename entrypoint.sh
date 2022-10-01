#!/bin/sh
set -e
echo "Starting up openldap container!"
echo ""
echo "Setting UID/GID to $PUID / $PGID for main process"
groupmod -g $PGID openldap
usermod -u $PUID -g openldap openldap

chown -R openldap:openldap /data /config /run/openldap
chmod 0700 /config /data /ssl

if [ ! -w "/config/" ]
then
        echo "Unable to read or write config directory!"
fi
if [ ! -w "/data" ]
then
        echo "Unable to read or write data directory!"
fi
if [ ! -w "/ssl" ]
then
        echo "Unable to read or write ssl directory!"
fi
if [ ! -w "/socket" ]
then
        echo "Unable to read or write socket directory!"
fi

if  [ "$1"  == "init" ]; then
        echo "Copying default config to /config/slapd.d"
        cp -avr /default/slapd.d/ /config/slapd.d
else
        echo "Starting slapd"
        exec /usr/local/lib/slapd -u openldap -g openldap "$@"
fi
