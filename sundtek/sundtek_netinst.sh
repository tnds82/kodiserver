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
	echo "Sollten Sie nicht ausreichend Speicher in /$tmp zur VerfÃ¼gung haben, verwenden Sie"
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
	    echo "Sundtek Ã¼bernimmt keinerlei Haftung fÃ¼r SchÃ¤den welche eventuell durch"
	    echo "das System oder die angebotenen Dateien entstehen kÃ¶nnen."
	    echo ""
	    echo "Dieses Softwarepaket darf ausschlieÃŸlich mit Geraeten von authorisierten"
	    echo "Distributoren oder Sundtek Deutschland verwendet werden"
	    echo "Der Virtuelle AnalogTV Treiber (vivi) kann fÃ¼r Testzwecke ohne jegliche"
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
‹ «W¡T ì[l[×u>¤%Z’­'[±YMŸ;6VP‰¢dù'‰×R–ü£ZvGÅ’.íERgŠdù“Ú[¶Èµã$¥†¤XÒ:³R$Ý€u°t@È‰š¨Q›±h˜Ñe+e›ãv…‚¹«±æÎ¹÷>¾ûž)Ç.–ö”ëûÎ=ßù¹çþðÞûnB#û‚©Ñôôc#Cð	=>|6mØÀr|lyû¦M› ½£sƒ¯£}ÓÆövðµwt`‘æû¤’Ÿl:Li¤‰ÌÍpÇÿ?ú<±­o»¢(%ÚÍ@Ôø€NÌ_Ne°¤4p#ïSÐHüäT5ÀÔS<¹'—HÀe;Çxb
1-|'ñî<ÈÓÀ“Ë„ògŒ§³Õ<-eÄçe
K~,èQ¸]â£¿0WMIaé2Ò—…_†Äò¤OïÁB&\.V†|[,:Ø·Æ¢ñìþV>#CÞtÂ»_uØ±çKLÎ)âã	C
Ë0Ubª‘ô+À}7dŒXÒCu_Š©
SµÐgh _=ÌßW`b1é²'Ñ÷ajèÏbòHt#&ŸDbÚ"Ñf¯áñû2¦~‰¯cè/`ŠIô§1í—è~rW¢A×‡GqFhF×Ã¢@o„d6“†à`"•t&Î&!™ŠÆ3CDe1HE‚aŽgõáHF'1ý±H*MÄ!K¤#HFâ„¤X6šD[Çm£qØÑ×»µ[ïðRWÆv‘ÿÀò®àµ¹*bQ.#Ä‚þ¨F;°ÁÎb¾
ƒ6K9
ž£zŽrlìó”cC¿O96|žrì$—(GùË”c'øåØ(ÇÎp•rìH×(GËnë÷üÜ=væ²+ßZpåO–çsy÷Â›…ÙãèÐ»¹î?}aöÚTÁxŸ‘Þ§¤÷Hïß—Þ_–ÞOJïÏIïOKïG¤÷Ç¥÷Œô£÷É‰‹Ÿ¸èR_¼´L›˜wiè?´ÔéS×tk¡Nj|§
?-þï˜æN øá„„y=–×k§
N_.ïÐžý7€½ï*¶)ÿT,^É#Æ<6êÐ|„ÈWÀC1NÏ“,ðw÷úbÛ<ÅÎ½Lêe¼—· L‹zª@òŠ:ïª›˜éÓó?T'	ë^LÞ-äU”kð#Æ7ÇpêØ™†FÿÖ×7SPÞÜøÆ»G•¡ÕT1Ýþ3—‚u:W-FàÎÖ\“Ï\èú×ÝžGyP'.¾ˆºÝP]pûÖ0Ù&€×•ûw]pùº/Ô`rÃš‚S˜W>7qñ0bk‹eß¡w”ñ£L-À·eÕW]¨éüý‚‚<´ÜH¾c÷¼BeQæÀ2ìÚWÀ—'YîlÇs».Àñ3—/0ýÕÎí¾ ¡]í’ÏI›Ï8§¼ÞäÛUòµJ›¸ø°äkRøZ…Ø;Ð6aÉGË\¾÷˜ŸèKù†Ã«Š|Ý‚ñÙr€~âPºâCºW´½+$;ÙþÞ|–“Í{V®Ã/°nüÝó<eÖÅuÙŒ~mQ«„oB?6£.²Cµqóéðð=[ ]çWœ*4qÝó ÅS–«.#÷2Ê-—ä°~"è?GÿIÖÉÛîÙÊ¯›²ã–0&taÕ®ø&¾†ÚcîÅvZŠ˜f¬k³h'¬_{Çöí†£ö¤öúÊk« YÏ¯¯[õ¨7Ñ3‡X¤Ç-ôüYä· ¿‚ú£Tþ®£6iA™õ¡ºžï¤‹úœÏÇûùvîúÍëè–lü5bU›o†ž7?¦Ž²žï ¶¾Œƒÿ,òDåòg„Õ±ešHmášªQÕÖà\G}bï<Öáõz¤=‚F=¯`?WÕ5*oÀò?æ1¡¾w¥žüô=ÃÊ]˜o¦y±ÄÒ8I]óçÖ1²;S¦>LL1L×¶µ~8UN*rù%\¾b ’‡$ÎEcóŽ‰‰ù=¨w{prþÚÑ3nW`ÛðO\TüGpúÛB%Úpó¹`žæÂ
èŸÿu±ØˆØË;q-çÇt›#[? 9XÁßá¶Áh¼-–†žH&ÊDÂÚúŽÁhFëJ&cÑP0CË“·±ó^6ŒE´LB3Ô}ÚgÃ´kbÄ‰„S@K…L$‰Æ‡5ZLhìB¤—ýGx¯UÛÞÕÛ·­GkNE¾–¦Ð4+íó¿Ëe[´áDÆ(½¯¤ïT8w­ø„±?
0r”¿+b-BkË¹Ã|­yþ_cÓzyðµ%­ïf‘nsí›<È×š'ñµçÔA¾æ|øº“ôÞ!lÒuªFak Z÷`ªÃ´šÖy‡ù{ø0_ËÑzu¥È¯‹‰,/bN¾.`~÷a¸íg®Ú\æß~’ŸÝÝ÷iÍ¡T"Î$±Ö=;´‘áÏ…#CÁl,Óê
mØÙØŠ„†îÑ:½›¼ëµ_ûz_GÇF­9™Š¤"±H0¹º6¢²`$8…ÖÛKºöîn÷õ÷ìî…
§[YªT9V¸V*õÊÊjgƒr§ÒèXãlRÀ›>0š	bŽ+X–o¸°¤’à'2o×ÖÞÖLp¼#ÁôxÃâ(ÈóL
¼¸æõK]™Ð‘‡>Ž¿$cÒÅ3‘ýøïÈJ„ƒ™ xÑkod4¼¼‘}(p¸L¥‚8ÜxÿƒPŠy†Ð*î“½\Ë`:ÞPbt4ÏpÁL&ÌâH¸v¦þjìØžQá}ÙxŒ^ð;À÷T„c{;…ïKŒÇ%òvà}œpÔß“ˆë“øÆXØ¼ÏŽÆÁâòBVs¯Gû§ÀÑ¸9éàãÅîßà}žpÔßïF!cì§Dû ëGã¤ÇÉë!Û¥'|OH8ga§¹7êAtLÂÑ¸Œ9ùxu‰ú¸¬ÐOãžæ9§ujèMJ86–7iÃQú#	Gç	ãX¸³âF}%ÍSç«¬û[wÌ~G\qï—Áå8.‰MÁÏ(ª¹¾îÛ’¾ÄÍT›<÷2ð=;µ1?s(£Ô
Í«³‹à¦„]ÂÑþÜ"¸Š˜ŽŸeðsŒ%ŽêõcIÍÇSXÑ›>J/á€ö%ËÊÇùÁ<¯à{«Fþ‰x7Îé·Ó†£t‘ëJåe|lÙõÕ¾‰çâþ£N>'a~ãËB%K_s\.µé»Š?x¥ŠÈçö‡æ`ò(ÑÜr²DsS%š y€Ó¼µŒß7§8Ñé)Ñ•,—hÞ"±½”ås%ºŠåù]Íòñ#Í{9#N/ãø½œûû”A×²|¦DóSŒ³â·ÕÉZ…÷gN³“8W¢WrÿJt=×_cÐbµ°Ì W±Ü]¢Wƒü8¡ÁFßii'|Xü*˜íA=!hã¿!ÅƒFýW¥úÒ%zZâ¿YF¿/ñ²óú ÖçGeìÏJúÛ“v.K|ÂíK«-¢Ï—ì/ƒ-R ýïÛðïKøïÙð£˜í¥`{~A®¿bÒ†MG­þ5Kô{ŠIøG%>Ñ.)>$?"ñ¦˜´!ÿ´ÄÿHáýƒÏ«¶´Ö[Õ“Vfí-Éw8LÚÐ?eóïlI_|ÞaÒ
ÒÄw—ü__‘&£ý/IýƒìÏHú£NOJö“ß°Æ3#Ñi§g%|ç1+Þ/ÑÄø„I?nóðÉVü¬D³þ&ÑöþBø™ÒxQá˜Ã¤é¤“ø¥³'ìOßrXû—ü¾—rûÕÁ«s¾Pp¾xÃam¿s˜ó‡‚óùk®×«™ý‰&þU‰¾äàõ£™xÖïªÃz.^AS¶tÎÜ ýHh˜:‰í¯aÿý‚Óznþ Óì*öÝi=GO^âÿ¡¿
:Íñ½Çë1þY§õþÉ’Õi=—Ûi=—ÿ©­>¿tZÏå¯;ÍñYçXÕ.>ß¹Xô—C£Ëznßâ²žÛ÷¹xÿ
‹ø>ê²út™ó/ñGlü¤Ë¿Ç]¼ûÐ¯Ž8(ýF“ÿß’ðäïK6þ.ëw„Y—9Ÿ®Àùñ\¶ï
máÈc‘X›¹Û‹·y³ÑX¸-˜mÍÆ÷Å_‹ï;¸‹¢íÜÈPG°[i¯ÞŠ›  ªIgÛÐÊög	ð„?ýì³)íÂ¼!hIŒFÚFƒ©}ÙtÛþV2“7³q3^ú@š¾r¶eÓ)ö‰+”ÊDÑf(‹é_÷éCñß’Ù8™MeÒ™ìÐÖU×¿Ø½Wïë}¨_×!Œ›íáh÷ÄzfTÅqÜL–)ÒõpBŽ%ƒ1=œI¤Òz0»p7šŒE2‘°wóÆö{Ëƒtss«ãÎ5u ØXgGG ˆDéæžX@ƒ©ÐHh$Ú‡~³œ
øEbC­¢u}ûÞ®ÝÛôm{z°Z¼ŽÆ»EmôžGötíîí¶rX§ }Gß[»úô¶oh[¿Þßµµo›n|ÎÂ¾Ãj#¾rùýæG-þ©L.Ñ{ûwëfxûwwS$ûéðhC/òOmAwú¥ÏtôñÍÂ%&Ö‚*aÜ%]bð¯xV²Él&meÚ>ÖY™–¯†ô­Ï¦8ÐG‚ñ0VKï} áh\Ï¦#añIPF—ûˆXÆŠ3;MáÍ%ZÆ¨µ`_õ/>¦ïQîŽÓiÖ]1ÞFûSC”möÍÓbŸYe_5åâ[~B#ûF£Ét$6½u©Û{>îþGûúâþG‡Ï·qÝÿhïüÿû¿•çÆûn¾ßªð³;3øƒY©B€îT@34âïué~øYšÆwJòýŽ«,ùY¢a=˜÷;ðIºi¯øY¢_˜ç¦7~–~€[TJl'­
>ûàÞÃÒ¾.€¸+¡ò³ÎþP7%Z¯Pªëýl·q£Àÿ©À«öØÆ{˜­—€ŸÅ–øÙnZ­õ3=×P7ù4àò3Û“?ÛÓÒÕ8+ÇÝn2€>ÊgæH×	z…È³q…G’Þ¤ƒ×)I1@½I:	@¹ä.—\Íå’Õ7oâ²Ù_#â^)lz¨nUÜ÷Òw„Z0ï¢,~×¿åG>›1ê¼š×‡Ù¤øg·KoÁOŠWãMøt¶¤©ü´KÅ¿¿³ÿ¬Ä½ÇàíÈùÙy!ömN»ÙY\@È×áß¯0ŸQMü/mô»ÀÛã?,VÒÞYâÓP’ñÃ˜/,÷³3ÝÒñ|S¯DkÀÏLóˆ_x:Ï:‡tLÐÔVÔÿš€¯miÒžF~‹àÓ¹ó$ÒGNÓœ5ô~Á§ø#ÝãàôŸbCzNð1%%×Øü¥c­å|Ìw€h\p*áŠ'ò]Šq‡‡ÿ,Š_|>äøý]Zkˆ5U4>”Àò²¥e~3Ù5v×‡_ëWyÄ• ó~]	"l8ÊÈ8HŒhs
0Y¸ÐÜ³«wÏtdo_¾»+°Økˆ}:Ñ‡ø¢f8YZßH?øú}aË‚%Ð´åÒ‰“ëÖæ_pæ‹gÖ©0uº	Þ:Ý€¹ulWC˜i†9åÔÆ^È±~Tyïº¥×4'ïSS¬LÆÛðËnÄ£œòNÎ¬“šÖb™¬«GèZ{ç†±#(ûJÎß[w­¨x<—_b~ÇÆŽåvŽÏ©ð—§ëá»èÿ™Ó£mÃf±Xº
Åt.<iÖ¹ëËê=vˆùuNÝ:¬_û™ÌqŠtùÕÃß/ùÏ|Á™P=ô4×üËUÔV» ÛúÜB†ø°ˆéš¬=â1uÊ)àôœS»'Ð!ÇcCþúËøKúšÆŽæ6£ìfÔKú– ­9õÏ±FìÄ¨Â×
Ä©ê46]6°¶Ð˜½rö§sûgÿûÌºN×[§}®7O¯]˜pr?x=“µ=žµÍ =R¹ïç<ðöiL¬¼ü¬m›áíu˜É­möã_á(#§1¹™\gy+ë‚­-«Á_oèlB™xç°ŒÇ`=ï›O³ëíÓµ¢-‰ïøÁ¯üb‘ÓN)·öò´cÃä6»Î¬s³¯M¼_=ŒÇiÛi¶Óf0ãä‡J¹ÅbDu5êÔ&b„1[§‰UAù51¹ò1j‚wrUX·5¢ž¤¯ñÂŽx_ïÄ2ŠQ'âyÛªF\Œ²
Qæ1ñÁôé
ñN²>ÔáxH³Xar‡œ¬±Š}ƒÇjcõ(Æêa)V«0üÛqßßÉ‘+EÂ¦ï€­¬?¯Õp]%úáþÚmž¾2±pŠ>B¾¶ ¯†ÞÆ[Ôûø"z«„^7^ùˆGæÐÖ[".dÓ‰6µ[´9¶ˆMUØ4äÝ‹È¿æ¾Ñ—“ÂsÇm~ÄRõÂ¿ò·ûubŽ3hœ'Œ¾Nýv¤Œ|³$¯ ÿ·c¯é7°ç±ÙÛ)ìÝL†Ædµˆ×­è×¤þÚu‹müô"mÜnëWÏa;ÿMÂ†&â²RølŒój´-Û<‰6U¬Ç£eô¹„Ý Ö¥NèiÂº'Ë`å¹äR‘ËÑ\æÒsŽóŽóÜ€m.8dþ¾ñõÇ¤å7Ù¥nÅß*P?*l¿mw~“ìýWñ3«?*ªwÓše-ë
ý^»?ï$¹FhðÈtƒ^e£ï°Ñõ6z¥^a£ëlt­^n£«‘ÛÃ~ÿ~ü­é uÍ5Pqkk.ã.Z¹»c>ï½Þõëùþ”°¥-j«ÁùßŠøÈùí>5jÏÇƒpj½´ÔüV‚ÿ&íŒ‡ö>´ß¡=íkh/CûÚ³Ð>%)°´¡}í5Äå­{¾t¶Þ»ÞÛa)éô¶ÿ%B³ÏøGR|4LŸþÿ/Ÿ7ãW2þ´ÌßŒ½è.ÁÍ}#ŸJ>›•? ñ…‹>Â¿ÅŸ[¸xFÛ1Ú‚™w¼Ê_>“¯“íî<„*³ƒiûÕ2ó>YˆÜQœgüƒ¤baÜ"&Å]2ë-²Ñpd0;ìF×w€7‰Cç–ù?›q[?ò=²
qþÂÏ¨Àr+&¢[8Nœ7ùÙ™Óy0ÏIŒû9À¼oFgF×÷XïñPºÌûft–4‰/“
×'ß7ëó¾=¸ø™“½»À¼WEý$†ÛêAÏƒŽàK@ºdlæ~OÂÑ¸,çç~v}!	GýOÅÀÃepQ0Û#‰¸d­uv0ì~MÂM"n²¶ü})ã¾Ÿ„{˜‚r÷›I87âÜ‹àž”p*âTµ¼ÝoJ8:‹ÒTóN”\ç$9Ñ÷¢‰Sé¬i@åßZe}„ý.˜÷´ÎÑ9¨j½ïhØý°Þu"Ü—%ÚàMJïÄ¿«,Á{Ó¦O«ã÷"íõ°ßç¢¡wÊè³ßçš[…ñ[ÂÏ	;añû\®&ôS¼Ù}®«¢g÷¹h\sš+ÐJ4·p­DóÚÐxä4µ4î8ÍG»1÷¹Œ3Fã>W`¹Aÿ{×Uuæï{3	&d€€&8°Ñ•d„
íP4ÚÈE!,Õ¤âÇX†15«ÝžÕz”®¬]·Úƒ[DW]‰',ž³ÝÔÒ+v³.Ú‰Ûl7u£fïïþyï¾›yIpÅ³íÉÍy¹ó}÷ûî¿wß}ïÝûû¾ÇW=å¼,ñ\µÍWaX´@-Šû¬Äsù,šã“üÍñ\‹æ£ Ê¢ùI]gÑÏeÑÎ]‰çZmÑµôI}îx.ŸFOÐèÉ=“5˜×× ý#ŸE%‹‰Ýí?¬eú­ô<†C{9¾h&†­t?¹‡àyŽëc?¤‰Æ'hzÇ§”®×ïï+õÃÆBŽR¿ÃZýþU«ßÛkxvþzÿü^£?ÖhÓàÏE×Ç½Ï—z¢awÃôiÎÈ¡CÝ4}äÃ¹¦~™rÂ0zæÎ5vØÞªkìQJ‡ä¹é'+çšðÃ¹f¼Áp®)ß©”ÇÖœÙÍ$Lneé>²WÐ¼<ù+Ã¹fý=Ã¹¦ý¤á\ãÿ{Ã¹~Èp®‘ÿ³¶†Üp®©ÿÜp®¹w(ýUH5`Ì¥®ÑwiùõÎ=„lÓ¹‡ |›ºæï7{švyã¨FP™ô¨0å}YIG®0{€Z”/gÈ<«¹ èÇr'cÉŠ¯Y Œµk¯tP‘¨ 3|5rõÒë-8ƒH·Aee*H-¢y. »o¿³zC]qÙœòrvÁÊ— ‰+UÂGa—°Á†€ _²|( †¹à{ÖÿÚ›·ÕfØ+Àê¿Š,û|ÿClB¸oyÈÍöôÌ¶4äF…²áØ>»ê^ƒ²ÇM@!ö_ÄöDæÝlQ¨†ÑFFÈßÚÈ¸]Ã7dFÂÿ÷°¡æëÌâí|–18þƒ^èóçXþ?æÐß¡ÒÒÒ9#ø/$ ÿa:ð_f÷vù|ü–™¶N˜TÐ»Z˜¾'ØÓo–"&aG÷Ëg<eãÉºVðkÍ°#ž*äd¬¾+È÷fY¢ïpýýl?`é¡®Ó8·`Ú:G¼JÔcéÔza!/ã}¢b2–í“ïô‰üí’qÀQŠýÎTõ~ÝFüþþ˜Oã°#–Ð®rM>KF‘áYÏe¢<·~IŠvÉXž‡]½ÕÚ£ý°ÊÃÚæ¼rÛ{ÊŽŠy³ç•c¾,£ïÙÿ…BŸA¡	ow&ÿ)R!‹Øë3(_õŸb(Ç¹„YÄÆì¨aÿz>ÊdàOv‘/wáoráÏváßìÂŸîÂ_çÂ_áÂÂgËù÷ÖRVŒå¶~ZøŸî«¥~òæÑú– ;§¯c±ôõc… çcÌ©cÆ§ðÕ5¿ÂW×,
¾:¾b"IŠ¾z}‡¾ú~X¡ðU|UXáQøQ…¯âÈª¾zEc)_ÒC{ yþ-Íëˆ¯5=÷o/
ôÌýôÞô0ýV¦¤«›3®ëjgô# Ñe]-ŒÞ]Õu€Ñ÷ƒÆ)èÚÇè{A£Ëºš½4ºªk£ïêvÕ2úvÐèš®uŒ^]ÒUÅèe Ñ]aem½ô£¥ñŸß¿ê©Z±´­¥ç‚0‰¶½ArµåÓ÷ääÝT¡·¹}Md=V ÑÆ–:3ÝÎº¢y×¢‰4o²2¿.¯û’h¬Åg}JÅÒoRùÿ‚|Âm|³þÔÑ¬)eo]-úá$ª¥I/³®¦yæ® ñÒxëñÅéÿ<ÞÚÜŒL£»S!/_†#‡Ñz1ñä¥´VñH2Ö$;¶D›^ì<N'’¯`'Ÿ;‹Ä¥“»éÏD$ëoD›!Gzò5ž¢?õ9m'é/œ«îÙ’mJ6NY÷$þ¡{Œý;Á~¡5´–±T(oèˆ&:XUy-c¬"=±†’·FPÑ¦úÎDCÏ+8É,–ÚKéä¯Ï¤Ó±†Þ1õ£M‘NZÃ¾h"Ò—w(ìÍ;Ô´ÇÚ:ýoÖMìžu¸öCòÕi‹à½Ÿt—îëiÎb)d9¼öç½Ôs8;Wv\•­•ˆœ°j¿.ÞðZ4^ -‚okxÍ¬Ð°š¨x}j®È¿±¥~•2¤Ô_ªRÓ!ÕÀ¥Æóç³V>×µÉd
žúRUa*¹BHðÓ„ä3BÏR‡/ƒÔ¤3ìÜµÓ>n½Y÷ö3NG4ÖÐAêŠ©zÇQÚÇ4u°r"^ég]	Z€áÌæyG6×’Í6–MŸ’MK&±J&Öß=#Sb	Ï£-ÒÏÈv6"Û’¼4?zÄ#Ç¨j¯ÞX·V¶èYŸ8¬OiÕÙ´viå€lšX6I=]ì&–b­¸”çÑIñáÔcÔßžˆœº"Ò»óÒD$yE¤ogaâºTbe2Qêp±5<_øÃó96¨+è…ëN%êû½‹ão,Ž·Çÿ?{8j)ìâ
lÈš‰Ès˜>šÿ»õ„â¼éÜ *ßì¨ŒïöE›f{ÆHeÓ¢þq4ŠovVÒÄde¼.Øß¤³[ª¢òÒ3‹ãg—Æÿ}ãŒgiüD²ûÚ‡ÕM-}ó~eü½Êøï®ŒÿÏâtþ¿Gc­FtÁ»õF·éØÞôW&6*é¯@e¢.XT™ØÑY³uÃu·¼ôL«Ý˜L1<…FcÝ¾h¬/]ÿÑª[Ž·²ûÏ÷iÙTËðE¬Ãðñ2ˆ‹—Ì^f¯Çýð¼»|Þ¾]Œ)ž+ðÌ‡^mnÆ±V½“$ ÉVÑùàkhÜ)î_r?Ó¸w1vøOÎ(_³Áß£p ïuÏ@`ñXÿƒæ’\ù¬´…ô¸Ñæc6C:Ö_qÿ{Û˜®—;E”›/t÷œáw ¼@ûvQ>ó•qÍÃæƒÙwŒÇF}ÇÓä}ÈùŽ7FÂH	#a$Œ„‘0FÂH	#a$Œ„óÒ"¸Ñ2È½¹Ÿ"÷
BŸ%¶1ÉNË=‰§üãÙôÝˆû-ßû«¾R®/x8-÷.¤»-¹g!·"èD{ï%)öuä„OT\®[È½‰^,xNÉ÷ZîµÈòFk4üv"îõOZöS %Ò¿¨ ÷«õp›8Ow‰ø>GÄOŠøÇ"~]Ä?ñoDü;Ÿ±B¢|‡ÑEO%ðÃÊÏïé…‡ Ï‹W²ßõq¥‡…,¿ç­ü–}9Îþ)ÇIëáY»>Ö¶_÷N³K‹ç‡JêÖoÝT]·­dGÅ¼µóÊz<àâ‰9w`»¡³Ý¶uCÉ&fTV¼ ªØ&,^(+.c¯,s·l¼D`v^*{×çRYcñg¯Ìöø¦øfú&0ß¶8?a‚Ã8=6—þ7Ä¦½ñ9·‹HÈ#;Ë£M9î<cŒkë•„®5Z:MÐS`\kfqž„ž az)ë±/¶ÚwÙÕ–Ã{²U_9À=y†à9‚>¯Ëv/±lîË¦±ôüd…¢"–ÕyÝEÿÜaÃËõgr†½Þò†½~(wØÒfi-6†°`røÁ¦ÿxÞ™b3K¦µë·®¿kSõ6I
K+žtûí[«·KŠŽ„jù[èüßƒj…`ã°8=U“×ñ2°•R±6Î‰ÓM^Ÿ§UÛ(ù\p@0¤?a9?«ø*øòþXøÊFÏ}Zýu}T›+ùœ!}BVˆK,ýþ¯Úb!Èç–*QAË-¨zÿÁF+­Ô_>üJèKÛYS‹aWuVÑ—Ï=B?@2×_à‡¼J~ò9Ç/
”íÔûOò¿©éËç¦"¡ ïš s2è«>Âä|ÊvÊÉ Ÿíš~Ôšo8Ýâ¢/ŸWwkú÷è~û´¿“´|’K}9?Âc5y½þMÄyýµý¡ÿ–&¯Ÿ¿¿Öôm¼ §õ,½ü§5ýv¡ß.ôOQþóD±¹#*~Ózéú5ý"¡_4LýW5ý
¡_1-³¼N·ÛÇ:‚ïäô>åúWõe½ŽkåKüXçôÁË—ñÏ4}ùž’ú–Ótý·4ýU·µ*ÀiýúÑëó.±mYyB¿6Y^?ï§x¤¾fBèÀñ"t“s"B³ÐoÖøúxøÔE?  £«µD]6ÛÈ¬ïëtÙ|ý'…þŠ!Ê¸èË‚‡jÿ Kš…~ñå«×¾vó¸SÌƒh¾˜éý7Sùëæñø-ósÁÛÂVS>8ù¦õœáä{¬ç'ßk=8ùYÖýÞÉÏ¶îãNþ¨Œïí°ñìÉÈmÝOü1Ö}ÒÉ¿Àºÿ9ù9Ö}ÍÉÏµîWNþXë>ääçY÷'ßoÝ7œüqÖýÀÉoÍóNþkþvòó­yÙÉŸ˜q]6¥ruò/´æG'¿Àš÷œü‹¬ùÌÉÏìQÐãðv§òõ§`É¿Ø…?Í…?} ×l6u¾Ï…ÛXßÐÎû%.òÅ„ûÈ×Ï×BÂmYõóuá>Ùõóu“(w…V.{ÉUúY^ß;ÙïR£õLä³g˜õXÔ? Õç	QÿÆ–pþûŸ"/¹´«UÔç!íºpëÿ·]øï‹|ˆv=#ø¿ü¹Ÿë[}.ù Zm˜ÇùEl¢Oòµú_æÂ_Äòx}][Õ×ËFf<µÁ}ÔMˆ}¯¨|}þÙé’Ï“.üŒÌv-.ü.ù|Àøç½”‹üYþÅ&î©ö<)Ÿw.g–öÛÈ›dÆ¿ÊÌœÿj“÷ùËïDÝé"Ÿÿ“ÛöêóÛ“.òÿ(äwhò/¹äóºK>íà›¹ˆð¶¿dòî_ÂÙ¹j[ò¶‘ÈðŒ‹â¡œ»Ï_;cÍ;OVÄçàçÝÅA»îã=ƒkwiƒ<ˆ÷uØ»èÎÞ…èà¾Ë¡¨ùçy9ìw2Ùý:½±3%V¬Óñ»R±L~ÚY²ÓûºÓàX5¦Ö}Õk–&ÖßíÑÝÊs=Û`Z÷ŠÏÒÙÉà–ÒNßñHåÖà¬À?‹°¡æë)}>ËÜþ·¬4²íËÊ¹ýohÄþ÷	ý¿s9þF¯kGýbƒþßG“"RHŸm-ÿï»¨=ð‹CõÿŽ÷Þ»½>xf@lßîViTÇË‚CõïžŸG§¼>AÊ€ïÕ¿{M/¢i8€Ç!möpÀÒ¬†–#@ø³„Lƒ­l¦¾þáa«–{”Rfûš)8ýË³­nÚ:¨mëÑgX+”ö©¹ZÖ²ÏdÿfÛöù ïð.žC†Êoé³[ôK–¾]£—h4Þž:÷z}¨¾´PKjô\^£Ñ—jt±Fß­Ñî6¦Úå29-µ~aÆ²­Nv5©¶§¦ÃötÜæÍ¹8›{ÏÏh“<"Ò{èØƒo²ÏëƒŸy/bJûÓAƒ˜ž?b: òÓAQ€˜Œ©ˆé  ¦+ˆ˜®"Ät \Ž˜–¸2þþòXÊ‹OK’[v·ž¢ã1ñ(6¾Y—•d–R•0ö¬¥ƒ68é¹}´fé™ýô?tÒ3QCÕÖ5å¶—ÜÖ5®A…­'j^ƒ%$aë‰Ôˆeë‰–ÔËÖ-ªAç
[O´¬¦‚X¶žhaM˜X¶žhi†¡°õD‹k°Îl=Ó3Ñòlt…4LKéG·Åÿƒ™~.«	íE®ôß7ÖLø¶×—\Âí>EíZTA³!õ%/hGÌžJÿ½Ñg6­Jwç†Ÿ^H“Òù`þ ¿tlýðhŒU·¬i¥YÄR¾Ø¢ ºPØ{6¶ÔåÆR95à¥ÛcGüÌÞ3þþîT=ÉmWÙ»H›7xŠV)ùmÛŽrÇvšèÃÔÐÔØ#3*šˆôÄ½Áä„=%§~Á,?{aù¹DˆÂ¢²±×²ûL©vŸ½–ÝgJ±ûL)vŸ)Ëî3Åí>Ñ¬
YÕDÄ‡Rß=Ãêkè%y{%¬)>ÌsM‘yU{!ö1ëTÑYXö©¯†T¤?é·L?;bÌô³Ã¬»°û2Ú#)ôlGÛ"ìÝó(sT‚2{˜mçInþ‰L˜õgÊ¥"3 òüK/9y¼µ©2è¥# ýÍ~Úœb©ñëŽ£½DäH¬Â¬Ÿ•Xy$ñUo¬Å›`ç¥‚fƒJÛ¶ xí”Ò—kÒWéz.›,`'éX×wM¡ã©ÿ’¦óe¡³˜ëL‘É¾û‘Ã2“«Ð¬lÖŸÐ.f•é€d-3µ<k8IêfÓæµO‡}Ú˜äv&ÙCeb-ÆÀŒþBÉèºA3šÝ/Æ Ï¨ÝE,›vÏtIÿ€×Þ¶–NHò· ){:SkODÚã‘vÛ‘;=ŒÆ2É8“ìTë¨fô¥ÓÃh,“s{ÓAËÄ.â¶ ™ËÒ?ù”eÓa“r¬!eÔoMD:¯ˆôì,6£—%"I:Œs(I#MƒúœýfzŒ]_á’ù\ÒÏ%sp¡1½¡·zû¸ž´=Æët,vdÅÍkšÖ÷ã
_ÓÚT7‹4½Æ|Sú¦—'¿Fîn}v"­k*'ù£OÒé¦WtbhŠáÿ¥mo¤ÍÆt]°ôãDÄÏKÍá—>Fuú»?Tì¨±àìÖßÄŽäÜrÛÚ5­‰©A>ÿ-atÂíÎ¢Ób·7á5h/¦Qk.–÷®"Zƒä­´7Óûž“pÏýs³	#a$œ¿É':{'&üýÊû€Ÿ:'-âh}ÇÄû×Áûéó:OP—)ö(äwÀÔïõÒéŒùn&Œ=\à[÷Ç¼>ü~‚ÆÄIìï‚ã³…òB]€#®Šyõíùa…¢§l½kh[VÓãNzÜK½ôxœÿ@WèñSzüšÒãÓ”ò@Þ9 òºql¬ãõWÏ.-ž[\v®Ÿ!OUÛá|©š¯èãÎçPõ7Ëå^´äBðsÜ!Îµ/ØùÀoÓá´z¼só¼ŠyŸ<h¾€ÛV¼íÚÒp[º€¾¤»6‰ö?%üå¿¤îµ%6”kñÜªõÅÛ>¿Â†ƒï=Ê*ÄöøÜ€²ŸWg’âb|ivcuí¶’MÕwUoÝ¼AÅü*ûì´f™!ž\£°¤pÑêÂM›JJÚ×kÒ$OŠˆ43›ò«XKfel	íaZ”ÝÅ/ CË3Í(,,ä¸Ü,ƒÌs¹Í!ö„ÚÌ¢ŠþÅ^û:”éÈ¬œÈâ¤’~îxÚÏ„¥µ ´ÃEÒþ)agUŒ,[Ó4œß=”€Š…ekÚ¦ŠY•˜WÜ;öÜîÁ«Èá˜Oll*î)Øûìº±×¿Bl*îAM~ïÑëw5±±¦¸wTy8>V–kÊ6SŠ{ÎÇw©å"`]q´ÐÁ=ë	Ü7·Ûz‹"‡{Ü~¿÷yEû¤\=±±”ï^¯W&ó­Uä0æËiB»&‡CÅ–b=˜Ö
ž3×WË'îY–+±žh®±“cœøL)÷°"w¾T¼ ³ŸÿÇˆÝckÍy™¿C°O‘Ã‚ÒT¹*rXD
º|'á9bcÙz_?W¿Gü_TòÃZdO†üp¼¢ÈáÙ¦78Ö„¥\«"Úçõ…\¾»pœØ˜D¬˜U¸ÈIì¤û‘BË´·4¹¤Ÿ›ÆÈ óþ@Ï>ŒÍPòç4¹Õã8ACù¡ÊÝGå¦eÈ/G“Û7ÁùY?ë×Iå&gÈOÇô's<w€þ=…òé„üÛ0¿§€yû{
5Í3ØcÑ¼„ÍÏæ)NóQ'Ÿe­ï)X4 >aÑ¼7ö[4·ó> iþ‚\nÑÜB×?§ùIË^Ió–“ÍÛ¸n9Í¿§ÿ”¤ù¬1Õ¢9Â5hÑ5QdÑüNÑcÑ|C­×¢ù›®Nóï)TXôÐßSpÒ“5zŠFOÕè‹çÙí{²ýðžY¨´X«¥ýÀjáÚ/ýmÒþ^&ÚÃˆ.dß_Àš¸WÐØß¹G‘×ËÇ<^ ”ýy~ð½„ïiåã»(ûöÚù½¬åwé´¼‹tÌ#×?èõý‹ ßÒäq–ç˜ª>¥?ˆé'£'=Õ°Ï¿aN 3ûüèù)ŽÑFú^þ9ž–_eØãôMŠ|€whô½¿r?n·–ÿ£†=Þ=zLK?¤ÑGçþÞ/µôßj4ö¤dûü´}ù”.ô8s)Ä÷
ž’ô8RLil«¬íS¿O€üª4z½i_À*}ú
½U“¿_“kéß×èç)ý¸ì3‡¡4ö{.öpú¸iÏ/øžƒÄ4àÒœ¹s	ÖnÞ¸ÔüÁðK%'Š&äWòhíµkkî õ	Yß—v……4tRHß+Ö!F¡!àS¥ƒÀ•4`™§¤¸B:
+äü~4:Ú‰¸
Ix’o
 4!/¼$ÿ/{çÅyÞñwïVÒ:ÁJ=c¹’¨•Vô!@á"G.?†Ä
Æµ[Àƒ¶e‰:>¢CÂ3(gOÂ5¶H°‡êR×MHJbÙ! #2#{ÔF¥–ÒÈƒþm¥Ubìíó¼ïóÞûîêN:lÀžŒof¥ûîûìó>ï³ïî¾»ûÙ½YØúõk6ÁÙò¬{ÿè8¦/>Ÿì#ù¯Ò«òë’â3ÿU\V^¬ø¯¹È•VÌù‚ÿºŸDüWÛ.ÁÕŒüW+„¿ÓÆð_L]—|>„10	þk†èÃ.þ‹Ï{Êž|Y‹ÿ2aoFaŒÏáo_BÝ…—ÁÉå/‡ßÂùYLñ[x¶gn~Ë£µ[æIò[ò<ëw{OòPõ,>¿e¹ô£ô}#1î+HÐò·»üás]Ù5Þ“»‚•T~?é©¤›IËß<XKziùÌÚvª_2îkX|~+Þ‘^1]Åâ¿Ÿä<fsŠk,—%®¸t!]
ãhbbña.:›Çs‰{Ël,Ïõ$sò\ÏRùÙ¨à¹ú£‚çˆ
~ëBTð[ƒø:ÁPTð[ÃQÁoD¿5üÖ¥¨à·Ø¿…oEÆGP«Ôú-8yígÌžÓEN«/*9-¬Yç´0ÓÂHtN#Ò9-ŒLç´0BÓÂHuN#Ö9-Œ\ç´°ŠÓÂÀtþjòWAÁ_‚ó³Á»ü•¼çoA€‘Î«ñ—ðGþæÕ5ÿˆÜ„Z´
\Ìié4¿ a¿qÿE¬ÇÞØ~ñT
–°˜°?È Pð–%Á,ÿi³ çÙ=Âf“•ƒðÄÓI1YÏ9˜¬_~&LÖ{:“…Ûk|&ë&«H2Y÷&Ãd`Fü“U3áÌÉÊ%&‹”¿Æò—Æ²î\õÕ–¡Pëò§k.‹YÝùú		LµÖ?]óR=¸:]sw¬—"ÛGv¼Y~ìƒç§<õê”½»_/|ew×”Ÿv
\ëÇµ¶Ÿh¹Å³½6²ãDä+ÒÓÑÓ5‡·qO‡ÈÓÑÈŽÃ‘å‡âyÊ|›'¬óÝÃòçÝ¾Êá¯ãtMôÜß~Ÿð×Ù,ßÏßà"r›Â¼J>ÞÿJ`^ßÂdýPðO.`i:ŸÛÛ²£—5ÌŒÔô&–Ç56ÕcÝœûP¹Y:®›ñæ{á¦+Ñp£á„ÔÓÓÂ	ýàÂ`”/ñÿ®HMWkÍYa–U~˜DC¹å-Ü²OE¨»yïI4”[þ·ìOØPnô7ˆ×P^þ¢prºf g¶ì¸Àñ®¾5ƒˆwõ/¨B¼‹0­~LõÑ&ÒŒk}Ç´:ùvµHX…¥%,a¹!±Ü -ÅåîËI¼«SÄÔÙr2t×ß®á€—ØgÞ¹ê¹ö3Äº^€ƒöàS¿·mþð¢@ºžhç`WÏ+£žy§¶Ý@œWO+’^ÄsÝ6ïã­#’æûÕÖœ‚Ö†s°šû]•åôÖzjÆµ#C[»òÉä§uxlïÖ`¬9pÐ:¤óap,8ˆãÄ–Q»!¯äü?àa
>-CXvÑDjl˜à[ýøÑ“‰¿Íã&Æb×Š+»ÆÜX"¶Ç18¤8Ù"Ø–ºþWKlK±-ûˆmÁçlã±-=QÁ¶àØQg[ˆmÙ’€m©r±-¹Ÿm1£j¹÷Á‡Îc²õ€©¦[aúL÷Â´¦fi¹ýDÇGÊf•Áøsü9å³Jp 8îœd–"þ›²:§2B|
®Ì÷K¯~¯Ið*¿‰Ù"b}½Ù"Öƒü¼Íœ¼Šþ2°(žU^FøD¶bãúõ7óðo–/wƒÀ‰µØ8Þ+í®@-úw'rRÁ‘ÑHþóèÆ©kÒH÷«ð®A#9Eã¦j4ý*“¿g†$Ê¤‰ru“á|^Šû­w¶‘[”;ÿÎ\NÈÀLìÄÞ|˜9_¼9/ÅƒÝÙ;‰Ìî»¯¨èæù¹œ}éøìZñjnMÞ,ƒb‚¸Yyýé/Øš[“ìGgiøõ¡$X~'	–UµI°4xÛ—KƒÇ¼8Ö¹ãÓY<Vå&ÁÒà1®*	–F27±4xLmðŠcíx,nv'½Ìq'Y¶CgiúÁ®ìŽ¹òìfiðÚ`Ì¼Oû¡Âx,îF`° ¿%EÖ«³4AØÊ‚é³4C`7”KÃ¯¦OÌÒŒ‚Ýh;¥ÁMÄÒðë‘‰Y¼t6Ž?7Kƒc©ž€ónñXó Ô›á|ö3Kƒ×8¬Œøíp³4h÷-M'biÚ2Ä;å'K3vg’`i^œâÜÎ±4o€ÝßÅñçfdª2_ã¶s32µ×6ßÐƒ×C12£°‘j3Æcd‚.F¦ÐÅÈÔº™}.F¦ÁÅÈäº™*#³ÅÅÈ4¸™“1-NúcZ02m1fFô¤#Œ11‚‘r12¸Ý	-ö£1Mo‹:3¦ÅàlLF¦'¦Åös¡#cÅôÕgdœ:×¥óÆ04—.téÙ.=ß¥;˜ë£F&å˜«ß{(óLnç£1)ö¥QÅÄàµ2~“	ææø8 Ë§ò÷èhõYƒ¯~d\F´úgtþDõWª £³ÄpÆ³RcRÐ¿;:ã‚ú¬K÷‚1’Ï; ßý*é‹.ûÿ5TÿAÇ _ÞÉ×›¿Æ“‚ÌŠÌ/2$¥µ}`ù<mç‘S­KßãÛ‹¼§²žÊå=™íµ}!“ó¨Gõ÷LÏulÙP|/¸âÅ÷óè÷l~AåòžÍ[¤å=¼T,ÛŒN Ç£sh¼Ô^Gí›Aû8ygiyg™Wm˜ŸÕ^g¾6»týkö;ÉŸ¼G´ÇeÈåÿÙË{H?ýcÙé÷$fçM¯Ú¿dÂþå¯Úÿq†gÝ½ÜÌçwèO<PVY1{Ã–ûgóÛIP6öõE×æÌùJ¼$I£Š**KðuHsç% ®ÎK’®Í	xò\Óå@IüŸ;]1J)\õya—>®¤§MÎrccq‘¦8,Y"Êi\¦Ih_ÀMÉ|ÖoÚ\_¿¾¬ôjÖ1>ÿSV2w®|ÿSiqiE1ÿSiÙüÏµøpþÇ£–<|ðmXÌä7c×Ÿåó% tÞpÈ¢‰‰a
Nd-š˜Àa2˜RïÂ™Ò%&X^„‚£OƒŠ	$·>†—„Š’YPÆ'&N¹]Q`ÑÄÄ,_–Ý×ð›¯&H_žøÄOJh~ÿ‘ì‹ÿàIÄÜ¯}¿üÇág–edâÐnáX±–/þY.ÝöxZÞGö+@¯…ÿ¤o½Ió7ßb“ñ~˜™)ê/ƒrj¶Qùý á!éVÐaøßAz-hÄòH?ºÂì"Ýo&n"ý(èø?ü9à¬¿’Xƒ˜Bƒ2x@^–ÀÇò,Ðùà¯‰…\@ðé;¬gã:úëÐ”ßaý¥Èï°îRåwXO>ùÖ‘_~‡õ3I~‡u“.¿Ãz	Èï°N2äwX“ù÷}ÓíÏó|›Á
j[\ËŒÌZ6éKaÐ!Ÿ÷ùÊé,E˜å‡f¤7ÖMg•b™a,Ãßü^Í~ìðä¾Z#Ã”¾Ú_aÙÜŸx¬©Ëó|8—ð^×âfÀåÀßté¿leÂ/_Þ·¨Ó2ÀGpwnfoûÛ,0ZXý«^4`;›¬á3›Ý
>Ÿa•éÌÜ1âÉ³†W„Íézyõ3öˆÙØ~ Î Ôçky[ÄõZ¼mP'Öõ¡Î§8ce¡×/„nÞÆ*7[·M·,ŒbR,ŒcHä'^û¦ØÃÛý¶YÔf˜å¡Eéó-VùÀä¡Jð¿ìTIs­‘þdhímy°<L¼Þ(Wæ±ìp†Loce‡ÉÀî1²³p>.öÖÌ0«®>ÀV¢=”vç±œ:–zø1 ¯æ¨-ÏÌ†>P®•y¨ÌCeÙ•Ì¶é{@~Ãòzw®c,ë‚¯×‹ö¥ëîn¤õÚ)ÚÇª ýK°}mM¬â+Tí›ôï±¸a¢ö¯Äö6A®xûØ$°{Žì8—{ì“ ÖÝhe¾‹˜o·Ÿ™ØÐÅ`SŒmÅuEß=ð=ÛK¹_`ÿû"˜¿DÌŸ‚uÜ%òÃç¡ï?³ê˜yÙa|ÔŽiÒÔS4A^ŽQ^–A^ê(/•mÏ²*ò±VÒz(‡z« ÿ™a8Š _^wë”%µ†ÿ5Ì	m#ŠU_¶*Á²µ°ìÚ²Á¥öGÛ)¿ÕµÌ3L>¼P¶,eàãvÍGÙù¤ÝRûcCó¥œÕÁr~š/ûÂ¬ZÃ'ûAÔ]@ÛW%ø,ÀœìŸ²ß`9÷}Gönççí×}®‹ãsõ>kd?Ó|Ç±›Fv>è…cËÓ>’~hú`Þ{8sË§P9ï£¼ß4±bwÚ÷“ÈE±«¾'h™|WÜÒç×“È…Ûç<Z&'ŽOÝ.“ì²)®òÔ÷¤ÊE6íËp
‹˜­¦p-nûUaQ_€tõ›ÕágY~øe–~‹e“ßï“?è_¬ŠìÀÎ» Øå‡mð•³ÿ{ÚFªÅ~L,õU·½2c×±Ø1n'³Ú² ë`ûÍÁãÝ­Ï²q¼³û›:ß‡miô¹pn˜í¼%l†ülå‚ÆêüÃ/Ãq°¸å™°‰e¡¶24mjýÖ|ø>+äÇ63ByƒÕ‹Ãö`ìX	u¶äÇ°l8†åÈã&Ä•}9qA<>¨;Ð4P»²éÝ©õÞµí"??>†r¼M}Ø86°™Ûw³}¶áG&ŠéÍn»þÍ‹vã¹t;|n¦½ûÜR»íÜf{ÿ¹ˆÝqîˆ}ø\·}ìÜEûøùt»óüL»ëüR»çüf»ï|Ä8Ä<ßmŸ¿h¢¯=Ýöñ=í{ÁvïLûäÞ¥v×ÞÍöÙ½»gï»wo·Ý·÷¢Ýßžn´Ï´/´/µÛ7ÛCí{¸ýˆ=ÒÞm¶ÃzD_¯A\¯A\g ®3×ˆëÄuâ:q¸Î@\ÝPW7ÄÕquC\ÝW7ÄÕquS\;!®W3Ø6C\ÍW3ÄÕq5C\ÍW3ÄÕqµ@\-WÄÕqµ@\-WËŒû,Æ†ëEöÙ+#úÅ8u¿±qQ¾eÌ›a™8FÃ±ô¥Ka¿}ivØ¶a¿’-ûÏ®<1ÆcÃ|öÉÔu©ý»_¹Ç¦–±Çg±´6‹¥/©ÇéIð|ã}	ˆ>†LB}IR}ìsõ>¸x< <ïVçß
´˜ÉÏçá|ÙxÎ¯—Àÿ‹yvÁÿTÐû˜8Å[FcA8ÏÀs^<÷A{ô…çÁ×[Ì‹züÇùhƒš¿ÒøaÛþæ×=,b4àÿ0è1¿›ÌÚÀsºn >Ÿ1÷Çýãg•âÞ/åWæÛ‚ÿk™óµ9Üþ×Ò>°R3 •`¹±-æ¯‹ü1ç#CoQ½IrõsÃÖúõ7ÏS|õ°ÀË©d|`.ŒÍzœ7ÑâMü¦
Ò±o©¬ûÆÖÛ®xDÔìõë±<^<"åºê)OR¼’)Ë(fYÆ8Ü"|^æii4/“øûéqc‹¸ÙyËŒÜð‡ÛŸ÷&˜¡ÏYëMÇ9ôÉË•"çƒMÈs6é]Éš[¼¥šùñfOûT3ÿ4ÎÌDÆZàßýlrÿ#÷]Þ +ÕEH[æ^SÞò2~xþ+€¼„ãv©Æ_Š%9…¹¼püòÚ1˜LÃ0ÅõùØ5zùƒaŠëè±kéò3Ãã>&X©•Á0Å8†Ù8¦Wð±…Ž Ä0LxÄx€	rµzc&Ž!È®Žñ)!†i’ÔÉÇ"W;P?¨ÙÁ8…]vÑ¼4»o’ÿTqçÇr'
$>;4»*Æ§I¡8v-ÊÇ|Œo}´²ØúÜÇøÄÂÂm·GÙM9Éøäø¸ñJÝ.F(NÖ+Æ|˜¯ü'ÍÊqŠk÷¯šÅ‡/ñëýf9¶‚Ì9Æ‘ýå#\SŒÿb÷ŽÜ¸æÏ57œâÆ×Mvi`7v0¼¦ìpêQþpü›é~¶Eúû%Õ“ÈN¶c+Ù¥ivgãø‹ý¼+Øõ’ž?éïí;#»xø§ëçZù=ŸFÍNÆëúYV¼ËãY5ÖŸ‘ê´¢My» ËîÛàïÏâÄçÂ?§…¢ü8v.üsÚÚý¡Ï[YBüóË`çÿac>tß“ß%]@ÚCz	i/é}¤M¡ù>5½Aœïxc¯Aàû0Ôi¤¥=1S|Ÿ„Ú/´)ã™DºŠtºÐ|_‚:@ºt†Ðbßà¥{›šæð''¢¶H›)àO±ýrEZÆó'¤e~è>ßæPÓý)¾m¡ž*t¦ô½Kg»ô¤{I;àO/sÂŸ^×OÞ{ø:ê\—Îsé|—žîÒØÇbýÆdö{LC·IÏqé*—þŠK¥óCì\¸>O¸ÊOËõcˆõóŸrýbýüZ®Âñ†)_8Ä|ÙP>Lå×ávõu¨úŒ‹¥dkz.èrMÿ%èPâøŒ:ðoªøŒuxž®â3’ýÍàýÍ9ã5vã	Vß3 £Z}®ü?rjO®KâÅûÕbyO¹ÅRa?gd“^è²¯uéU.}¯Å2°Í•YbùzÙ¿óy>=B9Æ»šÊ[Aw‚.'ýhÌÇÒßƒÓ‡Ã -Òÿå‡@¯$ýÐx\+"Ýíä<çayÌg5•ÿ4îË‹I ÛŸOÚ}	´Oho:ø©rïõ ·¨å½7AþqýT‘.á×àO€z1Ø?®â÷.·Äneé»eµxþ¼[hU@åÛ`ù|­¾&ÐÕš¿øÃKøAÒß±Ø?ðþ“É÷_Þç < Úïý7Xþ’ÊŸ÷h/ò9¤ºAåßû&ØÓ4ä/£WËÇï@Wí7cÇ|Ñ+²\úÏ!žbUŸYîä7ÌÛäþ9‹ï+ÌeÏãjýš«¡¼HÕoÞõ©|™[ñz(µö—æÈ/ÿ•LîOÍvð×«òi>ëäEÌàoµj¯ÙýÕ’î…ú³U5ßíÓì‡Á§¦/ÆúB§øÀßnµ¾R‚N>%¥ ì£*?)Å`Ÿ£êK©½IÓµNž%åN(oTùHYºJ«ïa'ï’²ÓÉ»¤„ú/¨ü¦ü3èÕßR~ú¨ÖžŸƒnTý+åu¹½[|{Oùo¨¿d•Þ§¶¯”Qˆ¿€ê
ûÛŒ“jý¤Ag«ýIj>è:µ>R‹ þš®¸?Î&ý)cTÕŸZºP«o-è•ŸTØÿfÕü…@÷¨|¦~êÐô?‚îQë#õ»`_«Ú—úè6•¯Ôƒ6ÕöŸz
ô}ZûÞùƒþ
ùK}ü·iñ^Äëü ÷‘þÊ;T{ÓÒœ¼RÚP~VùOûÔW©ÙÃþ*c—¦Bþ
UûÒ–Byƒª?ú×ä|µ=¦m×ce{ÒRûƒ´ ‡U~ÓpÔÊŸtòTiÏCùJÍß‹r|#öi?…úsTÿH;þw©ü§õÁòýZ{þÇ¹Mû=”Vþ}i Ïªöù®ÿA•/îßMÕ|¯À1µ~}þ}+À_ŸÚ~}÷€^¢Ö?¾t(c­j¿¯ü×â	C{û4Ay—f¿ô>µ~|œü™·×C*ß>Ø^3ÂZ<°½f”kúuÐj}ú~º^Óï‚¿~-?°¿©üú¡õ¸ ã¹
”×«|ùoVùôÿ…3_þùÞb‰í?ü·9×·¹“§ó¯qðtÌý-£Xí¯üÐß2^ÒüEðÞ§Žey¸nƒxúTûüQ9Ïäãqÿsòü!‹Ÿ?ø€¿{bþâ?KA—åÿ²ÒOý`Å¸õpeŸ«¨(©ÀŸ™†‰ÞìŠõMüÈ7»:Ï`Œ‰àrÏ¸w’:C]%_·íAÇ5ó5ð¯áþú­kJK×4êOqÄ
JÊ¡@™•éªV¸ÚÀKæéóËÌ5æ©\n#ÚÎÕ|”hßç(›²ám#Í}×ç—`îgMb¥óÔ÷’¹Ü2ÁS(±¨K´ïÚÒe¼ž;–,.]sëâ;ðù’XÅ²Õc9-(Õ2…Y‹ejž#S•%Z4ñS1ª‘°@Â‡cb‰-Õ–pVXÎ&ÛÿišX‹JÆ²FK„Ö\}å•9Ò5OO—ìX<áÅz¼cŸØ‰µK«§T_fÌS=ª¨\Ïý'yÚ'–­·bo‘A•ibO_w›£gÂÑÙÿŸ½«ŽêºÎ÷½]@–z+{ªýD6f]ó,‰Ò®@Ë1Ø*VZ¦&A`‘‚ƒc•¨S<ÃLC±hMœØ…jëPÛ‹zè”z„-ÿ$£¸Lì¹C;4Ñ[c`2J‡:ÊØãí9÷ç½óî¾•V˜hœOsµ÷Ü{î¹ÿ÷ÝŸïžçïH¾®XK›4‰ž–ñb“\âïÊž]4jW²¿U,ó5ä±;T•´ŽµQnÕ-Î¹åù-¸)åev9M()8Ÿ‚ÊöŸ¨‘É«Ÿ±'I6“´hni¹ùKøolyÍŒFã+5GŠô¦±ÌWK}9Yä«Ü$«#çv˜7œQ¡´ÑlcnÄÀ¨’$‰Ü{f®_’6`šzúº¡ù e½˜Ø—Ñ¢õÕÔb_xÃÍ+ÀIéôöÞYt0Y¯®À¹I[¤_‡#o>QÄû_¶=S6úÑïküL ÿyQbÙ2Wÿó’%	¼ÿµ¬öºþç)yrõ?Çùæô@§8ˆ9_É÷PÃxý«üæ	]mÍ¥Œ5FÞ©Ã.O?´0)CªºèöÂä×-LK©0Ó¤ú—–¡1¸AÙ¨_`ºôÇ–hƒÜºÀüú¡ñ›[ûv
c3r9Œå×=Cú¯?.ô®ôwT†ƒã£‚'G¿ôbrÁŒùõKcšç2O¿4æà†vÐa½
ƒ¼ÓHz‹˜w¹Œê¥P~‡#Ù)ì¸~ÄBãaw¡i|6wò7ÔeÑNhÔ'ÝAhÜ˜<@hÜ¸ú>¡?æ(¡ñ â8¡ÐKhÔOÝOh}6êÝãWº6l|†^uÉË½ò…÷Éø²À‹bâ™º{†—ÅäÕ±Üëfjœ–ç¦!èXŽ¹	m©/ú[’NY«#Ð`7âÁþ¢^	üÅƒ.üÿ*üÅï;á/Tt¡òãø•_ƒ¿Ðpü-ÆK›ð[‚ßË‚_huø‹zdÂï¬þ"c—Âï|g8<xäüÍÙ…CÜ}°;3k°k°hô•Ìéý¸w½u`øô‡½e“Ø{‰ý±#ö£Ä~˜Øûbï$öÄÞNì[Ñ~<=ÂÓ#aëÈù™vz(lCúÙ‚ŒÕ×	÷-È”²îL©Ó9“Í^zÌùÇkÝcüÆÀókÛÝ™Ó5hZO¾‡e£ÂÈ[Ùì\Z.ç€Lx™óoÆî1œÝ&s^Ÿ†þ« \QVâã2œƒœÏ`£ÚËÓå³³Ë©ÜH™èa3ûÒCìì‚÷ÃÇW×ÿlõpÈ8²˜•ùkH7sÒCUNI¦Ê™ËeÝÌØËõ¿wÏp©³r¸ŠÍÍ„¬ôq{zäYÉE^pè(„IA˜rÆžQa"àM<1ÀÝÄO‹9é;Q’&sÝMénJwhz™3Èí±Û	ˆ›¥‡Jß¹g˜m>ró´c¿??qÈKœ•@ÙÌåùyˆ¤1*ós+ägžsÏpTæ¥ØN<"ùxZÁ½èð?Œsß?ÜÂÎ™Œvì†,w´c> »C—¸Øå¹EÈ©^èSàÖ
n†tƒ.uå¯=3„u‰i¹Ÿ„©qróÛ	ùMƒéÕòÝùNA¾¬’†ÇúKÉ4A9ÏiàéÞmåI.36»;s—Ì3o_²^h¸Ò€p£Ý™å$ž{«2n„°/b>yºï±ÂŸ€ð·‘ð3$OáyœÈ{äušÝ™ÙÒ—;ÔÏP·Ù…›*+”å\\cÏåe ý…ób;À:þõÇ^[@~èSÃTÞ¥ yãÈË|ìµ%/)å)žs’Ûäõ"õ{—„GùÈósé†åðïÒŽ2“ ?¿2­}ä=IâzYòÇµ´*yÇ
È;•÷œäÈS<G$-óNýž"áQ¾-ÇìO0/™‡x£¼­‚|½:"iõr;ô—¸57ƒî6¸ïòF°ÍÀ+çbóà|‡û…á·ø£Àþ8¸=ú±è‡È/ÆaoèsÐ×Î‚9æ<˜`Â0?E¿Ñ;¡ÿAß3:ÒCf´étzhÈn²º3M07ññ~Ã iw®üƒãC†½kúc±Ù¼)(ˆ«úý|Ÿ¼öÔ{0nU\#Õ9<5}Í~ÇðÑ;Oñ´”f³YÌ…Nï½JÇøõK_£û(‰)½Ò1–ýV^`Ôõçúó)}Zö@Û#ìØ~q^Žë%<IÅõVë~&Ã5®Épm…kh¥ûÍ;Åúk`—ÔƒºS¬½”[Âru¦£²=\ €êL?º[Øïë\ÇQé;v´˜VÔ™þÕÝ“Ïs´Ìë©±ÎÉßã»é´@ù\¼Ã¦{ïßtŸ,ÃUÈ¤At=ëÖ±gu]*ëš‚ocœÿ¤Ë•|[÷û×Ô'<¹nÁô)ûÛÎÕƒ¶iÃÆ-_³×oR+ú›Û\¸IžÔ­¯u´;Ë¹Vq‘î
žnSÇséþÆµL7¿Eôåœ»F>——xÞþÿÎšé]Ëñ.¸\Ã,æ\)‚–ºÑX¸ÐY¸ÿSÚÐ±©…‡i
ls¡Ÿ@¢¸ÃÓSŸjrÛw(B‡=d»ê¾¨%ÇLÌ†Á< «z_TŽè·ø×/€0YÌÀË&Óê×¬^ÞÜ°ún6Ý,2n0*Â£Ò¸)5>cÌ1?m×!±wlÚ¾¥u;½äíòvePÃ~­´¯K»
ƒÉÚÐÞ¾mËÆ?ƒ¹Ý¸ã?}¨nv¾7kL¬›ï¡\
bâø‚1±nv|W^1&ÖÍŽïÖÓû¶MÕÍŽïÄ¯ ›ß¥;$x{<Ýìø.>\€nv|w£ÓÍÒ¿„ðQÝìü}f>ÅJ.ÕÍÎß·á‰u³ã¾ý 8œž+o'áÃ~ÚZ’{Yª›ûêvà;À'u³·á÷ ùY@©È_©Æ÷‘·øÖåÑ¥Ž -ÜãÆ:{ëÁ|Xe’ç^V¾^/ÿ%ðEòð½Æ<îâÌ@œè—‚Þ"ò„‚dû4yhÞ&|À×`_z—yºÙq¯p•|9ç?™Ïùþ>€oDã³‚u³ÿÆ×“Ì6â ¬k|ŽÄ‹úÕ)ßyà»?@^TãKBãk$´Jß­/“6åÞñ¾IåéºÞ_¾¥ñj—}XºâbÆ},ïe–˜ý¶@]ï8^2^písió.-^qiQã»-ZšË+]ï;\Zèz?ìÒ¢ÔŽº´Ðõ^Ú©h¡ "æÒ%">—½µu¿¢ÅÉÒv—ª±Zèz_çÒâô¢T®#”®wË¥"1âÒâui9YŠ+£—ºÞW¹ôÔëzçkA¹.DÝâå„ÆÑŽw	þªüqå‡t«;ç™ÉùUû@‰è?Ðé…G•¼î„t˜È§%€ºÍÑß›SÍâò¢Zü[Iü7káoc^ýP?¨¢AËoƒ–ßu„Æw:Ö˜žÞÄ`^ý£®÷¡q%‹M½E“ß¢É?Dè'˜×¾P·|„Ð8
üPË^î9¼G\ºTòkò7?æÑø-­@þ­ùù×îõh^Ÿ{ýþ§÷hÿEÌ_f‘ÿüã~þµû=Z¯¼ªúžâ×½hýà….Õ_³’á·dÝò5Ëù8[JèÛ¯¿f„§ß[»—ðô$þIB'¯=¢îüß7üçÅ÷þóâCä7Ì„.y|·¸þ¥ìÏÿyò!2°Ú`~ ÑÿdxýuåŸ2üçÍo¢ýc|¨ÿg†ÿüù$ý¨ûþCÃOP·ü¦WÞHWÝ(ýQ7þ<Ó~ º‰„¯3ÅÙá™¿UšÿZÓÞýé?ïFÝÿ4={Mÿù÷Óš¼£¦ÿ<ü„æÿÏš¼>Ó¿‘þ©é??ÿ…©Ÿ‡Dûîºô§…¼ñŒëÎ×AÔ±,ÖÊŠ×ETÔt|´§£>±Ô	fòc`Û·=ªi«'”L†¬…ÃÇVçÑØ®#× ^
~•Wó|Bà¨C<XéQÏ‹cM¦–…éÀÛD]¿dŸªx8ÈËˆ/~eæ	dR‡¨¢`Z¿>@É
?@™ÐAŒ~à¢Ž”_"ËûSA±SÉbÆÏ&ràw		²ûÿ¡^^àÿÁý—ßØ3þoÙÒ¥þÏY‚ø¿¥‹œëø¿©x$þoƒ¢þïr§Ø?*ð\ýûàW³ßgÂP|_3ÐÍ;…™ßw¶TŠï‹•¡1¸qp¾aøñ}É247ÊßÙfœ#ìÆf“Ç÷ÑøqïãIÿ¤ñ}‹
Ã÷åS ¯ÊK­a¯J<óÏ¹°»¯Ó÷æŸCáÜ†Îîfþ9®²ÆÈ•hÐ9Î½Ì?§ùóÏapÎIpMBç$ØÞ{hƒtÎ’ó§½Þ¦è×O‘€ºÒx¤)°œcC|íÃÝ%6ðûÒŸcCW‰,’ØÀ$6°XbK$6°TbgJlà,a@\ ÔÓ¥ŸìRxôÈyx‚à§ó'í­Ä¾ŽØ›'ülöÒi0ŸÓ0^¿pL âg¦þlöb¿Ä®ELŸs†crÚRÞoë8m„0†Û8¸²6=d¤V#¦$ÙÔ1ÏbïÉ –ÄüåSï1ç»žû‡{÷ðX6ûù"gØfûÈºÐuQƒã!˜µ[ˆõCL ÄJ·pDâÑŽòC£_àMÈu 
«c§rLbŸ˜Æ°KÃ~o*1†/¹ð‘†³‹iøÂð…·à¿¢á7|áï\¾p-”å¬ t¥‹ˆqZCð…7H|¡…Ø:ûLÆ ¹¡Ä®¡˜ÄÖçÃB¾ßdƒ©;àÏ
ò_ùOœaÁ¦4¼Ÿ=»;³8ÎP…+w¹¢;ó9g(ñ”CgXGp†zøã¾RÃ¦4œá>"q†fwfZ ÎðÂ$q†™	p†“Äþk8Ãþqp†¯à_%8Ãþqp†7Iœásà¿;Iœá_€3üö88Ã]ŸgØ¦áÛ%Î°!Î°AÃn–8Ã‚3D{ƒÖßpeí±_Ô
f3˜N0ð.àCŠ/¬™V7È €/Ýsª(_ˆãuÞ
[ø+x ï…X6›E³æ=¼_ªRÝ<­îøîú›#áTÃð¯³Ù9¼3ì2ï=¿_†4¡}jñ‡¿=ú°¯?×ý	Ò‘ÎÏ„˜X«Å%>ð²\ÿàÙ®Ñú%þïìN±.{–Mÿ×'ñ'óàÿöiø¿‡®ÿ—$ø¿ºÎÉ›Àç·ß#Î¸±N‹HªGà O¸üx‚¶+ßqO®[ÀWÛš H³À "¾à“a ?=ø¿çy¾ðã5DÒ„ýÃÖ*5ôOáþ°i…æ.²›Xh™ÁÉ¿˜Ú¤À6äP±¡…í9‘$óÆ>ÌÑª=¢8¢Œàý’r|@9cï‡›\ïÇ÷û>eˆ¾q5yšÁ{Ìßã{¯ÆÄø=¾GjLŒßS8¿q•z3ñ®Ão³«Ô›‰wc¿)Þ‰zú(~ßi…ò(õf~ß…ûBù•z+\¾KO€ßÃwo_ø=ìñp0ŽŽâ÷øû2<1~÷Ý/«Í]MÞNÊ}êr‰{®ø(~ûÞØøø=§„5Ì@\žRþu'öÄƒñliÂ‡ûT5yøž'|¸•ÈƒË;Æ<\žØëVÖýDÞx¸¼—	ŸÂåY>}ÌÃåáž[süžR®žæ<¸¼Ÿj|8©Âåý—Æ·¶\ôM]Þû_>\Þ¯4>Äå¥ä…?_<.¯ÜðãòÚ"ÁJÖu\â÷ªâUmO=§ç0öÎ1}…åÇåžÇØˆËÃqçQrmvi³‡ÓÏº´¨å~—§æØ
—·OÃåÔpy}./®áòê\Zàò.k¸¼Ë.oÌ¥Å	Ñ€†Ë‹¹¸:Q35./¡áò’.ÏÃá‰ÍÃá‰K³†ËSÏTàò0æ¸†S´‹›Ópxª¼î²;8<Õïr§ÞÃ«ätÕ8<o®3+g§pEÈÃ÷fÌÅuY\~Ì]YìNæÕŸÂ½ÕÜ~K&áúW°&æf´|ViåsŒÐ¨ò§ÙÅíÝÈÐ‹Ÿ+HúIøíÕäõjå;JÊóEøÿ&áÇøF	?Ž¿cš¼1MžCê+¨üšHùýüÆIù¡Ë7WÆþ[+Ä=ŸÜïÿ¤›~‘ÞABâ1å?Oü‘Nhí+©ÑWHù|–T˜Ÿ…H?&>Ü ä3wØOèåÀú1ž—ÿ´Æß§áOk8E‡¤…–äoÔÊã¡WóMYžf„=höjZü¾¥÷Þøb˜³yz¼=;\Ehôo"4~KÚÃV²¿2ügØÇÿv¯!Òf‡wÚðú3ÒgH~m0Ãýá?ó.2½ñq‡³4àí®ï¦ÿüKÎo†ëÛaR\b%û¶é¯ˆÓûÁñ•›•qëˆÿ1 2å_Î8îo¿˜Çb~¢ñ¿«áßÓp€cZü¨µœ†/ÓèHÈFùÃßòŸÙ1ä?³¿/$Úç‰3lyãõ¤p†_{dÛƒ›Ö·?²^Â»
Ôã:1"ÑYÎÐcý–Öí@ÕÖ^+u®×Lƒë$Ð×Ã¨a\Å©ù0ŒÂójOgŽºM?èã*TfŽ‡z¤Ê!]\£OEoá G'@S#ÕÎè…äõ“£Î°p­°Å7ýá-m“Úf˜ô3>þoñ¢Å‹k]üß²¥‹ÿW»¤ö:þo*Žÿ3É‹Ðäƒ¥¦w0»ºuŒæ3˜R ã×¦0%3RÂP Ñ‹MaÄñÈLégˆ¤qü„×£Ì[ª‹¥¤a'„ùj:Çn¹Ìê¥au‚§Ë¹`F/È†ñ©!š^F'ø	£A[Û3k4ùixÚ6…+;‚K“Ú-ìç>a‰DxZ­rc¨°ŒÀ_bÆ9RêÓ
Nø†“³Ô4œFÎd©ò./eâå•
wr9)þý(\t^bòª/ÕÛþã¨zÛn“0Í6¹ý×ÆÃó…?†ŸÑ&–ø•mâ5^Ý&áü{©i‡éwzv÷&ñ”Ë4Q(#. ‹˜·¦ ’a&Ò‰æÙÌÛ*ài%á1Ÿj»¡$ >ÌÝÆ+›Dz(Ó	àß[ê‡zèÃ´‰ïÍ°Wd9K}ú¿¨/©OŸÝÁRÅÐO¦……>~¶Â§¤?>íúk@Û„nÚ"ô@3B¥Ä÷›$ý»¿/qRèûg{Áø? ô;„®ºÐ@'ô
U¶øY¬èyâ§âë`î÷!ØBø´>÷}©Mr –Ì#8P“£9p“?=¬'7% ÔCs" 4ûIà¤r6“È{ï¹ûÞ» )kV5¬_]ß¤O:Ô›w‘*Ô>Š?þI ¨RÉ˜!Dâìß¼ngnÙ‚Å…í¯ˆY@«6=„þuUÌœø™†ÐÓƒÕóOe{^eU=½ÌêÚÕÑŠþVJô‡®§²Çø¦TW¯ÕrVÌ?œ¶€oâÌ_>£³p^+¥óv½*6sBƒ¬hþ)ßQºUë²`%RÝÕÙátý-È{Ž…cFv,ô7b˜§®½«ºöuà¶<ëyY=Ï²HÏ)…ø×Ò<YLœCA˜³P±ž—˜ÝóPÇYË¤ÎdõWØüy‘ûLŒ|è{ð–+±·Œ±•Öga»;ÖrZVC¢¦×•³úÊtC</ÆìC˜Ç'æÙüÛ}±ÈG8ÚÁš¬Û#©ìÿ²mÑjX(7½Ò>åë‚ttA:º ²<âua»ë–0ÿXG²<[Pæl[Œg!›Å:oùÃÐò›êÃþžWÃ‰žWÂN(=Z­ÊPæ1k(‡~¯y[}u~ÊîuHÏëbë8œâGálþë,Þõ&¸¥âÕ±éal+Íálä¿”îòxýÖ¬`õP®7)™¦j÷¬&-=²Ql¦¢½çõpÜ’c­ô7‰¿)ýg:›•tˆÒ]`B}ª» º æŸ
'U9Aý÷Aý×õ¼Â’zùô¼ÉRÔ8åc«ü@ù|Iæ%alQ>¬8OùT!O`ù¼Áª _ÅÇ¥JðG!Þ®ópK`ù ?×#kmùÁ2!nòÛŒb3VÖ÷Yˆ·.'M}Ì±ä·%ß• >Q'œ—×‰J×¡rC9­á+,ÖÂË­1(.çˆ:au]PöÐÎS¤NÒP'ë NÖju…:iéùk5ÏÙ*dZø¸ƒ2: Þ8)[¤çÎŠ8¤%¡¥%
m0äµ5ŸÌY“G&o¥–1ªÜ@v“Å—Œ#qT‡“'Ž™ZØ"¶Ô2“þ¸Ùy¯n+’ 3©Ë>ÞÞcÓØà¿.À¿âãmÆ¡r?§ÓÐ’U_‘í¾) |\ñCzIÆWuñÅ´øƒ1>ÿ+D>´CìÇºÖAž2n„4ñ>öˆ£ñ”wãéKä¿Ðø‚Ê{¢øAñMÆ!å=¡|>vxï‰;d“à&¾›½Òú]èéž ÷qŸEú@]× Üÿ½«ŽêºÎ÷½]‰E,Ò“¬€Œåx7,b„X¡¥–[9Yì¨42¥©â2– ‰ŸšŸ-Â©âzêÅÈ©¦ü¬:fRãØÃÆµ=dÆ­ÀàÆm…³±qì¤tÆc{:tBR–‹±gJgœ˜6
ÛóÝŸ÷î{z±ãvtgî¾{öž{îÿ}çÝ{Î¹„óKø¬SU”W›Z;A‹÷ÙSü–áJI«hÅ‰VŒh5úÑ’ëèq´‰N›\WÑØNk`§÷ý­`Á»ôKÞÞéÔ/°ÄàQV;x„ÞŸÏÓX<L<Ì!ÉÓíÏÔ²ÌÁ(Ëå¢¼ùÇ¢6¿µ3SM<_µlâcvV¤èû¨³Ÿ¾Ý3Ñ½·ÓW=-Vf.53qžÞìLDÍ
khïòQM=R¹“Y*C–Ê¥2ï#Þ%B¼Kµä]mþJ+ç£Únù ælbå…‚Îî•Ç€3ëÿScF9Oä¦©ßþÃ
÷ò2ÆªX¥¶<p™.õÀÓ=ð4\â§zàžâ‹™Ç‰~Ý{ÈË“Ï?_ÿÌ¿4÷ÿÕ¦ì¤›t“nÒMºI7é&Ý¤›t“nÒMº‰;?=Æ‰¸~RäÅY¸ãp†‰sKœUâ|g’8‡ÄÙ#ÎqÆˆsEœ%âüPžŠ´euøI_AÔžïð6@ëˆsw]èYà½ ðŠ±‹¶yš¹ÅæKzöwü„4½ µó›QÌv¡+x¡¿K>òIú:j
fŒ‰h
’{’Wl‹qMêwWQ?¯ª RàchéÒ¥};ûvš!¡‡‡qHâo3(Tñ¾ýip‹^Àâ®@™ñ-Y^´§_°ÿÎ^[øÚPæó"UÞËÆÄÓ|Hoçó!U~TÅ7“/£"ñ\§ÐðJMÉçEºQgÊ±ïñð[X*4<6ž¯V2¾d»O|§ÏåüÜÍ2¾?óå1éíø«Ö_ÜÖ½^**mÂ«×hÔõ—ÿnÛïSæ÷¯é¹:]FŽ²mSWÇæÕi©ÑØó	©4¢ôšJcÝf]·zÍÆ†…¬.ÝµmœðwŽš#—-³åË”SCÑQsä2^¶œ—r¶šcZÈ™BÍ–GÓñ ãZS…7ÄåË™2…‡½ü%L©Mr,.‡•“i<L¨	µI.›o´IzsdÂîfJm’Ërqy®÷}êûu)we
™+.wõE-_¥6¹ŽËi	¼'<?ïÐó…sÔù;Ž¿çú´Ÿ£¾ÈeáKôvVïºÞûüÝŸ÷¡·ÇÁÃ;•¿WWúà=Êìq Y+.ouÁ'ßï8xÄÀûª>Ã”z çs8¯ã§ö÷œ†÷!á}8ÞÖxß|_tð"LQ?Pá—4<‹ñcL_z¯Ï’²|„‚zÀ=¡áe/3½·˜R‡l†¼L¤oœòd.U<Žç§y:ÍtÕž(Æ^›†§Úò‚Êgü±½Q7ÞÎ3_uH£Ä7»”þû¼n¼Ê–[>#Fóèd‰|Ô!¤VV"Ë1·Sx‹™«ý8žŽ«úÃ£^9'±Ñ±ô¼ê•µqšÃûXocãªWÖŸ¡cèuB¶—ûJ¸OÂ¦„Ÿ–p@ÂCu2ª€ó%dT‹5KÈ®k¬”%¨>àë‡§Jø„„Å‰‘a,ä=å÷F@©Mžðt	ç%,dKùzÁa!*¿ªŸùüçp¹„G%,Ä"›#LÂ7HØ’p¥„#þœ„UygHx@Â.åÊ€ûýøF<Ëßä«=ðÍXÕÞ·xâQnÈˆŸ”¡}•Z6u.—{à™ªýÑ~sTû¢ýTû¢ýè›ªx°©dFE{€×D{tŒñ”pñŠ}¾7ÿ‡ˆþ-ÿÝªÑ¿{ò–ÆKJ£7ä¡÷:xSÂŽÈø7Á‹¼OÂ?õà¿k?SŸ¹a£DÍÃäòé7¨ñåãÇø<Á¼~§gÄ\2´Xg\2¶†­/§±œ¹d”{U¼Ñ56+XäjìpËøªùRÁç‹±_ßr>~A·Œ°qÂ-ClœrËDï»eŽ_«ú–óúš%RÆ]Ö×,UóYÔÏœ¡æK¹‰ùbÎ¦ö¼(a"a&Ü2ÎfÊ-m®PùY"¿¯»ÛËÜà–¡6ûÝ2Öæ~w˜Ï¨ò	yó9ŠÏiñ‡Ý2ÛæÝ2áæ?{è½é–ù6ßqË„›¿tËŒ›¿rÉ”oØ´Ý×"ÿõÒ«¿m‘¦WÛmìºé»]ÉþkS_ëX‡oœ+ê¬­OwtmìIûÉ|_»Û8zx×S¹Í­¼¶Š•"›Kuí2*kcÕÔ:ÖIíJÈoÚº–ºŒ(_^ná”ÛÖñOXÅ6G¬þcª¸MºË8©ÿ×½éÌã
öÿ‰ú¤ÔÿáD}}2™œÔÿû4œ´ÿo3ùPÿC8]ÌûX;½LŠ,Öõ¿×þ¿T ”$\öÿqgPÒHqïRþÙ¤»(ÐEqðþÊp)îw/LYV¼9­fîaò!ÇÔGƒPšyÐ€Oq¦ ^Sþc-|ŠûÓ”ÿ®Ð^ˆ÷êïÙÊ{l¬m0¡¿4\fŸ¸ëhæø–Äi)í”)MqzÛÍ¯ï©@ŠÓ9A0>jŽ1Ç†$1=éÕ_·%™¶8]~¥OËr¤ÑŽ”>-l°´TxKƒÑ'æ'X·=ùA0Åë ¥š…Ÿ$º°µ5Dÿë6'¦®Ðbc]@æ£î;(õÄ«W5–Pu×%êÅ?øÐnh³ñÄiauG[7°ÿ*<à‰¿Ë7{`|läeÿ”SéÛ¿ÃßëÛ=p¿žÇ`‡_äZN½ºÇßã¡†q#ài®uÎÓ'ÂøJlê~û.„±ÊwBŸÎWOÎQ¬ƒFÔ¶ãšwR×ÎÃ»ˆwõ8šrŽRœx´°XrÜw&TÈ;¾ÇÜw&‘ñMÔ¶Ø g ¶7è„MzÁÖ=§ÀÆ=C°eAÏ©°‰CÏØ¾ 'ØN<‰rž¥È¡º©z×s£ÃûÃ…cs«Ù-64Ë<œPn±ÌþìÔ‹¾b°r¾Ä¼eXaÞ0¥Í†Øp ÂŽÍÜL´“ÖþlÒzbîì|u Ú;x8_Å@ïR¡jn3+kj²þ{OˆEMÖÅ9€SNI¸EÂ-n•p«„—Ix™„Û$Ü&á•^)áv	·Kx•„WI¸SÂî’pÁ‹©>ÔV±"›z§öÅ{&dÏÎ½X0b±sßåm˜bSšz§ÿG,ÅBMéé¡9;8XÉžì¥v«bÇÑíÍÌl°œ¤41j÷{~°šœÁR•UìÐ`3+ojfM!«¾&l­¨™=p·¹s ‚Ö°5Ç+ÔÌ¬&ÆöïF{î³·Ï2÷lI,CÝ5ÏZÁ.R•ÑÈ_Q?b"¯%9Ê'Kùd)Ÿ,åÁû+NýÕLõ±¬‡wcƒ›±‰îís,Â÷~PËê‹W›¦ì_›[üÁ`<øÒ`ôBŽV{³éÒ–X4ŽE\Œ‰{y<Ìõ±Ù,ÅÇKœ½Lõ=žÆiþ‹cJÜÇ=žÝíÀYÑN‹k+©MTÚjÂ«e¯ì¤9²5•b,š±rÓâ{kˆ3µ8S‹+Üáè¹|€ê¥:dÁcsU_§>IRŸ$˜¨[#;>ØÈËìÔåUelu£ºÎÈº•0§nÕ×©[5{%[Båš#ËˆtU„S%éÙâô[1[b‰:b%2ü{²ühï“ÔÞ’&=Ûµ¸µ8´g•-‰©¼,¶x_4ÒÉPæ>Ú†Ú KmmdNÛ¤¶YImÓ&Û¦Úf{•ú$?ØNõB{—Éz­rêCse1·p¤xâewÆ“ùdÿ¢œµÔŠNùèÔjtŠ$a	- êz´ÇfN€^B£7MÒSø!þLÓÒ7–µÄöÉô)ªKŠú½ŽÅ¶Ëÿšè¿&I¯”Ï7þ_VÌªT.%ÇÆOF¦‰ki*Ã•èÎ˜ Ý˜‡n«¤ëÅÃX±Ç?õ¿?Ô6ª@³UæÑÂÃW×­>ù5ú”ûrtýÚÃnrº^¼ý«ìóñè$¨=h-ÊbLß*Ç]#ÁqIÿ‹”CÅøJÒÿ1íÿ°üã©©lqíÙÈ^Í&Ùh>¾–Õç©>öÚ	´ [ìo¨"\IaÐˆÑhÔh |Š†š÷4¿³4¿³íÚ¼WOðç<ƒ³N¾@u=:gGhžÆÂaz—â¼D„xˆèÁ‹ærüÝ},OeÊâT¬ŠøŒªÌÎl´?Åf¬¯láäÌh<cF¦Á¬¤²úšy‘
óbzË·ïkÓYÊ—ÚôÕëyz·¦w›x¯5J>D¹“œ¿Á{ÕjBùðÎe–Uómª{¡PS|½ÿöŽêgŽ¬ñ¾thÆ5šh‡ácy'Å2üù"åýˆ‹Mê?]­»V™@¸}{LÔ{\†Éïœ-.3…‡ó£ZYA%¨CïÐØxGˆ±Þ©cãÛµøôô1åàîf•žÇ9ã¥¯â]Ò€ÉºaÌœ+ñ­…ÀoFèc[5#	$È	‚ Ž#tY¡ž	;Ýf¹Ø/º’0Ú·G˜‡‰ýà‰ý¥+	ó¨}"gHá¹…yÄžÌvSŒ©ñ…yÄ^Í	S˜Ê_˜Gìíœ
ˆ=o}q¥l cåñ ø¦#ÌÃèØ›
Ž/Ì£l›co6ÆU=ÂZ}ÿœ9–07[ŠÜûŠÞ75<1ÇÅ}ëÊEä³OÃÃžbš–&-£¾ÝÿRÃÃX¦Tì1zó`ÎxÁ^L¾Ô_èç1ïPYŠ¼¿pËSL	Õ0¹Ÿè/Ìó=/Dx¡qðixáY–¾ºÍòáá$ÐO¨æŸ4<ì%Æ¡w\ÃÃ^]Òòo¿qð,ì¦-÷üPÂAojxý„×?N¾ÿÆ[éØ‹§?gnAàå|è•xjï¿¶\Ç
'·šÎAã^ýG¹¿-òQ-a†å:1-Îk³x%ÆX<PËÌ$_$Æû"6¾Ír¼DÂ´Yžä¦ô˜m³¼Å†EÎ]6,>hÃ¢±N	Xì˜Ÿ°a±z`Ý°XíÔ®²Y>dÃB¬æŒˆzg+›å9"˜ç+9æ³€ÅNoÞ†…Xæ§€eJÞ@Ù,Ù°8ù¶lXˆÕDlXˆÕ$lXìŒ'mXˆÕ¤mXˆÕôÛ°˜	6|m6ËÓ6,l–¿(Ûo¶"6—Ãx¦VØüž£Õ6¬´úTPÎKú&Ñÿš,¿˜'72\T¼à „±‡¼lŠƒïÍÿ!<µüñ‘®ú6¶÷äÿ,=¥½!=Ü× ¾î”ŒÇº>®ÚðO=øïjõgf9¿Ã@‡1'Õx3Í0‹Îø7Ì ›o8ã!Jã÷Fï–0lI›xü^bCð…!&l<ß«Åcô­7Üg½Z<ÞÇ¡ÁòßñÐÿ[Ãÿ4þÎø+§ñ÷cþ»6©õ3‡"Ó?Ótêñ1Sœ-©úÆMg>¢~	Óïåf»Ã„#Wp›ÕàƒŸ“ø÷xòÛ¤å‹õ=žøG=0lVëíH+Eô¿OpN‹ò¤¥Ÿ‰ü«‡ÞÏ<øÿéa‘	ß¹éé¬8à>3ùÄåd.jÐäd.Zô™•“i[ñÕ%w¶üÁŠ;ù©PóWî´…S&%h®§Í¤ÈÌ¤ûÌ¸µîÃ$þÓm4º6'¯Œ-îJò?Éú„-ÿSß@x$'í*NÉÿ(g²8çwòˆïÇ|9ÿÞ)‚üO1ÅÝL<°-ÿ“>Ï„×å ØýaFx—ñl¦}ûd„O†…/’ÿ!^ügp_ey¢bW|*opøb™ÇÝ#Û»üêªâ¥üÎüû—(‰ˆçõÀÍã‹_øÒ™%ñ§Éò«})|€OWŸ’øjÀ—¾fôoPÝéß{EÌ¹×ÌëÔþ“’‰©ÐâPoð©êæ%wWwì±Gœ´PÀIÈ;qÀ/á{}ÃtÃ†!óÖðB~™¿õÓâŸôÐfL‹ÇD	ÖpG˜PÒó…‰±ÖÆñCìz¶jé;È¯Ôàõä;5ûZ›4ø%Où¤g¯ÿŽ'ìOõiñß÷¤Þƒë`4|ìG=¡Áº¢êû×äjñâæ°ÝÛ$¿#/
áûÀ~ÿ:ÃT—¨SÓµq›KX‡Â[ €ÓÑ!·Ø‘²7Xèeà(IHê‘žŽŽî^bSmVG@œ_ì–Â¿'â¹C»¨B>ƒÔn3¨éBxÒD
ã‰ý?<i WâI®
OšpÕxÒ$‹àI †'Mª8ž4±jñ¤FLàI2‰'MÄF<i6áI“3…'MÞéùÜéÿ>ÿ½à¡eg.Þô¿}øÀHépv8tá¥‘QÜô£ì™ÐOvŸýhhD…?ÔÂháw´ð)-ü¶>¡…ká!-|T?§…ŸÖÂOhá}Zx·îCøPî,ÎZO¾3=’;ŒPÙü+`$˜Ÿ?fFÂ‰#§
…ó'
…÷Ûi ÷÷3v
ÿ+ù»Bä-òUä#äãääÉ§È·’o#ßN¾“üòi¤IÍ¯–è²Ä[#4ëÏZ™cUÀ¦./©¢|ÿžòÑF„Êye÷Ñ«¹…5¤‘â@ihm+©¥4µÖ‘W(]œö€¢ª–´n(,8ZŠNÑl
Ë¶ý½çLóÏ—Ÿ	½±üÌs cåÎ$š,‘;]™˜6R™¸‰Óú<cÿØü¥¥g‚‰%g*ÙM#+wÚ˜—;»KâZÀ¥ÿŸ"Ø¢4)JCkþã*M˜â­ä¢ü³ŒDîlUrÚåóøß”ÿ›òšçYb˜‡-\•¤¼õÝKÏ°þcç6ìrê§:DØ´‘•õø†V6KÖ£†ê1+±ôŒ%ëPBí}Äãe¤ÿÿ„à0á—>MYÀQ\ˆþRÆ)§0êý9„Q~zW•Ð=¿ŒÚñ·Í³1Â¥wâù&ú¯žþ3ä4µÏƒÞ¡ú·NÇ(e©ÑÒÄîz¦©ž»ÉÔêÛJõMQ}[¬i#HWMéR²,Ô®³Zxywža‰G9­MFêd]åØãý §û¤k¤t-tæ¶J¸•Òî º¤xyiÌù¤-§±«¥Ÿ"qBÎÞf¢wÂ80òëKâ¿ý— ~©£>J¼Zú¯Vöé4Ì‡ÈM¼XâeŽ‹þGßþLÒ¨’øå©Ó»pi,½ŠËÐûñ%gn(z’žÂÉ_rÆÕõ¼÷ZzÐ·´¶û´Ýë4ÇxÉi;zgÎz‘Æ‹¢ƒ1–å&^¬dºWÓˆÒPz‹ò}Z£AskÖƒDcøïl+÷ì|˜Ê¹Kâ©ñüó…Â,Ì¿V9n«åØÇøi$:¦ÑiõŒÛ<×ãä_'ÿù·ÉŸÚ%îÄýoáÝcß=Ÿ¦\B¢îöº†ÁçbI´YÝù*†è­åâÈº­÷ÓKþ«ÄüáŠ•îÚ¶qûk¶öFzîO§‰[‰tóÌmžúÁoÑÚ-ïÄª‹sð¢x§€GÆ;<2xwðÔà¡ÁK7\Íœ3ÓÐÁ§w
~8¿CðÝ8ÛQ2îºlûÅ°öÈ0·¬ººðj\*ìpäüÎåá•k®aöÝæ¨gÑ¢•w²â`È˜jT+Ï3UÆ,S#h¨k¨[Y˜H4Ô'‹"ñ–î5Wo‰¤·s¸©{uO÷­^Dêb\Ö ¶:Å™Ú>,ÛÏÑG˜0Ô-]Œã¿hãŸë¡®]îs½£]»¸E˜žoötu§{p£1¸gÞ¶*´aëæî›Wo»ïþž½óaw¦gþº[VoZÐµuí}`åƒ00ÓA,è`­Ý@¼é|¢ÔñEÛ»;Ö¯];Ÿ×pÞÚž}¼.ì@“.pýåX÷Y˜¨«gFF”»‚—gØñË–{Ëg¦Ü±Jô ¯¾¸M¯Ñÿ*zmapn0,0Maº£$P£ýáx•Ñ?ºã±í×”»f8C-Pf¨¬0â7KÐ–;Bˆ’RkœÂ;'çp6ìrâ'"zã/ZsUâ3Î®¹ÀQa!H£dx¸äŒ&8Ó¼b¹KTæ:ÚÖ™¨Óålø¾s_v¥&;äl”¼ÖgÜ‹UCíU¨µwñ*y¬Ûy²zÎ:¯gŽ¼Öùt@¬ïÞ|ogŽ|
ÖóUA±Î#­ÒÛÂÞ‡2’Q,ÇÌ© ÿîwhx|¦ˆ·=xð­ö!òTùÿeïi€ã,®Ûï»“tú³>É²}€±Ïæ¨íà	É²\D}¦ˆÚ¥bp[¥IÆÙ ×\mcÎåTŸ!"(±hM¢4Ô¡NšÖNÇmIÇLÇÐVÓq§PÜ© tr*ÑL	È±áúÞîÛï{ßÞwgÙüdò³žÏ«·ûÞÛÝ·?ß~ûÞí.ÉçwÃÃ1Ú]\î&gŸ}•Êg½‰÷i†‡ß0UÁöhß3ƒä ÎÃ‚ñð
¥ÂÃ÷lk<mßƒxøÍÔV ïáQ©s6ÁÞ^2~ø~ž¼õ?|exká{mmu°ýÌ—…gO‚ßŠë«ý—Uh¼C
G«Ú%7ÕãJ_Ö£Ï’wTÓÃÃço„ÿŒîéj¿Ý“®ëIÏ™A?¶3Ê3ð25—ÒäÙÅ¼ÿÀû_“Ÿ£Æ®Y?ÓŽå”£ìÚL~zìéÐ9[ˆ‘2%k<ó+dÇ’½RˆKàu2®3Bxv,¸ž(X•<êÂŠ!®
V½¬÷uÚŽåŒ+;–7]X2Ž>¨a%îG4¬ìXú\XÙ±èsLmÇÒL{BmÇÒêÂêä·Í…ézVv,S.¬V†µÕV'Åë]˜Ÿêzv,\oÀ³x¶Ï1à¨_æë'mw¢å‰3]ïU(—-:ïúfÈ{çÍ³ùe~›?¤ocô˜?jðŸd0o1ò	¯¿,è/Üëþ° ?¾³Z×ªVò÷öi'£a›ÊK²|´›ÁþQëAÌou¿ª¥M«[ž²›I3úAkþ'X>Ú#â9U”ñovùW‰Ã¶ ÆüßtÛS'ž7äùÞþ§BÖgŒ•÷/Ÿbõ9ø9/ñ‡ü2Á“?=àÇ`°¬ÿ#löæëþÂÂkÂßr<¸íŸ!Ëåý‰v{z~Yv(±¼þµìZQgyóÍ²Y?ï[¬Lò?Ï`9vôàÅ–ðéIV \òZ÷ÚÑfùõ–_pü9‹á÷X~=Êf€kYþvË¯WÈX~½Ê€QÞ—,¿^ååÍ×:˜_OZ~=Ë7Ù„ŒÁó}€ËYùÿð¿ð•Îí{ÛòëeÎ|ÃØ~=Mµí×ÓÌø½=ü…¶_oƒvH\o³ÊöËç€¯fåuÙjüÙhÇ¿mûõ:Ÿ±ýõßlûõ:h·¤×ã¬÷ÙÞzWëS?À¬¼ÏõyÔàÿ%€0ü?¸šÁhçd1øÛ¯7zÎöëþ‘ÕÏú¡Ó2Fÿßìeýû.À+Y~8äÏ¿<dèðË¿X–÷Šøí"¾SÄ7ùžnì$ó£Žoºù–‹µsºvuóê`¤ÞwÒFøèÙ¾Ûg uÏŸÝÜ»ÈW®r–ã·XB²˜;±žÒöK~ã@3"R°mì½}ëÖ»¶Ü¾qûµ~ESsy8-J#ÇRVú1­¬ó«ØH(¿<IWP3èñnbÀIžÓê×Ã‘¢ÎË_eh	½œ†`•¡OáçbïØªÌ†´BQ+üH±è3“[eÒU%JizXÍf4ú4•~Ë,kK2Ð†ÌCØº½€rU©>Qƒgÿƒ× m¿ˆ_îL?\Èþ§ñZÏþþ‰†Æ¦††¦_Úÿ|AÚÿØÞý?ró‡[°„ü±]³37$…S"ô@1ùs8e” Ç³êa&@x!=†	úh·:!O=¢À@	z„³_=À_on§G]¥òmY/‹Z!¬à­¯~ò(iÓÎÿ¹µ€8ôQS±²:&¬wò0Û‡&…W8>xÍV•H”¢™|µHÔ$ey	»G¶->%Û¡,à#ÕÂ#©
I¢ÙO»¼ÑS‰´×âˆE2•ÇvII/F*–¦MIµ¸2©L•®\…’(]«d&RI¼î§Ý9.ïˆN”ÆéNiâI‘(áGwÓÚ´
ÇÕL*÷r¡ÆÖñ2¡ïgU²Ç[}´¦Í¬ðƒ»¦ ~ŒQ&”‚L«0˜&Sx0€÷(C-W”STä‡]‚!@ø1ÈiD}¤ü©†dê~M¨o¢·Ïb¡:Žè§ñ@÷;z×¿‡ø‹¼ø1~?¢9Šåc»3ðÿÔ€[hüÐ}“ò§o<ÿ˜¶p|U±úþÿ¬Ÿ7ðÿÇ§*OÞ7:à–Æ Õ€Ž©úÔü³>|˜ŠwõönÜ¡nå
~Õ¹ö(póP`+–gŽ…âŠIVðž4ÀP‹¬ÀéJÆ ã,iž/÷X¾+•p„ZÂój{ë)ûß{x)êo9/«·lq„ZcÕ¢Ú¼Ä£0…1>	ÓcXÏÊ0~¦?Æc0å0>Sã—`èbcaÆã0m0~FÆÐÇuÃº3c˜?s0~–=Ê·êç›]ßªèÓ]ùWjÿªUŽý[{pHÇ£OÕP?U#@í¾â_tÈ9š;zúzÑÑ}è£uQ4÷~ŒÊ/œuN\=åœÁ’àQ€G|à“>ð)¿ð‹xŒÁ§>Íà— ~‰Ág >Ãàq€Çü:À¯38p–Áoü&ƒ'ždðÛ ¿p€|:ÂumjA¼Éâû+Ç|CˆEO‰pÜÊM…žÈÆ±oÚÊ ï‡¥'Ú""qu¤&yôôÕ“¢}¨}FDaNKýžë#÷¯EôèwDýÑcÊŸðPG­SŸW¶Áª$ý÷:ƒñgHù7vˆw}ÏÐ‚ˆc¯n«íƒ»á% }ôWñÚú/.¬­¯…þG3¢Ë¹¦>‘›ÛÉ}GÙ“%ñ°°þPŸ×ãûŒ„¡œ‘j+ > > >zÜ =Ô7<º€G)Ô»y´•@ý€ð:ÿFmÒÚ÷9¼Ô
fMü“ðŽˆIÿÊõ€wå
ü¢o÷ý³è™scGŸ/=ú½ðâÐÈ¤ªóÚšcèGÆ¶Ä9úÔï9¥&	'Ä¯HºçDìÀIHK ¿í0úªÏnÓVö%ÐÉ²–vˆvïMxõ</âä‡[À+×áÈÍ€åÛ,ßæùq;—‚À£üb‡—€v-z&Ü"?Ø®ïëï‰lïÑ“¢êÛj´7ªëí½Žê<ð¢ª½¢‚µ·ÓÝö>2·EÔy™¦ôù-×¶¡µÿƒ4éƒ}‘#ìÜ¡ê‡mdiR‘ í{MÎÕ7OCÙò^ô££b1ä½ÅòNë<òîæëòvÐÞ'Õ}=)z°íÖ˜æ	¸‹É¯xóúáfò;òÛ òë"ùu}A|èâPïnê¯*SúˆC›;hÀ%bªÜ”)ïC‡qbuæ|ê¦Á§Šñ‘Šè‹>’qgÄ	=Ký‚<CÀ3:žãYeàG8>”uØ,KÉÕ1a½MyrŒÅKÄrÀ×ýß¬}Â;äW^Ã#	éË¾Uû²>ãDÓ8Pk|gO“ï\ƒo¢ ^ÚØ/yàã Êú¯e²žËdý	&¿8¤OßzàQOm’¾ ßâãxW2žK¡^Ø‡oßã›`óÇ'å»â•çÎWXË¨Æ&®-¾ñä[»ˆ÷ÎxtÒ<Ú ó¨æQ·žG:Èw¼à]…wQ=¾›â]Î~(ç_¹o{ôk?§1wž|ÚÏ…wEÞõæCíYöf.°g‘ªâ =ÊÏ“¡—|Q¢,vÉý‡i™—ç °é¢SŸváój&*JO‰<¿bX/íw,Y<¿|d4/?Œ›|í÷l(?Ÿ]—”¨È÷®KRgEd_“,š?{¬Ÿ©Ë¦wïÑÅ:3ã¾Ìš…pÏÊtÐßaW%=ßcòì,øZ#Ü—h¼y¦XðëŠp}C“]í£päùÓÓÂóá¢Ïápo¥}”|¬cÄÏž™^“¤}”Á÷>V¹Ë:æ£Ö~yžÔÂÊÕ×u{>ÊJ>rìór1àÏÁÊ	o-dã9VŠøU²ö&…6ß’ãZŽmn>£ùÝíááÅû#Fñ.Ï`ð)ãÇÕúü*íáá|‘s¦5 Ü}Â¸·ÇÇw’yMà9HÎÿy¥þû ÐæVíîÙi¹ÕWÞ àÀ{’áoç`rÿœá· ë€þ’áA[å¹T¿¿exÇÍ|×àá;Ÿ|™á™“<wâíÐ×dxO`¹?®Ï3ôù"Ïbí0Ì¼$Þï1<÷²ßWXíÂ/7Áþ†ñT»KøƒÎ{×(Çüx@;s°:\ßùzÏÏyØ9jtùÄŸ3¹ÖèJ§=èÁEÌÁ”@0_aÛ÷L¾Âl«¶¨3qáù
“gåÂó¦Î¦=_arÍž¯0¹6ÏWX©öEF¾ÂÔžÀó¦ÎV=_aê}çù
“sTx¾Âä\ž¯09ç„ç+LÎ-áù
s´ï3òæú&#_aŽæO¾ÂäØž¯0ÅÆó&Ç²p}…µ+_Eá+¬à _an¿öí¥Úk¹¾½T{-íÛ‹äc)ùüºn¿¥6œˆÈ³m[ñÞBõGq¬
`©?"ø!Øÿ´1ü?†|©C¢|³~Cy¬~aÔç»F}^€þ1þfû_újk(Ìÿ/#ÿÜŸA<Iô?Æý°Iü¾ï–-§D™î?€çÈwGKúv²–kþt6¿Ò¯{°\Ó:òõu£®3ùúú¿.ÂºÏ¯‹°î~RþÊw–5`”÷~ŒæÏÜ:¥§úª‘ÿ¤_Wa½@ó©«N¶ßú'¿îÂ:mÐ¿lÀ¯úuÖFþY?l¿®À®Âý.ŒæÎ:Ë³küË8¦å»@ù»†æ?¶}
4ü[ýºû¿®Ã¾ÍàßmÀuyäûl«Î©üŒQž_WÄl{¦}‡Ñ4÷ii¼Ö»Ö æ@«ž–¦ævÅÞÎt!»Ÿ`ëž‚·iéNŠÜP ûñ]·#¯b7 ùT@Ó1êñ_Þã»àÇP¹jªéøìr
ÚãÂ(ø"%T¶¸	Ò“IeÓ/¶ÍÏjèí»;™ìmùˆnþQ¡¸ýOSCË*ÏÿWSKúÿjlú¥ýÏÇÐþÇ¶Ù¶Ý–ûK™àX3µ¿ï„Š®è"¨UZ™,”ß¸ÿ.áxŽå×œÅîO|è;ÅRøþXxWìèXë¡ù5šî‡”÷AU{Æ{Úm:©WíóÇP¥a‡GíÑÕ-VøþØ5irc¡¿+uûS»|±ð¾)u,m‹ZšWlÝÔÒìúÞ÷—¥ý‹	ÏE–þñÊ¿EpŸ€ß(Ú¦Æk‰ÿg|ú"¬+~UO~eOP°bÁéNô½uùi¸GßQ } @zSô_-¾µ@úòéX ýw¤ßZ }M`ú4.<ôüs}N¸h¯ ÷(z×ÑäÖÏü‡AÙ~à·´¶ý˜)Ô8q¿	kÎW[¾*A:®á€ôQ¡ÆŸ™Žº™Ò€tüV)ËOÇ[„äø5ÓcÂ»Ê‹§ãÙ[E@:®K•é¨§¬
HÏ5ÇÜôtÄ~jÊÎÔ‚Ü£ÂúZ§°îxÈXq+Æ­D2ùéHè©[2ÞYÒõû„˜j‹'¶îíÎ®ßÛÓ¿%ôüÝwK&óò2S'(/âÏÛ»ò(¯ÕÈs /Jy1#o ò†(oØ(o<»>“Uy™Iƒ.	t)¢Ëy#w„òŽ<OÏ1âù’A÷4ÐÝ)#/y”×…yé%•©Ô‚Ò×±3AÞ{Q¦ {1ag"ër¹ogÛ…Z—«b	s\”ªÉÃûibaÆYº>÷‰XFKºø möf™Ø"(kò2ûûS?ÈïÜ«¹©‰ŽL”øîÕy0ÒVÀHI<.úÞx-›Øu¼Ò¾)Óª:ax`zk¥ˆLÍ÷xb]°X¬ÖG×ÅÏ#wË9XÃrŒe°žo@}t]±~Ù;2‹u›Ý2`¶®¶?.–‚ü+Vvtûÿs·¦×T¦ ¼ÖVh÷ºÜ{W#]ºçŠÔÐ|±?Ê£ý8„§EÙñÕkÄ@:JõÇ×¥ZGÂH³„Ñd4â@ÞW0Ò2)xg^“‰Ä×DWë|1 òKÌƒ)Qƒ2,¯ƒr™š97³<›òlÊùårôw•þ;–™] „n3Ê•Í]+k£¿ý9Ùþ©=b<’Áù¬=i¨{šdð"þM2Èx2@Ãå–ÒxJç#¤€O´e?´?íON¬ÉrÆv<œ…eýZOÛØÇ(è£ÄºÜ¹'d¿â<š/°ý	Hï„ô‡)Ý¢ôÅÈ{¤\8)ŽNW:Œu9÷§‡2.Ef(3lëÔ×­ÈÐ|K*H”¬,AýÕ<±ÆŠ¬^""ržbû2ÝPþj9áXÆ9…u6hÛh{tÛm=Œ¯•²óÅ±NJä­àÑ<>cðˆž£ñ€ç«OûM]r]î'oi:ÙO{Ä0Œ•å¾—¥KyÒmù¡\†/á5V~2‹‰W.ûó]R€owa¾gŸa|w2¾G¼Ç^ÇŠ‘/çC}28»[§+9}™ÕñÔñÄ#ÀëˆjÃÙÍÓ”Í¯ì©³¬ì£šoõ4eÃù>Á×µ ¾o7_ËH6<ÿ“œÉ&Ck®aÇáï½kDjPÃšÑ…ë!À;	N`~º¼ì¸\'+eœÁµÆ™\Oú7*•.EùNµ³¹
cQôà’ŽHšÄc€xìOWøxeúÃ7¤ú¯~w~*ÕÓm@‡<ß}‹­ÇÔú©øƒ]ÂZ°w]îïâ{ÞIY;3”®„u1ÖÙuÝ¸»cÙçÛŸkïŸ˜ï_Òý‰bïìërÂú‰;‡èJ‹y;ÓkD¢=“;©ß“ê¤ÞiOä²ç¾Ÿ›duû¨Ó0ðÙ3ÞÙµgbÞÎë&r9Ú?´¥ç…R{Þ;—ºêökâuºëa½Ø—ƒ½âjÚ¹u‚²ß€²óêbû…™#ZfP))³›sS+¾•ËÁØmvßóì}þYX—~ƒí%6æÎ">ì#Îí¾ÿaû©Tåüxs"#úééJw¼¿+U9gSº£»áþÁºúë…5±µ$ºz°$š]/"j¯&ÛÃñ {²8F >Žï]Ü£A‚ø0ÄaˆA\ñAˆK!„¸bœ¸§KC\1®0or[ù>®G–ñÎîÀ}6Y¸OÇn
C1Û)Åì§0,»ƒb×ŽJ}dó——ÿ!ú‹ËQ(Çªï£8Cñ°ƒkÛ¥“°f¾Dp5Á“ËóGXú
œ‡ú.U°­u”ºæ_¦XŸaè|ÿEtžß‡)‚I‡miÝ¿¶ÝÐgÊ½ŠPmôaƒV‹Èæóck9Y“ÎìB?ûpƒcÕN©rK+øà)_¾(N/éNwžNWŽaÒÇƒÓ#ðË¤WìNŸ‘	N¯©/~,0`Çª‹øÓg«xæå_¾p²Sÿ*Ý9Ä¤Ã«í¤¸‹ânŠ{(î£x@ñ>_dqÖ´lÉ³l1,ñ<ES¦CE8<¬W³Æ™‚Î|ô8òàR=¿¹-Žm’ß»>~cîŸŠ_‡ðTµnoÚ¼kóÖ½ÛïÙ±cE2Ù«þÂkø–5,onRWó­HÞsßæí¨ÆXvï¶»·Ýsß¶eò6ºewm»w…ºŸä°ì.i»z-J@Ñ©”½;îu/3üˆŠãCqÞ5€-Ën:¨ÙŽlö+c³·ý›-ï:4ï>d0„—bÙ¶ÎÍ¨pïü˜Äã¿G±ÜÖ“#ô¢°æÍS7êÔ’ÎÐJHœ‡¿¥öRK'C³0Õó]¼kó§Ü´myMÕç7¢¤/Tî¥^´ÓK2ê½ý[õJÓàíÜº˜¬y·ß¾­·o#r¿'¹I[úJ_¿¡ï¥\ÎøamŒz@ëÃòôb:p»;í*•Ó“¾)Oï¤ßÐ Î‰Ûã²ý›»[oÐèÅÓV	oßFôz§c©,aõÖôR"<=Ñëý¢»oÔûCxûobû6¢ç·Ê0Wøëo³xƒÞ2úÑS,åT½Œ·¦O=Å–Öê}-oÿï3¾´?Öï_÷=lªÆyù;è3DOq%·AV(^Ð®]½Þ¸û‚ÅEÊß#òÆ/þ®WþE±ïJB“þsùôµô}¡ã¼8‡õU“èû@ëwuœ·ïàåk×±œžö;:.Jÿõ|z½ß¬Â7áÃô”ïîkcEè¿#<{MOýåÓWsº¦Çvý}~ù3éûOÇEÛ?@Ov®=8ý.LoÅŠÐs›l¢¯§uKÇÞ]=ÆÿÆ`²ƒÐß—îw¦øúÓÇèïS¬?ÎÿWòégå›ã‡—?nÀ,¸ôT„~B¤wï22øx˜*B¯ßc?*\¾é£ºÞ±"ôuEè'œ?)LŸw…*—“=†5¯½aKÏÃUôTŽý°@xw\ðþÏsì…e´þ‡MS¤Âv÷,hÛ{f_£Ó}‚›¢ôSF:ë¸ç6:Ý<ßÑéôùö®>8®êºß÷võmã]IØÂa×l°‚åÝÕ‡m9uË“%Û2‘mÝ)dV+íJZ¼«ÝÙ]{BËb;-mC–š	NÕ0ž”AÐ¡høþÃÓ±[f -Í˜v’ú’:“Ôõê9÷ã½·OoeCƒÛLÎÏsõÞ9÷ÜsÏ=÷¾ûå½ïUvÛê·úÖøjòë%ßpðß¿QòK~“à›ã–âËßÒšã‘â‹ý+kœQ|þk1ù+$ÿ¼ƒ/Ö¹Ž}õÛçþ„:`õÓ&¿EðÍ~Wñå¾HeªÎ¸ðW
~«³Å~˜VÙ¯©3.üë¥ÓžÊ#[ü5UøíUø×Wá;Ÿ7Å¿¡
?P…takò7ûN,«ÂßX…¿µ
g>žmRõ5/yè÷7t³=×ÚÛÕ;Uôü«æÞ>Ïkîíó#Íµ}jMÚâú–¶Z³Úá¬M>¨›ö·ÚÚ³¶ÙÆ\Þ~mÀfÿ9Äf¿m¾¨}Is}NµƒUÊuÍû¸_¥¾´«ð/¹óõz›~9¯æC@³¯~ÿØü5UôÜT…ß[…o¸2óÀ¿+àÚoè©fËÅ‡ö¦‘ïSr´ýOš÷'(ÿgÅù¢ülþóî¿“Óß°é?oãŸj6Û¿Øfü<£þ/þÅý6(ú–¼ØgüUÓú/}®~ðhn›ŽÀ_án§'¸ÖuñtXù®PÿÏð8ð·øu×|w¬u¿<»mõ¢Ê‹ù~©Š=™*üûªðËVýÚûsÏcîõîy¦Šžù*ògªÈ¿oÉ¯œµÉÿ¤ŠüEwýÞ&wyïú*ü­îåõ4ë¦ŸåüÄ‹_?ò»Ž¿ÞÛlíSõ3¨ßý÷ ñ±Ô¾ïµ…ÃæGQä>µ_I¦'"ü—h (¿Îm;¾s•·»ùÛQ­ß¥²°“ñI>‰nÚÔµi3Ëáec•EK|}ð“ŸºÊ»çWþvtgüP>YÇmf‰ï—÷Tœàq~b½òýÊ	ó­¿WôõŠÏƒ÷ÈãAaç§ÌŸK[ßB·ì
WPÎo·÷@ü"ÝÒ~Û©­°ÌÏù)õŠ÷,ú^{ãï=Ž•Ú<d™—©,yåû¦ŽOÛ÷È/®;¾éîH'”/ý}÷ç÷Ý{Ôq,ñ%vó4›Ýî­âWñ©ƒøâßdúSyó¯À’çº»zºlßÿŽölÆó?{zéüÏÕÀâï×óÙk´Ž¿Ø—Ek5Vçcüõ¿u¬ƒù1¿ÿ-_ |–‰M'û÷¿[58Y_Îì/öe¹A¸„8üà6s¾üað0³+bÃR½œRne0ñŸË8¬•|œÐ0<Ì‚Ru¶<Bƒ‡ F'ßïkž¿1ß@PçoÔáÄ=ëôëH	¦p=#Óy41y-Õ
œo6xúýºÁËuÂ+^ŽVï1ø¤r¿f}ï9X@øìßBZý'šà¤³^ä—“‡¤ròðRýzsèH—[-ÒånérhÃGÙ(Ø· WLw®—jgÑ.´õ«ö¢MuÒ>]”ÇÜ FÛqR¬¾±®|ŠöTl.1±8õHŸ¨C˜ú}ª¾™î¶¶Ê…·ð@?Ö!ãvÿ|áœM/Òxà|D®7ý`9~ºa¤EÔ©,±÷Î0ïgá4Ôù¼,sÎ€Ð.”ËßGˆï’ÏÛä…pèÌú^‰]76f!¾WñøÂ€SMë«Áïe4qÛÛüÿ¾c3x¿wõÈK}x˜¿Ô,žE¤ÕkàÚ¥ýX?Øvoä/˜É¼Ú¼ÂzðùÅ‹ÜP?¾¼xâOJ}³è/ ;%ýE‡~|qŒñÈøg DÈ2,š,žG8OH9g@ë“ënó%~*‹Ç‡¯øY*ëx•<s…§¬äÑ+y‚Ëõ–ã}ÅKCWg¿­ãaŽù˜ËdÑtÆ:h®îÄ€¯^ö«3ÑsêL¼ÿz™GRÈ÷ÈX÷i>Ùn}©Ôrl†|8PÖ£6b°.y¼—Ý*yB^7åçW´o=}äñuÁ³zÎ.¼¼®ýpÎÇ^šk+-cülÝ¡†‹¹ýRYäá÷ª´ð´éi+=ÊãJõ[Ö-%ŸpÈŸö/–øµžõØËöÏÊ± ðìúZ¥¾àEÆ†KÇ!Ý“e/{jÝÅ-:÷W¼L#¥?*O•(‹<NÌµ²oÏµ±—ç†¤*ÿ……Å¿‡Â<NþéŸtBð¶OØ'Ò¡vùÒáÅþl—þ<Í¶ñ½ÿ:©c¬*´Á`ÇžV>hçeÁQã¨|¿ÏüúŸU^6: õÕK=m ÀV£õxÈÒu´¬1Oè4˜uú–×ÿ=nõ¼Ü^úJ¹i‹ õÕ@^o³'µ´µd|ÒÖZó±ã!/´¨úD_a~nùÈüßúðåu½ÞÎE½?˜žŸõØÛáhË`(ØÁØVGùØ{å{eçw2ƒ·öÊº{­ì0 ù×†¢.é<Ýkå´{çõ³m«˜Ñªt¶CšNöê1xÎÀc­¢}ë¡ï+s+d]b¼n‹×e|Œ_X´ÇAC(ÏÍ{ÀeðA¹Ïûò:Õ¶ÐO‡„Ÿæ¡ž¶B=õ1ËO{C¹š°¬ªL»¥ÀgëÒGÌÝGí<»ÚÙ«åF(ÛYNÔ×òm2¯lë½ÀCõ‚¼¨û1Ÿò‹â]#ymÒ'ªÞ§ Þ.yGÙü\»CöxYÌ;
6ø”¼´ÏÇ¶ñwÛSÇ,og£Ì¨’'èáuþ/ƒÿË«¬£ãEQG³PG ŽîuÔu4
u”`¯Cû™‡ûWËXþé»„å³Œþü9
,»^hÙÊ9lj›<²mb;¡ŒJïê+ÔûR½R¯’cÖ8€ñ#W£&ü‰yÂè
\ažóUòôÉ<Uúú*é;ÛòïŽ¶ðÔãa—<Åç$ÌjB÷ºÄo…ø­2¿ì[½ñ¬zÆðyÙï’¾Ã–^û?N~íŸ ¿#¿!™ßRi°/PŸÏ½ýh¯w¸Äa¸ùm’6òûOîï¡ËØ×çRþ+ÍÏÍß—Ë¯·J~K¥‰Úü}%ú±Ÿ1Dö[â™‚rBÛ}åÍ¾X{‰gä¡Ž,þ
Çs{žƒ>ö:è}ìx³ìì×Äó3?·JÚ×kößæ}Þóù’Ô÷èë }!Ð×WEÚÏ¤.u¢þÙoBŸX†>±<jë7í°÷¥}Y9/€¾4
}i'û›¹ö<ŒÙÏA›|úÿïÂXs’ÏWFÁŽà‰ÎÎr[‚ßœ7ç'}¥cåA9ŸºÑwŒ{_êf4eÁr·|-˜Õƒ%=Õ1=tm7aú‹#+½¬ë&È¿ùC<ež¡gaüûnò/£Í}ržÊçÓÖ|ªìV6ª9 ö‹0 û.-Œ8æR×}çÿ½°vÕ¥ßMÖÔ¯æÁ>,çá³LwkÙé6½ÒA_ë [´ÏA¯pÐËt£ƒnpÐµ@;ëý3šY<ß´ÏéŒcPwåkÍñÓŸ«÷¾îžð–èÒçÌ>­3f@ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ „ß, ì×‹eŒù®@¬Ä˜×E²§›uë›‡û“‚öÍÂõT“ÁÚü{îKR®Tk°Üû€?
×É7àÅûŸtìÜó»Ÿô†»Â]W—Ã:!èÜ"/ÿ{lj“v÷Âu¶Îà2
!.Ô”ïk1¸“ZëŒ
gý¥WÃ¿©éTqþ„ÇYd*›IF2ñüÁ™B$›ŒŒÍ¤Ò‰H"3ñtd,³ycTòŠ™\äžlþ`d2ßÐî	o\?~¨ÐnìêŠnÞF0&2^˜aP¬@ÿ¾@w¸k”L+	|Ü‚÷þO,ÐüÌWë©_SÿÙú–°ÀI¿Ë-|c´¯i„¿úJûÕšÇ%7dR¹B2½!šž9Ìµû0ž/¦ÂûæïÕYŽíÀs‹öý¡!Ý†q¶	Oò†î*éõŠmÄ³B{ø»†n	¾ÿÿ«lÓö²a›õ´kÇlEÃæëY¦X˜¨?§ó—lýL4ùÏÀõ‹ã‘£â±/pÆÚâ±?pÃõ2¾ÇßRºhÏßÏÂ…#™b|®Å¼¸N©»Ôt1™Ï±ðt¶˜÷oÛµ¡Ÿdá|r25=‘eáÄ‘éx&5ÎÂSñÂ'A•¸ó,<9=>”ÌRÙé
"–GÍ©"“‡áïî]#û ó™±£¯!‡l"^Œ³pr*6‘g’,<^Ìæ!:!.wƒ
!’O'b™8Ø8™U…±Dó?ãÙL&9¼Drlf2ÏÇ§'“EÊˆ¨±±|ò¢ ò!¿\rÈpN8>–êévõ±Ö`ãd¢ÏjÕŒ-·Åkòz#„:)¹Dlr^yÅ¾µ–±Ê‚Ü Èµ9äþ¼ãú€Ü»(óPrõ ÔH¹ýº±çeZ%‡a„&)Wï1 @®	}š”Á>ñ6)wÂk@ ½ª¶òÞÉøX›E¹K5ÆÇ•¯.Ã„¤\ú‰(ŒØ|¥ü2#uczìOJpó„‹ÿ¾l“‹ÂÃ­““PcÍýv9>¦ÂCç¢ïA›ömçAî¹‡™ÕF Ÿiy›œÊ÷1›œÑj@°tØõ=)å<fr×§Sîi›Äûê«È=g“e>Pnù¾`“€\ ¨¨K9~`“ƒúòTÑ÷¦%çåAc9‡>”=%ìçr§y°5*fµ«¿·ä˜’¸Ø÷Ž-ã²Ÿ[8õe¼o5M^Ü^¿Ê—ÿá;r^—vÿ¡Cîi½Ò>%× UÊ¹G]ô]«U–c
2µÑÊÏ«rõ5îþó3³M™r.ùª6ªPjÒØ(<A¸¿…YýAƒCßY¿6.Öçì/O/¤B&-r4i‘Ã“`&èQ¢E/ƒý“ E¯ˆý E­b#èQF“nñuŠH´YÑËøõ¼I‹Ÿ{A_Ã¯ø|z…*²OÐ¢•Ö›´_EJº™Ó“núMº•Ó£&}-§O›ôJ½ŠÙá©Q¾ÎA¯vÐkt»ƒ¾ÞAÆAßà :XÑN¼ìçËt\¿*ë;ôNG|ƒþý&Ö$Ò¿èˆ]ÜripùfÕõó>³êSƒúü%³êKƒúÂÉú›OVÁßxc˜ñ-lÆÛòß ôÛß&å· ]ª¯nßv?s¦}·kÖší‹i•öe´JûŽ`þ~K¿Ó_e­’þÐA×á#	s[ì+0½_sÙ'$½Z¯”ÿ¬nµ_”¿è‘’ [ ~£.ž§ ¤ÇÖ¾S·ú
Œ¿C·žw?hŒëbíû ò™¶Äµ±é÷Aúo"Ý,Ö (ÿ q}RÒ‹ùKûüz{KsëzßÄÞ×ßØõ ü9Ýêš¡ø™#¿Çê/0ýu6Út è’\#£>Ãc=Ï~xžo×ÿÃ2þ€GÌåŸ—úÒëyÆòöˆµBt}Ízû}œ¯Aú^]¤ÿ–Gf-åÿÚcÕG<ü= qâ€Ìï-ÕŸ5Cöw@ã>Å¼Œÿ‘#ÿ{¬þÇýÏ‡>ß1ãemÒ-^Ñ?z¹ü5l­×²ÇöDlcðÙ€·2¿]^±‡¢ì¹Ó&þg0mßÀ.ûX8))$’¹B—x‘dz"R(ÆóEˆ›Jù*VxŸÚÂÞ}u‘Kåñx:›ÌÀÂˆÛ„«LXML€±ØÀþ½·Ç†wíÛ‹5XAmŠí¸½÷öØ¶í;wíá¬[ÌxX åÒÉb2îîÞ²‰åðÒ"‰ll2‹§c|5‹ÏfÙ±»“ãÅpwOoã+®Xb&“9¢òß¾gÐÊ^"kEaÆêÞÊaÜÌáj9×çñüøÔøTrü x_‘!î¦`]µ¿AÖxl‚¯"c“¹X"UÈ1X·ŽOåcçð®m±îp”ÅïÜÓ¿{× xuÏvíÙi2P61“«áÒ¸ kf±lå«Ì
I‘E¦"Ùx:[HVêI²±©øt"ÝƒâÅøâ87S,Tó¥4$I^.sÙ¼b|ÙòØd²(´Ë•¹%Þâ·Æv÷ ÅÅlºR•i“Ì–ÜR}&žšVœCNejL+ò|üH,9`X2u.Ÿš.NTHóRgsÉJIQq;‡÷nëŽíÝ±cßöý±ýýÛ†·CD¥¹È’ïÚw‰Ôtl¦D	[Æ±[Ån—HÇ…d²Æ„|2ž¨4ßzV¡¹~=1>u°0ÕûéælÞ¸‘_Žk×¦îM=¬«»wc´»;ÚÛÓÃ¢]ÑM›»X zyÕÿ{Ì`X>›-.%w¹ø_SÜ·}x‡ØJÐÙÍ|¾9[#þ¿âŸXËöÂì£ŽuÀ
h_Eöò`ðp–‰ý\mâô§X¸ß'öý¾Jk‘q³¯}Ú`™ˆA¬V5/xý<DÑ§©=2¯‚;—cèçç®j™µo÷Árý<˜˜;©¸Û~\L¸ùB¥ÇÿˆÀÀÊGÔp!Ã /“Úï«æm¬4tÿÝçfÅRHíùàŠØ÷åÇïíßý÷¾°þàµ_üÖo­8ùÞÁÖCï<vï½?õ¯Hå½×_üó‡Ûú£‡ÛŸzìáö»¾ñp{dÏo_pÚ‚zËu:ÎëÖC¸£Æ¢qeiØâ·C8`£qå,”áÎàzÊÈs6Ÿ5¯M?î5l4þ?UÑFãJú[úßÃ:°ÑwAØj“g8¢/7ñ¡¦¥YnÄäAwr„å#ë¸,¦|”S9X<Ðg"WÏÇÅÓ30†Y:Ã6.þiæú'ZŸÆ¬ý²æTj9¦¸OÒm×ô³'äÆN;ÞËùv ïeÃá½Ü[íÀ{¹hïÄ{¹ÑÅ{¹)Ý‹÷rC­ïÅ¶ÛŠ÷rÓÜÀ{¹¶Ä{±ÃÞˆü$²voÍ›Þ÷–mõ¾é=³¬«©ÿÓ5³ðÔF5¾XoXâŸvFóFíf£×™òþ«`×¿eoÚ{aº‰]HÃsyZ­xàïzãÂ¨H×
6ø x«ŸYo´ŒzàoA@!ÜâÐgËªÄ¡ÛªÄ¡OCUâÐÇÑ*qèó­Uâ°†ªÄaì¯‡u4Z%ë,]%ëðp•8¬ÓãÌ?»üÅÄŽHíi¨·½ïÔœiêo`âo´ÊkÝø¬©çÙŽ?Œ|#òTä{ÿ?¯Ý{2Þ\õ§¾w}ÿäÿÇ}Á¡¯‡.{P{_ËéŸ«7žÑPï×GFÿ«¬årÚû¾õÐ^¸ûB
ÚÂTÂzÀ>Â0Ü×¼ý?ì\pTU–¾ïuçÇt'yé$ÉKˆN2@:Ý	ÚÑt$:’Ð™A7¿DcB£™Ùd.mG™-Æã–«»n­ãÏLÜÑ2(¢ë¸U Ô®;²µÉ(L"ÌQ‘ÞsîÏëû^ºÌLYSµ¾ÊÍ{çÜsÏý¿ïÜ{¾~7€V{Ø~8'O	/€Ô:>
ùÚ“¿ríîœ*÷áÌvr¬˜–zõîsgFüŸÛQ­„—ÂX]†Tc`÷?:ç]è¹ñG¥í™ÁùëæSù
ˆKÍ(§ò™í¹”çêÊUþñYÞ‚¡…fÁîÂ=çJ+<ó\WïžOuØ7j­Pz¯mHùÀëÎ„<fïžeÄ¨4F…˜Dˆ‰Œ»Ü*Þ›ï>Ýl{¤¿êê•X‹,ûÛ©/ˆ½Âé§k'®¿¸Ææ¯<ºeªåÃµøvÖÍCË…t*å^IëV?ÌxW6Lµ:{3ÛçSŽ’i\2³½ÀàÍ[•e+šjý°wªÅ¹1×…ÜÜ(uËÜ—[?Ý¬•$„UzO	» ‡lhÝlªŒgäæ '8”£Œ)¹é¼¹ÚÆŒ–+[2[‡±,#ÍÇõ[XåzÖ@½ñÔ÷~~Z÷Q¨{”¼1cª•ŒÏ…òe­ÂöLšjÉ„rºZ~µ?LµÛ`t¨PE’Ì0$¤’CT2YObOjnåcXâ¬U6žeHo§Òƒ\:…ò“ŸÙ¾…§Ë‡tP·–wëTË7 ¤—CûžÁ+^NCNž+÷Ud\Ëg2äXÊñÞÐ‹­(¥l¼Ü%4l˜¦a^Í\Cš¡!Ûý6MÏH¥½"ø«¤Td<×µ’åÕ¾ÌÈó*ª/»a–ÿcyjf¬Q6×\Á5_f*ÓP6c„†\CÊ4+Æ®ƒ×HðçI©Èøbî*œ‘7C¿MµÎn\ÔYê¡Ïs‹áyÁPæ»S-³oj™³jªåŠ†ÒöM°d®Oç£Ô•[
ú‚qˆvÆ^¸7'úÉ>¸—%ùáë§öÚ,h§ -ó$³i ÷JÐ;ïÐºç4¸Ü˜CF.Íc}›)®˜Óéz?Ÿ¸|¾ÏýÆÃn2ù„»íŽ_¸ï<èvþw·vô¸ÛY¡½—¿Ò¦,½+ýpŽ/³+/H~»2Ùÿ?Ê»íÏ_ç¨V¾woù™¿ÞÓŒïÕ3wéŒ®ª;U…ôœDœäõ;éð}îÜúÈÎ¤æ¯ÌÜPÑçðŸë»·9²óó!,ß™GÕ3¾ß»§º>èÉ®ØñÌ~°½¡‚ý0Õe£vÃYØXíƒ‘Ï"Ù&@ÛÉÝÚÑåîÜDj‚¡`[(Ø®—z[;BzuOOgG[K-¶hÜ5eÓâ6wµ´võP·ÞN¥®Ó¯jG³fQ„VÁÎuxRå-.#¡à¦PG×zí<}år,¦(oŠ[¤ßT][wc^ØÜ¸¹£²¦|nCê•KXÚ…úúîà^gè+âvU,\œØ» ý2jó3ïŒÿ=é.„}î_6¨~ºØ	4ª
¾'€Íõ ùè„w'šs»  ×
MAôF•€^ôûkpGœ æw
î§Õéïö‹¿˜q)|“¨ó[7¯¡<,–=Sù;¯ ŒùvƒöApÂ)N˜[…j 4CèG;ŸaáW¯èhëívBwövwu´mr×á.J¿¡eSQr¥Åeº·¤¤Üãñ–~èKt%Ä]:,©7ØÙRÜÓ2”.”$ QLÖœ¢%8é®X¸¢L)^Æáøœ›èŸk&QŸ¼8XD¢øœ³;v–!Î*ÄœYL¢øœãT6·­ù.!Q|ÎÙÓ*ó…‰|¾g‰â{p®k¶è…È¯ïðgŠ¹[3Pße<×£6ÅãàÚ4
­Rùt~ÿIŽî«@A§É§ÉB‡$‡gAÃ°¸5'N××-ÉáZˆ…¹&F¾§„õðœäŽJr¢¾’\V*ôojlÐ_‘(Î†‘˜øž%9î[bËýX’Ã½Kaœ|ÿ†×åØù;{²Kr¨ÿqIßQ;šj?ù§HÓÅÎ«bãß~)éÃw‡3Ð}­,‡á%Åá^-»¾û‰ƒ‚r›bà]¬¸˜_¥ò™.gÅÅì…—šce$>.æIpHŒKÁÅZp1;-¸œ§Œfµ>mÐì¤Q³àbJšÌŒ4kÁ7Ãh†Ü7œ‚f‡?>ƒf@8žÍurøûVàbtƒf¸˜Bƒf#g¡A3\ÌQƒf¸˜“ÍVDgš .&`ÐÂ!œžE[ô ¯ú`_’h,Ñ¨Dãùß›8”·%Z>»GÜÃµú½BjÚc­ÔˆÛèÚqwÃ}Œç§B~ðú1-›â	ñ|ÂÎiœgþÄ¨¼5ÿà>WÊÿUí/úë%\»†Q}Öú¶Ðç	¡û•#\>
Šû–sœÎ°àJæ*ÑþSÔ,âU¢íCÔ4²ÔBß¢DÇ‡¢2Ü‹:Œ;óyq?Ðxnd'·ñ€ÏHïQÌçÉx¶9Æë›ñÏIåÕ!¼Ac!ï ÿ¦˜ÏŸ*æóì“
›÷à$_HåEùdÕ|¾Œ8ù|q3òyv…j>Ï^4×—¡ºÈw.0èt²h<;ÛÀë{j>ÿ~DÎÄY<®šÏÃ_PÍçÛï ®F’ÿÕ|^ÿ;Õ|~þ™E?.Yxžwq*j
I°E×ÎÆ:æ®cÇÛuÌã\7íÜ»®‰¬OÇr\4žBOÄ†ID!‹¯ñ”ŒhêhïÊë™	7qiP‰K€/Äv[ýë±\áÅ0ƒïÝ;{  *fÀ‚×êíK§
ÌÎ	3–Á;£ƒÞ
·ðNCRx-(/óµ˜jBV˜ð,fHÃ…áQÈƒ5â	ÿàeð3ªÀ;dáæÔ¡eúúú^mîÄárOo¨§§í~ßq)×…üÿe%Ãÿ_êAÿ¿wqiÉ×þÿ¯â¢þUz™«ÔXT4b&ÔtÏx‰ò fÞÔEG! „ýDƒøDã°#®,b hDì‰§X€ô¬(
ÒšÂ¡[r
‘ÄãUÜhj
„ý<c„—ËÞ:Ö§º4^ø÷7/Ni:ÒÐ¨žÅëÁå³It[ƒ&p2‰þ4l4äSxÝÐˆGÃ_†hË—Øå$Æ‰¿,kì"ÑŸ0É×ZñÀv Ñ-?§×[ètè×~Nc9º-ñÆÆ@g·×ù8¸Xþw[äÿÒB»-é·Yâw[èQè?4­¡Q#Ãm¯%~ØB/×ˆÃÎiì‹-éßÖ”Ô—$úï-éŸ¶ÐÏ™hëÛà}…CÂ# …µ«W€ÆÕ+–vvwWã¹5‹‰âÍqô=^á@¡øÎkïè5Áà¹‹Ø dÆ‡GàÍ ŒŒ`ˆ”^ÆôíŠí ¤Â|U²ù3t‹*žaËfÏ0Ä³šV<ûaXŠç oñ\Ã\<†¾xn†!&žÁ´ÎÏ=0EÄs3úüP^d¬?Y}b—B
DÙ ‰³áÙ—GôþdÛ7Â½ÈÑ·:\³dXSËÿéC>–îÆC:2†}ÄS0¨7\ÑW1ªßA{ÅÜç°W4Ã½-éÃ€’Ü¾D× •ò"ç¨¯Í9Z^DlóõÂ$±îe¢/–qƒ¾} ó·ë˜¦bPS0o»s´›^ß¿}VOÿýi=Ë”¯øYŒ´5}"=æ®M}Þ}?˜ð‡u^â‡r,sœÅº¿²•hUÃšrýËŽsØ[þa¢~ËË³z*—÷]ÿr$2p[c_Õ˜¦l­JÙžðû÷½¼–(»›RGÖ,Ó®¨¨/æyå-DŽB mX®å'•©Ïc;ý
òÀ6ÅödmGÛ<ä²€¯‰¶†´Y3Å?”÷ï/{ÁžqûÜþ*GÔø:¾A¨ßAÏ½%iö®-$ykIÆö¨ÞGzÊ«@ð
–÷ù†í$ $¾2NäÁóg ë„~ðûJjPvwÑÂU$gMQb%ðÿ£Ä‰õX(ñUÎW¯•ë‘Ü“ñ>0y_ù»>è€qeßv"rn em¯ÿ(¯_ÍžqRu€²BY
£uH\c©Ã°¹$d©‹± ›e
‰:lÅz;–â”êG‰wîs¡¬yÛ-(	?…z ¥‚óÀ‹:£žÇŠˆ¶¦È^	c‡øîp´c9XY¾ƒiY‰?NŸáu^u®ãuöíú[Ri¡¬NÈÃçfmZÏ0ží[‹˜^Z¦°£òZÜßqE¶‰èKZ_œ´ƒÅþ™”V[ùò¤DMæémÀÄI¿Ò¿(¥×¹\²[9_Äô)#¼€4›‘eLÆ~‚þ-ÞV¨;íÚ·¬¾Z9¬t?©…õ„ÉìcÖ¾öÏ¢2E´¾²®Å]õ3ë²á¸Ï‘tÍ!óÈèÐï1âv`zÞgºÔîOÆi·]f«Ônƒ¼mö¿t@º^öÛ O?Ð… Ç!é†ü5Ÿ-éÉázž(ê8»~(oÐÿ‰ó	õ0ÙÈ3|nê|Žà|Öxú7Aþ1iüÖÇ¿Æšã×‰ëáõÇ';ª"çÜáHç•´žÄukÈ™×®™Öµè{hyäóë;è«ôs———–2*5I„™ºHÄ€¾6êÑf}]÷fxÕ¯£àÖU«Ý7õv„¾ßÚÝ§oÚÜÓÛ~=H37ð®1üÚŠÐnvr1•ÛZv(hk%hÄ†¶m"ÐhGa“îmn“¡Ý¼HîmH?†ÏüžÌãÑîg3_ð‚þÉã{ z1G*mÞzO[z»u`êeÅ¾EÞOYq‰Gï-+)+÷¡CÕWýÁß\fé‹h1»WÊª€ÆÿÂˆïgmå.8“œÒ`È¡»N¹,bv=ËóSD~&èÇOÄ¯´ØOzzºï	öö´áÏz<ÅÄ}WWÈÝÞéÞÔÙrwp‘Ï}WO›oq_ÿÙýßÖ¢;ÔÝÝÙ¶ÌÈE\A“oqYI¸‹°-:iÓ4™W±×m¡£ß`ñzÉ –ôæš£¥Æ˜~.öçP´«iÑ~Aÿ3)ýNM†âR¬ß®Y3ík6&Áýu˜Ú•/ÒRo¾À_üaB?ÏâáŸg!	*,›[É³izÞü¼¼¼üü<›SÏ£ìû©ÆoÑ\ò¦åbùîW×?[¤DÒa·e*QUµ—¤j×ì<“®,[†"•‹D×)ÌÂNÌ‚1¤ø]l9² ³ì"@±Â‚˜ŽxøÃ>ÇÂžyšKºØ?g2â’a	L×|ºîãçD¬°	°2l‚½hh&ÓažVeïúþ8#ßržFeïú~ØGŒÏr0‡¥<M"[é\ éîíZIn˜ÐØCneT×qº–ë1äÖDÛÇ_¯Ç»]’;Ihˆ	#XÏålì|‹žqÅrÓwIrgAîl9„W$29'o*zf…%ü ªÏ	ñbêÛÎå’@nä Lƒ/`¨äé“Ø;Ÿ¾÷?Œ¡/Ìå ßÔç¹ÜLp~ôKåäŸä;åb‚
¤¢.ùó)B÷¹> OZôáõ¬Y.ÇŠ/†Ü¨EÇèùro›å´aÂ?€g)Ÿ^¡Á¿ßÄÐgWdÃüµ#ì?Hgnqàs`îª·ÇÐ7íâë&æöûH«œ~šÓ6FÓ¹Œ„ÓcœN`4;g´ñóNnO!ÄhvŽgãm!Öl?eó‡Ò\ÁÏ‘vpú,§Œf&˜fŠoJ§qz”Óéœ>Äiö[z:.)-Î~…>—…Î´ÐY:ÛBÏ²Ðó4úÁÎÎ)úrQ_…Õ÷*Q_…É–¢­ˆ´ÊÚ3 ‘]¢×Ý,ÑyýðµŠõš®œ~äOIòOi$Ñ)Ñ/h¸DFikyBù>‘Êû®è?…õß¸FRþNJÿ)Ðrù-í¡¸,ô<È?Yq€É+…@cy?á´Gô¿Bû_¹èœ†þVê…>¦X¹UŒ‡Ç‡Òå?ÇiP¤ôXä7ƒüK’ü½–øûÍçêÊ.Kü#‚Öýsó¹º2b‘YSàçÚ´üoZâYô´Än¦UÅ|N®ÂÞ.	ÖiuÔ¥bþªË"?ÇBç‰ù¤Óù¤.4ŸÃ«^‹þró9¼ZiÑ·ÔB/ú5¦ÿVSü¥£¤Ï „îjjÃƒy<xŸÆºÀáZôS  ¼ì;±ÓÉØ*vÑ`ˆX ˆi]46Â€5ÄFFpgDSÓêKc}Ô‚z)Lá²`.î¸˜Á3Â|Ô³ÑÔXSÝtCu#äk89frœÄr€Lû°‚Å#"À€,¸C ²»Ä¥`¾“ÿçWÛ†;é‰~ä!æ¢ÿ×Ìþoéµ%× ÿî¥Ïbúÿßþµÿÿ+¸Ðÿ¯*Šá{VÁ¤Ç—±ŸsËÏù{%«Æ¦q2üG( w	’œŸøM÷Qþfwaø¢igòŒý¦»ÈNÜeC8ÁT¿é~„ïRŽ»ÝH‡e}óßÃ¯.J÷B^¿jN'~cX…Í¦{3/X³¥~bƒ”Ãõåðz‰»Û%’<^õÇBíøü4ÿ4ÞÓé~Ó]`¾+,éð›ñ€±.Ñ<xÎì¶!"Ø¹Žy¾y=Äfþ¦Þ`ð†ÆRY“nðU‰6 Aˆ¦BC\=È 4¢…Ñ¢“ç•Nâ_òFÇ€˜Àò8Ìâ´ŽÉdæk;±øüZ‡_‡ß‡ß‡ÿM‚í4‹h™Í”å\GÞ‡ßWÕ@O×#®ûâÈ÷Åá÷Äác›ê1øCqä+ãð¿‡_@Äï¤r5SZ´Ãqä·ÄáX‹kcã.›zz»×wáQ]°ëîŽÞî.$CØ êÜÄm4ÃüÅ	ÉA[ˆ-¡`_G(j,¡õqL&E¿3¡˜¾?AL\vY¿CñLá÷ÑN7 2}¼½L›'‚ßÒ‹òåßcì”øòï/vI|y~í•øòz;,ñåùü¤Ä—çÜ3?EâH|yÞŽJ|Ù©ò¦ÄO“ø‡$¾¼v¼'ñåƒ«1‰/£	‰/oðÛN&OüZl¢7	©É¯ùŠ,Îwè$rUüOÏõÃÒˆ*'“cx8}Õ¤±‹&QÚ…4vÍä(¥SÆ.™|†Ò*ÒØ“Ã”þ<hì‚É]”>4.§“ƒ”þi,öd¥‹4vÁd3¥ƒ4.•“õ”~iìŠI?¥ßB»`²„Ò¯"M?©Sú_Æ¥|R£ô³HcLâáûš@øXõ­Õ·T¯©^ÝX_>·b¨¬ ¶íàŠöÐÛ–ü#H“ÍIuá%?ƒ§Zh¿wœùAYí½ °c4´àDÆ:¼ŠÓsÙ×/‘Ñ@8á=a‡ç]÷'~æMnÿ×Íà;¥ÂŸNì9‰œH˜¸Ê "Òwü3hxeø2?™Aô‹Gàå>‚ÿEoÖ†_¯ÝÿeUíþß/©UðÑ¶bÇïCÏû–ü‡ìÿESl;«ö:jÂŸÖ…×…?
D^«+?ÑûßP:ñë/#ÔüÏû8.¨Ï`M¼…?)|câ›Pòhy°}ëM™Â¯öQØbI@ÁGÛ	Ç:!Šw¼ÊÄlßFñÈ¯!gåîNÇ±»ööÉ`h¥ç!?’/Ž5E$“–1²»G½ý5ºÇ¶þäöW0*2–ž;Hå‰$¿ÿ¬äáWû?ª
(‡áƒÃçÿ¯½£¢ˆîm{íY°wA"	œ€ÄhÚÞGii«ñ+›&$ESK±«ØB¯‡†¤	x–p©¿ƒññ‡‰?4ðšÚp%ÄR51FsñWcÛ%T½Bã9oæÍîÎÜ.VþÚ×ÓyóÞ›7³3oæfÞ¾MþAÆÿ½Áÿ3òx åƒ±6ì‹)Ðñà„N{hÒ§õyã¤Ú¤%'<Zm&¾TK{Èx’às·I)û¼€ª6Óõ³^OÀˆ·Ê¾2´…çÄç™| PD*ì^b4©lK:RR¿æ¾kºtá¿´
G²vp2PÈ‚x+é©Ò=CWôbòLS³ÉžYåÅV­¿êZ.××0;SK}KÚ–Y È$Éøf¡8›ÌÆöUký½@­¥¦ü§z§É¿÷{Å`&–rŒJ0`&æÀ›ðÒä«sT¥ädHKõd´¾†ÕKKgZí5´ò†õ^ëß0j•(\­3×,jí%™dO¶$Ñ¤õ7ŒƒFD&Ñ*Vè?5LIw1£Ý&–§³¤åú¦k0³@«HzÙ}ê‚*~e<øO§FÒ~ÞQOqC÷©ž!-•8q¾&{†ÔÄ
Â~‚<Vò¸•3fÒ$ýÊÕ\®w8QL=œð>+áz$üšúYÙriÄC
UV†Fdx—1,Æ² )ô1à„×žÒ› uP?é“,¡Êž©`ý¬w0¤®%{t¥;LÊô°YÚÉâó8x:û bcVv— ìÑë«¢ÂÆ-Â2”%”rlân‡òßf¨¤ócüø{PKgvÕVìªŽÚU­é&è’áªð(QxTéÖ&*	Ë0°ÂŠzf2}Å˜ÊÒq`Z2Ã‡M”Áa&‡°ö+‰A6Æ&{¦=‰’ôa`º5Æ9uýËFû÷EÆ´+Ô ª\÷í´œ˜	±y}€K\æ&à5ºn™'.Ùsðå¹Ž+½'Oy¸ñØxñP'ž<;÷9ùïx–ÔÃ¥,þoý™ËÁåÓ[¤ç NÕ4éc8€†ß—I
qŸ#‡üü’Â³“ây1àY2¿Øþ³péï§¯!ràBå¡ÒÀ!uÝ­EÉâWŠú½¯¡ÛE _z{H=4r§[›¤å ”œú#—£ÒÒÀ#¥‹ýó^ðP¼³þÞèÊå\¼«ùµoZå¨¯X9\4y‰þCBùi£.×Ž“rˆYf”DUJ€CpÊsðH)ßs1F5ÿfI¦”åùYSYžïGñÝCþ\Çr¾ç=Ž)ßëòHóâ›¸æÞ|;îGùþT?G¾÷æìðÝBˆ) éQÌç0ÏÛ7…ùgwuo2ðó	¶bÿîÄt¦‡0}ÓO0=…é¦?bzÓ?0-Âs«E˜®Â´SŸ#‡•xˆQìjÛÝÖo«‡*È}G‚)·<ßZ]Å|¯žFªV‡Éœ„ÂÑòP¸<T×Ô­^S©y"ø\ûŽàÊ–  pGWKG+FÖD# 4RŠ–‡ÃäßºPU]¨öß
mßÕÑÙÕÖÌ^‹¼Êo¯ØŒ„kÂ¡Õ /ÌåU×…ˆÈ0—ÇœïPhp#1_ñàºÎÝÎ„XOð·«!ÆqîµvÌ©Ö9º‰F¹¹ÑPša˜cl”]ÝL,ñ_#¢Øƒ5N
Ç="d»#;€#õÁ<¿dyùl¾PÊC\þ}% n/5D¼/ñù¤<8}ð¸, ÜžêˆG…½¨;ççvµ^1ãµ pû<Šp{ÌAn?\Pò8. Ü^>‹ÿI_UJáÂù/?·ÇG‘?¨ØëÏ¡Y1ÏY¸}@~¾ M‰’ß~küZÚÇ .‚ƒ’ÿüZ%þòÇøÂ#uX@J…¸0Šå>=*VÄ¬ð]+ ¾þfðð§T¢—õçß»2ÆòëÈxV¢—û?)ñ›çð,¿D/×ÿº\?òëÈ?)ÑËõóïañý€y_ÁòrÉüKü:òësäÿTâÏ"6`O/ç?WÌ89Œ{–l·Ì_+?×Ëï†Òã~h;Ú?O‡%~~¾<u›X“þ#ŠG‡?_Ç‰³X¢—ù¿QG6ÿœ4ä}¨w‡Ã9Ü ŽIxÙ~Ic<ŽŸ(Êâ<Gˆ]"Û9N‡èm¹O*tt,³¿GÙàUcñÆú!âuAÄ{{/â‹l÷½ïç¨-ÞgØ]‹aOE|‰a'Eü<Ãþ‰øù†]ñ·æíS¾Ô°C"ÞoØ0ì†ˆ/3ìˆ¿Í˜ç"~í>â
ñy)âÍû¿ÈœGþŽ<s"¾œ÷{m-3Ç	¯«’ð·¾Ãôûþ¨²ñ:Èo¤ròûíqŠÏï·Ÿßoq¬Waß55à0âCþ=Äï‘ð'©|³ßDGÔEŠOº?üåŒKrœÚû¶w\Òÿ"Åû•ï¢œßÚŽ…´Ÿ¥qß÷²«wÒ—`L¡7_Žø?dá±“SÞªc’>ëðMø½ø—ðoÓ—òçÅ‡ô')}þ|¸Iv÷™ý½ë´}¡
µ.Ì›_óh<¡|;S¦ÚË	:àÃøµªý=v#àÕ2eJê‡Ç(~¡’•ú¡ÕA~Üÿ²jïRYü)no·â„yÍAÎ1ü	”/÷çÊ¾+¶c]­ÁEö¬ƒœTûçxûA–ÅAŽ·À^Î2ÙA!ä€_[`ß¾èÕüum³ƒœ]x¥2ïªŒw=m{€_#ƒ_á$×ÜÑÉnÛI–ü–nÙÝ¾¿­ë?©ºQ¾ž«£µK0«hmÕÿÌª™º-
±ªötµå‡«’°yQ­Â"K
seËÖE”¹2Äb†ûÂõ|61–I‹Þ—–ue<Z•€€¨Q‚ûgHq©$oTØe©º5Oj/eÒ:¸–ZIlýILßYô÷;Ë¶«xø.«Bb‡X\U0	÷J±±_Vç\pÁ\pÁ\pÁ\pÁ\pÁ	þ_Zª¹ À 