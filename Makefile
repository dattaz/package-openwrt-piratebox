include $(TOPDIR)/rules.mk

PKG_NAME:=piratebox
PKG_VERSION:=1.1.0
PKG_RELEASE:=2


include $(INCLUDE_DIR)/package.mk

define Package/piratebox
  SECTION:=net
  CATEGORY:=Network
  TITLE:=PirateBox-Main package
  SUBMENU:=PirateBox
  URL:=http://piratebox.aod-rpg.de
  DEPENDS:= +python +lighttpd +lighttpd-mod-cgi +lighttpd-mod-redirect +lighttpd-mod-alias +lighttpd-mod-setenv  +lighttpd-mod-fastcgi +php5-cgi +zoneinfo-core +zoneinfo-simple +php5-mod-json  +php5-mod-sqlite3 +php5-mod-pdo-sqlite +php5-mod-sqlite +php5-mod-pdo +radvd +ip
  PKGARCH:=all
  MAINTAINER:=Matthias Strubel <matthias.strubel@aod-rpg.de>
endef

define Package/piratebox/description
	Turns your OpenWRT Router into a PirateBox; see http://www.daviddarts.com
endef

define Package/librarybo/conffiles
/etc/piratebox.config
endef


define Package/piratebox/postinst
	#!/bin/sh
	##------ Preparerations for /mnt/ext dependencies
	if [ ! -e /etc/init.d/piratebox ] ; then
	   ln -s $$PKG_ROOT/etc/init.d/piratebox /etc/init.d/
	fi

	if [ ! -e /etc/piratebox.config ] ; then
	   ln -s $$PKG_ROOT/etc/piratebox.config /etc
	fi

	# include PirateBox shared functionality
	. $$PKG_ROOT/usr/share/piratebox/piratebox.common
	. $$PKG_ROOT/etc/piratebox.config

	# disable web interface, start PirateBox instead
	# Only disable if installed!
	if [ -e /etc/init.d/uhttpd ] ; then 
	   echo "Stopping uttpd and disable it"
	   /etc/init.d/uhttpd stop
	   /etc/init.d/uhttpd disable
	fi

	if [ -e /etc/init.d/luci_fixtime ] ; then
	   echo "Stopping luci_fixtime and disable it"
	  /etc/init.d/luci_fixtime stop
	  /etc/init.d/luci_fixtime disable
	fi

	if [ -e /etc/init.d/luci_dhcp_migrate ] ; then
	  /etc/init.d/luci_dhcp_migrate stop
	  /etc/init.d/luci_dhcp_migrate disable
	fi

	if [ -e /etc/init.d/dnsmasq ] ; then
	   /etc/init.d/dnsmasq stop
	   /etc/init.d/dnsmasq disable
	fi

	if [ -e /etc/init.d/watchdog ] ; then
		/etc/init.d/watchdog stop
		/etc/init.d/watchdog disable
	fi

	##only do network config etc, when first install
	setup_run=0
	if [[ ! -e  $$PKG_ROOT/etc/piratebox.install_done ]]  ; then
	    # configure USB, network
	     /etc/init.d/piratebox setup
	     [ $$? -ne 0 ] && exit 99
	     setup_run=1
	    touch $$PKG_ROOT/etc/piratebox.install_done 
	fi
	# prepare USB partition and install PirateBox
	/etc/init.d/piratebox init
	[ $$? -ne 0 ] && exit 99
	# start PirateBox service
	/etc/init.d/piratebox enable 
	/etc/init.d/piratebox start
	
	echo "Bringing PirateBox down again and leave image mounted"
 	echo " for further installation"
	/etc/init.d/piratebox  stop_keep
 
	if [[ "$$setup_run"  -eq "1" ]] ; then
	  # give some user feedback
   	  echo "Setup complete!"
   	  echo "You can remove the WAN connection now."
   	  echo "Please reboot your PirateBox now: "
   	  echo "   # reboot "
	fi
	echo "Done"
endef

define Package/piratebox/preinst
	#!/bin/sh
	#Disable Piratebox, it it seems that it is installed
	if [ -e  /etc/init.d/piratebox  ] ; then
	   /etc/init.d/piratebox stop
	fi

	if [ -z $$PKG_ROOT ] ; then
		echo "Attention, since package piratebox version 1.0, piratebox needs to be installed on installation destination "ext", which is created by the package extendRoot. See http://piratebox.aod-rpg.de for more informations"
		echo " ... " && sleep 2
		echo " ... " && sleep 2
	fi
	exit 0
endef

define Package/piratebox/prerm
	#!/bin/sh
	# Revert-Changes
	
	. /usr/share/piratebox/piratebox.common


	if [ -e /etc/init.d/luci_fixtime  ] ; then
	   /etc/init.d/luci_fixtime enable
	fi

	if [ -e /etc/init.d/luci_dhcp_migrate ] ; then
	   /etc/init.d/luci_dhcp_migrate enable
	fi

	if [ -e /etc/init.d/uhttpd ] ; then
	   /etc/init.d/uhttpd enable
	fi

	 /etc/init.d/watchdog enable
	 /etc/init.d/dnsmasq enable

	/etc/init.d/piratebox disable
	/etc/init.d/piratebox nodns
	#Stop Piratebox
	/etc/init.d/piratebox stop

	# undo configuration
	pb_undoconfig

	echo "Please reboot for changes to take effect."
endef

define  Package/piratebox/postrm
	#!/bin/sh

	# remove links, if exists

	[ -e /etc/piratebox.config ] && rm  /etc/piratebox.config  
	[ -e /etc/init.d/piratebox ] && rm  /etc/init.d/piratebox

	exit 0

endef 


define Build/Compile
endef

define Build/Configure
endef


define Package/piratebox/install
	$(INSTALL_DIR) $(1)/usr/share/piratebox
	$(INSTALL_DIR) $(1)/etc/	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/hotplug.d
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/usr/share/piratebox/piratebox.common $(1)/usr/share/piratebox/piratebox.common
	$(INSTALL_BIN) ./files/usr/share/piratebox/timesave.common  $(1)/usr/share/piratebox/timesave.common
	$(INSTALL_BIN) ./files/etc/piratebox.config $(1)/etc/piratebox.config
	$(INSTALL_BIN) ./files/etc/init.d/piratebox $(1)/etc/init.d/piratebox
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/15-pbxRedirect $(1)/etc/hotplug.d/iface/15-pbxRedirect
	( [ "$(CONFIG_PIRATEBOX_BETA)"  == "y" ] &&  sed 's|piratebox.aod-rpg.de|beta.openwrt.piratebox.de|' -i $(1)/etc/piratebox.config ) || echo "skipped"
endef

$(eval $(call BuildPackage,piratebox))
