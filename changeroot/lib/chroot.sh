# This is a bash library of functions used in the changeroot_xxxx scripts

usage () {
    echo -e "Usage:\n \
       $0 CHROOT_DEVICE CHROOT_MOUNTPOINT COMMAND"
    exit 1
}


# as_fn_set_status STATUS
# -----------------------
# Set $? to STATUS, without forking.
as_fn_set_status ()
{
  return $1
} # as_fn_set_status

# as_fn_exit STATUS
# -----------------
# Exit the shell with STATUS, even in a "trap 0" or "set -e" context.
as_fn_exit ()
{
  set +e
  as_fn_set_status $1
  exit $1
} # as_fn_exit

setup () {
    local chroot_mountpoint="$1"
    if [[ ! -d "$chroot_mountpoint" ]]; then
        mkdir -p "$chroot_mountpoint"
    fi
}

breakdown () {
    local chroot_mountpoint="$1"
    do_bind_unmounts $chroot_mountpoint
    umount "$chroot_mountpoint"
}

bind_it () {
    mount --bind $1 $2
}

do_bind_mounts () {
    local mountpoint chroot_mountpoint="$1"
    for mountpoint in "/dev/" "/dev/pts" "/dev/shm" "/proc" "/sys" "/run"; do
        bind_it "$mountpoint" "${chroot_mountpoint}${mountpoint}"
    done
}

do_bind_unmounts () {
    local mountpoint chroot_mountpoint="$1"
    for mountpoint in "/dev/pts" "/dev/shm" "/dev" "/proc" "/sys" "/run"; do
        umount "${chroot_mountpoint}${mountpoint}"
    done
}

do_chroot () {
    [[ $# -eq 0 ]] && usage
    [[ "$(id -u)" -eq 0 ]] || { echo -e "\tRoot permissions required...\n"; return 1; }
    local CHROOT_DEVICE CHROOT_MOUNTPOINT
    CHROOT_DEVICE="$1"
    CHROOT_MOUNTPOINT="$2"
    [[ x"$CHROOT_DEVICE" == "x" ]] && usage
    [[ x"$CHROOT_MOUNTPOINT" == "x" ]] && usage
    [[ -b $CHROOT_DEVICE ]] || { echo -e "\t$CHROOT_DEVICE is not a block device...\n"; return 1; }


    # Catch error status, even normal exit. Make sure anything mounted
    # by this script is unmounted, no matter if the script exits
    # normally or not.
    trap 'exit_status=$?
    breakdown $CHROOT_MOUNTPOINT
    exit $exit_status
' 0
    for ac_signal in 1 2 13 15; do
        trap 'ac_signal='$ac_signal'; as_fn_exit 1' $ac_signal
    done
    ac_signal=0

    setup "$CHROOT_MOUNTPOINT"
    
# Attempt mount
    mount "$CHROOT_DEVICE" "$CHROOT_MOUNTPOINT"
    # returns status 32 when already mounted
    if [[ $? != 0 && $? != 32 ]]; then
        echo "Could not mount $CHROOT_DEVICE on $CHROOT_MOUNTPOINT"
        exit 1
    fi
    do_bind_mounts $CHROOT_MOUNTPOINT
    
    # run teh commands
    if [[ ${#COMMANDS[@]} -gt 0   ]]; then
        for __ in "${COMMANDS[@]}"; do
            chroot "$CHROOT_MOUNTPOINT" $__
        done
    else
        echo "Nothing to do..."
    fi
    
}

do_chroot_interactive () {
    [[ $# -eq 0 ]] && usage
    [[ "$(id -u)" -eq 0 ]] || { echo -e "\tRoot permissions required...\n"; return 1; }
    local CHROOT_DEVICE CHROOT_MOUNTPOINT
    CHROOT_DEVICE="$1"
    CHROOT_MOUNTPOINT="$2"
    [[ x"$CHROOT_DEVICE" == "x" ]] && usage
    [[ x"$CHROOT_MOUNTPOINT" == "x" ]] && usage
    [[ -b $CHROOT_DEVICE ]] || { echo -e "\t$CHROOT_DEVICE is not a block device...\n"; return 1; }


    # Catch error status, even normal exit. Make sure anything mounted
    # by this script is unmounted, no matter if the script exits
    # normally or not.
    trap 'exit_status=$?
    breakdown $CHROOT_MOUNTPOINT
    exit $exit_status
' 0
    for ac_signal in 1 2 13 15; do
        trap 'ac_signal='$ac_signal'; as_fn_exit 1' $ac_signal
    done
    ac_signal=0

    setup "$CHROOT_MOUNTPOINT"
    
# Attempt mount
    mount "$CHROOT_DEVICE" "$CHROOT_MOUNTPOINT"
    # returns status 32 when already mounted
    if [[ $? != 0 && $? != 32 ]]; then
        echo "Could not mount $CHROOT_DEVICE on $CHROOT_MOUNTPOINT"
        exit 1
    fi
    do_bind_mounts $CHROOT_MOUNTPOINT

    chroot "$CHROOT_MOUNTPOINT" "/bin/bash"
}
