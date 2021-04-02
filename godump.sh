#~/bin/sh

# This the Guest path, MODIFY according to your setup.
KDUMPCTL=~/workspace/kdumpctl

# MODIFY alias according to your host ~/.ssh/config
GUEST_ALIAS=vm
# This is the domain name displayed in virsh, MODIFY it
# according to you reality.
DOMAIN_NAME=f27s
# MUST be the same as "path" of guest /etc/kdump.conf
#DUMP_DIR=hostshare
DUMP_DIR=/var/crash

RET=

# debug use. Replace "cat" with ":" when release
_logx () {
cat <<DEBUGX
$1
DEBUGX
}

ssh $GUEST_ALIAS sudo $KDUMPCTL start
RET=$?
if [[ $RET != 0 ]]
then
    _logx "kdump service start fail. Command exit with $RET."
    exit # We may consider exit with a specific value to indicate the caller
else
    _logx "kdump service start OK. $RET"
fi

# If we directly modify the KEXEC path of Guest /usr/bin/kdumpctl,
# this could be used to double check kdump service is available or not.
# ssh $GUEST_ALIAS systemctl is-active kdump

# Before dump, should clean the dump file directory(defaults to /var/crash),
# or else crash don't know which directory belongs to the last dump.
# check and determine if need cleanup.
entries=`ssh $GUEST_ALIAS ls $DUMP_DIR`
lines=`echo "$entries" | wc -w`
if [[ $lines != 0 ]]
then
    _logx "$lines entry, Need clean"

    ssh $GUEST_ALIAS "sudo rm -r $DUMP_DIR/*"

    entries=`ssh $GUEST_ALIAS ls $DUMP_DIR`
    lines=`echo "$entries" | wc -w`

    if [[ $lines != 0 ]]
    then 
	echo "failed to clean dump file directory. Bye~"
	exit
    else
	_logx "dump file directory cleaning success."
    fi
else
    _logx "No need to clean"
fi

_logx "Trigger kdump now..."
sudo virsh inject-nmi $DOMAIN_NAME
