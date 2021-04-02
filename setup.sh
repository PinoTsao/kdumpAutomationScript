#!/bin/sh
#
# Update & build all components of kdump, test it with the latest components.
#
# We use an ordinary account to login VM, not root, so, before executing
# this script, you need much more preparation work to do. this will be
# documentd somewhere else. And this scripts is implemented & tested on
# fedora 28 server.

# Please note, the follwong path variables means the path under ~/
# in the VM. MODIFY them according to your real path!
KERNELS=(workspace/linux workspace/tip workspace/linux-next)
TARGET_KERNEL=${KERNELS[0]}

KEXEC=workspace/kexec-tools
MAKEDUMPFILE=workspace/makedumpfile
CRASH=workspace/crash
TOOLS=($KEXEC $MAKEDUMPFILE $CRASH)

# MODIFY alias according to you ~/.ssh/config
GUEST_ALIAS=vm

RET=

# debug use. Replace "cat" with ":" when release
_logx () {
cat <<DEBUGX 
$1
DEBUGX
}

for tool in ${TOOLS[0]} ${TOOLS[1]} ${TOOLS[2]}
do
    if [[ $tool == $KEXEC ]]
    then
	ssh $GUEST_ALIAS "cd $tool; git pull; ./bootstrap; ./configure; make -j2"
    elif [[ $tool == $MAKEDUMPFILE ]]
    then
	ssh $GUEST_ALIAS "cd $tool; git pull; make LINKTYPE=dynamic"
    elif [[ $tool == $CRASH ]]
    then
	ssh $GUEST_ALIAS "cd $tool; git pull; make lzo"
    else
	echo "Programming Error!"
	exit
    fi

    RET=$?
    if [[ $RET != 0 ]]
    then
        _logx "$tool update fail. Last command exit with $RET."
        exit # consider exit with a specific value to indicate the caller
    else
        _logx "$tool update success."
	echo
    fi
done

# Why need both "olddefconfig" & "localmodconfig"? Generally speaking, new
# version kernel often introduce new configuration items, this will stop
# localmodconfig, prompt user to configure the new items. With olddefconfig
# first, the automation won't be interrupted.
#
# "olddefconfig" & "localmodconfig" are not enough for our purpose,
# in reality, when want to test certain features, we should prepare a
# customization config file, say iaas.config, put it under kernel/configs/,
# then append `make iaas.config` after `make localmodconfig`.
ssh $GUEST_ALIAS "cd $TARGET_KERNEL; git pull; make olddefconfig; make localmodconfig; make -j2"
RET=$?
if [[ $RET != 0 ]]
then
    _logx "kernel update fail. Last command exit with $RET."
    exit # consider exit with a specific value to indicate the caller
else
    _logx "kernel update success."
    echo
fi

# May seperate 'install' info a individual one, for more accurate check.
ssh $GUEST_ALIAS "cd $TARGET_KERNEL; sudo make modules_install; sudo make install"
RET=$?
if [[ $RET != 0 ]]
then
    _logx "modules/kernel install fail. Command exit with $RET."
    exit # consider exit with a specific value to indicate the caller
else
    _logx "modules/kernel install success."
fi

# After installed new kernel, need to make it the default entry in grub menu.
KERNEL_RELEASE=`ssh $GUEST_ALIAS "cd $TARGET_KERNEL; make kernelrelease"`
ssh $GUEST_ALIAS "sudo grubby --set-default /boot/vmlinuz-$KERNEL_RELEASE"
RET=$?
if [[ $RET != 0 ]]
then
    _logx "grubby FAILed. Command exit with $RET."
    exit # consider exit with a specific value to indicate the caller
else
    _logx "grubby success."
fi

echo
echo "All Kdump components have been updated."

# Have installed the new kernel, now reboot.
ssh $GUEST_ALIAS sudo reboot
