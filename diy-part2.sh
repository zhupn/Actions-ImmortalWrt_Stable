#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 更改默认IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

#添加软件包
#OpenClash
#rm -rf feeds/luci/applications/luci-app-openclash
#git clone -b master --single-branch --filter=blob:none https://github.com/vernesong/OpenClash.git feeds/luci/applications/luci-app-openclash
#AdguardHome
#git clone https://github.com/rufengsuixing/luci-app-adguardhome package/luci-app-adguardhome
#Mihomo
#git clone -b main --single-branch --filter=blob:none https://github.com/nikkinikki-org/OpenWrt-nikki
#mv OpenWrt-nikki/luci-app-nikki package/
#mv OpenWrt-nikki/nikki package/
#添加qosmate
#git clone https://github.com/hudra0/qosmate.git package/qosmate
#git clone https://github.com/LemonCrab666/luci-app-qosmate.git package/luci-app-qosmate

#修改nginx默认http
mkdir -p files/etc/config

cat <<EOF > files/etc/config/nginx
config main global
	option uci_enable 'true'

config server '_lan'
	list listen '8888 ssl default_server'
	list listen '[::]:8888 ssl default_server'
	option server_name '_lan'
	list include 'restrict_locally'
	list include 'conf.d/*.locations'
	option uci_manage_ssl 'self-signed'
	option ssl_certificate '/etc/nginx/conf.d/_lan.crt'
	option ssl_certificate_key '/etc/nginx/conf.d/_lan.key'
	option ssl_session_cache 'shared:SSL:32k'
	option ssl_session_timeout '64m'
	option access_log 'off; # logd openwrt'

config server '_redirect2ssl'
	list listen '8887'
	list listen '[::]:8887'
	option server_name '_redirect2ssl'
	option return '302 https://$host$request_uri'
EOF

chmod 0600 files/etc/config/nginx

#修改sysguarde备份列表
mkdir -p files/etc

cat <<EOF > files/etc/sysupgrade.conf
## This file contains files and directories that should
## be preserved during an upgrade.

# /etc/example.conf
# /etc/openvpn/

EOF

chmod 0644 files/etc/sysupgrade.conf

#将clash内核、TUN内核、Meta内核编译进目录
#mkdir -p files/etc/openclash/core
#Dev内核
#curl -L https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-amd64.tar.gz | tar -xz -C /tmp
#mv /tmp/clash files/etc/openclash/core/clash
#chmod 0755 files/etc/openclash/core/clash
#tun内核
#curl -L https://raw.githubusercontent.com/vernesong/OpenClash/core/master/premium/clash-linux-amd64-2023.08.17-13-gdcc8d87.gz | gunzip -c > /tmp/clash_tun
#mv /tmp/clash_tun files/etc/openclash/core/clash_tun
#chmod 0755 files/etc/openclash/core/clash_tun
#meta内核
#curl -L https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz | tar -xz -C /tmp
#mv /tmp/clash files/etc/openclash/core/clash_meta
#chmod 0755 files/etc/openclash/core/clash_meta

#将AdGuardHome核心文件编译进目录
#curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest \
#| grep "browser_download_url.*AdGuardHome_linux_amd64.tar.gz" \
#| cut -d : -f 2,3 \
#| tr -d \" \
#| xargs curl -L -o /tmp/AdGuardHome_linux_amd64.tar.gz && \
#tar -xzvf /tmp/AdGuardHome_linux_amd64.tar.gz -C /tmp/ --strip-components=1 && \
#mkdir -p files/usr/bin/AdGuardHome && \
#mv /tmp/AdGuardHome/AdGuardHome files/usr/bin/AdGuardHome/
#chmod 0755 files/usr/bin/AdGuardHome/AdGuardHome

# 修改固件MD5值
# 生成VerMagic文件
echo "e7e50fbc0aafa7443418a79928da2602" > vermagic
# 检查VerMagic文件是否生成成功
if [ ! -f "vermagic" ]; then
    echo "VerMagic文件生成失败！"
    exit 1
fi

# 修改include/kernel-defaults.mk
# 设置变量
pattern="grep '=[ym]' \$(LINUX_DIR)/.config.set | LC_ALL=C sort | \$(MKHASH) md5 > \$(LINUX_DIR)/.vermagic"
replacement="cp \$(TOPDIR)/vermagic \$(LINUX_DIR)/.vermagic"
# 对pattern中的特殊字符进行转义处理
escaped_pattern=$(printf '%s\n' "$pattern" | sed -e 's/[][\/$*.^|[]/\\&/g')
# 使用sed命令替换整段语句
sed -i "s|$escaped_pattern|$replacement|g" include/kernel-defaults.mk
# 检查替换是否成功
if [ $? -ne 0 ]; then
    echo "include/kernel-defaults.mk 替换失败！"
    exit 1
fi

# 修改package/kernel/linux/Makefile
sed -i 's/STAMP_BUILT:=$(STAMP_BUILT)_$(shell $(SCRIPT_DIR)\/kconfig.pl $(LINUX_DIR)\/.config | $(MKHASH) md5)/STAMP_BUILT:=$(STAMP_BUILT)_$(shell cat $(LINUX_DIR)\/.vermagic)/g' package/kernel/linux/Makefile
# 检查替换是否成功
if [ $? -ne 0 ]; then
    echo "package/kernel/linux/Makefile 替换失败！"
    exit 1
fi

# 输出成功信息
echo "替换成功！"

#将nlbwmon从服务目录移动到菜单栏
sed -i -e '/"path": "admin\/services\/nlbw\/display"/d' -e 's/services\///g' -e 's/"type": "alias"/"type": "firstchild"/' package/feeds/luci/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
sed -i 's|admin/services/nlbw/backup|admin/nlbw/backup|g' package/feeds/luci/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js

#由于内核参数 net.core.rmem_max 的限制，缓冲区大小被限制为 212992 字节，永久设置 Netlink 接收缓冲区大小为 524288 字节。
mkdir -p files/etc
echo "# Defaults are configured in /etc/sysctl.d/* and can be customized in this file" > files/etc/sysctl.conf
echo "net.core.rmem_max=524288" >> files/etc/sysctl.conf

# =================================================================
#        以下为新增：ImmortalWrt 傲腾固态 8G 专属全功能定制脚本
# =================================================================

# ----------------- 1. 空间物理扩容 -----------------
# 根目录物理分区直接拉满到 8G
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=8192" >> .config
# 引导分区加大到 64M，确保内核和后续包不拥挤
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=64/g' include/target.mk

# ----------------- 2. 强行锁死：你提供的高级核心包清单 -----------------
echo "CONFIG_PACKAGE_6relayd=y" >> .config
echo "CONFIG_PACKAGE_apk-openssl=y" >> .config
echo "CONFIG_PACKAGE_autocore=y" >> .config
echo "CONFIG_PACKAGE_automount=y" >> .config
echo "CONFIG_PACKAGE_base-files=y" >> .config
echo "CONFIG_PACKAGE_block-mount=y" >> .config
echo "CONFIG_PACKAGE_ca-bundle=y" >> .config
echo "CONFIG_PACKAGE_default-settings-chn=y" >> .config
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config
echo "CONFIG_PACKAGE_fdisk=y" >> .config
echo "CONFIG_PACKAGE_firewall4=y" >> .config
echo "CONFIG_PACKAGE_font-wqy=y" >> .config
echo "CONFIG_PACKAGE_fstools=y" >> .config
echo "CONFIG_PACKAGE_grub2-bios-setup=y" >> .config
echo "CONFIG_PACKAGE_htop=y" >> .config
echo "CONFIG_PACKAGE_i915-firmware-dmc=y" >> .config

# 全套有线与 USB 网卡驱动
echo "CONFIG_PACKAGE_kmod-8139cp=y" >> .config
echo "CONFIG_PACKAGE_kmod-8139too=y" >> .config
echo "CONFIG_PACKAGE_kmod-amazon-ena=y" >> .config
echo "CONFIG_PACKAGE_kmod-amd-xgbe=y" >> .config
echo "CONFIG_PACKAGE_kmod-bnx2=y" >> .config
echo "CONFIG_PACKAGE_kmod-button-hotplug=y" >> .config
echo "CONFIG_PACKAGE_kmod-drm-i915=y" >> .config
echo "CONFIG_PACKAGE_kmod-dwmac-intel=y" >> .config
echo "CONFIG_PACKAGE_kmod-e1000=y" >> .config
echo "CONFIG_PACKAGE_kmod-e1000e=y" >> .config
echo "CONFIG_PACKAGE_kmod-forcedeth=y" >> .config
echo "CONFIG_PACKAGE_kmod-fs-ext4=y" >> .config
echo "CONFIG_PACKAGE_kmod-fs-f2fs=y" >> .config
echo "CONFIG_PACKAGE_kmod-fs-ntfs3=y" >> .config
echo "CONFIG_PACKAGE_kmod-fs-vfat=y" >> .config
echo "CONFIG_PACKAGE_kmod-i40e=y" >> .config
echo "CONFIG_PACKAGE_kmod-igb=y" >> .config
echo "CONFIG_PACKAGE_kmod-igbvf=y" >> .config
echo "CONFIG_PACKAGE_kmod-igc=y" >> .config
echo "CONFIG_PACKAGE_kmod-ixgbe=y" >> .config
echo "CONFIG_PACKAGE_kmod-ixgbevf=y" >> .config
echo "CONFIG_PACKAGE_kmod-nf-nathelper=y" >> .config
echo "CONFIG_PACKAGE_kmod-nf-nathelper-extra=y" >> .config
echo "CONFIG_PACKAGE_kmod-nft-offload=y" >> .config
echo "CONFIG_PACKAGE_kmod-pcnet32=y" >> .config
echo "CONFIG_PACKAGE_kmod-r8101=y" >> .config
echo "CONFIG_PACKAGE_kmod-r8125=y" >> .config
echo "CONFIG_PACKAGE_kmod-r8126=y" >> .config
echo "CONFIG_PACKAGE_kmod-r8168=y" >> .config
echo "CONFIG_PACKAGE_kmod-tg3=y" >> .config
echo "CONFIG_PACKAGE_kmod-tulip=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-core=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-hid=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-net=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-net-asix=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-net-asix-ax88179=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-net-rtl8150=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-net-rtl8152-vendor=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-ohci=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-storage=y" >> .config
echo "CONFIG_PACKAGE_kmod-usb-uhci=y" >> .config
echo "CONFIG_PACKAGE_kmod-vmxnet3=y" >> .config

# 依赖库
echo "CONFIG_PACKAGE_libc=y" >> .config
echo "CONFIG_PACKAGE_libgcc=y" >> .config
echo "CONFIG_PACKAGE_libiconv=y" >> .config
echo "CONFIG_PACKAGE_libustream-openssl=y" >> .config
echo "CONFIG_PACKAGE_libc-libintl=y" >> .config
echo "CONFIG_PACKAGE_logd=y" >> .config

# LuCI 网页应用及皮肤
echo "CONFIG_PACKAGE_luci-app-attendedsysupgrade=y" >> .config
echo "CONFIG_PACKAGE_luci-app-package-manager=y" >> .config
echo "CONFIG_PACKAGE_luci-app-statistics=y" >> .config
echo "CONFIG_PACKAGE_luci-app-ttyd=y" >> .config
echo "CONFIG_PACKAGE_luci-compat=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-attendedsysupgrade-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-commands-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-ddns-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-vpn-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_luci-lib-base=y" >> .config
echo "CONFIG_PACKAGE_luci-lib-ipkg=y" >> .config
echo "CONFIG_PACKAGE_luci-light=y" >> .config
echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config

# 关键网络组件与 IPv6 环境
echo "CONFIG_PACKAGE_miniupnpd=y" >> .config
echo "CONFIG_PACKAGE_mkf2fs=y" >> .config
echo "CONFIG_PACKAGE_mtd=y" >> .config
echo "CONFIG_PACKAGE_nano=y" >> .config
echo "CONFIG_PACKAGE_netifd=y" >> .config
echo "CONFIG_PACKAGE_nftables=y" >> .config
echo "CONFIG_PACKAGE_odhcp6c=y" >> .config
echo "CONFIG_PACKAGE_odhcpd-ipv6only=y" >> .config
echo "CONFIG_PACKAGE_openssh-client=y" >> .config
echo "CONFIG_PACKAGE_openssh-server=y" >> .config
echo "CONFIG_PACKAGE_partx-utils=y" >> .config
echo "CONFIG_PACKAGE_ppp=y" >> .config
echo "CONFIG_PACKAGE_ppp-mod-pppoe=y" >> .config
echo "CONFIG_PACKAGE_procd-ujail=y" >> .config
echo "CONFIG_PACKAGE_qosify=y" >> .config
echo "CONFIG_PACKAGE_samba4-server=y" >> .config
echo "CONFIG_PACKAGE_uci=y" >> .config
echo "CONFIG_PACKAGE_uclient-fetch=y" >> .config
echo "CONFIG_PACKAGE_urandom-seed=y" >> .config
echo "CONFIG_PACKAGE_urngd=y" >> .config
echo "CONFIG_PACKAGE_vnstat=y" >> .config

# ----------------- 3. 额外追加：Docker 全家桶核心 -----------------
echo "CONFIG_PACKAGE_luci-app-dockerman=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_docker-compose=y" >> .config
echo "CONFIG_PACKAGE_dockerd=y" >> .config
