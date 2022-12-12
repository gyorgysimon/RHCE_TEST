#!/bin/bash
#set -x

CURRENTDIR=$(pwd)
SAVEDIR=${CURRENTDIR}/rhce-test-save
ARCHIVE=${SAVEDIR}/${USER}-rhce-test-project-$(date +%Y-%m-%d-%H-%M).tar

[[ ! -d $SAVEDIR ]] && mkdir $SAVEDIR
sudo LIBGUESTFS_BACKEND=direct virt-copy-out -d rhce-test-control /home/ansiusr/project $SAVEDIR > /dev/null
cd $SAVEDIR

tar cf $ARCHIVE project/
rm -fr project/
echo "Archive is ready to send, file: $ARCHIVE"
