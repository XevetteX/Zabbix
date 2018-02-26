#!/bin/bash
#		Versão 1.1
#
#		zimbra_monitor.sh - Monitoramento em Zabbix
#
# -------------------------------------------------
# 	
# 	Autor	: Matheus Oliveira Viana
# 	Email	: matheus.viana@tradein.com.br
#
# -------------------------------------------------
#	DESCRIÇÃO :
#
# 		Este programa tem como função auxiliar o 
#		monitorameto com Zabbix. Com funções de 
#		analise de Blacklist, serviços e fila 
#
# -------------------------------------------------
#	NOTAS:
#
# 		Utiliza do pacote dig para fazer as 
#		consultas em blacklist
#
# 		Utiliza o arquivo /tmp/zmcontrol_status.log
#		para analize dos serviços.
#		
#		Utiliza do arquivo /etc/zabbix/scripts/list.txt
#		Para realizar a checagem de quantidade de emails
#		enviados e /etc/zabbix/scripts/list_reject.txt
#		para carregar os emails com falha de envio
# 		Ex. : 192.168.0.1-SERVER1
#
# -------------------------------------------------
#	MODIFICADOR_POR	(DD/MM/YYYY)
#	Matheus.Viana	 21/02/2018	-	Primeira versão.
#	Matheus.Viana	 26/02/2018 -	Adcionado função Sender
#
#
# Licença	: GNU GPL
#
WHO_CHECK=$1

function Services_Discovery(){
HOUSECLEANER=$(cat /tmp/zmcontrol_status.log | grep -v Host | grep -v not | rev | cut -d' ' -f 2- | rev | sed 's/ w/_w/')
RESULT=$(for a in $HOUSECLEANER
	do 
		echo -n '{"{#SERVICE}":"'${a}'"},' | sed 's/_w/ w/'
	done)
VAR=$(echo -e '{"data":['$RESULT']' | sed -e 's:\},]$:\}]:' )
echo -n $VAR'}'
}

function Services_Status(){
TARGET=$2
COUNT_LINE=$(cat /tmp/zmcontrol_status.log | grep -v not | grep "$TARGET")
STATUS_SERVICE=$(echo $COUNT_LINE | rev | cut -d' ' -f 1 | rev )
if test $STATUS_SERVICE = "Stopped"
	then 
		echo 1
	else
		echo 0
fi
}

function Queue(){
MAILQ=$(/opt/zimbra/common/sbin/mailq | grep Request | awk -F" " '{print $5}')

if [ -z "$MAILQ" ]
	then	
		echo 0
	
	elif [ "$MAILQ" -ge 1 ]
	then
	echo "$MAILQ"
fi
}

function Blacklist(){
DOM=$1
BL=$2
RESOLVED=$(dig +short $DOM)
LOAD_RESOLVED=$(echo $RESOLVED)
P1=$(echo $LOAD_RESOLVED | cut -d '.' -f 4)
P2=$(echo $LOAD_RESOLVED | cut -d '.' -f 3)
P3=$(echo $LOAD_RESOLVED | cut -d '.' -f 2)
P4=$(echo $LOAD_RESOLVED | cut -d '.' -f 1)
REVERSED=$(echo "$P1.$P2.$P3.$P4")
TEST_THIS=$(echo $REVERSED.$BL) 
LOAD_BL=$(dig +short -t a $TEST_THIS)
if [ -z $LOAD_BL ]
	then
		echo 0
	else
		echo 1
fi
}

function Sender(){
rm -rf /etc/zabbix/scripts/list.txt
rm -rf /etc/zabbix/scripts/list_reject.txt
DATE=$(date +%Y%m%d)
/opt/zimbra/bin/zmprov -l gaa | grep -v admin | grep -v spam | grep -v ham | grep -v virus | grep -v galsync > users.txt
USERS=$(cat /etc/zabbix/scripts/users.txt)
for l in $USERS
	do
		LOAD_MSG=$(/opt/zimbra/libexec/zmmsgtrace --sender $l --time $DATE | grep "$l -->")
		echo -e "$LOAD_MSG" >> /etc/zabbix/scripts/list.txt
	done

for l in $USERS
	do
		LOAD_MSG1=$(/opt/zimbra/libexec/zmmsgtrace --sender $l --time $DATE --id reject| grep "$l -->")
		echo -e "$LOAD_MSG1" >> /etc/zabbix/scripts/list_reject.txt
	done
}

if test $WHO_CHECK = "Blacklist"
	then 
		Blacklist $2 $3
elif test $WHO_CHECK = "Queue"
	then
		Queue
elif test $WHO_CHECK = "Services_Discovery"
	then
		Services_Discovery
elif test $WHO_CHECK = "Services_Status"
	then
		Services_Status $2
elif test $WHO_CHECK = "Sender"
	then
		Sender
elif test $WHO_CHECK = "Enviados"
	then
		cat /etc/zabbix/scripts/list.txt | grep ">" | wc -l
elif test $WHO_CHECK = "Rejeitados"
	then
		cat /etc/zabbix/scripts/list_reject.txt | grep ">" | wc -l
fi
