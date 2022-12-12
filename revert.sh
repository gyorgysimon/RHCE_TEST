#!/bin/bash

export LIBVIRT_DEFAULT_URI="qemu:///system"
PREFIX=rhce-test

echo "saveing your project directory from the control node before I destroy it!"
if [ "$1" == grade ]; then
  ./save-result.sh
else
  ./save-my-work.sh
fi

#echo "remove hosts fingerprint"
for ip in 50 51 52 53 54
do
  ssh-keygen -R 10.9.0.$ip
done

for host in contorl control.rhce-test.example.com utility utility.rhce-test.example.com node1 node1.rhce-test.example.com node2 node2.rhce-test.example.com node3 node3.rhce-test.example.com 
do
	ssh-keygen -R $host
done

#echo "destroying vms"
for host in ${PREFIX}-utility ${PREFIX}-control ${PREFIX}-node1 ${PREFIX}-node2 ${PREFIX}-node3 
do
  virsh destroy $host
  virsh undefine $host
done

#echo "destroying pool"
virsh pool-destroy ${PREFIX}-images
virsh pool-undefine ${PREFIX}-images

#echo "destroying network"
virsh net-destroy ${PREFIX}-network
virsh net-undefine ${PREFIX}-network

virsh net-destroy ${PREFIX}-dummy-network
virsh net-undefine ${PREFIX}-dummy-network

#echo "removing dir"
sudo rm -fr /home/kvm/${PREFIX}

