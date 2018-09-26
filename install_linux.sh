#!/bin/bash

########VARIAVEIS##########
DISTRO=$1
VERSAO=$2
PROXY_IP=$3

function Config{
	mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf-bkp
	touch -c /etc/zabbix/zabbix_agentd.conf
	echo "PidFile=/var/run/zabbix/zabbix_agentd.pid" >> /etc/zabbix/zabbix_agentd.conf
	echo "LogFile=/var/log/zabbix/zabbix_agentd.log" >> /etc/zabbix/zabbix_agentd.conf
	echo "LogFileSize=0" >> /etc/zabbix/zabbix_agentd.conf
	echo "EnableRemoteCommands=1" >> /etc/zabbix/zabbix_agentd.conf
	echo "Server=$PROXY_IP" >> /etc/zabbix/zabbix_agentd.conf
	echo "Hostname=$host" >> /etc/zabbix/zabbix_agentd.conf
	echo "Timeout=30" >> /etc/zabbix/zabbix_agentd.conf
	echo "Include=/etc/zabbix/zabbix_agentd.d/*.conf" >> /etc/zabbix/zabbix_agentd.conf

	echo "Iniciando serviço zabbix_agent"
	systemctl restart zabbix-agent 
	systemctl enable zabbix-agent
}

function Debian{

	if test	$VERSAO = "9" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/debian/pool/main/z/zabbix-release/zabbix-release_3.4-1+stretch_all.deb
			dpkg -i zabbix-release_3.4-1+stretch_all.deb
			apt update
			apt install zabbix-agent
	elif test $VERSAO = "8" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/debian/pool/main/z/zabbix-release/zabbix-release_3.4-1+jessie_all.deb
			dpkg -i zabbix-release_3.4-1+jessie_all.deb
			apt update
			apt install zabbix-agent 
	elif test $VERSAO = "7" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/debian/pool/main/z/zabbix-release/zabbix-release_3.4-1+wheezy_all.deb
			dpkg -i zabbix-release_3.4-1+wheezy_all.deb
			apt update
			apt install zabbix-agent
		else
			echo "VERSAO NAO SUPORTADA" 
		fi

	Config
}

function RHEL{

	if test $VERSAO = "7" 2>/dev/null
		then
			rpm -i https://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm
			yum install zabbix-agent
	elif test $VERSAO= "6" 2>/dev/null
		then
			rpm -i https://repo.zabbix.com/zabbix/3.4/rhel/6/x86_64/zabbix-release-3.4-1.el6.noarch.rpm 
			yum install zabbix-agent
		else
			echo "VERSAO NAO SUPORTADA"

	Config
}

function Ubuntu{

	if test	$VERSAO = "18" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.4-1+bionic_all.deb
			dpkg -i zabbix-release_3.4-1+bionic_all.deb
			apt update 
			apt install zabbix-agent
	elif test $VERSAO = "16" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.4-1+xenial_all.deb
			dpkg -i zabbix-release_3.4-1+xenial_all.deb
			apt update 
			apt install zabbix-agent
	elif test $VERSAO = "14" 2>/dev/null
		then
			wget https://repo.zabbix.com/zabbix/3.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.4-1+trusty_all.deb
			dpkg -i zabbix-release_3.4-1+trusty_all.deb
			apt update 
			apt install zabbix-agent
	fi

	Config
}

if test $DISTRO = debian 2>/dev/null
	then
		Debian
elif test $DISTRO = ubuntu 2>/dev/null
	then
		Ubuntu
elif test  $DISTRO = rhel 2>/dev/null
	then
		RHEL
else 
	echo "DISTRO NAO SUPORTADA"
fi 