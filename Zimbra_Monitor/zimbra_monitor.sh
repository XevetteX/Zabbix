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
VERSION="1"

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
OLD_SUBVER=$(cat /etc/zabbix/scripts/zimbra_monitor.sh version)
if test $OLD_SUBVER -lt 1
	then
		echo "Apagando arquivos de instalação da versão anterior"

			rm -rf /Zabbix/

		echo "executando backup da versão anterior"
	
			cp /etc/zabbix/scripts/zimbra_monitor.sh /etc/zabbix/scripts/zimbra_monitor.sh-bkp
			rm -rf /etc/zabbix/scripts/zimbra_monitor.sh

		echo "Obtendo nova versão"
	
			git clone https://github.com/XevetteX/Zabbix/

		echo "Instalando nova versão"
	
			cp /Zabbix/Zimbra_Monitor/* /etc/zabbix/scripts/

		echo "Aplicando permissões de execução"
		
			chmod +x /etc/zabbix/scripts/zimbra_monitor.sh
	
		echo "Executando backup das configurações do Zabbix_agent"

			cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf-bkp

		echo "Atualizando arquivo de configuração do zabbix-agent"
	
			rm -rf /etc/zabbix/zabbix_agentd.conf
			cat -s /etc/zabbix/zabbix_agentd.conf-bkp | grep -v "#" | uniq -u > /etc/zabbix/zabbix_agentd.conf

			#
			#APLICAR AQUI NOVOS PARAMETROS
			#Exemplo abaixo
			#echo "UserParameter=Mail.Services_Discovery,/etc/zabbix/scripts/zimbra_monitor.sh Services_Discovery" >> /etc/zabbix/zabbix_agentd.conf
	
		echo "Reiniciando zabbix-agent"	
	
			pkill zabbix_agentd
			/usr/sbin/zabbix_agentd
	
	else 
		echo "Você ja possui a versão mais atual"
fi
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
	cat -s /etc/zabbix/zabbix_agentd.conf-bkp | grep -v "#" | grep -v "Timeout=3"| uniq -u > /etc/zabbix/zabbix_agentd.conf

	echo "Timeout=30" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Services_Discovery,/etc/zabbix/scripts/zimbra_monitor.sh serv_discovery" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Blacklist[*],/etc/zabbix/scripts/zimbra_monitor.sh blacklist $1 $2" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Fila,/etc/zabbix/scripts/zimbra_monitor.sh fila" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Services_Status[*],/etc/zabbix/scripts/zimbra_monitor.sh serv_status $1" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Sent,/etc/zabbix/scripts/zimbra_monitor.sh sent" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Reject,/etc/zabbix/scripts/zimbra_monitor.sh reject" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Zimbra_Monitor_Version,/etc/zabbix/scripts/zimbra_monitor.sh version" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Zimbra_Monitor_Update,/etc/zabbix/scripts/zimbra_monitor.sh update" >> /etc/zabbix/zabbix_agentd.conf

echo "Reiniciando zabbix-agent"	
	pkill zabbix_agentd
	/usr/sbin/zabbix_agentd
}

# VARIAVEIS DO MENU
HELP="
		Zimbra Monitor $VERSION
USO: $0 [função] [parametro 1] [parametro 2] ...

		- help								Mostra esta tela de ajuda.
		- version							Mostra a versão do programa.
		- update							Checa novas versões, e atualiza o programa.
		- install							Instala a ultima versão obtida.
	
	FUNÇOES
	
		- fila								Mostra a fila de email.
		- blacklist [dominio] [blacklist]	Consulta se o dominio esta na blacklist especificada.
		- reject							Consulta quantos emails falharam o envio no dia.
		
	FUNÇOES ESPECIAIS	
	
		Os comandos seguintes utilizam arquivos especificos para serem realizados,
		Ler notas no cabeçario do programa.
		
		- serv_discovery					Coleta todos os serviços do zimbra.
		- serv_status						Coleta o status dos serviços do zimbra. 
		- sent								Consulta quantos emails foram enviados no dia.
"
BAD_PAR="
$0: opção invalida -- '$1'
Use '$0 help' para mais informações."

# AQUI SE INICIA O PROGRAMA, TODAS AS FUNÇÕES SAO CARREGADAS A PARTIR DAQUI.

if test $WHO_CHECK = "blacklist"
	then 
		Blacklist $2 $3
elif test $WHO_CHECK = "fila"
	then
		Queue
elif test $WHO_CHECK = "serv_discovery"
	then
		Services_Discovery
elif test $WHO_CHECK = "serv_status"
	then
		Services_Status $2
elif test $WHO_CHECK = "sender"
	then
		Sender
elif test $WHO_CHECK = "version"
	then
		echo $VERSION
elif test $WHO_CHECK = "update"
	then
		Update
elif test $WHO_CHECK = "install"
	then
		Install
elif test $WHO_CHECK = "Sent"
	then
		cat /etc/zabbix/scripts/list.txt | grep ">" | wc -l
elif test $WHO_CHECK = "reject"
	then
		cat /etc/zabbix/scripts/list_reject.txt | grep ">" | wc -l
elif test $WHO_CHECK = "help"
	then 
		echo "$HELP"
	else 
		echo $BAD_PAR
fi
