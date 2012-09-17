#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install rsync"
    exit 1
fi
cur_dir=$(pwd)

# If necessary, edit these for your system
DBUSER='root'
DBPASS='root'
DBHOST='localhost'

ZBX_VER='2.0.0'
#-----------------------------------------------------------------	
#if [ ! "`rpm -qa|grep fping`" ]; then
  if [ "`uname -m`" == "x86_64" ]; then
     rpm -Uhv http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
  elif [ "`uname -m`" == "i686" ]; then
     rpm -Uhv http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.i686.rpm
  fi
#fi
#-----------------------------------------------------------------	

yum -y install   curl-devel net-snmp-devel fping e2fsprogs-devel zlib-devel libgssapi-devel krb5-devel openssl-devel wget libssh2-devel openldap-devel  
chmod 4755 /usr/sbin/fping
#groupadd zabbix
#useradd -g zabbix zabbix
#-----------------------------------------------------------------	

rm -rf zabbix-$ZBX_VER
rm zabbix-$ZBX_VER.tar.gz
wget http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/$ZBX_VER/zabbix-$ZBX_VER.tar.gz
tar -zxvf zabbix-$ZBX_VER.tar.gz
cd zabbix-$ZBX_VER
./configure --prefix=/usr/local/zabbix --enable-server --enable-agent --with-mysql --enable-ipv6 --with-net-snmp --with-libcurl --enable-proxy  --with-ldap --sysconfdir=/etc/zabbix --with-mysql=/usr/local/mysql/bin/mysql_config 
make
make install

#-----------------------------------------------------------------	


echo "DROP DATABASE IF EXISTS zabbix;" | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS}

(
echo "CREATE DATABASE zabbix;"
echo "USE zabbix;"
cat $cur_dir/zabbix-$ZBX_VER/database/mysql/schema.sql
cat $cur_dir/zabbix-$ZBX_VER/database/mysql/images.sql
cat $cur_dir/zabbix-$ZBX_VER/database/mysql/data.sql
) | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS}


#cat $cur_dir/zabbix-$ZBX_VER/database/mysql/schema.sql | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS} zabbix
#cat $cur_dir/zabbix-$ZBX_VER/database/mysql/images.sql | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS} zabbix
#cat $cur_dir/zabbix-$ZBX_VER/database/mysql/data.sql | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS} zabbix

#cat /root/zabbix-2.0.2/database/mysql/images.sql | mysql -hlocalhost -uroot --password=root zabbix
#cat /root/zabbix-2.0.2/database/mysql/data.sql  | mysql -hlocalhost -uroot --password=root zabbix

#-----------------------------------------------------------------	

#### BEGIN ZABBIX SERVER & AGENT PROCESS INSTALL & START
adduser -r -d /usr/local/zabbix -s /sbin/nologin zabbix
mkdir -p /etc/zabbix/alert.d
mkdir -p /var/log/zabbix-server
mkdir -p /var/log/zabbix-agent
mkdir -p /var/run/zabbix-server
mkdir -p /var/run/zabbix-agent
chown zabbix.zabbix /var/run/zabbix*
chown zabbix.zabbix /var/log/zabbix*
chown -R zabbix:zabbix /etc/zabbix
chown -R zabbix:zabbix /usr/local/zabbix
chown zabbix.zabbix /usr/local/zabbix/*

cp -a $cur_dir/zabbix-$ZBX_VER/misc/conf/zabbix_* /etc/zabbix
#cp $cur_dir/zabbix-$ZBX_VER/misc/conf/zabbix_agentd.conf /etc/zabbix

chmod 777 /etc/zabbix/zabbix_*
chown zabbix /etc/zabbix/zabbix_*

cp -a $cur_dir/zabbix-$ZBX_VER/misc/init.d/redhat/8.0/zabbix_* /etc/init.d
#cp $cur_dir/zabbix-$ZBX_VER/misc/init.d/redhat/8.0/zabbix_agentd /etc/init.d



#cp $cur_dir/zabbix-$ZBX_VER/misc/init.d/redhat/zabbix_server_ctl /etc/init.d
#cp $cur_dir/zabbix-$ZBX_VER/misc/init.d/redhat/zabbix_agentd_ctl /etc/init.d
#-----------------------------------------------------------------	
cd /etc/init.d
patch -p0 -l << "eof"
--- zabbix_server.orig  2008-11-13 22:59:49.000000000 -0800
+++ zabbix_server       2008-11-13 23:53:58.000000000 -0800
@@ -14,7 +14,7 @@
 [ "${NETWORKING}" = "no" ] && exit 0
 
 RETVAL=0
-progdir="/usr/local/zabbix/bin/"
+progdir="/usr/local/zabbix/sbin/"
 prog="zabbix_server"
 
 start() {
--- zabbix_agentd.orig  2008-11-14 00:15:24.000000000 -0800
+++ zabbix_agentd       2008-11-14 00:15:32.000000000 -0800
@@ -14,7 +14,7 @@
 [ "${NETWORKING}" = "no" ] && exit 0
 
 RETVAL=0
-progdir="/usr/local/zabbix/bin/"
+progdir="/usr/local/zabbix/sbin/"
 prog="zabbix_agentd"
 
 start() {
eof



#-----------------------------------------------------------------	

chkconfig zabbix_server on
chkconfig zabbix_agentd on
chmod +x /etc/init.d/zabbix_server
chmod +x /etc/init.d/zabbix_agentd

#chmod 755 /etc/init.d/zabbix_server
#chmod 755 /etc/init.d/zabbix_agentd
service zabbix_server stop
service zabbix_agentd stop
service zabbix_server start
service zabbix_agentd start


#-----------------------------------------------------------------	
#Installing the Web frontend

cd $cur_dir
cd zabbix-$ZBX_VER
mkdir /home/www/zabbix
cp -a frontends/php/* /home/www/zabbix
chmod -R 777 /home/www/zabbix
chown -R zabbix:zabbix /home/www/zabbix

sed -i 's/max_input_time = 60/max_input_time = 300/g' /usr/local/php/etc/php.ini
/etc/init.d/php-fpm restart

echo "============================install  end !================================"
echo "Load http://localhost/zabbix/"
echo "username: admin"
echo "password: zabbix"
echo "vim /usr/local/php/etc/php.ini "
echo "service zabbix_server {start|stop|restart|condrestart}"
