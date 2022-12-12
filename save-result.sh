#!/bin/bash
set -x

CURRENTDIR=$(pwd)
SAVEDIR=${CURRENTDIR}/rhce-res-save
ARCHIVE=${SAVEDIR}/rhce-res-$(date +%Y-%m-%d-%H-%M).tar

[[ ! -d $SAVEDIR ]] && mkdir $SAVEDIR
sudo LIBGUESTFS_BACKEND=direct virt-copy-out -d rhce-test-control /home/ansiusr/project/tests/ReszletesVegeredmeny.csv $SAVEDIR > /dev/null
 
echo "Archive is ready to send, file: $SAVEDIR/ReszletesVegeredmeny.csv"
