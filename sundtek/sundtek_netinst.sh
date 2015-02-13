#!/bin/sh
#
# Copyright 2009 - 2014 Sundtek Ltd. <kontakt@sundtek.de>
#
# For use with Sundtek Devices only
#

export _LANG="EN DE"
_SIZE=58710
tmp=tmp
dialogbin=`which dialog >/dev/null 2>&1`
sttybin=`which stty >/dev/null 2>&1`
USE_CUSTOM_PATH=""
usedialog=0
softshutdown=0
NETINSTALL=1
KEEPALIVE=0
# using blacklist for opensource driver is recommended since the opensource
# driver is not stable and failed even our basic tests with a full system
# lockup
useblacklist=0

if [ -x $dialogbin ] && [ -x $sttybin ] && [ "$sttybin" != "" ] && [ "$dialogbin" != "" ]; then
  usedialog=1
  BACKTITLE="Welcome to the Sundtek Driver Installer"
  WIDTH=`stty -a | grep columns | awk 'BEGIN{FS=";"}{print $3}' | awk '{print $2}'`
  HEIGHT=`stty -a | grep rows | awk 'BEGIN{FS=";"}{print $2}' | awk '{print $2}'`
fi

busyboxfound=`ls -l /bin/ls 2>&1 | grep busybox -c`
if [ -e /bin/busybox ]; then
	busyboxfound=1;
fi

if [ "$NETINSTALL" = "1" ]; then
	if [ -e /usr/bin/wget ]; then
		WGET="wget"
	else
	   wget > /dev/null 2>&1
	   rv=$?
	   if [ "$rv" = "0" ] || [ "$rv" = "1" ]; then
		WGET="wget"
   	   else
		curl > /dev/null 2>&1
		rv=$?
		if [ "$rv" = "0" ] || [ "$rv" = "1" ] || [ "$rv" = "2" ]; then
		    WGET="curl -s -O"	
		else
	            echo "This installer requires 'curl' or 'wget' please install one of both"
		    exit 1
		fi
	   fi
	fi
fi

if [ "$busyboxfound" = "1" ] && [ "$usedialog" = "0" ]; then
	echo "Busybox installation"
fi

showdialog() {
	dialog --backtitle "$BACKTITLE" --title "Information" --msgbox "This installer will set up the latest Linux driver for Sundtek based Products\n * Sundtek MediaTV Pro (DVB-T, DVB-C, AnalogTV, FM Radio, Composite, S-Video)\n * Sundtek MediaTV Digital Home (DVB-C, DVB-T)\n * Sundtek SkyTV Ultimate (DVB-S/S2)\n * Sundtek FM Transmitter/Receiver\n * Sundtek Virtual Analog TV driver (for testing purpose)" $((HEIGHT-6)) $((WIDTH-4))
}


#if [ "$usedialog" = "1" ]; then
#  showdialog
#fi

checkperm() {
	fail=0
	idstr=$(id -u 2> /dev/null)
	if [ "$?" != "0" ]; then
	   if [ "$USER" != "root" ]; then
		   fail=1
	   fi 
	elif [ "$idstr" != "0" ]; then
	   fail=1
	fi
	if [ "$fail" = "1" ]; then
		echo "In order to install this driver please run it as root"
		echo "eg. $ sudo $0"
                echo "If you are sure that you already have root/admin permissions"
                echo "you can also try $0 -admin"
		exit 0;
	fi
}

print_help() {
echo ""
echo "Sundtek linux driver setup"
echo "(C)opyright 2008-2014 Sundtek <kontakt@sundtek.de>"
echo ""
echo "Please note it's only allowed to use this driver package with devices from"
echo "authorized distributors or from Sundtek Germany"
echo "The Virtual analogTV Grabber (vivi) might be used freely for testing purpose"
echo ""
echo "-h ... print help"
echo "-u ... uninstall driver"
echo "-e ... extract driver"
echo "-easyvdr ... install without asking"
echo "-service ... only install driver, without preload modification"
echo "-noautostart ... no autostart, eg. used for synology NAS systems"
echo "                 installer will handle it differently"
echo "-nolirc ... do not install lirc scripts"
echo "-netinst ... download driver packages from sundtek.de"
echo "-system ... override system parameter"
echo "     possible system parameters"
echo "      armsysv        ... ARM SYSV4"
echo "      armoabi        ... ARM OABI"
echo "      32bit          ... x86 32bit (newer libc)"
echo "      32bit23        ... x86 32bit (older libc)"
echo "      64bit          ... x86 64bit"
echo "      android        ... android linux"
echo "      mips           ... MIPS MIPS-I (big endian)"
echo "      openwrtmipsr2  ... MIPS MIPS32 (big endian)"
echo "      mipsel         ... MIPS MIPS32 (little endian)"
echo "      dreambox       ... MIPS MIPS32 (little endian, includes startscripts)"
echo "      mipsel2        ... MIPS MIPS-I (little endian)"
echo "      ppc32          ... PowerPC 32bit (big endian)"
echo "      ppc64          ... PowerPC 64bit (big endian)"
echo ""
echo "default operation is to install the driver"
echo "if no argument is given"
echo ""
}

remove_driver() {
	echo -n "removing driver"
	rm -rf /$tmp/.sundtek
	rm -rf /$tmp/.sundtek_install
	for i in libmediaclient.so  libmedia.so  medialib.a; do
           rm -rf /opt/lib/$i;
        done
	echo -n "."
	rm -rf /etc/udev/rules.d/80-mediasrv.rules
	rm -rf /etc/udev/rules.d/80-mediasrv-eeti.rules
	rm -rf /etc/udev/rules.d/80-remote-eeti.rules
	rm -rf /lib/udev/rules.d/80-mediasrv.rules
	rm -rf /lib/udev/rules.d/80-mediasrv-eeti.rules
	rm -rf /lib/udev/rules.d/80-remote-eeti.rules
	# this file is not deployed anymore
	if [ -f /etc/init.d/mediasrv ]; then
	  rm -rf /etc/init.d/mediasrv
	  rm -rf /etc/rc2.d/S25mediasrv
	  rm -rf /etc/rc2.d/S45mediasrv
	  rm -rf /etc/rcS.d/S45mediasrv
	  if [ -f /etc/rc.local ]; then
	    sed -i '/.*mediasrv start*$/d' /etc/rc.local
	  fi
	fi
	echo -n "."
	for i in dmx.h frontend.h mediaclient.h mediacmds.h videodev2.h; do
           rm -rf /opt/include/$i;
        done
	echo -n "."
	rm -rf /etc/ld.so.conf.d/optlib.conf
	ldconfig > /dev/null 2>&1
	echo -n "."
        for i in dvb mediaclient mediasrv sundtekremote; do
	   rm -rf /opt/bin/$i;
        done
	echo "."
	rm -rf /opt/doc/README /opt/doc/mediaclient.c /opt/doc/override.c
	rm -rf /lib/udev/rules.d/80-mediasrv-eeti.rules
	rm -rf /opt/bin/audio/libalsa.so
	rm -rf /opt/bin/audio/liboss.so
	rm -rf /opt/bin/audio/libpulse.so
	rm -rf /opt/bin/extension/librtkfm.so
	rm -rf /opt/bin/extension/librtkfmc.so
	rm -rf /opt/bin/extension/sundtek32decoder
	rm -rf /opt/bin/plugins/libencoder_plugin.so
	rm -rf /opt/doc/libmedia.pc
	rm -rf /opt/doc/sundtek_vcr_remote.conf
	rm -rf /opt/include/mcsimple.h
	rm -rf /opt/lib/libmcsimple.so
	echo "driver removed..."
	echo ""
	echo "ENGLISH:"
	echo "You might contact Sundtek about your distribution, to receive a custom driver version"
	echo "In case you do not have sufficient space in /$tmp for the driver installation please"
	echo "use our netinstaller, the netinstaller only requires around 5mb temporary space"
	echo "while the full installer which contains drivers for all architectures requires around"
	echo "50mb free temporary space"
	echo "http://sundtek.de/media/sundtek_netinst.sh"
	echo ""
	echo "DEUTSCH:"
	echo "Um einen angepassten Treiber zu erhalten kontaktieren Sie bitte Sundtek"
	echo "Sollten Sie nicht ausreichend Speicher in /$tmp zur Verfügung haben, verwenden Sie"
	echo "bitte unseren Netinstaller, dieser laedt lediglich benoetigte Dateien nach"
	echo "Der sundtek_installer_development beinhaltet Treiber fuer alle Architekturen und"
	echo "benoetigt ca. 50 MB freien Speicher in /$tmp"
	echo "http://sundtek.de/media/sundtek_netinst.sh"
	echo ""
	echo "                                         Sundtek Team"
	echo "                                         kontakt@sundtek.de"
}

uninstall_driver() {
	echo ""
	echo "Sundtek linux driver setup"
	echo ""

	if [ "$busyboxfound" = "1" ]; then
	   pid=`ps | grep mediasrv | grep grep -v | while read a b; do echo $a; done`
	else
	   pid=`ps fax | grep mediasrv | grep grep -v | while read a b; do echo $a; done`
	fi

	if [ "$softshutdown" = "1" ]; then
		if [ -e /opt/bin/mediaclient ]; then
                	/opt/bin/mediaclient --shutdown
                fi
        elif [ "$pid" != "" ]; then
		echo "stopping sundtek driver stack..."
		kill $pid > /dev/null 2>&1;
		killall -q -9 sundtekremote >/dev/null 2>&1
	fi
	echo "removing driver "
	sed -i 's#/opt/lib/libmediaclient.so ##' /etc/ld.so.preload
	echo -n "."
	if [ -f /etc/redhat-release ]; then
	   if [ -f /usr/sbin/semanage ]; then
	      if [ "`/usr/sbin/semanage fcontext  -l 2>/dev/null | grep libmediaclient -c`" = "1" ]; then
                 /usr/sbin/semanage fcontext -d -t lib_t /opt/lib/libmediaclient.so >/dev/null 2>&1
	      fi
           fi
        fi
	for i in libmediaclient.so  libmedia.so  medialib.a; do
           rm -rf /opt/lib/$i;
        done
	echo -n "."
	rm -rf /etc/udev/rules.d/80-mediasrv.rules
	rm -rf /etc/udev/rules.d/80-mediasrv-eeti.rules
	rm -rf /etc/udev/rules.d/80-remote-eeti.rules
	if [ -f /etc/init.d/mediasrv ]; then
	  rm -rf /etc/init.d/mediasrv
	  rm -rf /etc/rc2.d/S25mediasrv
	  rm -rf /etc/rc2.d/S45mediasrv
	  rm -rf /etc/rcS.d/S45mediasrv
	  if [ -f /etc/rc.local ]; then
	    sed -i '/.*mediasrv start*$/d' /etc/rc.local
	  fi
        fi
	echo -n "."
	for i in dmx.h frontend.h mediaclient.h mediacmds.h videodev2.h; do
           rm -rf /opt/include/$i;
        done
	echo -n "."
	rm -rf /etc/ld.so.conf.d/optlib.conf
	ldconfig > /dev/null 2>&1
	echo -n "."
        for i in dvb mediaclient mediasrv; do
	   rm -rf /opt/bin/$i;
        done
	echo -n "."
	rm -rf /opt/doc/README /opt/doc/mediaclient.c /opt/doc/override.c
	rm -rf /opt/doc/hardware.conf /opt/doc/lirc_install.sh /opt/doc/lircd.conf /opt/doc/sundtek.conf /opt/doc/sundtek_vdr.conf /opt/bin/getinput.sh /opt/bin/lirc.sh /opt/bin/mediarecord /opt/lib/pm/10mediasrv /etc/hal/fdi/preprobe/sundtek.fdi /usr/lib/pm-utils/sleep.d/10mediasrv
	rm -rf /lib/udev/rules.d/80-mediasrv-eeti.rules
	rm -rf /opt/bin/audio/libalsa.so
	rm -rf /opt/bin/audio/liboss.so
	rm -rf /opt/bin/audio/libpulse.so
	rm -rf /opt/bin/extension/librtkfm.so
	rm -rf /opt/bin/extension/librtkfmc.so
	rm -rf /opt/bin/extension/sundtek32decoder
	rm -rf /opt/bin/plugins/libencoder_plugin.so
	rm -rf /opt/doc/libmedia.pc
	rm -rf /opt/doc/sundtek_vcr_remote.conf
	rm -rf /opt/include/mcsimple.h
	rm -rf /opt/lib/libmcsimple.so
	rm -rf /usr/lib/systemd/system/sundtek.service
	echo -n "."
	echo ""
	echo "driver successfully removed from system"
	echo ""
}

extract_driver() {
	echo "Extracting driver ..."
	app=$0
        dd if=${app} of=installer.tar.gz skip=1 bs=${_SIZE} 2> /dev/null

        if [ ! -f installer.tar.gz ]; then
           sed '1,1615d' ${app} > /tmp/.sundtek/installer.tar.gz
        fi

	if [ "$busyboxfound" = "1" ]; then
		tar xzf installer.tar.gz 2>/dev/null 1>/dev/null
		if [ "$?" = "1" ]; then
			gzip -d installer.tar.gz
			if [ "$?" != "0" ]; then
				echo "Extracting driver failed..."
				exit 1
			fi
			tar xf installer.tar
			if [ "$?" != "0" ]; then
				echo "Extracting driver failed..."
				exit 1
			fi
		fi
	else
		tar xzmf installer.tar.gz 2>/dev/null 1>/dev/null
		if [ "$?" != "0" ]; then
			echo "Extracting driver failed..."
			exit 1
		fi
	fi
	echo "done."
}

modt() {
	echo ""
	echo "Welcome to the Sundtek linux / freebsd driver setup"
	echo "(C)opyright 2008-2014 Sundtek <kontakt@sundtek.de>"
	echo ""
	for lang in $_LANG; do
	  if [ "$lang" = "EN" ]; then
	    echo "Legal notice:"
	    echo "This software comes without any warranty, use it at your own risk"
	    echo ""
	    echo "Please note it's only allowed to use this driver package with devices from"
	    echo "authorized distributors or from Sundtek Germany"
	    echo "The Virtual analogTV Grabber (vivi) might be used freely for testing purpose"
	    echo ""
	    echo "Do you want to continue [Y/N]:"
  	  elif [ "$lang" = "DE" ]; then
	    echo "Nutzungsbedingungen:"
	    echo "Sundtek übernimmt keinerlei Haftung für Schäden welche eventuell durch"
	    echo "das System oder die angebotenen Dateien entstehen können."
	    echo ""
	    echo "Dieses Softwarepaket darf ausschließlich mit Geraeten von authorisierten"
	    echo "Distributoren oder Sundtek Deutschland verwendet werden"
	    echo "Der Virtuelle AnalogTV Treiber (vivi) kann für Testzwecke ohne jegliche"
	    echo "Restriktionen verwendet werden"
	    echo ""
  	    echo "Wollen Sie fortfahren [J/N]:"
	  fi
	done
        if [ "$AUTO_INST" = "1" ]; then
		echo "AUTO_INST is set"
		key="Y";
	else   
		read key
	fi
	if [ "$key" != "Y" ] && [ "$key" != "J" ] && [ "$key" != "j" ] && [ "$key" != "y" ]; then
	  for lang in $_LANG; do
	    if [ "$lang" = "EN" ]; then
		echo "Installation aborted..."
  	    elif [ "$lang" = "DE" ]; then
		echo "Installation abgebrochen..."
	    fi
  	    exit
	  done
	fi
}

install_bsd_driver() {
	if [ ! -e /usr/local/bin/wget ]; then
		echo "This installer requires wget"
		echo ""
		echo "pkg install wget"
	fi
	modt
	app=$0
	if [ -d /$tmp/.sundtek ]; then
		rm -rf /$tmp/.sundtek
		if [ -e /$tmp/.sundtek ]; then
			echo "please remove /$tmp/.sundtek manually and retry the installation"
			exit 1;
		fi
	fi
 
 	rm -rf /$tmp/.sundtek
	mkdir -p /$tmp/.sundtek

	dd if=${app} of=/$tmp/.sundtek/installer.tar.gz skip=1 bs=${_SIZE} 2> /dev/null
        if [ ! -f /$tmp/.sundtek/installer.tar.gz ]; then
           echo "extracting..."
           sed '1,1346d' ${app} > /$tmp/.sundtek/installer.tar.gz
        fi

	cd /$tmp/.sundtek
	if [ "$busyboxfound" = "1" ]; then
		tar xzf installer.tar.gz 2>/dev/null 1>/dev/null
		if [ "$?" = "1" ]; then
			gzip -d installer.tar.gz
			tar xf installer.tar
		fi
	else
		tar xzmf installer.tar.gz 2>/dev/null 1>/dev/null
	fi
	echo "FreeBSD Installer ...."
	/$tmp/.sundtek/chk64bit_fbsd 1>/dev/null 2>&1
	if [ "$?" = "0" ]; then
		echo "64bit FreeBSD Detected"
		mkdir -p /$tmp/.sundtek/64bit_fbsd
		cd /$tmp/.sundtek/64bit_fbsd
		echo "Downloading driver"
		wget http://sundtek.de/media/netinst/64bit_FreeBSD/installer.tar.gz
		cd /
		echo "Deploying driver in /opt/bin"
		tar xvzf /$tmp/.sundtek/64bit_fbsd/installer.tar.gz
		echo "done."
	fi
	
}

install_driver() {
	if [ -e /etc/issue ]; then
		qnapcnt=`grep -c QNAP /etc/issue`
		if [ "$qnapcnt" = "1" ] && [ -e /etc/config/Model_Name.conf ] && [ "$USE_CUSTOM_PATH" = "" ]; then
			echo "Please use the QNAP QPKG Installer via Webinterface on your NAS"
			echo ""
			echo "See:"
			echo "http://forum.qnap.com/viewtopic.php?f=276&t=57049"
			echo "http://support.sundtek.com/index.php/topic,1573.0.html"
			exit 0;
		fi
	fi
	if [ -e /etc/synoinfo.conf ] && [ "$USE_CUSTOM_PATH" = "" ]; then
	       echo ""
	       echo "Please use the synology web-installer"
               echo ""
	       echo "http://sundtek.de/synology"
	       exit
	fi
	if [ -e /raid/data/module/cfg/module.db ] && [ "$USE_CUSTOM_PATH" = "" ]; then
		echo ""
		echo "Please use the Thecus Installer package"
		echo ""
		echo "http://support.sundtek.com/index.php/board,6.0.html"
		echo ""
		echo "Look at Linux drivers, Thecus NAS"
		exit
	fi

	modt

	if [ "$USE_CUSTOM_PATH" != "" ] && [ ! -e $USE_CUSTOM_PATH ]; then
		echo "Creating $USE_CUSTOM_PATH"
		mkdir -p $USE_CUSTOM_PATH
		if [ "$?" != "0" ]; then
			echo "unable to create $USE_CUSTOM_PATH"
		fi
	fi

	if [ -f /etc/environment ]; then
	  if [ "`grep -c /opt/bin /etc/environment`" = "0" ]; then
		echo "adding /opt/bin to environment paths"
		sed -i 's#\(PATH.*\)\"$#\1:/opt/bin\"#g' /etc/environment > /dev/null 2>&1
	  fi
	fi
	
	if [ -f /etc/ld.so.preload ]; then
	  sed -i 's#/opt/lib/libmediaclient.so ##g' /etc/ld.so.preload
	  sed -i 's#/opt/lib/libmediaclient.so##g' /etc/ld.so.preload
	  rm -rf /opt/lib/libmediaclient.so
        fi

	if [ -f /etc/group ]; then
	  if [ "`grep -c ^audio:x /etc/group`" = "1" ]; then
             if [ "`grep  ^audio:x /etc/group | grep root -c`" = "0" ]; then
		echo "adding administrator to audio group for playback..."
		sed -i 's#\(^audio:x\:[0-9]*\:\)#\1root,#g' /etc/group
	     fi; 
	  fi;
        fi;

	app=$0
	if [ "$KEEPALIVE" = "0" ]; then
	  if [ "$busyboxfound" = "1" ]; then
	     pid=`ps | grep mediasrv | grep grep -v | while read a b; do echo $a; done`
          else
	     pid=`ps fax | grep mediasrv | grep grep -v | while read a b; do echo $a; done`
          fi
 
	  if [ "$softshutdown" = "1" ]; then
		if [ -e /opt/bin/mediaclient ]; then
                	/opt/bin/mediaclient --shutdown
                fi
	  elif [ "$pid" != "" ]; then
		echo "stopping old driver instance..."
		kill $pid > /dev/null 2>&1;
		killall -q -9 sundtekremote >/dev/null  2>&1
	  fi
        else
          echo "not stopping driver"
        fi
	echo "unpacking..."

	# in order to satisfy linux magazine writers who need a few more lessions in secure bash
	# scripting, by far there have been other more important parts than an already existing
        # /$tmp/chk64/etc binary.
  

	if [ -d /$tmp/.sundtek ]; then
		rm -rf /$tmp/.sundtek
		if [ -e /$tmp/.sundtek ]; then
			echo "please remove /$tmp/.sundtek manually and retry the installation"
			exit 1;
		fi
	fi
 
	mkdir -p /$tmp/.sundtek

	dd if=${app} of=/$tmp/.sundtek/installer.tar.gz skip=1 bs=${_SIZE} 2> /dev/null
        if [ ! -f /$tmp/.sundtek/installer.tar.gz ]; then
           echo "extracting..."
           sed '1,1346d' ${app} > /$tmp/.sundtek/installer.tar.gz
        fi

	cd /$tmp/.sundtek
	if [ "$busyboxfound" = "1" ]; then
		tar xzf installer.tar.gz 2>/dev/null 1>/dev/null
		if [ "$?" = "1" ]; then
			gzip -d installer.tar.gz
			tar xf installer.tar
		fi
	else
		tar xzmf installer.tar.gz 2>/dev/null 1>/dev/null
	fi
	
	echo -n "checking system... "
	unamer=`uname -r`
        dm500hd=`echo $unamer | grep -c 'dm500hd$'`
        dm800=`echo $unamer | grep -c 'dm800$'`
        dm800se=`echo $unamer | grep -c 'dm800se$'`
	dm7020=`echo $unamer | grep -c 'dm7020hd$'`
	dm7080=`echo $unamer | grep -c 'dm7080hd$'`
	if [ "$dm7080" = "0" ]; then
	    dm7080=`echo $unamer | grep -c 'dm7080$'`
	fi
        dm8000=`echo $unamer | grep -c 'dm8000$'`
	vusolo1=`uname -a | grep "vusolo 2.6.18-7.3 " -c`
	vusolo2=`grep Brcm4380 /proc/cpuinfo -c`
	if [ -e /proc/stb/info/model ] && [ "$dm800se" = "0" ]; then
		dm800se=`grep -c dm800sev2 /proc/stb/info/model`
        fi
	azbox=0
	if [ -e /proc/stb/info/azmodel ]; then
		azbox=1
	fi
	tardereference=`tar --help 2>&1 | grep dereference -c`
	tvh64=0
	if [ "$tardereference" != "0" ]; then
		tarflag=" -h"
	else
		tarflag=""
	fi
	if [ "$vusolo1" = "1" ] && [ "$vusolo2" = "1" ]; then
	   vusolo=1
        else
           vusolo=0
        fi
	if [ -e /proc/stb/info/vumodel ]; then
           vusolo=1 # it doesn't matter, vu is a settopbox and the driver
                    # takes care about the rest. just install the correct
                    # package
        fi
	if [ -e /proc/stb/info/boxtype ]; then
	   gigablue=`grep -c gigablue /proc/stb/info/boxtype`;
	else
	   gigablue=0
	fi


        ctversion=0
	if [ -e /proc/stb/info/version ]; then
		ctversion=`cat /proc/stb/info/version`;
        fi

        ctet9000=0

	if [ -e /proc/stb/lcd/scroll_delay ] && [ "$ctversion" = "2" ] && [ "`grep -c BCM97xxx /proc/cpuinfo`" = "1" ]; then
		ctet9000=1
	fi

	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et9000 /proc/stb/info/boxtype`" = "1" ]; then
		ctet9000=1
	fi

	ctet8000=0

	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et8000 /proc/stb/info/boxtype`" = "1" ]; then
		ctet8000=1
	fi
	ctet5000=0

	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et5000 /proc/stb/info/boxtype`" = "1" ]; then
        	ctet5000=1;
        fi
	
	ctet6000=0

	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et6000 /proc/stb/info/boxtype`" = "1" ]; then
        	ctet6000=1;
        fi
	
	ctet10000=0

	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et10000 /proc/stb/info/boxtype`" = "1" ]; then
        	ctet10000=1;
        fi

	ctet4x00=0
	if [ -e /proc/stb/info/boxtype ] && [ "`grep -c et4000 /proc/stb/info/boxtype`" = "1" ]; then
        	ctet4x00=1;
        fi
	         
        # should more be like openwrt installer on wndr3700
	wndr3700=`grep -c 'NETGEAR WNDR3700$' /proc/cpuinfo`
	tplink=`grep -c 'Atheros AR9132 rev 2' /proc/cpuinfo`
        ddwrt=`grep -c dd-wrt /proc/version`
        atheros=`grep -c "Atheros AR7161 rev 2" /proc/cpuinfo`
        dockstar=`grep -c "ARM926EJ-S" /proc/cpuinfo`
	synology=`grep -c "Synology" /proc/cpuinfo`
	if [ "$synology" = "0" ]; then
 	  synology=`uname -a | grep -i synology -c`
        fi
	if [ -e /etc/synoinfo.conf ]; then
	  synology=1
	fi
	sedver=`sed --version | grep "GNU sed version" -c 2>/dev/null >/dev/null`
	driverinstalled=`grep -c mediaclient /etc/rc.local 2>/dev/null >/dev/null`
	if [ "`grep -c 'VIA Samuel 2' /proc/cpuinfo`" = "1" ] && [ "`grep -c 'CentaurHauls' /proc/cpuinfo`" = "1" ]; then
		c3="1"
	else
		c3="0"
	fi
	   
        if [ "$dockstar" != "0" ]; then
	    if [ -e /usr/local/cloudengines/hbplug.conf ]; then
               touch /dev/.testfile >/dev/null 2>&1
               if [ ! -e /dev/.testfile ]; then
                    dockstar=1; # remains 1
               else
                    dockstar=0;
               fi
            else
               dockstar=0;
            fi
        fi
	if [ "$ddwrt" = "1" ] && [ "$atheros" = "1" ]; then
		ddwrtwndr3700=1;
        else
                ddwrtwndr3700=0;
        fi
	arm=`file /bin/ls 2>/dev/null | grep -c 'ARM'`

	# Dreambox dm800(0)
        # http://www.i-have-a-dreambox.com/wbb2/thread.php?threadid=135273
        #
	if [ "$SYSTEM" != "" ]; then
	        echo "overriding SYSTEM parameter with $SYSTEM"
	elif [ "$gigablue" = "1" ]; then
		echo "Gigablue detected"
		SYSTEM="mipsel2"
	elif [ "$azbox" = "1" ]; then
		echo "Azbox detected"
		SYSTEM="mipsel2"
	elif [ "$vusolo" = "1" ]; then
		echo "VU+ Solo detected"
		SYSTEM="mipsel2"
        elif [ "$ctet9000" = "1" ]; then
                echo "Clarke Tech ET9000 detected"
		SYSTEM="mipsel2"
	elif [ "$ctet4x00" = "1" ]; then
		echo "Clarke Tech ET4000 detected"
		SYSTEM="mipsel2"
	elif [ "$ctet8000" = "1" ]; then
		SYSTEM="mipsel2"
		echo "Clarke Tech ET8000 detected"
	elif [ "$ctet5000" = "1" ]; then
		SYSTEM="mipsel2"
		echo "Clarke Tech ET5000 detected"
	elif [ "$ctet6000" = "1" ]; then
		SYSTEM="mipsel2"
		echo "Clarke Tech ET6000 detected"
	elif [ "$ctet10000" = "1" ]; then
		SYSTEM="mipsel2"
		echo "Clarke Tech ET10000 detected"
        elif [ "$dm7020" = "1" ]; then
                echo "Dreambox 7020HD detected"
		SYSTEM="dreambox"
	elif [ "$dm7080" = "1" ]; then
		echo "Dreambox 7080HD detected"
		SYSTEM="dreambox"
	elif [ "$dm8000" = "1" ]; then
		echo "Dreambox 8000 detected"
		kver=`uname -r`
		if [ "`echo $kver | grep -c 'dm'`" = "1" ]; then
		    echo "Kernel is supported"
                    SYSTEM="dreambox"
		else
		    echo "This is an unsupported dreambox version, please send an email to kontakt@sundtek.de"
		    echo "pointing out that your system kernel uses $kver"
		    remove_driver
		    exit 1;
		fi
        elif [ "$dockstar" = "1" ]; then
                echo "Dockstar like system detected"
		SYSTEM="armsysv"
	elif [ "$dm800" = "1" ] || [ "$dm800se" = "1" ] || [ "$dm7020" = "1" ]; then
		echo "Dreambox 800/800se detected"
		kver=`uname -r`
		if [ -e /usr/sundtek/usbkhelper-dm800.ko ]; then
			rm -rf /usr/sundtek/usbkhelper*;
		fi
		if [ -e /etc/image-version ] && [ "`grep -c 'version=1openpli' /etc/image-version`" = "1" ]; then
                    SYSTEM="mipsel2"
		elif [ "`echo $kver | grep -c 'dm'`" = "1" ]; then
		    echo "Kernel is supported"
                    SYSTEM="dreambox"
		else
		    echo "This is an unsupported dreambox version, please send an email to kontakt@sundtek.de"
		    echo "pointing out that your system kernel uses $kver"
		    remove_driver
		    exit 1;
		fi
        elif [ "$dm500hd" = "1" ]; then
                echo "Dreambox 500hd detected"
		#delete old modules
		if [ -e /usr/sundtek/usbkhelper-dm800.ko ]; then
			rm -rf /usr/sundtek/usbkhelper*;
		fi
                SYSTEM="dreambox"
        elif [ "$wndr3700" = "1" ]; then
		echo "Netgear WNDR3700 detected"
		SYSTEM="openwrtmipsr2"
		if [ -e /bin/opkg ] && [ "`opkg list libpthread | wc -l`" = "0" ]; then
			echo "running opkg update"
			opkg update
			echo "installing libpthread"
			opkg install libpthread
			opkg install librt
		fi	
        elif [ "$ddwrtwndr3700" = "1" ]; then
                echo "Netgear WNDR3700 (DD-WRT) detected"
                SYSTEM="openwrtmipsr2"
	elif [ "$c3" = "1" ]; then
		echo "Via C3 detected"
		SYSTEM="c3"
	else
           CHK64=-1
	   if [ "$arm" = "0" ]; then
	     /$tmp/.sundtek/chk64bit 1>/dev/null 2>&1
             CHK64=$?
#	     echo "CHECKED 64bit: $CHK64"
             if [ "$CHK64" = "0" ]; then
		if [ "$synology" = "1" ]; then
		     if [ -e /usr/local/tvheadend/bin/tvheadend ] || [ -e /usr/local/tvheadend-testing/bin/tvheadend ] || [ -e /var/packages/DVBLinkServer/target/dvblink_server ]; then
			  /$tmp/.sundtek/chk32bit23 -a
			  if [ "$?" = "0" ]; then
				/$tmp/.sundtek/chk32bit23 -elfhdr /bin/ls
				basesys=$?
				if [ -e /var/packages/DVBLinkServer/target/dvblink_server ]; then
				  /$tmp/.sundtek/chk32bit23 -elfhdr /var/packages/DVBLinkServer/target/dvblink_server
				fi

				if [ "$?" = "1" ] && [ "$basesys" = "0" ]; then
					echo ""
					echo "Your base system is 32bit (busybox), but you installed 64bit dvblink_server"
					echo ""
					tvh64=1
				fi
				  
				if [ -e /usr/local/tvheadend/bin/tvheadend ]; then
				  /$tmp/.sundtek/chk32bit23 -elfhdr /usr/local/tvheadend/bin/tvheadend
				fi

				if [ "$?" = "1" ] && [ "$basesys" = "0" ]; then
					echo ""
					echo "Your base system is 32bit (busybox), but you installed 64bit tvheadend"
					echo ""
					tvh64=1
				fi

				if [ -e /usr/local/tvheadend-testing/bin/tvheadend ]; then
			 	  /$tmp/.sundtek/chk32bit23 -elfhdr /usr/local/tvheadend-testing/bin/tvheadend
				fi

				if [ "$?" = "1" ] && [ "$basesys" = "0" ]; then
					echo ""
					echo "Your base system is 32bit (busybox), but you installed 64bit tvheadend"
					echo ""
					tvh64=1
				fi
			  fi
		     fi
		fi
		/$tmp/.sundtek/chk64bit -b 1>/dev/null 2>&1
                if [ "$?" = "1" ] && [ "$tvh64" = "0" ]; then
                    CHK64=-1
                else
                    CHK64=0
                fi
             fi
	   fi
	   if [ "$CHK64" = "0" ] && [ "$arm" = "0" ]; then
		   if [ "$tvh64" = "0" ]; then
	           	/$tmp/.sundtek/chk64bit -a
  	  	   	if [ "$?" != "0" ]; then
				remove_driver
				exit 1;
		   	fi
	   	   fi
	 	   echo "64Bit System detected"
		   SYSTEM="64bit"
	   else
             if [ "$arm" = "0" ]; then
	       /$tmp/.sundtek/chk32bit 1>/dev/null 2>&1
	     fi
	     if [ "$?" = "0" ] && [ "$arm" = "0" ]; then
                geode=0
                if [ -e /proc/cpuinfo ]; then
                   geode=`grep -c 'Geode(TM) Integrated Processor by AMD PCS' /proc/cpuinfo`
		   if [ "$geode" != "0" ]; then
                          echo "Found AMD Geode (using non optimized driver)"
                   fi
                   #Geode has no SSE2 instructions
                fi
	        /$tmp/.sundtek/chk32bit -a
		if [ "$?" != "0" ] || [ "$geode" = "1" ]; then
			/$tmp/.sundtek/chk32bit23 1>/dev/null 
			if [ "$?" = "0" ]; then
                           echo -n "checking older libc version... "
                           /$tmp/.sundtek/chk32bit23 -a
                           if [ "$?" != "0" ]; then
			       remove_driver
			       exit 1;
			   else
			       echo "32Bit System detected (libc2.3)"
                               SYSTEM="32bit23"
                           fi
                        else
			   remove_driver
			   exit 1;
                        fi
	        else
	 	        echo "32Bit System detected"
		        SYSTEM="32bit"
		fi
	     else
		if [ "$arm" = "0" ]; then
		    /$tmp/.sundtek/chkppc32 1>/dev/null 2>&1
		fi
		if [ "$?" = "0" ] && [ "$arm" = "0" ]; then
		    /$tmp/.sundtek/chkppc32 -a
		    if [ "$?" != "0" ]; then
			remove_driver
			exit 1;
		    fi
		    echo "PPC32 System detected"
                    SYSTEM="ppc32"
                else
                  if [ -e /lib/ld-linux-armhf.so.3 ]; then
	            if [ ! -e /lib/ld-linux.so.3 ]; then
		        ln -s /lib/ld-linux-armhf.so.3 /lib/ld-linux.so.3
	            fi
                    /$tmp/.sundtek/chkarmsysvhf 1>/dev/null 2>&1
                    if [ "$?" != "0" ]; then
                        remove_driver
                        exit 1;
                    fi
                    echo "ARM SYSV HF System detected"
                    SYSTEM="armsysvhf"
		  else
                    /$tmp/.sundtek/chkarmsysv 1>/dev/null 2>&1
                    if [ "$?" = "0" ]; then
		       if [ ! -e /etc/WiAutoConfig.conf ]; then
                         
                          /$tmp/.sundtek/chkarmsysv -a
		       fi
		       if [ "$?" != "0" ]; then
			  remove_driver
			  exit 1;
		       fi
		       if [ "$synology" = "1" ]; then
		          echo "Synology NAS Detected"
		       else
                          echo "ARM SYSV System detected"
		       fi
                       SYSTEM="armsysv"
                    else
		       /$tmp/.sundtek/chkarmoabi 1>/dev/null 2>&1
		       if [ "$?" = "0" ]; then
		          /$tmp/.sundtek/chkarmoabi -a
		          if [ "$?" != "0" ]; then
			     remove_driver
			     exit 1;
		          fi
                          echo "ARM OABI System detected"
                          SYSTEM="armoabi"
                       else
		          /$tmp/.sundtek/chkmips 1>/dev/null 2>&1
			  if [ "$?" = "0" ]; then
		              /$tmp/.sundtek/chkmips -a
		              if [ "$?" != "0" ]; then
			        remove_driver
			        exit 1;
		              fi
			      echo "MIPS System detected"
                              SYSTEM="mips"
                          else
			     /$tmp/.sundtek/chkmipsel 1>/dev/null 2>&1
			     if [ "$?" = "0" ]; then
                                /$tmp/.sundtek/chkmipsel -a
                                if [ "$?" != "0" ]; then
                                    remove_driver
                                    exit 1;
                                fi
				if [ -e /dev/misc/vtuner0 ]; then
				    echo "MIPS STB (little endian) detected"
				    SYSTEM="mipsel2"
				else
                                    echo "MIPSel (little endian) detected"
                                    SYSTEM="mipsel"
				fi
				if [ `grep -c Brcm /proc/cpuinfo` -gt 0 ]; then
					SYSTEM="mipsel2"
				fi
                             else
		                /$tmp/.sundtek/chkppc64 1>/dev/null 2>&1
 			        if [ "$?" = "0" ]; then
		                   /$tmp/.sundtek/chkppc64 -a
		                   if [ "$?" != "0" ]; then
	 	 	               remove_driver
			               exit 1;
		                   fi
		                   echo "PPC64 System detected"
                                   SYSTEM="ppc64"
                                else
                                   /$tmp/.sundtek/chkmipsel2 1>/dev/null 2>&1
                                   if [ "$?" = "0" ]; then
                                      /$tmp/.sundtek/chkmipsel2 -a
                                      if [ "$?" != "0" ]; then
                                         remove_driver
                                         exit 1;
                                      fi
                                      echo "MIPSel (old libc) System detected"
				      SYSTEM="mipsel2"
                                   else
                                      /$tmp/.sundtek/chkopenwrtmipsr2 0.9.33 1>/dev/null 2>&1
                                      if [ "$?" = "0" ]; then
                                         /$tmp/.sundtek/chkopenwrtmipsr2 -a
                                         if [ "$?" != "0" ]; then
					     remove_driver
					     exit 1;
					 fi
					 if [ -e /var/flash/ar7.cfg ]; then
                                             echo "Fritzbox detected"
                                         else
					     echo "OpenWRT MipsR3 (0.9.33) detected"
                                         fi
					 SYSTEM="openwrtmipsr3"
					 if [ -e /bin/opkg ]; then
		                           if [ "`opkg list librt | wc -l`" = "0" ] || [ "`opkg list libpthread | wc -l`" = "0" ]; then
					     echo "running opkg update"
					     opkg update
				           fi
		                           if [ "`opkg list libpthread | wc -l`" = "0" ]; then
					     echo "installing libpthread"
					     opkg install libpthread
					   fi	
		                           if [ "`opkg list librt | wc -l`" = "0" ]; then
					     echo "installing librt"
					     opkg install librt
					   fi	
				         fi
				      else
					 /$tmp/.sundtek/chkopenwrtmipsr2 1>/dev/null 2>&1
                                         if [ "$?" = "0" ]; then
                                           /$tmp/.sundtek/chkopenwrtmipsr2 -a
                                           if [ "$?" != "0" ]; then
					     remove_driver
					     exit 1;
				  	   fi
					   if [ -e /var/flash/ar7.cfg ]; then
                                             echo "Fritzbox detected"
                                           else
					     echo "OpenWRT MipsR2 detected"
                                           fi
					   SYSTEM="openwrtmipsr3"
					   if [ -e /bin/opkg ]; then
		                             if [ "`opkg list librt | wc -l`" = "0" ] || [ "`opkg list libpthread | wc -l`" = "0" ]; then
					       echo "running opkg update"
					       opkg update
				             fi
		                             if [ "`opkg list libpthread | wc -l`" = "0" ]; then
					       echo "installing libpthread"
					       opkg install libpthread
					     fi	
		                             if [ "`opkg list librt | wc -l`" = "0" ]; then
					       echo "installing librt"
					       opkg install librt
					     fi	
				           fi
					 else
					   /$tmp/.sundtek/chkmipselbcm 1>/dev/null 2>&1
					   if [ "$?" = "0" ]; then
                                              /$tmp/.sundtek/chkmipselbcm -a
                                              if [ "$?" != "0" ]; then
                                                remove_driver
                                                exit 1;
                                              fi
                                              echo  "MIPS BCM detected"
                                              SYSTEM="mipselbcm"
                                           else
				            /$tmp/.sundtek/chksh4 1>/dev/null 2>&1
					    if [ "$?" = "0" ]; then
						/$tmp/.sundtek/chksh4 -a
						if [ "$?" != "0" ]; then
						    remove_driver
						    exit 1;
						fi
						echo "SH4 detected"
						SYSTEM="sh4"
					    else
						/$tmp/.sundtek/chkopenwrtarm4 1>/dev/null 2>&1
						if [ "$?" = "0" ]; then
					           brcarm=`uname -a | grep brcmarm -c`
						   /$tmp/.sundtek/chkopenwrtarm4 -a
						   if [ "$?" != "0" ]; then
						        remove_driver
							exit 1;
						   fi
						   if [ "$brcarm" = "1" ]; then
							   echo "using new ARM4 SYSV uClibc toolchain"
							   SYSTEM="arm4uclibc"
					           else
						           echo "ARM4 SYSV uClibc detected"
						           SYSTEM="openwrtarm4"
					           fi
						else
						   /$tmp/.sundtek/chkopenwrtppc32 1>/dev/null 2>&1
						   if [ "$?" = "0" ]; then
					             /$tmp/.sundtek/chkopenwrtppc32 -a
						     if [ "$?" != "0" ]; then
						         remove_driver
							 exit 1;
						     fi
						     if [ -e /bin/opkg ]; then
						       if [ "`opkg list librt | wc -l`" = "0" ] || [ "`opkg list libpthread | wc -l`" = "0" ]; then
						         echo "running opkg update"
						         opkg update
						       fi
						       if [ "`opkg list libpthread | wc -l`" = "0" ]; then
					  	         echo "installing libpthread"
						         opkg install libpthread
						       fi	
						       if [ "`opkg list librt | wc -l`" = "0" ]; then
						         echo "installing librt"
						         opkg install librt
						       fi	
						     fi
						     echo "OpenWRT PPC detected"
						     SYSTEM="openwrtppc32"
						   else
		                                     echo "Your system is currently unsupported"
						     echo ""
						     echo "also check that this installer is not corrupted due a bad download"
						     echo "/$tmp must not be mounted with noexec flag, otherwise the installer"
						     echo "won't work"
						     echo ""
						     echo "In case you do not have enough free space on your system you might"
						     echo "use the network installer"
						     echo "http://sundtek.de/media/sundtek_netinst.sh"
						     echo ""
		                                     echo "in case your system is really unsupported please contact"
						     echo "our support via mail <kontakt@sundtek.de>"
		                                     echo ""
			                             remove_driver
		                                     exit 0
						   fi
					        fi
				              fi
					    fi
                                         fi
                                      fi
                                   fi
                                fi
                             fi
                          fi
                       fi
                     fi
		  fi
                fi
             fi
	  fi
	fi
	if [ "$NETINSTALL" = "1" ]; then
	   echo "installing (netinstall mode) ..."
	   if [ "$SYSTEM" = "" ]; then
		   echo "unable to detect architecture.."
		   echo "please contact us via email kontakt@sundtek.de"
		   # report a failed installation.. this should never happen 
		   # if it happens report it back. 
		   $WGET http://sundtek.de/support/failed.phtml
		   exit 1
	   fi
		   
	   mkdir /$tmp/.sundtek/$SYSTEM
	   cd /$tmp/.sundtek/$SYSTEM
	   echo "Downloading architecture specific driver ... $SYSTEM"
	   $WGET http://www.sundtek.de/media/netinst/$SYSTEM/installer.tar.gz > /dev/null 2>&1
	   if [ "$?" != "0" ] || [ ! -e "installer.tar.gz" ]; then
		echo "unable to download $SYSTEM drivers"
		exit 1
	   fi
	   echo "Download finished, installing now ..."
	else
	   echo "installing (local mode) ..."
	fi
        if [ "$USE_CUSTOM_PATH" = "" ]; then
	  mkdir -p /opt/bin >/dev/null 2>&1
	  if [ -d /opt/bin ]; then
		USE_TMP=0
		mkdir -p /opt/include > /dev/null 2>&1
		if [ -d /opt/include ]; then
			USE_TMP=0
		else
			echo "Trying to use /$tmp/opt/bin for driver installation"
			echo "please note this installation will only be temporary"
			echo "since we don't have write access to /opt/bin"
			USE_TMP=1
		fi
	  else
		echo "Trying to use /$tmp/opt/bin for driver installation"
		echo "please note this installation will only be temporary"
		echo "since we don't have write access to /opt/bin"
		USE_TMP=1
 	  fi
        fi
	if [ "$vusolo" = "1" ] || [ "$ctet9000" = "1" ] || [ "$ctet5000" = "1" ] || [ "$ctet6000" = "1" ] || [ "$ctet8000" = "1" ] || [ "$ctet4x00" = "1" ] || [ "$ctet10000" = "1" ]; then
          cd /
          tar xzf /$tmp/.sundtek/mipsel2/installer.tar.gz
        elif [ "$dm8000" = "1" ] || [ "$dm800" = "1" ] || [ "$dm500hd" = "1" ] || [ "$dm800se" = "1" ] || [ "$dm7020" = "1" ] || [ "$dm7080" = "1" ] || [ `grep -c Brcm /proc/cpuinfo` -gt 0 ]; then
	  echo "Using /dev/misc/vtuner0 interface"
	  if [ ! -e /usr/sundtek/mediasrv ] && [ `df -P | grep root | awk '{print $4}'` -lt 5000 ]; then
	     if [ `df -P | grep '/usr$' -c` -eq 1 ] && [ `df -P | grep '/usr$' | awk '{print $4}'` -gt 5000 ]; then
	       echo "root / doesn't seem to have enough space,"
	       echo "although /usr has .. OK"
             else
	       echo "Not enough free space"
	       if [ `df -P | grep /media/hdd -c` -gt 0 ] && [ `df -P | grep /media/hdd | awk '{print $4}'` -gt 5000 ]; then
	 	 echo "using /media/hdd for driver installation"
		 if [ ! -e /usr/sundtek ]; then
		     mkdir /usr/sundtek
	         fi
		 if [ "`mount | grep sundtek -c`" = "0" ]; then
		   echo "mounting driver loopback"
		   mkdir -p /media/hdd/sundtek
		   mount -obind /media/hdd/sundtek /usr/sundtek
		 fi
	       else
		 echo "not enough space available for driver installation, you might contact kontakt@sundtek.de"
	       fi
	     fi
	  else
	      echo "Default installation"
	  fi
	  cd /
	  tar ${tarflag}xzf /$tmp/.sundtek/$SYSTEM/installer.tar.gz
	elif [ "$USE_CUSTOM_PATH" != "" ]; then
	  cd $USE_CUSTOM_PATH
	  tar xzf /$tmp/.sundtek/$SYSTEM/installer.tar.gz >/dev/null 2>&1
	  if [ "$?" = "1" ]; then
		  cd /$tmp/.sundtek/$SYSTEM
		  gzip -d installer.tar.gz
		  cd $USE_CUSTOM_PATH
		  tar ${tarflag}xf /$tmp/.sundtek/$SYSTEM/installer.tar
          fi
	  if [ "$synology" = "1" ]; then
	     if [ -e /var/packages/tvheadend/scripts/start-stop-status ]; then
		     echo "adding libmediaclient to tvheadend start script"
		     sed -i 's#LD_PRELOAD=/opt/lib/libmediaclient.so ##g' /var/packages/tvheadend/scripts/start-stop-status
		     if [ "`grep -c libmediaclient.so /var/packages/tvheadend/scripts/start-stop-status`" = "0" ]; then
		        sed -i 's#^    ${TVHEADEND}#    LD_PRELOAD=/var/packages/sundtek/target/opt/lib/libmediaclient.so ${TVHEADEND}#g' /var/packages/tvheadend/scripts/start-stop-status
		        sed -i 's#su - ${RUNAS} -c "${TVHEADEND}#su - ${RUNAS} -c "LD_PRELOAD=/var/packages/sundtek/target/opt/lib/libmediaclient.so ${TVHEADEND}#g' /var/packages/tvheadend/scripts/start-stop-status
                     fi
	     fi
	     if [ -e /var/packages/tvheadend ]; then
		     echo "setting up tvheadend autorestart in /etc/sundtek.conf"
		     echo "device_attach=/var/packages/tvheadend/scripts/start-stop-status restart" > /etc/sundtek.conf
             fi
	     if [ -e /var/packages/tvheadend-testing/scripts/start-stop-status ]; then
		     echo "adding libmediaclient to tvheadend start script"
		     sed -i 's#LD_PRELOAD=/opt/lib/libmediaclient.so ##g' /var/packages/tvheadend-testing/scripts/start-stop-status
		     if [ "`grep -c libmediaclient.so /var/packages/tvheadend-testing/scripts/start-stop-status`" = "0" ]; then
		        sed -i 's#^    ${TVHEADEND}#    LD_PRELOAD=/var/packages/sundtek/target/opt/lib/libmediaclient.so ${TVHEADEND}#g' /var/packages/tvheadend-testing/scripts/start-stop-status
		        sed -i 's#su - ${RUNAS} -c "${TVHEADEND}#su - ${RUNAS} -c "LD_PRELOAD=/var/packages/sundtek/target/opt/lib/libmediaclient.so ${TVHEADEND}#g' /var/packages/tvheadend-testing/scripts/start-stop-status
                     fi
	     fi
	     if [ -e /var/packages/tvheadend-testing ]; then
		     echo "setting up tvheadend autorestart in /etc/sundtek.conf"
		     echo "device_attach=/var/packages/tvheadend-testing/scripts/start-stop-status restart" > /etc/sundtek.conf
             fi
	  fi
	elif [ $USE_TMP -eq 1 ]; then
          cd /$tmp
	  tar xzf /$tmp/.sundtek/$SYSTEM/installer.tar.gz >/dev/null 2>&1
	  if [ "$?" = "1" ]; then
	     cd /$tmp/.sundtek/$SYSTEM/
	     gzip -d installer.tar.gz
	     cd /$tmp
	     tar ${tarflag}xf /$tmp/.sundtek/$SYSTEM/installer.tar
	  fi
        else
	  cd /
	  if [ "$busyboxfound" = "1" ]; then
		# can fail on some systems 
		tar ${tarflag}xzf /$tmp/.sundtek/$SYSTEM/installer.tar.gz >/dev/null 2>&1
		if [ "$?" = "1" ]; then
			cd /$tmp/.sundtek/$SYSTEM/
			gzip -d installer.tar.gz
			cd /
			tar ${tarflag}xf /$tmp/.sundtek/$SYSTEM/installer.tar
		fi
	  else
		tar ${tarflag}xzmf /$tmp/.sundtek/$SYSTEM/installer.tar.gz
	  fi 
	  if [ -f /sbin/udevadm ]; then
	     if [ `/sbin/udevadm version` -lt 086 ]; then
		rm -rf /etc/udev/rules.d/80-mediasrv-eeti.rules
	     else
		rm -rf /etc/udev/rules.d/80-mediasrv.rules
  	     fi
	  else
	    if [ -f /usr/bin/udevinfo ]; then
#        since --v is not supported with older versions...
	      if [ `/usr/bin/udevinfo -V | sed 's#[^0-9]##g'` -lt 086 ]; then
 		 rm -rf /etc/udev/rules.d/80-mediasrv-eeti.rules
	      else
		 rm -rf /etc/udev/rules.d/80-mediasrv.rules
  	      fi
	    else
#       stick with the newer rules which disable UAC audio
	     rm -rf /etc/udev/rules.d/80-mediasrv.rules
	    fi
          fi
	  if [ -d /usr/lib/pkgconfig ]; then
                # can fail on read only filesystems
                cp /opt/doc/libmedia.pc /usr/lib/pkgconfig > /dev/null 2>&1
          fi
	  if [ -d /lib/udev/rules.d ]; then
		if [ -f /etc/udev/rules.d/80-mediasrv-eeti.rules ]; then
		   cp /etc/udev/rules.d/80-mediasrv-eeti.rules /lib/udev/rules.d;
		fi
		if [ -f /etc/udev/rules.d/80-mediasrv.rules ]; then
		   cp /etc/udev/rules.d/80-mediasrv.rules /lib/udev/rules.d;
		fi
		if [ -f /etc/udev/rules.d/80-remote-eeti.rules ] && [ "$NOLIRC" = "0" ]; then
		   echo "installing remote control support"
		   cp /etc/udev/rules.d/80-remote-eeti.rules /lib/udev/rules.d;
                else
                   rm -rf /etc/udev/rules.d/80-remote-eeti.rules 
		   rm -rf /lib/udev/rules.d/80-remote-eeti.rules
		fi
	  fi
	  if [ ! -e /opt/bin/mediasrv ]; then
		  rm -rf /$tmp/.sundtek
		  echo "Seems like there's a problem installing the driver to /opt/bin"
		  echo "doing some tests..."
		  echo "mkdir -p /opt/bin"
		  mkdir -p /opt/bin >/dev/null 2>&1 
		  if [ -d /opt/bin ]; then
			  echo "succeeded"
	          else
			  echo "failed!"
		  fi
		  echo "mkdir -p /$tmp/opt/bin"
		  mkdir -p /$tmp/opt/bin > /dev/null 2>&1
		  if [ -d /$tmp/opt/bin ]; then
			  echo "succeeded"
		  else
			  echo "failed!"
		  fi
		  echo "Some more information"
		  echo "uname -a"
		  uname -a
		  echo "vendor_id"
		  cat /proc/cpuinfo | grep "vendor_id"
		  echo "Model Name"
		  cat /proc/cpuinfo  | grep "model name"
		  echo "disk space"
		  df
		  echo "memory"
		  free
		  echo ""
		  echo "please send these information to kontakt at sundtek de"
		  exit 1
          fi
	  chmod gou=sx /opt/bin/mediasrv
	  rm -rf /$tmp/.sundtek
	  echo -n "finalizing configuration... (can take a few seconds)  "
	  if [ -d /usr/lib/pm-utils/sleep.d ]; then
	     cp /opt/lib/pm/10mediasrv /usr/lib/pm-utils/sleep.d/
	  fi
	  if [ -f /etc/redhat-release ]; then
            /usr/bin/chcon -t lib_t /opt/lib/libmediaclient.so >/dev/null 2>&1
	    if [ -f /usr/sbin/semanage ]; then
	       if [ "`/usr/sbin/semanage fcontext  -l 2>/dev/null| grep libmediaclient -c`" = "0" ]; then
                 echo -n "."
                 /usr/sbin/semanage fcontext -a -t lib_t /opt/lib/libmediaclient.so >/dev/null 2>&1
               fi
	    fi
	    if [ -e /usr/bin/systemctl ]; then
		rm -rf /etc/udev/rules.d/80-mediasrv-eeti.rules
		rm -rf /lib/udev/rules.d/80-mediasrv-eeti.rules
	    fi 
          fi
	  echo ""
	# dreambox doesn't need preloading, the driver is directly using /dev/misc/vtuner0

	  if [ `grep -c Brcm /proc/cpuinfo` -gt 0 ] || [ -e /dev/misc/vtuner0 ]; then
	     echo "Settopbox Detected"
#         if /etc/ld.no.preload exists the preloading mechanism will not be installed
	  elif [ ! -e /etc/WiAutoConfig.conf ] && [ "$NOPREL" != "1" ] && [ ! -e /etc/ld.no.preload ]; then
	    if [ -f "/etc/ld.so.preload" ] && [ `grep -c Brcm /proc/cpuinfo` -eq 0 ]; then
	      if [ "`grep -c libmediaclient.so /etc/ld.so.preload`" = "0" ]; then
	        echo "installing libmediaclient interception library"
	        sed -i "s#^#/opt/lib/libmediaclient.so #" /etc/ld.so.preload
	        if [ `grep -c libmediaclient.so /etc/ld.so.preload` -eq 0 ]; then
	           echo "/opt/lib/libmediaclient.so " >> /etc/ld.so.preload
                fi
	      fi
	    else
	      echo "/opt/lib/libmediaclient.so " >> /etc/ld.so.preload
	    fi 
	    chmod 644 /etc/ld.so.preload
	    if [ -f /sbin/ldconfig ]; then
	    /sbin/ldconfig >/dev/null 2>&1
	    fi
	    if [ -f /etc/sidux-version ]; then
	       if [ -f /etc/init.d/lirc ] && 
                  [ "`grep -c '#udevsettle' /etc/init.d/lirc`" = "0" ]; then
                  echo "  uncommenting udevsettle in /etc/init.d/lirc in order to avoid"
                  echo "  a deadlock when registering the lirc remote control"
	          /bin/sed -i 's#udevsettle ||#:\n\#udevsettle ||#g' /etc/init.d/lirc
               fi
	    fi
          fi
        fi
	rm -rf /$tmp/.sundtek_install
	rm -rf /$tmp/.sundtek
	if [ "$KEEPALIVE" = "0" ]; then
   	  echo "Starting driver..."
        fi
        if [ "$ctet8000" = "1" ] || [ "$ctet5000" = "1" ] || [ "$ctet9000" = "1" ] || [ "$ctet6000" = "1" ] || [ "$vusolo" = "1" ] || [ "$ctet10000" = "1" ]; then
           if [ "$KEEPALIVE" = "0" ]; then
              /opt/bin/mediasrv -d --no-nodes
              /opt/bin/mediaclient --loglevel=off
           fi
	   if [ ! -e /usr/bin/mediaclient ]; then
               ln -s /opt/bin/mediaclient /usr/bin/mediaclient
           fi
	   if [ -e /usr/lib/enigma2/python/Screens/ScanSetup.py ] && [ "`grep -c Sundtek /usr/lib/enigma2/python/Screens/ScanSetup.py`" = "0" ]; then
	       sed -i 's/^                if tunername == "CXD1981"\:/                if tunername\[0:7\] == "Sundtek":\
                        cmd = "mediaclient --blindscan %d" % \(nim_idx\)\
                elif tunername == "CXD1981"\:/' /usr/lib/enigma2/python/Screens/ScanSetup.py
           fi
	elif [ "$dm800" = "1" ] && [ "$SYSTEM" = "dreambox" ]; then
           cd /usr/sundtek
	   KVER=`uname -r`;
           VERMAGIC=`/opt/bin/mediaclient --strings /lib/modules/${KVER}/extra/lcd.ko | grep vermagic=`
           if [ "$dm800" = "1" ]; then
              VERMAGICOLD=`/opt/bin/mediaclient --strings usbkhelper-dm800.ko | grep vermagic=`
           fi
	   if [ "$VERMAGICOLD" != "$VERMAGIC" ]; then
               /usr/sundtek/kpatch usbkhelper-dm800.ko /usr/sundtek/usbkhelper-dm-local.ko "$VERMAGICOLD" "$VERMAGIC"
           else
              cp usbkhelper-dm800.ko /usr/sundtek/usbkhelper-dm-local.ko
	   fi
	   if [ "$KEEPALIVE" = "0" ]; then
             /opt/bin/mediasrv -d --no-nodes
             /opt/bin/mediaclient --loglevel=off
	   fi
	   mkdir -p /opt/bin/ > /dev/null 2>&1
	   mkdir -p /opt/lib > /dev/null 2>&1
	   if [ ! -e /opt/bin/mediaclient ]; then
	       ln -s /usr/sundtek/mediaclient /opt/bin/mediaclient -s > /dev/null 2>&1 
	   fi
	   if [ ! -e /usr/bin/mediaclient ]; then # this symlink is needed for the automatic search
               ln -s /opt/bin/mediaclient /usr/bin/mediaclient
           fi
	   if [ ! -e /opt/bin/mediasrv ]; then
	       ln -s /usr/sundtek/mediasrv /opt/bin/mediasrv > /dev/null 2>&1
	   fi
	   if [ ! -e /opt/lib/libmediaclient.so ]; then
	       ln -s /usr/sundtek/libmediaclient.so /opt/lib/libmediaclient.so > /dev/null 2>&1
           fi
	   if [ -e /usr/lib/enigma2/python/Screens/ScanSetup.py ] && [ "`grep -c Sundtek /usr/lib/enigma2/python/Screens/ScanSetup.py`" = "0" ]; then
	       sed -i 's/^                if tunername == "CXD1981"\:/                if tunername\[0:7\] == "Sundtek":\
                        cmd = "mediaclient --blindscan %d" % \(nim_idx\)\
                elif tunername == "CXD1981"\:/' /usr/lib/enigma2/python/Screens/ScanSetup.py
           fi
	elif [ "$SYSTEM" = "dreambox" ]; then
	   cd /usr/sundtek
	   if [ "$KEEPALIVE" = "0" ]; then
             /usr/sundtek/mediasrv -d --no-nodes
             /usr/sundtek/mediaclient --loglevel=off
           fi
	   mkdir -p /opt/bin/ > /dev/null 2>&1
	   mkdir -p /opt/lib > /dev/null 2>&1
	   if [ ! -e /opt/bin/mediaclient ]; then
	       ln -s /usr/sundtek/mediaclient /opt/bin/mediaclient -s > /dev/null 2>&1 
	   fi
	   if [ ! -e /usr/bin/mediaclient ]; then # this symlink is needed for the automatic search
               ln -s /opt/bin/mediaclient /usr/bin/mediaclient
           fi
	   if [ ! -e /opt/bin/mediasrv ]; then
	       ln -s /usr/sundtek/mediasrv /opt/bin/mediasrv -s > /dev/null 2>&1
	   fi
	   if [ ! -e /opt/lib/libmediaclient.so ]; then
	       ln -s /usr/sundtek/libmediaclient.so /opt/lib/libmediaclient.so > /dev/null 2>&1
           fi
	   if [ -e /usr/lib/enigma2/python/Screens/ScanSetup.py ] && [ "`grep -c Sundtek /usr/lib/enigma2/python/Screens/ScanSetup.py`" = "0" ]; then
	       sed -i 's/^                if tunername == "CXD1981"\:/                if tunername\[0:7\] == "Sundtek":\
                        cmd = "mediaclient --blindscan %d" % \(nim_idx\)\
                elif tunername == "CXD1981"\:/' /usr/lib/enigma2/python/Screens/ScanSetup.py
           fi
        elif [ "$dockstar" = "1" ]; then
           cd /$tmp/opt/bin
	   if [ "$KEEPALIVE" = "0" ]; then
              ./mediasrv -d
              ./mediaclient --loglevel=off
              ./mediaclient --enablenetwork=on
           fi
        elif [ "$ddwrtwndr3700" = "1" ]; then
           cd /$tmp/opt/bin
	   if [ "`grep usbkhelper /proc/modules -c`" = "0" ]; then
             KVER=`uname -r`;
             VERMAGIC=`strings /lib/modules/${KVER}/kernel/fs/ext2/ext2.ko | grep vermagic=`
	     VERMAGICOLD=`strings ../kmod/usbkhelper-ddwrt2.ko | grep vermagic=`
	     # doesn't really matter if it fails or not the router is fast enough to work without
             # acceleration module
	     if [ "$VERMAGIC" != "$VERMAGICOLD" ]; then
               ./kpatch ../kmod/usbkhelper-ddwrt2.ko ../kmod/usbkhelper-ddwrt-local.ko "$VERMAGICOLD" "$VERMAGIC"
             else
               cp ../kmod/usbkhelper-ddwrt2.ko ../kmod/usbkhelper-ddwrt-local.ko
             fi
	     insmod ../kmod/usbkhelper-ddwrt-local.ko
	     if [ "$?" != "0" ]; then
               echo "not using acceleration module"
	     fi
           fi
	   if [ "$KEEPALIVE" = "0" ]; then
             ./mediasrv -d
             ./mediaclient --loglevel=off
             ./mediaclient --enablenetwork=on
           fi
        elif [ "$wndr3700" = "1" ]; then
         if [ $USE_TMP -eq 1 ]; then
            cd /$tmp/opt/bin
         else
            cd /opt/bin
         fi
	 #if [ "`grep usbkhelper /proc/modules -c`" = "0" ]; then
         #  KVER=`uname -r`;
         #  VERMAGIC=`strings /lib/modules/${KVER}/ehci-hcd.ko | grep vermagic=`
	 #  VERMAGICOLD=`strings ../kmod/usbkhelper-openwrtmipsr2.ko | grep vermagic=`
	   # doesn't really matter if it fails or not the router is fast enough to work without
           # acceleration module
	 #  if [ "$VERMAGIC" != "$VERMAGICOLD" ]; then
         #     ./kpatch ../kmod/usbkhelper-openwrtmipsr2.ko ../kmod/usbkhelper-openwrt-local.ko "$VERMAGICOLD" "$VERMAGIC"
         #  else
         #     cp ../kmod/usbkhelper-openwrtmipsr2.ko ../kmod/usbkhelper-openwrt-local.ko
         #  fi
	 #  insmod ../kmod/usbkhelper-openwrt-local.ko
	 #  if [ "$?" != "0" ]; then
         #      echo "not using acceleration module"
	 #  fi
         #fi
          ./mediasrv -d
          ./mediaclient --loglevel=off
          ./mediaclient --enablenetwork=on
        elif [ "$USE_TMP" = "1" ]; then
          cd /$tmp/opt/bin
          ./mediasrv -d
          ./mediaclient --loglevel=off
          ./mediaclient --enablenetwork=on
        else
	  if [ "$synology" != "0" ]; then
	     if [ "`grep -c mediaclient /etc/rc`" = "0" ]; then
		     echo "Setting up autostart (/etc/rc)"
		     sed -i 's#exit 0#/opt/bin/mediaclient --start\nexit 0#g'  /etc/rc
             else
		     echo "Driver is already installed in /etc/rc"
	     fi
	  fi
	  if [ "$synology" != "0" ] && [ "$sedver" != "0" ] && [ "$driverinstalled" = "0" ]; then
	     echo "Setting up autostart (/etc/rc.local)"
	     cp /etc/rc.local /etc/rc.local.`date +%s`
	     sed -i '2 s/\(.*\)/\/opt\/bin\/mediaclient --start\n\1/' /etc/rc.local 2>/dev/null 1>/dev/null
	  else
	     if [ "$synology" != "0" ]; then
	       echo "Driver is already installed in /etc/rc.local"
	     fi
	  fi
	  if [ "$USE_CUSTOM_PATH" != "" ]; then
		  $USE_CUSTOM_PATH/opt/bin/mediasrv -d -p $USE_CUSTOM_PATH/opt/bin
          else
	          /opt/bin/mediaclient --start
          fi
        fi
	if [ -e /lib/systemd/system/enigma2.service ]; then
		if [ "`grep -c sundtek /lib/systemd/system/enigma2.service`" = "0" ]; then
			sed -i 's/enigma2-environment.service/enigma2-environment.service sundtek.service/g' /lib/systemd/system/enigma2.service
		fi
		cp /usr/sundtek/sundtek.service /lib/systemd/system/
		systemctl daemon-reload
	fi
	if [ -e /usr/bin/enigma2-environment ]; then
		if [ ! -e /etc/rc3.d/ ]; then
			mkdir -p /etc/rc3.d/
		fi
		if [ "`grep -c libmediaclient.so /usr/bin/enigma2-environment`" = "0" ]; then
			sed -i  's/^echo LD_PRELOAD/\nif [ -e \/opt\/lib\/libmediaclient.so ]; then\n      LD_PRELOAD="\/opt\/lib\/libmediaclient.so ${LD_PRELOAD}"\nfi\necho LD_PRELOAD/g' /usr/bin/enigma2-environment
		fi 
	elif [ -f /usr/bin/enigma2.sh ]; then
	    sed -i 's/LIBS=\/usr\/lib\/libopen.so.0.0.0/LIBS="\/opt\/lib\/libmediaclient.so \/usr\/lib\/libopen.so.0.0.0"/g' /usr/bin/enigma2.sh
	    sed -i 's/LIBS="$LIBS \/usr\/lib\/libopen.so/LIBS="$LIBS \/opt\/lib\/libmediaclient.so \/usr\/lib\/libopen.so/g' /usr/bin/enigma2.sh
	fi
	sleep 3
	rm -rf /$tmp/.sundtek_install
	if [ ! -e /lib/systemd/system/enigma2.service ]; then
		if [ -d /lib/systemd/system ]; then
			if [ -e /opt/doc/sundtek.service ]; then
			    cp /opt/doc/sundtek.service /lib/systemd/system
			fi
		fi
	else
		if [ -e /lib/systemd/system ]; then
			if [ -e /usr/sundtek/sundtek.service ]; then
			    cp /usr/sundtek/sundtek.service /lib/systemd/system
			elif [ -e /opt/doc/sundtek.service ]; then
			    cp /opt/doc/sundtek.service /lib/systemd/system
			fi
			if [ -e /etc/systemd/system/multi-user.target.wants ] && [ ! -e /lib/systemd/system/sundtek.service ]; then
				ln -s /etc/systemd/system/multi-user.target.wants/sundtek.service /lib/systemd/system/sundtek.service
			fi
			if [ -e /bin/systemctl ]; then
				/bin/systemctl daemon-reload
			fi
		fi
	fi
	if [ -e /usr/bin/systemctl ] && [ -e /opt/doc/sundtek.service ] && [ "$USE_TMP" = "0" ]; then
		mkdir -p /usr/lib/systemd/system/
		cp /opt/doc/sundtek.service /usr/lib/systemd/system/
	fi
	HOSTNAME=`hostname`
	if [ "$HOSTNAME" = "raspbmc" ] && [ -e /opt/xbmc-bcm/xbmc-bin/share/xbmc/addons/script.raspbmc.settings ]; then
             echo "Deploying RASPBMC Init Script, due faulty udev behaviour"
             cp /opt/doc/sundtek.startscript /etc/init.d/sundtek
             update-rc.d sundtek defaults >/dev/null 2>&1 
        fi
	echo "done."
}

export NOLIRC=0

CHECKPERM=0;

if [ $# -eq 0 ]; then
	CHECKPERM=1; INSTALLDRIVER=1;
fi

while [ $# -gt 0 ]; do
	case $1 in
	   -u) checkperm; uninstall_driver; exit 0;;
	   -h) print_help; exit 0;;
	   -e) extract_driver; exit 0;;
	   -nolirc) NOLIRC=1; INSTALLDRIVER=1;;
           -softshutdown) softshutdown=1;;
	   -use-custom-path) shift; USE_CUSTOM_PATH=$1; INSTALLDRIVER=1;;
	   -easyvdr) AUTO_INST=1; CHECKPERM=1; INSTALLDRIVER=1;;
	   -service) NOPREL=1; INSTALLDRIVER=1;;
	   -system) SYSTEM=$2; INSTALLDRIVER=1;;
	   -keepalive) KEEPALIVE=1; INSTALLDRIVER=1;;
           -admin) CHECKPERM=2; INSTALLDRIVER=1;;
           -netinst) NETINSTALL=1; INSTALLDRIVER=1;;
	   -tmp) shift; if [ -d $1 ]; then echo "using $1 as temp directory"; tmp=$1; INSTALLDRIVER=1; else echo "invalid directory $1"; exit 0; fi;;
	   *) if [ "$CHECKPERM" = "0" ]; then CHECKPERM=1; fi; INSTALLDRIVER=1;;
	esac
	shift;
done

if [ -e /etc/freebsd-update.conf ]; then
	if [ "$INSTALLDRIVER" = "1" ]; then
		INSTALLDRIVER=0
		INSTALLBSDDRIVER=1
	fi
fi
if [ "$CHECKPERM" = "1" ]; then
  checkperm
fi

if [ "$useblacklist" = "1" ]; then
	em28xxblk=`grep -c em28xx /etc/modprobe.d/blacklist.conf`
	if [ "$em28xxblk" = "0" ]; then
		echo "blacklist em28xx" >> /etc/modprobe.d/blacklist.conf
		if [ -x /sbin/rmmod ]; then
			/sbin/rmmod em28xx >/dev/null 2>&1 
		fi
	fi
fi
   
if [ "$INSTALLDRIVER" = "1" ]; then
  install_driver
fi

if [ "$INSTALLBSDDRIVER" = "1" ]; then
  install_bsd_driver
fi

exit 0
� �W�T �[
1-|'��<�ӝ��˄�g����<-e��e
K~,�Q�]⣿0WMIa�2җ�_����O��B&\.V�|[,:��Ƣ���V>#C�t»_uر�KL�)��	C
�0Ub���+�}7d�X�Cu_��
S��gh _=��W`b1��'��aj���b�Ht#&�D�b�"�f����2�~��c��/`�I��1��~rW�AׇGq�FhF���@o�d6���`"��t&�&!���3CDe1HE�a�g��HF'1��H*M�!K�#�HF�
�6K9
��z�rl��cC�O96|�r�$�(G�˔c'���(��p�r�H�(G�n����=v�+�Zp�O��sy�����л��?}a��T�x��ާ��H�ߗ�_��OJ��I�OK�G��ǥ�����ɉ�����R_��L��wi�?���S�tk�Nj|�
?-���N ��ᄄy=��k�
N_.�О�7���*�)�T,^�#�<6��|��W�C1Nϓ,�w��b�<�νL��e����L�z�@�:�瀞����?T'	�^L�-�U�k�#�7�p�ؙ�F���7SP�����G���T1��3��u:W-F���\��\�����GyP'.����P]p��0�&�ו�w]p��/�`rÚ�S��W>7q�0bk�eߡw��L-��e�W]������<��H�c��BeQ��2��W��'Y�l�s�.��3�/�0�������]
��u�؈��;q-��t�#[?�9X����h�-���H&�D�����hF�J&c�P0C�����^6�E�LB3�}�gôk
0r��+b-Bk˹�|�y�_c�zy
m��������:����_�z_G�F�9���"�H0��6��`$8���K���n�����
�[Y�T9V�V*���jg�r���X�lR��>0�	b�+X��o�������'2o����Lp�#��x��(��L
����K]�Б�>��$c��3�����J��� x�kod4���}(�p�L��8�x��P�y���*\�`:
ͫ��঄]����"�����e�s�%���cI��SX��>J/��%�����<��{�F��x7���ӆ�t��J�e|l���������N>'a~��B%K_s\.�黊?x�������`�(��r�DsS%��y�Ӽ���7�8��)ѕ,�h�"����s%����]���#�{9�#N/�������Aײ|�D�S�����Z��gN��8W�Wr�Jt=�_c�b��̠W��]�W��8��F�ii'|X�*��A=!h�!ŃF�W���%zZ�YF�/��� ��Ge��J���v.K|��K�-�ϗ�/�-R �����K��������`{~A��b҆MG��5K�{�I�G%>�.)>$?"����!����H��������[��V�f�-�w8L��?e��lI_|�a�
��w��_
:����1�Y������i=��i=����>�tZ��;��Y�X�.>߹X��C��zn�Ⲟ���x�
��>��t��/�Gl�����]��Я�8(�F��ߒ���K6�.�w�Y�9�����\��
m��c�X��ۋ�y��X�-�m����_���;������PG�[i�ފ�� �Ig����g	��?��)�¼!hI�F�F��}�t��V2�7�q3^�@��r�e�)��+��D�f(��_���C�ߒ�8�Meҙ���U׿ؽW��}�_�!����h��zfT�q�L�)��pB�%�1=�I��z0�p7��E2��w���{˃tss���5u �XgGG��D��X@���Hh$ڇ~��
��EbC��u}�ޮ���m{z�Z��ƻEm��G�t����rX� }G�[����oh[��ߵ�o�n|�¾�j#�r���G-��L.�{�w�fx�wwS$���hC/�OmAw���t����%&ւ*a�%]b�xV���l&me�>�Y������Ϧ8��G��0VK�} ��h\Ϧ#a�IPF���X��3;M��%Zƨ�`_�/>��Q��i�]1�F�SC�m���b�Ye_5��[~B#�F��t$6�u��{>��G�����G�Ϸq��h���������n�ߪ�;3��Y�B��T@34��u�~�Y��wJ����,�Y�a=��;�I�i���Y�_���7~�~�[TJl'�
>������.��+�����P7%Z�P����l�q���������{�����Ŗ��nZ��3=�P7�4��3ۓ?۝���8+��n2�>�g�H�	z�ȍ�q�G�ޤ��)I1@�I:	@��.�\���7o��_#�^)lz�nU���w�Z0�,~���G>�1꼚ׇ٤�g�Ko�O�W�M�t�����Kſ����Ľ������y!�mN��Y\@���߯0�QM�/m���ۏ�?,V��Y��P��Ø/,��3�ҝ�|S�Dk��L�_x:�:�tL��V�����miҞF~��ӹ�$�GNӜ5��~����#�����bCzN�1%%����c���|�w�h\p*��'�]�q���,�_|>���]Zk�5U4>���e~3�5vׇ_�Wyĕ �~]	"l8��8�H�hs
0Y��ܳ�w�tdo_���+��k�}:ч��f8YZ�H?��}a˂%д�҉����_p�g֩0u�	�:݀�ulWC�i�9���^ȱ~Tyﺥ�4'�SS�LƏ���nģ���N
�t.<iֹ���=v��uN�:�_���q��t����/��|��P=�4���U�V�����B�����隬=�1u�)���S�'�!�cC����K��Ǝ�6��f�K����9��
ĩ��46]6��И�r���s�g��̺N�[�}�7O�]�pr?x=��=��� =R���<��iL����m���u�ɭm��_�(#�1��\gy+낭-��_o�lB�x���`=�O���ӵ�-������b��N�)���c���6�άs��M�_=��i�i��f0��J��bDu5��&b�1[��UA�51��1j�wrUX�5�����
Q�1����
�N�>��xH�Xar�����}��jc�(��a)V�0��q��ɑ+E¦����?��p]%����m��2�p�>B�������[���"z��^7^��G���[".dӉ6�[�9��MU�4�݋ȿ�ї��s�m~�R������ub�3h�'��N�v��|�$����c��7����)��L��d��׭�פ��u�m��"m�n�W�a;�M&�R�l��j�-�<�6U�ǣe���� ֥N�iº'�`��R���\���s����܀m.8d����Ǥ�7٥n��*P?*l�mw~���W�3�?*�wӚe-�
�^�?�$�Fh��t��^e����6z��^a��lt��^n�����~�~���u�5Pqkk.�.Z��c>���������-j���������>5j�ǃpj����V��&폌��>�ߡ=�kh/C�ڳ�>%)���}�5��{�t��޻��a)����%B����GR|4L���/��7�W2���ߌ��.��}#�J>���? ��>¿ş[�xF�1ڂ�w��_>�����
q��Ϩ�r+�&�[8N�7�ٙ�y0�I��9��oFgF��X��P���ft�4�/�
�'�7���=
�P4��E!,����X�15�ݞ�z���]�ڃ[DW]�',������+v�.ډ�l7u�f���yﾛyIpų���y��}���w�}������W=�,�\��WaX�@-����s�,�����\�棠ʢ�I]g��e��]��Zm���I}�x.�FO���=�5��נ��#�E�%����?�e���<�C{9�h&��t?���y��c?���'hz����������+���B�R��Z��U���kxv�z��^�?�h���E�ǽ��z�a�w���i�ȡC�4}�ù�~�r�0z��5v�ުk�QJ����'+
�:��b"I��z}���~X��U|UX�Q�Q���Ȫ�z�Ec)_�C{ y
�������0�V����3���jg�#��e]-��]�u�����)����{A�˺��4��k����v�2�v�蚮u�^
��RUa*�B�H�ӄ�3B
lȏ���s�>�������� *�쨌��E�f{�HeӢ�q4�ovV��de�.�����[����3��g���}�gi�D��ڇ��M-}�~e����ﮌ���t��Gc�Ft���F�����W&6*�@e�.XT���Y�u�u���L�ݘL1<�Fcݾh�/]�Ѫ[������i�T��E����2����^f����|޾]�)�+�̇^mn���V��$ �V����kh�)�_r?Ӹw1v�
B�%�1ɁN�=������݈�-����R�/x8-�.��-�g!�"��D{�%)�u��OT\�[Ƚ�^,xN��Z���Fk4�v"��OZ�S��%ҿ� ���p�8Ow��>G�O���"~]�?�oD�;��B�|��EO%������� ϋW���q���,����}9��)�I��Y�>ֶ_�N�K���J��o�T]��dGż���z<��9w`���ݶuC�&fTV� ��&,^(+.c�,s�l�D`v^*{��RYc�g������f�&0߶8?a
K+�t��[��K���j�[��߃j�`�8=U���2��R�6Ή�M^��U�(�\p@0�?a9?��*���X��F��}Z�u}T�+��!}BV�K,����b!��*QA�-�z��F+��_>�J�K�YS�aWuVї�=B?@2�_���J~�9�/
����O����"� � s2�>��|�v�ɠ���~Ԛo8��/�Wwk���~�����|�K}9?�c5y��M�y������&������m� ��,���5�v��.�OQ��D��#*~��z��5�"�_4L�W5�
�_1-��N���:�����>��W�e��k�K�X���˗��4}������t��4�U��*�i�����.�mYyB�6�Y^?��x��fB���"t��s"B��o���x��E?  ���D]6�Ȭ��t�|�'���!���˂�j� K��~��׾v�S̃h����7S�����-�s���VS>�8������{��'�k=8�Y����϶��N����������m�O��1�}�ɿ���9�9�}��ϵ�WN�X�>���Y�'�o�7��q����o��N�k�v��y�ɟ�q]6�ru�/��G'�������������Q���v����`ɿ؅?ͅ?} �l6u�υ�X����%.�ń�����B�mY��u
[O����X��haM�X��hi
Y�DćR�=��k�%y{%�)>�sM�yU{!�1�T�YX�����T�?�L?;b
_��T7�4��|S���'�F�n}v"�k*'��O��Wtbh����mo���t]���D��K��>Fu��?�T쨱����Ď��r��5���A>�-at��΢�b�7�5h/�Qk.���"Z�䭴
�3�W�'�Y�+��h���c��L)��"w��T� ���ǈ��ck�y��C�O�Â�T�*rXD
�|'�9bc�z_?W�G��_T��ZdO��p����٦7�8ք�\�"����\��p�ؘD��U��I����B˴�4������ ��@Ϗ>��P��4���8AC����G�e�/G��7��Y?��I�&g�O��'s<w��=�����0���y��{
5�3�cѼ����)N�Q'�e��)X4 >aѼ7�[4��> i��\n��B�?��I�^I󝖓�۸n9Ϳ�������1բ9�5h�5Qd��N�c�|C�ע���N��)TX���Spғ5z�FO�����{���Y��X����j��/�m��^&���.d�_���W��߹G����<^����y~��i��(�������w鴼�t�#�?��������q����>�?��'�
���8RLil���S�O���4z�i_�*}�
�U��_��k�����)���3��4�{.�p��i�/����4��Ҝ�s	�n޸����K�%'�&�W�h��kk� �	Yߗv��4tRH�+�!F�!�S����4`����B:
+��~4:ډ�
Ix�o

Ƶ[���e�:>�C�3(gO�5�H���R�MHJb�! #2#{�F���ȃ��m�Ub���������N:l���of������>���ٽYؐ��k6���{��8�/>��#��ҫ���3�U\V^������V������D�W�.����W+�����_L]��|>�10	�k���.���{ʞ|Y���2aoFa����o_B݅����/����YL�[x��gn~ˣ�[�I�[�<�w{O�P�,>�e����}#1�+H����s]�5ޓ���T~?驤�I��<XKzi���v�_2�kX|~+ޑ^1]�⿟�<fs�k,�%��t!]
�hbb�a.:���s�{�l,��$s�\�R�٨������
~�BT�[��:�PT�[�Q�o�D�5�֥��؁��oE�GP���-8y�g̞�EN�/*9-�Y�0���HtN#�9-�L�0B���HuN#�9-�\細����t�j�WA�_��������oA��Ϋ��G���5��܄Z�
\�i�4� a�q�E����~�T
����?� P�%�,�i� ��=�f������I1Y�9��_~&L�{:���k|&�&�H2Y�&�d`F��U3�����%&��������\�Ֆ�P���k.�Y���		L��?]�R=�:]sw��"ۏGv�Y~��<�ꔽ��_/|ewה�v
\�ǵ��h�ų�6��D�+����5��qO����ȎÑ��y�|�'������ݾ���tM���~�����,��ߍ�"r�¼J>��J`^��d�P�O.`i:��۲��5̌��&��56�cݜ�P�Y:����{�+��p������	���`�/���HMWk�Ya�U~�DC��-ܲOE��y�I4�[���O�Pn�7��P^��pr�f g����5��w�/�B��0�~L��&Ҍk}Ǵ:�v�HX��%,a�!�� -����I��S���r2t�߮ဗ�g޹���3ĺ^����S��m��@��h�`W�+��y���@�WO+�^�s�6��#����֜�ֆs���]����zj��#C[�����uxl��`�9p�:��ap,8��ĖQ�!���?�a
>
���K�~�I�*���"b}��"փ��͜���2��(�U^F�D�b���7��o�/w�����8�+��@-�w'rR���H���Ʃk�H���A#9E�j4�*��g�$ʤ�ru��|^���w��[�;��\N��L���|�9_�9/Ń��;��������}���Z�jnM�,�b��Yy��/ؚ[��Ggi���$X~'	��U�I�4xۗK�Ǽ�8ֹ��Y<V�&���1�*	�F27�4xLm��c�x,
Nd-���a2�R��%&X^���O��	$��>�����YP�'&N�]�Q`��Đ,_����&H_���OJh~������I��ܯ}��Ǎ�g�ed��n�X��/�Y.��xZ�G�+@�����o�I�7�b��~��)�/�rj�Q����!�V�a��Az-h��H?�
j[\ˌ�Z6�Ka�!�����,E��f�7�Mg�b�a,���^�~���Z#Ô��_a�ܟx����|8��^��f����t�le�/_޷��2�Gpwnfo��,0ZX��^4`;���3��
>�a����1�ɳ�W���zy�3����~�� ��ky[��Z�mP'֍��
����p-n�UaQ_�t����gY~�e�~�e���?�_������ ��m���{�F��~L,�U���2cױ�1n'��� �`����ݭϲq����:߇mi��pn���%l��l�����/�q��噰�e��24mj���|�>+�Ǐ63By�Ջ��`�X	u��ǰl8����&ĕ}9qA<>�;�4P���ݩ�޵�"??>�r��M}�86���w�}��G&���n��͋v�t;|n����R���f{����q�}�\�}��E���t���L���R���f��|�8�<�m��h���=���=�{�v�L��ޥv����ٽ�g��wo�ݷ���ߞn�ϴ/�/��7�C�{���=��m���zD_�A\�A\g �3����u�:q����@\�PW7��
������|�xί����yv��T���8��[FcA8��s^<�A{����[̋z���h�����a����=,b4��0�1�����s
ұo�����
$>;4�*ƧI�8v-��|�o}�����������m�G�M9������J�.F(N�+ƍ|���'��q�k����Ň/����f9���9Ƒ��#\S��b��ܸ��5�7����Mvi`7v0���p�Q�p���~�E��%Փ�N�c+٥ivg�����+�����?���;#�x����Z�=�F�N���YV���Y5֟���My������������?����8v.�s�����[YB���`��ac>tߓ�%]@�Cz	i/�}�M��>5�A��xc�A��0�i��=1S|���/�)�D��t��|_�:@��t��b��{����'�'��H�)�O��r�EZ��'�e~�>��P��)�m��*t���Kg��
�ی�j��Ag��Ij>�:�>R������?�&
�}Z�ސ���
�K}��i�^��������;T{�Ҝ�R�
U�ҖBy��?
�׫|�oV����3_���b��?��9׷����q�t��-�X�����2^��E����ey�n�x�T��Q9���q�s��!��?����{b��?KA�����O�`���pe���(���������M��7�:�`���rϸw�:C]%_��A�5�5�����kJK�4�Oq�
Jʡ@���V���K�����5�\n#���|�h��(���m#͏}��`��gMb�������2�S(��K����e��;�,.]s��;���XŲ�c9�-(�2�Y�ej�#S�%Z4�S1���@cb�-ՖpVX�&��i�X�J��FK��\}�9�5OO��X<��z�c�؉�K��T_f�S=��\��'y�'�
c3r9���=C��?.����wT��㣂'G��br����Kc��2O�4���v�a�
���Hz��w���P~�#�)�~��B�aw�i|6w�7�e�Nh�'�Ahܘ<@hܸ�>�?�(�� �8��Kh�O�Oh}6���W�6l|�^u�˽�������b���{����ձ��fj����!�X��	m�/�[�NY�#�`7����^	�Ń.��*���;�/Tt�����_���p�-�K��[��˂_hu��z�d���"c���|g8<x���مC�}�;3k�k�h�������w
n�t�.u��=3�u�i����qr��	�M������NA������K�4A9�i���
�;�����S<G$�-�N��"�Q�-��O0/��x����|�:"i��r;���57��6���F���+�b��|��������8�=����/�ao�s��΂9�<�`�0?E��;��A�3:�Cf��tzh�n��3M07��~àiw
�nS�s��ƵL7�E�圻F>��x���Κ�]��.�\�,�\)����X��Y���S�б����i
ls��@����S�jr�w(B�
����޾m��?��ݸ�?}�nv�7kL����\
b���1�nv|W^1&�͎�����M�͎�į��ߥ;$x{<���.>\�nv|w���ҿ��Q���}f>��J.���߷�u��� 8��+o'��~�Z�{Y����v�;�'u���� �Y@��_��������ѥ� -���:{��|Xe��^V�^/�%�E���<���@�藂�"�d�4yh�&|
�P�^�9�G\�T�k�7?���-��@���������h^�{����h�E�_f����~���=Z������׽h���.�_���d��5��8[J��
~�W�|B��C<X�QϋcM������D�]�d��x8�ˈ/~e�	dR���`Z�>@�
?@��A�~ࢎ�_"��SA�S�b��&r�w		����^^�������3�o�ҥ��Y����������x$�o����r��?*�\��
���S ��K�a�J�<�Ϲ�����
�c�rLb��ưK�~o*1�/�𑆳�i���������7|��\�p-��� t���qZC��7H|���:�L� ��Į������B��d��;��
�_�O�a��4��=�;�8�P�+
f3�N0�.�C�/��
[�+x �X6�E��=�_�R�<������#�T���9�3�2�=��_�4�}j�=���?��	ґ�τ�X��%>�\������%���N�.{�M��'�'����i������$����ɛ���#θ�N�H��G� O��x��+�qO�[�Wۚ�H�� "���a ?=���y���5D�����*5�O���i��.��Xh��ɿ�ڤ�6�P����9�$��>�Ѫ=�8������r|@9c\����>e��q5y��{̏��{����=�GjL��S8�q�z3��o���ԛ�wc�)މz�(~�i��(�f~߅�B��z+\�KO���wo_�=��p0������2<1~��/��]M�N�}�r�{��(~�����=���5�@\�R��u'�ă�li�T5y��'|��ȃ�;�<\���V���D�x���	���Y>}����[s��R���<���j|8�����Ʒ�\�M]��_>\ޯ4>���?_<.������"�J�u\����UmO=��0��1}����������q��Qrmvi���Ϻ���~
��O���py}./����\Z��.k���.o̥�	р�ˋ��:Q35./���.������K���S�T��0渆S����px���;8<��r�ޏë�t�8<o�3+g�pE���f��uY\~�]�Y�N�՟½��~K&��W�&�f�|Vi�s�Ш������Ћ�+H�I�����j�;J��E��&���F	?��c��1M�C�+���H����I���7W��[+�=������~��AB�1�?O��Nh�+��WH�|�T���H?&>ܠ�3
��:1"�Y��c����@��^+u��L��$Ѝ�èa�\ũ�0���jO�g��M?��*Tf��z��!]\�OEo� G'@S#�������ΰp�����7��-m��f��3>�o�ŋk]�߲���W���:�o*��3ɋ�����w0��u��3�R �צ0%
N�����4�F�d��./e��
wr9)��(\t^b��
U��Y��y���`��!�B��>�}�Mr ��#8P��9p�?=�'7% �Cs" 4�I�r6��{��޻ )kV5�_]ߤO:ԛw�*�>�?�I �Rɘ!D��߼ngnقŅ���Y@�6=��uU̜����Ӄ��Oe{^eU=�����ъ�VJ􇮧����TW���ՐrV�?����o��_>��p^+��v�*6sB��h�)�Q�U�`%R����t�-�{��cFv,�7b�������u�<�y�Y=ϲH�)����<YL�CA��P������P�Yˤ�d�W��y��L�|�{�+������ga
'U9A��A����z����R���8�c��@�|I�%alQ>�8O�T!O`���� _ŐǥJ�G!���pK`� ?�#km��2!n�یb3V��Y��.'M}̱�%ߕ >Q'��׉JסrC9��+,��˭1(.�:au]P���S�N�P'�N�ju�:i��k5���*dZ���2:��8)[��Ί8�%��%
m0�5���Y�G&o���1��@v����#qT��'��Z�"��2����y�n+� 3��>��c���.����mơr?��ВU_���) |\�Cz�I�Wu�Ŵ��1>�+D>�C��
��ݟ��{z���vtg�{��{��}��{ι��K��SU�W�Z;A���S����JI��hŉV�h5�ђ��q��N�\W��Nk`����`��
kh��QM=R��Y*C�ʐ�2�#�%B�K��]m�J+��n� �lb兂��ǀ3��ScF9O䦩ߏ��
��2ƪX��<p�.���=�4\⁧z���⁋�ǉ~�{�˓��?_
f��h
�{�Wl�qM�wWQ?�� R�ch�ҥ};�v�!���qH�o3(T��ip�^��@��-Y^��_���^[��P��"U�����|Ho��!U~T�7�/�"�\���JM��E�Qg�����[X*4<6��V2�d�O|������2�?��1�����_�ֽ^**m«�h����n��S����:]F��mSW���i����	�4���Jc�f]�z�Ɔ��.ݵm��w��#�-��˔SC�Qs�2^���r��cZ��B͖G�� �ZS�7����2����%L�Mr,.���i<L�	�I.�o�Izsd��fJm��rqy��}��u)we
�+.w�E-_�6���i	�'�<?���s��;���������e�K�vV����ݟ������;��WW��=��q Y+.ou�'��8x����>Ôz �s8�������!�}8�
��������D}}2�����4���o3�P�C8]��X;�L�,�������T �$\��qgP�Hq�R�٤�(�Eq���p)�w/LYV�9�f�a�!��G�P�yЀOq� ^S�c-|��Ӕ���^������{l�m0��4\f���h����i)�)Mqz����@��9A0>j�1ǆ$1=��_�%��8]~��O�r�ю�>-l��TxK��'�'
�̬&���F{���2�lI,C�5�Z�.R���_Q?b"�%9�'K�d)�,���+N��L����wc������s,��~P��W���_�[��`<��`�B�V{��ҖX4�E\��{y�<����,��K��L�=���i��cJ��=����Y�N�k+�MT�j«e��9�5�b,��r��{k�3�8S�+���|�ꐥ:d�csU_�>IR�$��[#;>�����
�bz˷�k�Yʗ����yz��w�x�5J>D�����{�jB���e�U�m�{�PS|�����g���th�5�h��cy'�2��"����M�?]��V�@�}{L�{\���-.3���ZYA%�C���xG��ީc�۵���1���f���9㥯�]Ҁɺa̜+��oF�c[5#	$ȍ	���#tY��	;�f��/��0�ڷG��������+	�}"g�HṅyĞ�vS���y�^�	S��_�G��
�=o}q�l�c�����#���؛
�/̣l�co6�U=�Z}��9�07[�����75<1��}��E�O�Þb��&-����R��X�T�1z�`�x�^L��_��1
'���A�^�G��-�Q-a��:1-�k�x%�X<�P
���~�:�T��Sӵq�KX��[ ���!�ؑ�7X�e�(IH������^bSmVG@�_�¿'�C��B>��n3��Bx�D
��?<i W�I�
O�p�x�$��I �'M�8�4�j�FL�I2�'M�F<i6�I�3�'M������>���eg.���}��H�pv8tᥑQ܍����Ov��hhD�?��h�w��)-��>���k�!-|T?�����Oh�}Zx��C�P�,Ν
��'
���i ��3v
�+��B�-�U�#����ɧȷ�o#�N����i�I�����[#4��Z�cU��./��|����F��ye�ѫ��5���@ihm+��4�ց�W(]��������n(,8
�����L�ϗ�	����s�c��$�,�;]��6R�����<c�����g��%g*�M#+wژ�;�K�Z����"آ4)JCk��*M��������D�lUr�
~8�C��8�Q2�l�Ű���0�����j\*�p�����k�a���gѢ�w��`ȘjT+��3U�,S#h�k�[Y�H4�'�"��5Wo���s��{uO��^D�b\� �:ř�>,���G�0�-]��h����]�s��]���E��o�tu�{p�1�g޶*�a����Wo������aw�g���[VoZеu�}`��00�A,�`��@��|���Eۻ;֯];��p�ڞ}�.�@�.p��X�Y���gFF����g��˖{�g���J� ���M���*zmapn0,0Ma��$P����x��?���ה�f8C-Pf��0�7KЖ;B���Rk��;'�p6�r�'"z�/ZsU�3ή��Qa!H�dx��&8Ӽb�KT�:�֙���l��s_v�&;�l���g܁�UC�U��w�*y��y�z��:�g����t@���|og�|
��UA��#����އ2�Q,�̩���whx|����=x��!�T��e�i��,��ﻓt��>ɲ}������	ɲ\D}��ڥbp[�I�� �\mc��T��!"(�hM�4ԡN��N�mI�Lǝ�V�q�Pܩ�tr*��L	ȱ������{��wg��d�ϫ����ݷ?�~���.��w��1�]\�&g�}��g���i���0
����lk<m߃x���V ��Q�s6��^2~�~���?|exk�{mmu��̗�gO�ߊ���Uh�C
G��%7��J_֣ϒwT����o�����j�ݓ��IϙA?�3�3�25����������_���ƮY?ӎ唣��L~z���9[��2%k<�+dǒ�R�K�u2�3Bxv,��(X�<�!�
V���uڎ�+;�7]X�2�>�a%��G4��X�\Xٱ�sLm��L{Bm������ͅ�zVv,S.�V���V'��]���zv,\o��x��1�_��'mw��3]�U(�-:��f��{�ͳ�e
I��O����S�����E2��vII/F*��MI�
��L*�r����2��gU�Ǐ[}��ͬ���� ~�Q&��L�0�&Sx0��(C-W�ST�]�!@�1�iD}����d�~M�o���b�:���@�;z�������
~���(p�P`+�g����IV�4�P����J� �,i�/�X�+�p�Z��j{�)��{x)�o9/��lq�Zc����ģ0�1>	�cX��0~�?�c0�0>
fM�����I����w�
��o����scG�
�g����Φ=_ar���0�6�WX��EF��Ԟ����V=_a�}��
�sTx���\��09��+L�-��
s��3���&#_a��O������0���&ǲp}��+_E�+��� _an�����k���T{-�ۋ�c)���n��6��ȳm[��B�Gq�
`�?"�!���1�?�|�C�|�~�Cy�~a��F}^���1�f�_��jk(��/#�
4�[�����þ���m�uy��l�Ώ���Q�_W�l{�}��4�ii�ֻ���@�����v���t!��`랂�i�
���(�"%T��	ғIe�/���j���;��m��n�Q���OSC�*��WSK��jl�������Ƕٶݖ�K��X3����"�UZ�,����.�x��ל��O|�;�R��XxW��X��5��AU{�{�m:�W���P�a�G����-V���5irc��+u�S�|��)u,m�Z�Wl�����������	�E�����Ep���(ڦ�k��g|�"�+~UO~eOP�b��N���u�i�G�Q }�@zS��_-���@���X �w��Z }M`�4.<��s}N�h� �(z�������A�~෴���)�8q�	k�W[�*A:���Q�Ɵ����Ҁt�V)�O�[���5�c»ʋ���[E@:�K�騧�
H�5���t�~j��Ԃܣ���Z���x�Xq+ƭD2��H�[2�Y�����j�'���ή��ӿ%���wK&��2S�'(/��ۻ�(���s /Jy1#o �(o�(o<�>�Uy�I�.	t)��y#�w��<O�1���A�4Ѝ�)#/y��ׅy�%��Ԃ�ױ3A�{Q� {1ag"�r�ogۅZ��b	s\�����iba�Y�>��XFK�� m�f��"(k�2��S?��ܫ����L����y0�V�HI<.��x-��u�Ҿ)Ӫ:ax`zk��L��xb]�X��G���#w�9X�r�e��o@}t]�~�;2�u��2`����?.����+Vv�t��s���T����Vh���{W#]����|�?ʣ��8��E���k�@:J��ץZG�H���d4�@�W0�2)xg^����DW�|1 �K
cQ����H���c�x�OW�xe��7���~w~*��m@�<�}���������]�Z�w]���{�IY;3���u1��uݸ�c��۟k�_���b���r����;���J�y;�kD�=�;�ߓ��iO�羟�du���0��3�ٵgb���&r9�?���R{�;����k�u��a�ؗ���j��u��߀���b����#ZfP�))��sS+�����mv���}�YX�~��%6��">�#�����a��T��xs"#���Jw��+U9gS����������5��$�z�$�]/"j�&��� {�8F >��]ܣA��0�a�A\�A�K!��b���KC\1�0or[�>�G�����}6Y�O�n
C1�)��0,��b׎J}d����!���Q(Ǫ�8C��k����f�Dp5����GX�
���.U��u���_�X�a�|�Et�߇)�I�miݿ���gʽ�Pm�a��V����ck9Y���B?�p�c�N�rK�+��)_�(�N/�Nw�NW�a�ǃ�#���W�N��	N��/�~,0�`Ǫ���g�x��_�p�S�*�9Ĥë�����n�{(�x@�>_dqִlɳl1,�<ES�CE8<�W�����|�8��R=��-�m�߻>~c_���T�noڼk�����ٱcE2٫��k��5,onRW�H�s�����Xvﶻ��s߶e�6�ewm�w�����.i�z-J@ѩ��;�u/3����Cq�5��-�n:�َl�+c����-�:4�>d0��b���ͨp�����G��֓#�����S7�Ԓ��JH�����RK'C�0�
~���~�Vٯ�3.���Ӟ�#[�5U��U��W�;�7ſ�
?P�tak�7�N,���X���
g>�mR�5/y��7t�=����;U�����>�k���#͵}jM�����Z���M>�����ڳ���\�~m�f�9�f�m��}Is}N��U�u����_�����/���z�~9��C@���~���5U��T��[�o�2���+��o�f�Ň����Sr��O��'(�g�����l���߰�?o�j6ۿ�f�<��/���6(����g�U��/}�~�hn���_�n�'��u�tX��P���8��u�|w�u�<�m��ʋ�~��=�*�����V���s�c���y����*�g�ȿoɯ�������Ew��&wy��*�����4릟��ċ_?򻎿��l�S�3��������﵏���GQ�>��_I�'"��h (��m;�s�����Q�ߥ����I>�n��Եi3��ec�EK|}��ʻ�W�vtg�P>Y�mf���T��q~b����	�W���σ���Aa���K[�B��
WP�o��@�"��~۩�����)����,�^{���=���<d���,y����O���/�;���H'�/�}����{�q,�%v�4����W�����d�Sy������z�l����l��?{z����������k���ؗEk5V�c���u���1��-_ |��M'���[58Y_��/�e�A��8��6s��a�0�+b�R��Rne0��8���|��0<̂Ru�<B�� F'��k��1�@P�o����=���H	�
�o6x�����u�+^�V�1��r�f}�9X@���BZ�'���ळ^䗓��r��R�zs�H�[-��n�rh�G�(ط WLw��jg�.�����Mu�>]��ܠF�qR����|��Tl.1�8�H��C��}�����ʅ��@?�!�v�|�M/�x�|D�7�`9~�a�Eԩ,���0�g�4���,s���.���G������p���^�]76f!�W��SM���e4q�����c3x�w��K}x���,�E��k�ڥ�X?�v�o�/�Ɂ�ڼ�z��ŋ�P?��x�OJ}��/�;%�E�~|q����g D��2,�,�G8OH9g@��n�%~*�����Y*�x�<s�����+y������}�KCWg���a����d�t�:h��Ā�^��3�s�L��z�GR���X��i>�n}��rl�|8P֣6b�.y���*yB^7��W�o=}��u���z�.�����p��^�k+-c�lݝ�����RY��������i+=��J�[�-%�pȟ�/����������ʱ ���Z���EƆK�!ݓe/{j��-:�W�L#�?*O�(�<N̵�oϵ��熤
6�����Ƕ�w�S�,og�̨�'��u�/�������EQG�PG���u�u4
u�`�C����W�X�黄����9
,�^h��9lj�<�mb;��J��+��R��R��c
\a��U���<U��*�;�����a�<���$�jB���o���2��[
�s{��>�:�}�x������3?�J��k����}�������� }!��WEڍϤ.u���oB�X�>�<j�7����}Y9/��4
}i'����<���A�|����Xs��WF������r[�ߜ7�'}�c�A9���w�{_�f4e�r�|-�Ճ%=�1=tm7a��#+���&ȿ�C<e��ga��n�/��}r�����|��V6�9 ��0 �.-�8�R�}
��7�����t�����]W��:!��"/�{lj�v��u���2
!.Ԕ�k1��Z�
g���Wÿ��Tq���Yd*�IF2����B$���ͤ҉H"3�td,�ycT�\�l�`d2����	o\?~���n��nސ�F0&2^�aP�@��@w�k�L+	|܂��O,���W�_S������I��-|c��i���J�՚�%7dR�B2�!���9̍��0�/������Y����s����!��q�	O��*����mĳB{���n	����l���a���k�lE���Y�X���?��l�L4������㑣�/pƏ��?p��2����R�h���#�b|�ż�N���t1�ϱ�t���o۵��d�|r25=�e�đ�x&5��S��'A���,<9=>��R��
"�Gͩ"�����]#� ���!�l"^��pr*6��g�,<^��!:!.w��
!�O'b�8�8�U��D�?��L&9
2����ϫr�5���3�M�r.��6�Pj��(<A���Y�A�C�Y�6.���/O/�B&-r4i���`&�Q��E/����E�����E�b#�QF�n�u�H�Y�����I��{A_ï�|z�*�OТ�֛�_EJ����n�M��ӣ&}-�O��J����Q���A�v�kt����A�A��:X�N����t\�*�;�NG|����&�$ҿ�]�rip�fՏ��>��S���%��K������OV��xc��-l���� ���&� ]��n�v�?s�}�k֚�i��e�J��`�~K��_e����A��#	s[�+0�_s�'$�Z����n�_��葒�[ ~�.�� ��־S��
��C��w?h��b�� ���ĵ���A�o"�,֠(��q}R���K��z{Ks�z���������9������#���/0�u6�t �\#�>�c=�~x�o���2��G�埗���y�����Bt}�z�}��A�^]���Gf-���c�G<�=�q���-�՟5C�w@�>ż���#�{����χ>�1�em�-^�?z��5l�ײ��Dlc�ـ�2�]^�����&��g0m��.�X8))$��B�x�dz"R(��E��J�*Vx����}u�K��x:���ۄ�LX
�I�E�"�x:[HV�I����t"�������87S,T�4$I^.sټb|�
h_E��`�p���\m���X��'���Jk�q��}
6� x���Yo��z�oA@!���g˪ġ۪ġOCU����*q��U����a���u4Z%�,]%��p�8����?����ĎH�i�����Ԝi�o`�o��k�����َ?�|#�T�{�?��{2�\���w}����}������.{P{_�韫7��P��G�F����r�����^��B
��T�z�>�0�׼�?�\
�ړ�r��*���vr���z��sgF��ېQ����X]�Tc`��?:�]��G������S�
�K�(��������U��Yނ���f���=�J+<�\W�Ou�7j�Pz�mH���΄<f�eĨ4F��D�����*���>�l{����X�,�۩/����k'�����<�e��Í��v��C˅t*�^I�V?�xW6L�:{3��S��i\2�����[�e+�j��w�Ź1ׅ��(u���[?ݬ�$�UzO	� �lh�l���g�� '8���)���
��q�v�^�7'��>��%�����,h��-�$�i��J�;����4�ܘCF.�c}�)�����z?��|�ϝ���n2����_��<�v�w�v���Y����Ҧ,�+�p�/�+/�H~�2��?ʻ��_�V�wo����ӌ��3w�錮�;U����D���;��}����Τ���P���뻷9���!,ߙ
�'�������w'�s� ��
MA�F��^��kpG� �w
��������q)|���[7��<,�=S�;� ��v��A�p�)N�[�j 4C�G;�a�W��h��vBw�vwu�mr��.J��eSQr��e�������~��Kt�%�]:,�7��R��2�.�$ QL���%8��X��L)^�������k&Q��8XD����;v�!�*ĜYL����T6���.!Q|���*�|�g��{p�k�������g��[3P�e<ף6����4
�R�t~�I��@A�ɧ�B�$�gAð�5'N��-��Z���&F��������Jr���\V*�ojl�_�(Ά�����%9��[b��X�ýKa�|������;{�Kr��qI�Q�;�j?��H��Ϋb��~)��w�3��}�,��%��^-�������r�b�]���_���.g��셗�ce$>.�IpH�K��Zp1;-����f�>m��Q��bJ�̌4k�7�h�
���s�ΰ�J�*��S�,�U��C�4��BߢDǇ�2܋:��;�yq?�xnd'���H�Q���x�9����I��!�A
���$_H�E�d�|��8�|q3�yv�j>�^�4ח���w�.0�t�h<;���{�j>�~D���Y<����_P���� �F���|^�;�|~��E?.Yx�wq*j
I�E���:��c��u��\7�ܻ����O�r\4�BOĆID!����h�h���	7qiP�K�/�v[��\��0���;
��	3��;���
��NCRx-(/�jBV��,fHÅ�Qȃ5�	��e�3��;
Қ��[r
���U�hj
��<c����:���4^��7/Ni:�Ш�����It[�&p2��4�l4�Sx�ЈG�_�h˗��$Ɖ�,k�"џ0��Z��v �-?��[�t��~Nc9�-���@g���8�X�w[���B�-�Y�w[�Q�?4��Q#�m�%~�B/׈��i�-��֔ԗ$��-韶�ϙh���}�C�# ���W���+�vvwW�5���
D� ���ٗG��d�7½�ѷ:�\�dXS���C>���C:2�}�S0�7\�W1��A{���W4ý-�À�ܾD����"稯�9Z^Dl���$��e�/��q���}��똦bPS0�o�s��^߿}VO��i=˔��Y��5�}"=��M}�}?���u^�r,s�ź���hUÚr�ˎs�[�a�~�˳z*��]�r$2p[c_՘�l�J��������(��RG�,Ӯ��/�y�-�D�B�mX��'���c;�
��6��dmG�<䲀�����Y3�?���/{��q���*Gԏ�:�A��AϽ%i��-$ykI����Gzʫ@�
�����$�$�2N���g �~��JjPvw��U$gMQb%���ĉ��X(�U�W����ܓ�>0y_��>�qe�v"rn�em��(�_͞qR�u��BY
�uH\c�ð�$d��� �e
�:l�z;���G�w�s��y�-(	?�z �����:��Ǌ����^	c���p�c9XY��iY��?N���u^
��.��)B��> OZ����Y.Ǌ/�ܨE���ro��a�?�g)�^�������g�Wd���#�?H�gnq�s`��7���&����H��~��6Fӹ����c�N`4;g���NnO!��hv�g�m!�l?e��\�ρ�vp�,���f&��f��oJ�qz���>�i�[z:.)-�~�>��δ�Y:�Bϲ��4����)��rQ_���*Q_�ɖ������3��]���,�y������~�OI�Oi$�)�/h�DFikyB�>�����?��߸FR�NJ�)�r�-���,�<�?Yq��+�@cy?�G��B�_�����V�>�X�U��Ǉ��?�iP��X�7��K����������.K�#���s�2b�YS��ڴ�oZ�Y����n�U�|N���.	�iuԥb���"?�B������.4�ë^��r�9�Ziѷ�B/�5��VS����� ��jjÃy<x�ƺ��Z�S ���;����*v�`�X �i]465�FFpgDS��Kc}Ԃz)L�`.�3�|Գ��XS�tCu#�k89fr��r�L����#"��,�C� ����`����Wۆ;�~�!揢����o�%נ���b�������+����*��{V��Ǘ��s���{%���q2�G( w	����M�Q�fwa��ig�����N�eC8�T��~��R���H�e}���ï.J�B^�jN'~cX�ͦ{3/X��~b������z���%�<^��B���4�4���~�]`�+,����.�<x���!"ع�y�y=�f���`���RY�n�U��6� A��BC\=� 4��с���N�_�Fǀ���8�ⴎ�d�k;���Z�_������M��4�h�͔�\G����W�@O�#����������c��1�Cq�+����_@�欄r5SZ�Íq���X�kc�.�zz��w�Q]�����.$C� ���m4���	�A[�-�`_G(j,��qL�&E�3���?AL\vY�C�L���N7 2}��L�'��ҋ���c����/vI|y~���z;,�����ė��3?E�H|yގJ|٩��O���$��v�'�僫1�/��	�/o��N&O�Zl�7	�ɯ��,�w�$rU�O���҈*'�cx8}����&Qڅ4v��(�S��.�|��*���Ô�<h��]�>�4.�����i,�d��4v�d3��4.����~i�I?��B�`��ү"�M?�S�_�ƥ|R���HcL����@�X��շT��^�X_>�b���������ۖ�#H��Iu�%?��Zh�w��AY퐽 �c4��D�:���s��/��@8��=a��]�'~�Mn�����;�N�9��H��
D^�+?���P:��/#��
(�Ⴡ�����������m{�Y�wA"	���h��Gii��+�&$ESK���B����	x�p�����?4���p%�R51Fs�Wc�%T�B�9o�����.V����y�ޛ7�3o�f޾M�A�����3�x ���6�)����N{hҧ�y�ڤ%'<Zm&�TK{Ȑx��s�I)����6���^O�����2�����| PD*�^b4�lK:RR��k�tῴ
G�vp2PȂx+��=CW�b�LS
�~�<V�3f�$���\�w8QL=��>+�z$���Y����ri�C
UV�Fdx�1,Ʋ )�1��מқ�uP?�,�ʞ�`��w0��%{t�;L���
q�#����³��y1�Y2����p�璘!r�B���!uݭE���W������E��_z{H=4r�[��� ���#�����#����^�P�������\����oZ娯�X9\4y��CB�i�.׎�r�Yf�DUJ��Cp�s�H)�s1F5�fI����YSY��G��C�\�r��=�)���H�⛸��|;�G��T�?G������B�) �Q��0��7��g�wuo2��	�b���t��0}�O0=���?bz�?0-�s�E��´S�#��x�Q�j���o��*�}G�)�<�Z]�|��F�V�ɜ�����P�<T�ԭ^S�y"�\����� � pGWKG+�F�D# 4R�����ߺPU]���
m�������^����o����k¡� /��Uׅ��0�ǜ�Php#1_����΄XO�!�q�v̩�9��F���P�a�cl�]��L,�_#�؃5N
�="d�#;�#���<�dy�l�P�C\�}% n/5D�/���<8}�, ܞ�G���;��v�^1� p�<�p{�An?\P�8. �^>��I_UJ���/?��G�?���ϡY1�Y�}@~� M���~k�Z�� .�����Z%�����#uX@J��0��>=*VĬ�]+ ��f��T����߻2����xV���?)���,�D/���\?���?)�����a���y_��r��K�:��s��T��"6`O/�?W�89�{�l��_+?�����~h;�?O�%~~�<u�X���#�G�?_ǉ�X����QG6���4�}�w��9� �Ix�~Ic<��(��<G�]"�9N���m�O*tt,��G���Uc����!��uA�{
�y)����ȜG��<s"���{m-3�	�����
�.̛_�h<�|;S���	:������=v#��2eJ��(~������A~���j�RY�)no��y�A�1�	�/��ʾ+�
���t�凫��yQ��"K
se��E��2�b����|61�I�ޗ�ue<Z����Q��gHq�$oT�e���5Oj�/e�:��ZIl�IL�Y���;˶�x�.�Bb�X\U0	�J��_V�\p�\p�\p�\p�\p�	�_Z�� � 