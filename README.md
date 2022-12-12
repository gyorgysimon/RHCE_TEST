# RHCE_test
This environment intent to have a clear picture about the ansible engine knowledge of all those who are preparing themself for RHCE (EX294) exam.

=======
# PREREQs:
1. The environmnet build scripts need a git extension called lfs, large files. This extension can be downloaded from https://git-lfs.github.com/ Instruction:

   *  1.1. download the .tar.gz file (directlink: https://github.com/git-lfs/git-lfs/releases/download/v2.11.0/git-lfs-linux-amd64-v2.11.0.tar.gz)  
   *  1.2. extract the archive `mkdir gitlfs && tar xvf git-lfs-linux-amd64-v2.11.0.tar.gz -C gitlfs`  
   *  1.3. run `cd gitlfs && sudo ./install.sh && git lfs install` from the extracted folder  

2. user need to be in the libvirt and qemu groups
  `usermod -aG libvirt,qemu [username]`

3. You will need the rhel-8.1-x86_64-dvd.iso for the environment. You can download it from the access.redhat.com, or https://ibm.box.com/s/rer0a4uj06i51fqmgc7gba5sg386zha8

4. need to ensure x permisson to the `qemu` (which is probalby `others` from your user point of view) user thourgh the path of the DVD iso file.

=======
# Work here
The environment sits in the 10.9.0.0/29 network. Gateway and DNS service is 10.9.0.1.
It provides 5 VMs:
  1) utility.rhce.example.com as content provider/utility server for the environment. IP address: 10.9.0.54
  2) control.rhce.exmaple.com as the ansible control node with preinstalled ansible version 2.8. IP address: 10.9.0.50
  3) node1.rhce.exmaple.com managed node. IP address: 10.9.0.51
  4) node2.rhce.exmaple.com managed node. IP address: 10.9.0.52
  5) node3.rhce.exmaple.com managed node. IP address: 10.9.0.53

You have SSH service available on all nodes. Root password is "password" currently.

Build script usage:
  usage: 
> ./build-RHCE_test-environment.sh [-b] | [ -s ] | [-h]  
>>           -h print this help  
>>           -b to build the whole environment at once  
>>           -s toggle Start & Stop the whole environment at once  
           

`revert.sh` script destroy all nodes in the environment including the control and utility nodes too, but before the destroy, it will save the project folder in from ansiusr's home. You can call save-my-work.sh script individually to copy out your project directory from the control node. It will be saveed into the rhce-test-save directory and named as ${USER}-rhce-test-project-[date of action time].tar
