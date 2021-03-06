#!/bin/sh

# This is only invoked when the relevant preseed entry is passed in
# during the preinstall questioning.  (Thus, not for vanilla installs.)

breakpoint() {
    # Yes, we want to test the file existence each time, so that
    # it's possible to continue automatically by removing the file
    if [ -f /debathena/debug ]; then
	echo "breakpoint: $@" > /dev/tty5
	echo "(press enter to resume)" > /dev/tty5
	read dummy < /dev/tty5
    fi
}

cp /debathena/preseed /target/root/debathena.preseed
cp /debathena/install-debathena.sh /target/root
if test -f /debathena/pxe-install-flag ; then
  cp /debathena/pxe-install-flag /target/root/pxe-install-flag
fi

. /lib/chroot-setup.sh

chvt 5

breakpoint "in postinstall.sh, before setting up the chroot."

chroot /target dpkg-divert --rename --add /usr/sbin/policy-rc.d
if ! chroot_setup; then
    logger -t postinstall.sh -- "Target system not usable. Can't install Debathena."
    exit 1
fi

breakpoint "in postinstall.sh, before running install-debathena.sh"

# Something like this approach was once said to fail due to lingering
# processes keeping the pipeline open and the script hung.  According to
# trac#225 this doesn't happen any more.
(chroot /target sh /root/install-debathena.sh < /dev/tty5 2>&1 \
     && touch /debathena/install-succeeded) \
     | chroot /target tee /var/log/athena-install.log > /dev/tty5

if ! [ -e /debathena/install-succeeded ]; then
  echo "WARNING: your debathena postinstall has returned an error;" > /dev/tty5
  echo "see above for details." > /dev/tty5
  echo > /dev/tty5
  echo "This shell is provided for debugging purposes.  When you exit" > /dev/tty5
  echo "the shell, your system will reboot into the newly-installed"  > /dev/tty5
  echo "system, though depending on the failure you may see continuing issues." > /dev/tty5
  /bin/sh < /dev/tty5 > /dev/tty5 2>&1
fi

sleep 5

breakpoint "in postinstall.sh, after install-debathena.sh"

chroot_cleanup
chroot /target dpkg-divert --rename --remove /usr/sbin/policy-rc.d

breakpoint "at the end of postinstall.sh"

chvt 1
