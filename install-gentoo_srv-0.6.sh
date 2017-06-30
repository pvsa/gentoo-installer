#!/bin/sh
# Gentoo Server Install Start
## was falkland-installer
## PvSA, 24.6.2013
###################
#### DONE
## b1
# portage: http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2 - OK
# resolv.conf - OK
# mtab in chroot - OK
## b2
# chroot-script -OK
# -quiet /-interactive Option -OK
# quiet: IP/dhcp -OK
## RC1
# ch_install -OK
# paramter einlesen ohne reihenfolge
# fertig vorbereitete Disks (z.B. mdadm oder mit swap)
# part a already parted disk
## RC2
# ch_install in install_falkland
# multi chroot cmds
# NET aus chvar
# - dhcp - OK
# - IP - OK
# ssh re-emerge wegen falkland bug
# chavar.in ersetzten
## RC3
# own mirror
# hostname
# default bei read ="" /mnt/falkland
# select profile (/bin/bash: -c: line 0: syntax error near unexpected token `>') -> kein env-update etc, wenn es in die var geht !
# boot ist leer
# Warnung fuer 32-bit booted OS/System"
# mtab/fstab leer
# grub timeout = 5
# Quiet und feste IP: werte werden nicht in conf.d/net gesetzt
#######
## Gentoo-Fork Changes
# DONE
# parted anstatt fdisk: parted /dev/... mkpart primary 0% 200MiB 
# Swap Parition anlegen
# emerge -j CPU#
# modules check (loaded in grml) and in the kernel
# TODO
# Parse cmd parameter correct e.g. -q= (needed for add hostname and mirror from cmd direct)
# offer precompiled VM Kernel
# Kernel config from seperate own mirror
# -> obsolet wg udev dev/pts sauber in die fstab (nicht aus dem live-system) oder das nehmen, das drin ist
# TEST: modules fuer hdd/net in kernel pruefen
# udev renaming eth to enp ln /dev/null /etc/udev/rules.d/80-net-name-slot.rules
# keymap de/us
# rc-update sshd (abfrage in cmd), wenn angegeben ja ansonsten nix
# Prozessorkerne und emerge -j Option
### DEBUG
#set -x
#

# Set default editor
EDITOR=${EDITOR=vim}
# assuming disk(s) are not defnied
PD=0
# and using default mirror
OWNMIRROR=0

for i in "$@"
do
case $i in
    -h)
    HELP=1
    shift # past argument=value
    ;;
    -q=*)
    NET="${i#*=}"
    shift # past argument=value
    MODE="Q"
    ;;
    -i)
    MODE="I"
    shift # past argument=value
    ;;
    -om=*)
    INSTSRV="${i#*=}"
    OWNMIRROR=1
    shift # past argument=value
    ;;
    -pd)
    PD=1
    shift # past argument=value
    ;;
    -pk)
    PREK=1
    shift # past argument=value
    ;;
    -n=*)
    HNAME="${i#*=}"
    shift # past argument=value
    ;;
    *)
    NOOPT=1
            # unknown option
    ;;
esac
done


if [ "$MODE" = "" ] || [ "$NOOPT" = 1 ] || [ "$HELP" = 1 ] ; then
	echo "install-gentoo_srv.sh - Script for Installing Gentoo-Server"
	echo "==========================================================================================="
	echo "USAGE: sh install-gentoo_srv.sh -i|-q=dhcp/IPs [-i] [-n=hostname] [-om=[MIRROR]] [-pd] [pk]"
	echo " -h : help"
	echo " -q=dhcp/IPs: quiet Installation with defaults (for quiet you have to set >IP,gateway< or >dhcp<)"
        echo " -n=hostname : Name of the host aka. hostname or hostname.domnain.tld (FQDN)"
	echo " -i : interactive"
	echo " -om=[MIRROR]: Own mirror. You can specify altenativ mirror. "
	echo "      If Mode interactive, you will be asked later, else" 
	echo "      URL (with trailing /) must be specified to "
	echo "	    stage3-latest.tar.bz2 and portage-latest.tar.bz2 (assuming both lying on the same place) "
	echo " -pd: Predefined disks (Expecting:"
	echo "	    already mounted disks (/mnt/xxx/ and /mnt/xxx/boot) "
	echo "      with empty filesystem on it and not chrooted." 
	echo "	    This is recommend for md"
	echo "	    For md-devices respect the metadata=0.9 for grub(1)"
    	echo " -pk: precompiled kernel. See at http://www.pilarkto.net/mirror which version."
	echo "==========================================================================================="
	echo "THIS IS BETA STUFF. Please use only empty systems. Script erase disk to install !"
	exit 1
fi

if [ `uname -m |grep -c 64` = 0 ]; then
	echo "No 64-bit system booted or available. Installer not supporting 32-bit enviroment."
	exit 1
fi



if [ "$HNAME" = "" ]; then
	HNAME="localhost"
fi


if [ "$MODE" = 'Q' ]; then
	if [ "$NET" = "" ]; then
		echo 'You have to set IP,gateway or dhcp for quiet-Mode.'
		exit 1
	fi
fi
	

#STG3="stage3-20130329.tar.bz2"
#STG3="stage3-latest.tar.bz2"

if [ $OWNMIRROR = 0 ]; then
	INSTSRV="distfiles.gentoo.org"
    wget -q http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64.txt
    STG3="`cat latest-stage3-amd64.txt |tail -1 |cut -d " " -f 1`"   
	FLURL="http://$INSTSRV//releases/amd64/autobuilds/$STG3"
	#PURL="http://git.nitso.org/falkland-portage.git"
	PURL="rsync://rsync8.de.gentoo.org/gentoo-portage"
else
	if [ "$MODE" = "I" ]; then
		echo "Assuming stage3 and portage are on the same dir on URL"
		#echo "Which protocoll you want to use ? [http,ftp]"
		PROTO="http"
		echo "What is the name or IP of the mirror-server you want to use ? (example: distfiles.nitso.org or 192.168.0.1)"
		read INSTSRV
		echo "In which directory are the files on this server ?"
		echo "(example: mirror for 192.168.0.1/mirror/[stage3-latest|portage-latest] )"
		read RPATH
		FLURL="$PROTO://$INSTSRV/$RPATH/stage3-latest.tar.bz2"
		PURL="$PROTO://$INSTSRV/$RPATH/portage-latest.tar.bz2"
	## IF Quiet-Mode and OwnMirror
	else
		FLURL="$INSTSRV/stage3-latest.tar.bz2"
		PURL="$INSTSRV/portage-latest.tar.bz2"
	fi
		echo "Assuming stage3-URL: $FLURL"
		echo "Assuming portage-URL: $PURL"	

fi


ROT="tput setaf 1"
GRUEN="tput setaf 2"
GELB="tput setaf 3"
NRML="tput op"
MNTRT="/mnt/gentoosrv"
ADIR="`pwd`"

#check ram
$GRUEN 
echo "Checking ram size" 
$NRML
RAMSZ="`cat /proc/meminfo |grep MemTotal |cut -d ':' -f 2|tr -d ' ' |tr -d 'kB'`"
if [ $RAMSZ -lt 128000 ]; then
        $ROT
        echo "RAM ist too small (<128MB)"
        exit 1
else
		$GRUEN && echo "RAM size OK"
		$NRML
		#sleep 3
fi

# Get CPU count
CPU=`grep -c ^processor /proc/cpuinfo`

# check network (-> mirror reachable ?)
$GRUEN 
echo "Checking mirror (stage3) reachable" 
$NRML
#ping -q -c 2 $INSTSRV >/dev/null
#if [ "$?" != "0" ]; then
curl -Is $INSTSRV |grep -q 'HTTP/1.1 200 OK'
if [ $? != 0 ]; then
        $ROT
        echo "Server or network down. Not reaching $INSTSRV, exiting"
        exit 1
else
		$GRUEN && echo "Mirror reachable"
		$NRML
		#sleep 3
fi


# ssh starten
if [ "`netstat -tan|grep -c ':22 '`" = "0" ]; then
        $GRUEN
        echo "SSH is down. Try to activate now"
        $NRML
        /etc/init.d/ssh start
fi

if [ $PD = 0 ]; then
if [ "$MODE" = "I" ]; then

	# checking for usable disks
	echo "--------------------"
	fdisk -l |grep "/dev/" |cut -d " " -f 2 |sed 's/:/ /g' |sed 's/\/dev\///g'
	echo "--------------------"

	# dselect disk
	$GELB
	echo "Wich Disk is for the new system ?"
	$NRML
	read DISK

	# part. the disk
	echo 'Normaly two partitions are enough (no swap) /boot (256MB) und / (rest) [Enter]'
	read IT
	cfdisk $DISK
	
elif [ "$MODE" = "Q" ]; then
	## http://www.gentoo-wiki.info/Gentoo_Install_Script
	# Default is 2 partitons on the only disk device
	# select disk (vda, hda, sda) and not a partition
	DISK="`find /dev/ | grep -E [s:h:v]da |grep -v da[0-9]`"

	parted -s $DISK mklabel msdos
    parted -s $DISK mkpart primary 0% 256MiB
    SWAPEND=$(($RAMSZ+256000))
    SWAPEND2=$(($SWAPEND/1000))
    SWAPEND="`echo -n $SWAPEND2 && echo MiB`"
    parted -s $DISK mkpart primary 256MiB $SWAPEND
    parted -s $DISK mkpart primary $SWAPEND 100%
	echo ""
	$GRUEN && echo "Partions created"
	$NRML
fi
	# reload parttiontable
	sfdisk -R $DISK
	
	#Defining disks
	BDISK="${DISK}1"
    SDISK="${DISK}2"
	RDISK="${DISK}3"

	# formating filesystem (sys und boot)
	$GRUEN && echo "Formating partitions"
	$NRML
	mkfs.ext2 -q $BDISK 
    mkswap $SDISK
	mkfs.ext4 -q $RDISK


	# create SYS 
	$GRUEN && echo "Mounting system"
	$NRML
	mkdir -p $MNTRT
	mount $RDISK $MNTRT

elif [ $PD = 1 ]; then

	echo "Which mount point (e.g. /mnt/gentoosrv) shell be used for Root-System (/)"
	# override VAR default
	read MNTRT
	echo "Which is boot device for grub (Grub Version 0.9)"
	read BOOTDEV
fi


#stage 3 extracting
$GRUEN && echo "Getting stage3"
$NRML
cd $MNTRT
#wget -q $FLURL
curl -# -O $FLURL
$GRUEN && echo "Unpacking stage3"
$NRML
STG3="`ls stage3*.tar.bz2`"
tar --numeric-owner -xjpf $STG3
mv $STG3 $MNTRT/root/

#portage extracting
#! websync
$GRUEN && echo "Getting portage"
$NRML
if [ $OWNMIRROR = 0 ]; then
    rsync -r --info=progress2 $PURL/ $MNTRT/usr/portage/
else
    curl -# -O $PURL
    $GRUEN && echo "Unpacking portage"
    $NRML
    mkdir -p $MNTRT/usr/portage/
    tar -xf portage-latest.tar.bz2 -C $MNTRT/usr/portage/
fi


# mount /boot etc
$GRUEN && echo "Mounting boot and dependings"
$NRML
if [ $PD = 0 ]; then
	mount $BDISK $MNTRT/boot
fi
mount -t proc none $MNTRT/proc
mount --bind /dev $MNTRT/dev
mount --bind /dev/pts $MNTRT/dev/pts
mount -t sysfs none $MNTRT/sys

# mounts /mtab (s.u.)
#grep -v rootfs /etc/mtab > $MNTRT/etc/mtab


## Chroot-commands following ...
cp $ADIR/install-gentoo_srv* $MNTRT/root/

# only grub-install device is DISK
if [ $PD = 0 ]; then
	BOOTDEV="$DISK"
	# PD=1 set this above
fi

# Network config
if [ "$MODE"  = "I" ]; then
	$GELB && echo "Following NIC are present, choose primary one: [Enter = Next]"
	$NRML
	chroot $MNTRT ifconfig -a |grep "Link encap" |cut -d " " -f 1
	read NETDEV
	echo "Netzwerk-config - Editor: $EDITOR, File: /etc/conf.d/net (in Chroot)"
	echo 'config_eth0="IP netmask 255.255.255.0"' >>  $MNTRT/etc/conf.d/net
	echo 'routes_eth0="default via GW"' >>  $MNTRT/etc/conf.d/net
	$EDITOR $MNTRT/etc/conf.d/net
    echo "Setting hostname (conf.d)"
    echo "hostname=\"$HNAME\" " > $MNTRT/etc/conf.d/hostname
    echo "Please setup hosts-file [Enter]"
    $EDITOR $MNTRT/etc/hosts

elif [ "$MODE" = "Q" ]; then
	# assume it is eth0
	NETDEV="eth0"
	if [ "$NET" = "dhcp" ]; then
		echo 'config_eth0="dhcp"' >> $MNTRT/etc/conf.d/net
	else
    		IP="`echo $NET| cut -d ',' -f 1`"
	    	GW="`echo $NET| cut -d ',' -f 2`"
	    	echo "config_$NETDEV=\"$IP netmask 255.255.255.0\"" >>  $MNTRT/etc/conf.d/net
	    	echo "routes_$NETDEV=\"default via $GW\"" >>  $MNTRT/etc/conf.d/net
	    	#Namesever
	    	## German Priv. Foundation
	    	echo "nameserver 87.118.100.175" > $MNTRT/etc/resolv.conf
	    	## FoeBuD
	    	echo "nameserver 85.214.73.63" >> $MNTRT/etc/resolv.conf
            echo "$IP $HNAME" >> $MNTRT/etc/hosts
	fi
    echo "hostname=\"$HNAME\" " > $MNTRT/etc/conf.d/hostname

fi

chroot $MNTRT /bin/bash -c "ln -s /etc/init.d/net.lo /etc/init.d/net.$NETDEV"
chroot $MNTRT /bin/bash -c "rc-update add net.$NETDEV boot"
DNS="`cat /etc/resolv.conf |grep nameserver |cut -d " "  -f 2`"
echo "Setting DNS-Server to $DNS (like actual active system)"
cp /etc/resolv.conf $MNTRT/etc/


# syncing portage
$GRUEN && echo "Syncing Portage"
$NRML
 chroot $MNTRT /bin/bash -c "emerge -q --sync >/dev/null"


# compiling/getting Kernel
if [ "$PREK" = "1" ]; then
$GRUEN && echo "Getting pre-compiled Kernel"
$NRML
    wget -q http://www.pilarkto.net/mirror/latest-precompiled_kernel.txt -O /tmp/pck.txt
    KERNELVER="`cat /tmp/pck.txt`"
    echo "-Kernel version: $KERNELVER"
    $GRUEN && echo "--Getting config"
    $NRML
    curl -# -O http://www.pilarkto.net/mirror/$KERNELVER/config
    $GRUEN && echo "--Getting kernel"
    $NRML
    curl -# -O http://www.pilarkto.net/mirror/$KERNELVER/vmlinuz
    $GRUEN && echo "--Getting modules"
    $NRML
    curl -# -O http://www.pilarkto.net/mirror/$KERNELVER/modules.tar.bz2
    mv config $MNTRT/boot/"config-$KERNELVER"
    mv vmlinuz $MNTRT/boot/"vmlinuz-$KERNELVER"
    mkdir -p $MNTRT/lib/modules
    tar -xf modules.tar.bz2 -C $MNTRT/lib/modules/
    rm /tmp/pck.txt
else
$GRUEN && echo "Getting Kernel-Sources"
$NRML
 chroot $MNTRT /bin/bash -c "emerge -q -j$CPU gentoo-sources >/dev/null"
 LINUX="$(ls $MNTRT/usr/src/|grep linux-)"
 chroot $MNTRT /bin/bash -c "ln -s /usr/src/$LINUX /usr/src/linux"
 wget -q http://www.pilarkto.net/mirror/config-latest 
 $GELB && echo "Using Kernel Version: $(cat config-latest)" && $NRML
 cp config-latest $MNTRT/usr/src/linux/.config
 mv config-latest $MNTRT/usr/src/$LINUX-config
 #echo "to setup default settings just save the config and exit [Enter=Go on]"
 #read

$GRUEN && echo "Compiling Kernel"
$NRML
 echo -e "\t" >> $MNTRT/usr/src/menuconfig.in
 echo -e "\n" >> $MNTRT/usr/src/menuconfig.in	
 #echo -e "\n" >> $MNTRT/usr/src/menuconfig.in
 chroot $MNTRT /bin/bash -c "cd /usr/src/linux; make menuconfig KCONFIG_CONFIG=$MNTRT/usr/src/$LINUX-config < /usr/src/menuconfig.in"
$GELB && echo "Logging kernel compiling to $MNTRT/usr/src/$LINUX-compile.log"
$NRML
 chroot $MNTRT /bin/bash -c "cd /usr/src/linux; make -j$CPU all; make -j$CPU modules_install; make -j$CPU install" > $MNTRT/usr/src/$LINUX-compile.log
fi


# setting passwd
$GELB && echo "Set password:"
$NRML
if [ "$MODE" = "I" ]; then
	chroot $MNTRT /bin/passwd 
else
	echo "pilarkto" > .pw-file
	echo "pilarkto" >> .pw-file
	chroot $MNTRT /bin/passwd < .pw-file
	rm -f .pw-file
	$GELB && echo "Password set to: pilarkto"
	$NRML
fi


# base-extras (grub etc)
$GRUEN && echo "Installing grub"
$NRML
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;ABI_X86=32 emerge -q sys-boot/grub:0 >/dev/null"

# grub-config
if [ "$MODE" = "I" ]; then
	$GRUEN && echo "Configure GRUB - menu.lst (Editor: nano)  [Enter]"
	$NRML
	$EDITOR $MNTRT/boot/grub/menu.lst
elif [ "$MODE" = "Q" ]; then
	$GRUEN && echo "Configure GRUB - menu.lst"
	$NRML
	HEREP="`pwd`"
	cd $MNTRT
	KERNVER="`find boot/ |grep vmlinuz |sed 's/boot\/vmlinuz-//g'`"
	echo "title Gentoo Linux - Kernel $KERNVER" >> $MNTRT/boot/grub/menu.lst
	echo "root (hd0,0)"  >> $MNTRT/boot/grub/menu.lst
	echo "kernel /vmlinuz-$KERNVER root=$RDISK" >> $MNTRT/boot/grub/menu.lst
	sed 's/timeout 30/timeout 5/' -i $MNTRT/boot/grub/menu.lst
	cd $HEREP
fi

# fstab etc
$GRUEN && echo "Generating mtab/fstab"
$NRML
## mounts holen mit korrektem Pfad
chroot $MNTRT /bin/bash -c "cat /proc/mounts > /tmp/mounts"
# mtab
cat $MNTRT/tmp/mounts |grep -v rootfs > $MNTRT/etc/mtab
# fstab
echo "#Genrated by Gentoo installer" > $MNTRT/etc/fstab
cat $MNTRT/tmp/mounts |grep $RDISK >> $MNTRT/etc/fstab
cat $MNTRT/tmp/mounts |grep $BDISK >> $MNTRT/etc/fstab
echo "$SDISK none            swap    sw              0       0" >> $MNTRT/etc/fstab
## Anstatt fremd-kernel-config -> statische aus der source  
# devpts kann mehr als einmal vorkommen, also das letzte nehmen
#cat $MNTRT/tmp/mounts |grep devpts |tail -n 1 >> $MNTRT/etc/fstab

#grub-install
$GRUEN && echo "Installing grub to $BOOTDEV"
$NRML
# otherwise grub fails with no BIOS drive found
if [ "`cat $MNTRT/boot/grub/device.map|grep $BOOTDEV`" = "" ]; then
	echo "(hd0) $BOOTDEV" >> $MNTRT/boot/grub/device.map
fi
chroot $MNTRT /sbin/grub-install --no-floppy $BOOTDEV

# emerge sshd
$GRUEN && echo "emerge openSSHd and activate at startup"
$NRML
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge -q openssh >/dev/null"
#chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;/etc/init.d/sshd start"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;rc-update add sshd default"

# emerge eix gentoolkit and acpid
$GRUEN && echo "emerge eix, gentoolkit"
$NRML
emerge -qD --quiet-build eix gentoolkit acpid >/dev/null
$GRUEN && echo "emerge ACPId and activate at startup" >/dev/null
$NRML
emerge -qD --quiet-build acpid
chroot $MNTRT /bin/bash -c "rc-update add acpid"

$GRUEN && echo "Checking for necessary Net and Disk modules"
$NRML
# needed net drivers
lsmod|grep net|cut -d ' ' -f 1 > /tmp/netmods.lst
while read MOD
do
 echo "$MOD:"
 find $MNTRT/lib/modules/ |grep "$MOD"
 if [ $? != 0 ]; then
    $GELB && echo "module: $MOD NOT EXISTING (or compiled in kernel). Please check if module needed and if so, fix it manually"
    echo "Find following in kernel config:"
    $NRML
    cat $MNTRT/boot/config-$KERNVER |grep -i $MOD
 else
    $GRUEN && echo "OK"
    $NRML
 fi
done < /tmp/netmods.lst

# needed hdd drivers
lsmod|grep ata|cut -d ' ' -f 1 > /tmp/hddmods.lst
while read MOD
do
 echo "$MOD:"
 find $MNTRT/lib/modules/ |grep "$MOD"
 if [ $? != 0 ]; then
	$GELB && echo "module: $MOD NOT EXISTING (or compiled in kernel). Please check if module needed and if so, fix it manually"
    echo "Find following in kernel config:"
    $NRML
    cat $MNTRT/boot/config-$KERNVER |grep -i $MOD
 else
    $GRUEN && echo "OK"
    $NRML
 fi
done < /tmp/hddmods.lst

$GRUEN && echo "Installation finished. You may now check the system or reboot."
$GELB && echo "root password is pilarkto, hostname ist not yet set and keymap is set to US."
$NRML
echo "Visit Projekt-Wiki: http://wiki.open-laboratory.de/Intern:IT:HowTo:Gentoo_Install"
echo "Have fun"
$NRML
