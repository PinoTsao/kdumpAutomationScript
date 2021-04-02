#!/bin/sh
#set -x

# MODIFY alias according to you ~/.ssh/config
GUEST_ALIAS=vm

# Your guest crash source directory
CRASH=workspace/crash
# This is default path in which vmcore will be saved. make sure
# it must be the same as your guest's /etc/kdump.conf
DUMP_DIR=/var/crash
# This crash cmd file must locates crash source directory, and
# MUST BE correct, if not, crash cannot read the file, and will
# go into the interactive shell, then this script won't work.
CRASHCMDFILE=cmdfile


# debug use. Replace "cat" with ":" when release
_logx () {
cat <<DEBUGX
$1
DEBUGX
}

DUMPFILE_DIR=`ssh $GUEST_ALIAS "cd $DUMP_DIR; ls"`
_logx "dump file dir is: $DUMPFILE_DIR"

dircnt=`echo "$DUMPFILE_DIR" | wc -w`
if [[ $dircnt -gt 1 ]]
then
    echo "More than 1 directory, can't figure out which one is from last kdump. Bye~"
    exit # consider exit with a specific value to indicate the caller
elif [[ $dircnt -lt 1 ]]
then
    echo "NO directory, your kdump doesn't succeed. Bye~"
    exit # consider exit with a specific value to indicate the caller
else
    _logx "Good, just 1 directory"
fi

# Check if vmcore file exists
if ssh $GUEST_ALIAS test -e $DUMP_DIR/$DUMPFILE_DIR/vmcore
then
    _logx "vmcore exists, try to analyse with crash tool"
else
    _logx "vmcore doesn't exist, please check serial output via virsh console"
    exit # consider exit with a specific value to indicate the caller
fi

# Create the crash command file. May consider add some more command
# and check the output.
ssh vm "echo "p jiffies" > $CRASH/$CRASHCMDFILE; echo q >> $CRASH/$CRASHCMDFILE"

crash_output=`ssh $GUEST_ALIAS "cd $CRASH; sudo ./crash ../linux/vmlinux -s -i $CRASHCMDFILE $DUMP_DIR/$DUMPFILE_DIR/vmcore"`
if [[ $? != 0 ]]
then
    echo "crash tool cannot analyse vmcore. Bye~"
    exit # consider exit with a specific value to indicate the caller
else
    _logx "$crash_output"
    # Typical output looks like this:
    # WARNING: kernel relocated [144MB]: patching 97034 gdb minimal_symbol values jiffies = $1 = 4461838973
    # Catch the last substring, which is the jiffies value.
    jiffies=${crash_output##* }
    _logx $jiffies

    re='^[0-9]+$'
    if ! [[ $jiffies =~ $re ]]
    then
	echo "$jiffies is NOT a number. Crash analyse fail. Bye~"
       	exit # consider exit with a specific value to indicate the caller
    fi

    echo "crash can analyse vmcore, the whole dump process succeed. Congratulations~"
fi
