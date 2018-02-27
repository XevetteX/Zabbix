#!/bin/bash
#		Versão 1.1
#
#		zimbra_monitor.sh - Monitoramento em Zabbix
#
# -----------------------------------------------------------------------
# 	
# 	Autor	: Matheus Oliveira Viana
# 	Email	: matheus.viana@tradein.com.br
#
# ------------------------------------------------------------------------
#	DESCRIÇÃO :
#
# 		Este programa tem como função auxiliar o 
#		monitorameto com Zabbix. Com funções de 
#		analise de Blacklist, serviços e fila 
#
# ------------------------------------------------------------------------
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
# 		
#		Utiliza o repositorio do github para atualizações
#
# ------------------------------------------------------------------------
#	MODIFICADOR_POR	(DD/MM/YYYY)
#	Matheus.Viana	 21/02/2018	-	Primeira versão.
#	Matheus.Viana	 26/02/2018 	-	Adicionado função Sender
#
#
# Licença	: GNU GPL
#
WHO_CHECK=$1
VERSION="1.1"

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

function Update(){


#
# ADICIONAR NOVOS PARAMETROS AQUI E NO UPDATE
#



echo "executando backup da versão anterior"
	cp /etc/zabbix/scripts/zimbra_monitor.sh /etc/zabbix/scripts/zimbra_monitor.sh-bkp
	rm -rf /etc/zabbix/scripts/zimbra_monitor.sh

echo "Obtendo nova versão"
	git clone https://github.com/XevetteX/zabbix/

echo "Instalando nova versão"
	cp /zabbix/Zimbra_Monitor/* /etc/zabbix/scripts/

echo "Aplicando permissões de execução"
	chmod +x /etc/zabbix/scripts/zimbra_monitor.sh
}

function Install(){
DISTRO=$(cat /etc/issue | cut -d' ' -f 1)

echo "Criando entradas em Crontab"
if test $DISTRO = "Ubuntu";
	then
		echo "Fazendo backup do Crontab do sistema"
		cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root-bkp
		echo '*/5 * * * * su -c "/opt/zimbra/bin/zmcontrol status" zimbra > /tmp/zmcontrol_status.log' >> /var/spool/cron/crontabs/root
		echo '* 1 * * * /etc/zabbix/scripts/zimbra_monitor.sh Sender' >> /var/spool/cron/crontabs/root
	else
		echo "Fazendo backup do Crontab do sistema"
		cp /var/spool/cron/root /var/spool/cron/root-bkp
		echo '*/5 * * * * su -c "/opt/zimbra/bin/zmcontrol status" zimbra > /tmp/zmcontrol_status.log' >> /var/spool/cron/root
		echo '* 1 * * * /etc/zabbix/scripts/zimbra_monitor.sh Sender' >> /var/spool/cron/root
fi

echo "Criando diretorios"
	mkdir /etc/zabbix/scripts/ 

echo "Copiando arquivos"
	cp /Zabbix/Zimbra_Monitor/* /etc/zabbix/scripts/

echo "Aplicando permissões de execução"
	chmod +x /etc/zabbix/scripts/zimbra_monitor.sh
	
echo "Executando backup das configurações do Zabbix_agent"

	cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf-bkp

echo "Atualizando arquivo de configuração do zabbix-agent"
rm -rf /etc/zabbix/zabbix_agentd.conf
cat -s /etc/zabbix/zabbix_agentd.conf-bkp | grep -v "#" | uniq -u > /etc/zabbix/zabbix_agentd.conf

#
# ADICIONAR NOVOS PARAMETROS AQUI E NO UPDATE
#
PARAMETERS="
UserParameter=Mail.Services_Discovery,/etc/zabbix/zimbra_monitor.sh-Services_Discovery
UserParameter=Blacklist[*],/etc/zabbix/zimbra_monitor.sh Blacklist-$1-$2
UserParameter=Fila,/etc/zabbix/zimbra_monitor.sh-Queue
UserParameter=Mail.Services_Status[*],/etc/zabbix/zimbra_monitor.sh-Services_Status-$1
UserParameter=Mail.Senders,/etc/zabbix/scripts/zimbra_monitor.sh-Enviados
UserParameter=Mail.Reject,/etc/zabbix/scripts/zimbra_monitor.sh-Rejeitados
UserParameter=Zimbra_Monitor_version,/etc/zabbix/scripts/zimbra_monitor.sh-Version
UserParameter=Zimbra_Monitor_Update,/etc/zabbix/scripts/zimbra_monitor.sh-Update"

for a in $PARAMETERS
	do
		TESTA=$(cat /etc/zabbix/zabbix_agentd.conf | sed  's/-/ /') 
		TESTP=$(cat /etc/zabbix/zabbix_agentd.conf | grep $TESTA | wc -l ) 
		if test $TESTP = "0"
			echo "$TESTA" >> /etc/zabbix/zabbix_agentd.conf
		fi
	done
	

echo "Reiniciando zabbix-agent"	
pkill zabbix_agentd
/usr/sbin/zabbix_agentd
}

# AQUI SE INICIA O PROGRAMA, TODAS AS FUNÇÕES SAO CARREGADAS A PARTIR DAQUI.

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
elif test $WHO_CHECK = "Version"
	then
		echo $VERSION
elif test $WHO_CHECK = "Update"
	then
		Update
elif test $WHO_CHECK = "Install"
	then
		Install
elif test $WHO_CHECK = "Enviados"
	then
		cat /etc/zabbix/scripts/list.txt | grep ">" | wc -l
elif test $WHO_CHECK = "Rejeitados"
	then
		cat /etc/zabbix/scripts/list_reject.txt | grep ">" | wc -l
fi
