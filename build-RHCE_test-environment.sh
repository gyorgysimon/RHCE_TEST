#!/usr/bin/env bash
###############################################################
#                       Readme.md                             #
#                                                             #
#     This script has been createed to prepare the same       #
#        for all those, who are trying to complete            #
#               practise exam for RHCE v8.0                   #
#                   prepared for RHEL 7                       #
###############################################################
#set -x

### set hypervisor
export LIBVIRT_DEFAULT_URI="qemu:///system"

### Static variables
DOMAIN="rhce-test.example.com"
PREFIX="rhce-test"
VMROOT="/home/kvm/"
POOL_DIR="$VMROOT/$PREFIX/virtualdiskpool"
BASE_IMG_FILE="rhel-8.1-x86_64-kvm.qcow2"
DVD_ISO_FILE="rhel-8.1-x86_64-dvd.iso"
ROOTPWD="password"
SM_POOL="8a85f99b70399fb4017043e872817b1a"
DISK_POOL="${PREFIX}-images"
NET_POOL="${PREFIX}-network"
NET_XML=${NET_POOL}.xml
BACKING_IMAGE=$POOL_DIR/$BASE_IMG_FILE
EXTRA_DISK_SIZE="1G"

### Dynamic varialbles
# generate HOSTS and HOSTIP associative arrays from network definition file
declare -A HOSTS
declare -A HOSTIP
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
    local ret=$?
    TAG_NAME=${ENTITY%% *}
    ATTRIBUTES=${ENTITY#* }
    return $ret
}

parse_dom () {
  if [[ $TAG_NAME = "host" ]] ; then
    eval local $ATTRIBUTES
#    echo -e host '\n' name: ${name} '\n' macaddress: ${mac} '\n' ipaddress: ${ip}
    HOSTS[${name}]=${mac}
    HOSTIP[${name}]=${ip}
  fi
}

while read_dom; do
    parse_dom
done < $NET_XML

WM_W_EXTRA_DISK=(node3)
VM_W_DVD_IMG=(utility)
VM_W_EXTRA_NIC=(node1)

# set worker nodes in an array called MANAGEDNODES
for name in node1 node2 node3
do
  DOMNAME=${PREFIX}-$name
  MANAGEDNODES+=($DOMNAME)
done

# set all nodes in an array called VMS
for name in ${!HOSTS[@]}
do
  DOMNAME=${PREFIX}-$name
  VMS+=($DOMNAME)
done

# set up a variable for the host OS
VERSION=$(uname -r|awk -F'.' '{print $6}')
case $VERSION
in
	el7) 
		VOS="rhel8-unknown"  # for RHEL7
		;;
	*)
		VOS=rhel8.1 # for RHEL8
		;;
esac

# check if VMROOT directory is exists or need to create
[[ ! -d "$VMROOT" ]] && sudo mkdir $VMROOT
# check if PREFIX dir exists
[[ ! -d $VMROOT/$PREFIX ]] && sudo mkdir -p $VMROOT/$PREFIX

#setup virtual network
function createNetwork {
  local net_pool=$@
  local net_xml=${net_pool}.xml
  virsh net-define --file ./${net_xml}
  virsh net-autostart --network ${net_pool}
  virsh net-start --network ${net_pool}
}

#setup virtual disk pool
function createStoragePool {
  virsh pool-define-as $DISK_POOL dir - - - - $POOL_DIR
  virsh pool-build $DISK_POOL
  virsh pool-autostart $DISK_POOL
  virsh pool-start $DISK_POOL
}

#move base image into the pool directory
function uploadBaseDiskImage {
  echo "Uploading base OS (RHEL 8.1) image into the storage pool..."
  virsh vol-create-as $DISK_POOL $BASE_IMG_FILE --prealloc-metadata --format qcow2 1G
  virsh vol-upload --vol $BASE_IMG_FILE --file $BASE_IMG_FILE --pool $DISK_POOL 
}

#create virtual disk images
function createNewOSDisk {
  hosts=$@
  for i in ${hosts[@]}
  do
	  IMAGE=${i}_vda_rhel8.1-x86_64-kvm.qcow2
	  virsh vol-create-as $DISK_POOL $IMAGE --format qcow2 --backing-vol ${BACKING_IMAGE} --backing-vol-format qcow2 8G
  done
}

#remove virtual disk image
function removeOSDisk {
  hosts=$@
  for i in ${hosts[@]}
  do
    echo removedisk $i
  done
}

# install new vms
function createVM {
  for name in ${!HOSTS[@]}
  do
	  IMAGE=${DISK_POOL}/${name}_vda_rhel8.1-x86_64-kvm.qcow2
	  DOMNAME=${PREFIX}-$name
	  VIRTINSTALL="virt-install --name ${DOMNAME} --memory 1536 --vcpus 2 --import --os-variant $VOS --boot hd --noreboot"
	  case $VERSION in
  		el7)
	  		# virt-install in EL7 has bus option in --disk section, and mac option in --network section
		  	VIRTINSTALL=${VIRTINSTALL}" --disk vol=${IMAGE},size=20,format=qcow2,bus=virtio --network network=${NET_POOL},model=virtio,mac=${HOSTS[${name}]}"
			  ;;
  			# newer version of virt-install has target.bus in --disk section and mac.address option in --network section
	  	*)
		  	# dvd image attach at define time --cdrom $(pwd)/$DVD_ISO_FILE
			  VIRTINSTALL=${VIRTINSTALL}" --disk vol=${IMAGE},size=20,format=qcow2,target.bus=virtio --network network=${NET_POOL},model.type=virtio,mac.address=${HOSTS[${name}]} --install no_install=yes"
			  ;;
    esac
  	VIRTINSTALL=${VIRTINSTALL}" --graphics none --noautoconsole"
	  $VIRTINSTALL 2> /dev/null
  done
}

#add addition disk for $VM_W_EXTRA_DISK
function addExtraDisk {
  vm_w_extra_disk=$@
  for domname in ${vm_w_extra_disk[@]}
  do
  	virsh vol-create-as --name ${domname}-vdb.qcow2 --capacity $EXTRA_DISK_SIZE --format qcow2 --pool $DISK_POOL --prealloc-metadata
	  virsh attach-disk --domain ${PREFIX}-${domname} --targetbus virtio --persistent --source ${POOL_DIR}/${domname}-vdb.qcow2 --target vdb
  done
}

#add iso image ${VM_W_DVD_IMG[@]}
function addDVDImage {
  for domname in ${VM_W_DVD_IMG[@]}
  do
	  case version in 
  		el7) 
	  		virsh attach-disk --domain ${PREFIX}-${domname} --source $(pwd)/$DVD_ISO_FILE --target hda --type cdrom --mode readonly --persistent
		  ;;
  		*)
	  		virsh attach-disk --domain ${PREFIX}-${domname} --source $(pwd)/$DVD_ISO_FILE --target hdc --type cdrom --targetbus sata --mode readonly --persistent
		  ;;
  	esac
  done
}

#add extra nic to domain ${WM_W_EXTRA_NIC}
function addExtraIsolatedNIC {  
  local wm_w_extra_nic=$@
  local net="${PREFIX}-dummy"
  local net_pool="${net}-network"
  local net_xml=${net_pool}.xml
  #generate network xml
  cat << EOF > ${net_xml} 
<network>
  <name>${net_pool}</name>
  <ip address="192.168.254.1" netmask="255.255.255.248"/>
</network>
EOF

  createNetwork ${net_pool}
  for domain in ${wm_w_extra_nic}
  do
    virsh attach-interface --domain ${PREFIX}-${domain} --type network --model virtio --config --live --source ${net_pool}
  done
}

#start the vmsstart
function startVM {
  vms=$@
  for domname in ${vms[@]}
  do
	  echo virsh start $domname
	  virsh start $domname
  done
}

function stopVM {
  vms=$@
  for domname in ${vms[@]}
  do
    virsh destroy $domname
  done
}

function undefineVM {
  vms=$@
  for domname in ${vms[@]}
  do
    virsh undefine $domname
  done
}

function usage {
  echo "usage: ${0} [-b] | [ -s ] | [-h]"
  echo -e '\t' "-h print this help"
  echo -e '\t' "-b to build the whole environment at once"
  echo -e '\t' "-s toggle Start & Stop the whole environment at once"
#  echo -e '\t' "-r rebuild all managed nodes"
  exit
}

function automatedBuild {
  #generate ip based inventory
  eval inventoryfile=$(grep inventory ansible.cfg|awk -F'=' '{print $2}')
  [[ -f $inventoryfile ]] && echo "" > $inventoryfile
  for ip in ${HOSTIP[@]}
  do
    echo ${ip%?} >> $inventoryfile
  done
  
  #generate hosts.j2 for ansible template
  templatefile=hosts.j2
  [[ -f $templatefile ]] && echo "127.0.0.1 localhost localhost.localdomain" > $templatefile
  for key in ${!HOSTIP[@]}
  do
    echo "${HOSTIP[$key]%?} $key ${key}.${DOMAIN}" >> $templatefile
  done
  
  ansible all -u root -e ansible_password=password -i $inventoryfile -m wait_for_connection
  ansible-playbook deploy-utility.yaml
  ansible-playbook deploy-control.yaml
}

function checkVmState {
  if [[ `virsh list | grep $PREFIX` ]]; then
    VMSTATE=1
  else
    VMSTATE=0
  fi
  export VMSTATE
}

#### MAIN ####

#process options need add rebuild option r:

[ $# -eq 0 ] && usage
while getopts "bsh" options
do
  case $options in
    b)
      echo createNetwork ${NET_POOL}
      createNetwork ${NET_POOL}
      echo createStoragePool
      createStoragePool
      echo uploadBaseDiskImage
      uploadBaseDiskImage
      echo createNewOSDisk ${!HOSTS[@]}
      createNewOSDisk ${!HOSTS[@]}
      echo createVM ${VMS[@]}
      createVM ${VMS[@]}
      echo addExtraDisk ${WM_W_EXTRA_DISK[@]}
      addExtraDisk ${WM_W_EXTRA_DISK[@]}
      echo addDVDImage ${VM_W_DVD_IMG[@]}
      addDVDImage ${VM_W_DVD_IMG[@]}
      echo startVM ${VMS[@]}
      startVM ${VMS[@]}
      echo addExtraIsolatedNIC ${VM_W_EXTRA_NIC}
      addExtraIsolatedNIC ${VM_W_EXTRA_NIC}
      automatedBuild
      ;;
#    r)
#      vmname=$OPTARG
#      stopVM $vmname
#      undefineVM $vmname
#      createVM $vmname
#      addExrtaDisk $vmname
#      addDVDImage $vmname
#      startVM $vmname
#      ;;
    s)
      checkVmState
      echo vmstate $VMSTATE
      if [[ $VMSTATE == 1 ]]; then
        echo vms are running need to stop
        echo stopVM ${VMS[@]}
        stopVM ${VMS[@]}
      else
        echo vms are NOT running need to start
        echo startVM ${VMS[@]}
        startVM ${VMS[@]}
      fi
      ;;
    h)
      usage
      ;;
    *)
      echo "Invalid option!"
      usage
      ;;
  esac
done

