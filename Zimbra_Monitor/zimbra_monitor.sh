#!/bin/bash
#		Versão 1.2(BETA)
#
#		zimbra_monitor.sh - Monitoramento Zimbra no Zabbix
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
#		monitorameto do Zimbra no Zabbix. Com funções de 
#		analise de Blacklist, serviços, fila e etc.
#
# ------------------------------------------------------------------------
#	NOTAS:
#		
#		Utiliza o arquivo /etc/zabbix/scripts/zimbra_monitor.conf
#		para carregar parametros do programa
# 		
#		Utiliza do pacote dig para fazer as 
#		consultas em blacklist
#
# 		Utiliza o arquivo /tmp/zmcontrol_status.log
#		para analise dos serviços.
#		
#		Utiliza do arquivo /etc/zabbix/scripts/send.txt
#		Para realizar a checagem de quantidade de emails
#		enviados.
# 		
#		Utiliza o repositorio do github para atualizações
#
# ------------------------------------------------------------------------
#	MODIFICADOR_POR	(DD/MM/YYYY)
#	Matheus.Viana	 21/02/2018		-	Primeira versão.
#	Matheus.Viana	 26/02/2018 	-	Adicionado função Sender
#	Matheus.Viana	 01/03/2018		-	Desabilitada a função Sender (exigia muitos recursos do servidor)
#	Matheus.Viana	 06/03/2018		-	Adicionado as funções Upgrade e Zversion,
#										organizado o menu
#	Matheus.Viana	 07/03/2018		-	Corrigido a a função Sender
#	Matheus.Viana	 08/03/2018		-	Adicionado a função AuthFail
#
#
#
# Licença	: GNU GPL
#

function Install(){
DISTRO=$(cat /etc/issue | cut -d' ' -f 1)

echo "Criando entradas em Crontab"
	
	if test $DISTRO = "Ubuntu";
		then
			echo "Fazendo backup do Crontab do sistema"
			cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root-bkp
			echo '*/5 * * * * su -c "/opt/zimbra/bin/zmcontrol status" zimbra > /tmp/zmcontrol_status.log' >> /var/spool/cron/crontabs/root
			echo '* 0,2,4,6,8,10,12,14,16,18,20,22 * * * /etc/zabbix/scripts/zimbra_monitor.sh sender' >> /var/spool/cron/crontabs/root
		else
			echo "Fazendo backup do Crontab do sistema"
			cp /var/spool/cron/root /var/spool/cron/root-bkp
			echo '*/5 * * * * su -c "/opt/zimbra/bin/zmcontrol status" zimbra > /tmp/zmcontrol_status.log' >> /var/spool/cron/root
			echo '* 0,2,4,6,8,10,12,14,16,18,20,22 * * * /etc/zabbix/scripts/zimbra_monitor.sh sender' >> /var/spool/cron/root
	fi

echo "Criando diretorios"
	
	mkdir /etc/zabbix/scripts/ 

echo "Copiando arquivos"
	
	cp /Zabbix/Zimbra_Monitor/* /etc/zabbix/scripts/

echo "Modificando arquivos de configuração local"
	
	MAIL=$(locate mailq | fgrep "opt" | fgrep "sbin") 
	Zversion=$(su -c "/opt/zimbra/bin/zmcontrol -v" zimbra)
	Dominios=$(su -c "/opt/zimbra/bin/zmprov gad" zimbra)
	
	sed -i "s/^Zversion=/Zversion=$Zversion/" /etc/zabbix/scripts/zimbra_monitor.conf
	sed -i "s/^Dominios=/Dominios=$Dominios/" /etc/zabbix/scripts/zimbra_monitor.conf
	sed -i "s/^MAILQ=/MAILQ=$MAIL/" /etc/zabbix/scripts/zimbra_monitor.conf
	
echo "Aplicando permissões de execução"
	
	chmod +x /etc/zabbix/scripts/zimbra_monitor.sh
	
echo "Executando backup das configurações do Zabbix_agent"

	cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf-bkp

echo "Atualizando arquivo de configuração do Zabbix-agent"

	rm -rf /etc/zabbix/zabbix_agentd.conf
	cat -s /etc/zabbix/zabbix_agentd.conf-bkp | fgrep -v "#" | fgrep -v "Timeout=3"| uniq -u > /etc/zabbix/zabbix_agentd.conf

	echo "Timeout=30" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=AuthFail,/etc/zabbix/scripts/zimbra_monitor.sh authfail" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Services_Discovery,/etc/zabbix/scripts/zimbra_monitor.sh serv_discovery" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Blacklist[*],/etc/zabbix/scripts/zimbra_monitor.sh blacklist $1 $2" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Fila,/etc/zabbix/scripts/zimbra_monitor.sh fila" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Services_Status[*],/etc/zabbix/scripts/zimbra_monitor.sh serv_status $1" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Sent,/etc/zabbix/scripts/zimbra_monitor.sh sent" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Mail.Reject,/etc/zabbix/scripts/zimbra_monitor.sh reject" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Tries.Fail[*],/etc/zabbix/scrips/zimbra_monitor.sh tryfail $1" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Zimbra_Monitor_Version,/etc/zabbix/scripts/zimbra_monitor.sh version" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Zimbra_Monitor_Update,/etc/zabbix/scripts/zimbra_monitor.sh update" >> /etc/zabbix/zabbix_agentd.conf
	echo "UserParameter=Zversion,/etc/zabbix/scripts/zimbra_monitor.sh Zversion" >> /etc/zabbix/zabbix_agentd.conf
	

echo "Reiniciando Zabbix-agent"	
	pkill zabbix_agentd
 	/usr/sbin/zabbix_agentd
}

function Update(){
echo "Apagando arquivos de instalação da versão anterior"

	rm -rf /Zabbix/

echo "Obtendo nova versão"
	
	git clone https://github.com/XevetteX/Zabbix/
	
echo "Executando backup da versão anterior"
	
	cp /etc/zabbix/scripts/zimbra_monitor.sh /etc/zabbix/scripts/zimbra_monitor.sh-bkp
	rm -rf /etc/zabbix/scripts/zimbra_monitor.sh
	
echo "Salvando configurações pessoais"

	cp /etc/zabbix/scripts/zimbra_monitor.conf /etc/zabbix/scripts/zimbra_monitor.conf-bkp
	rm -rf /etc/zabbix/scripts/zimbra_monitor.conf

echo "Atualizando arquivos"
	
	cp /Zabbix/Zimbra_Monitor/* /etc/zabbix/scripts/
	
echo "Aplicando permissões de execução"
		
	chmod +x /etc/zabbix/scripts/zimbra_monitor.sh

echo "Instalando nova versão"

		/etc/zabbix/scripts/zimbra_monitor.sh upgrade
}

function Upgrade(){
	
echo "Reiniciando zabbix-agent"	
	
	pkill zabbix_agentd
	/usr/sbin/zabbix_agentd
}

function AuthFail(){
rm -rf /etc/zabbix/scripts/ipauthfailed.txt

TODAY=$(date | cut -d' ' -f 2-4)

	cat /var/log/maillog | fgrep "$TODAY" | fgrep "authentication failed:" | cut -d'[' -f 3 | cut -d']' -f1 | sort | uniq -c | sort -n >> /etc/zabbix/scripts/ipauthfailed.txt

IPFAILED=$(cat /etc/zabbix/scripts/ipauthfailed.txt | rev | sed -e "s/ /=/" | rev )
RESULT_A=$(for d in $IPFAILED
	do 
		ATTACKER=$(echo $d | cut -d'=' -f 2)
		FAIL=$(echo $d | cut -d'=' -f 1)
		
		if test $FAIL -ge 20
			then 
				echo -n '{"{#ATTACKER}":"'${ATTACKER}'"},'
		fi
	done)
VAR_A=$(echo -e '{"data":['$RESULT_A']' | sed -e 's:\},]$:\}]:' )
		echo -n $VAR_A'}'
 }

function Blacklist(){
IP=$(wget http://ipecho.net/plain -O - -q; echo)
BL=$PAR2
P1=$(echo $IP | cut -d '.' -f 4)
P2=$(echo $IP | cut -d '.' -f 3)
P3=$(echo $IP | cut -d '.' -f 2)
P4=$(echo $IP | cut -d '.' -f 1)
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

function TryFail(){
cat /etc/zabbix/scripts/ipauthfailed.txt | fgrep "$PAR1" | rev | sed -e "s/ /=/" | rev | cut -d'=' -f 1
}

function Queue(){
BIN=$(cat /etc/zabbix/scripts/zimbra_monitor.conf | fgrep "MAILQ=" | cut -d'=' -f 2)
MAILQ=$($BIN | fgrep Request | awk -F" " '{print $5}')

if [ -z "$MAILQ" ]
	then	
		echo 0
	
	elif [ "$MAILQ" -ge 1 ]
	then
	echo "$MAILQ"
fi
}

function Services_Discovery(){
HOUSECLEANER=$(cat /tmp/zmcontrol_status.log | fgrep -v Host | fgrep -v not | rev | cut -d' ' -f 2- | rev | sed 's/ w/_w/')
RESULT=$(for a in $HOUSECLEANER
	do 
		echo -n '{"{#SERVICE}":"'${a}'"},' | sed 's/_w/ w/'
	done)
VAR=$(echo -e '{"data":['$RESULT']' | sed -e 's:\},]$:\}]:' )
echo -n $VAR'}'
}

function Services_Status(){
TARGET=$PAR1
COUNT_LINE=$(cat /tmp/zmcontrol_status.log | fgrep -v not | fgrep "$TARGET")
STATUS_SERVICE=$(echo $COUNT_LINE | rev | cut -d' ' -f 1 | rev )
if test $STATUS_SERVICE = "Stopped"
	then 
		echo 1
	else
		echo 0
fi
}

function Sender(){
rm -rf /etc/zabbix/scripts/send.txt
SENDER=$(cat /etc/zabbix/scripts/zimbra_monitor.conf | fgrep "Dominios=" | cut -d'=' -f2)
TODAY=$(date '+%Y%m%d')
for s in $SENDER
	do
		/opt/zimbra/libexec/zmmsgtrace --sender $s --time $TODAY | fgrep "$s -->" | sort | fgrep -v admin | fgrep -v spam | fgrep -v ham | fgrep -v virus | fgrep -v galsync >> /etc/zabbix/scripts/send.txt
	done
}

# VARIAVEIS DO MENU
WHO_CHECK=$1
PAR1=$2
PAR2=$3
VERSION="1.2(BETA)"
BAD_PAR="
Opcao invalida -- '$1'
Use 'zimbra_monitor.sh help' para mais informacoes."

HELP="
		Zimbra Monitor $VERSION
USO: zimbra_monitor.sh [funcao] [parametro 1] [parametro 2] ...

FUNÇOES
	
	- authfail					Realiza uma consulta nos logs para identificar Ips que estao 
						realizando ataques forca bruta no zimbra, 
						e apresenta o resultado em formato JSON.
	- blacklist [blacklist]		Consulta se o dominio esta na blacklist especificada.
	- fila						Mostra a fila de email.
	- Zversion 					Mostra a versao do Zimbra
			
FUNÇOES ESPECIAIS	
	
	Os comandos seguintes utilizam arquivos especificos para serem realizados,
	Ler notas no cabeçario do programa.
		
	- serv_discovery				Coleta todos os serviços do zimbra.
	- serv_status					Coleta o status dos serviços do zimbra. 
	- sent						Consulta quantos emails foram enviados no dia.
	
OUTRAS FUNÇOES

	- help						Mostra esta tela de ajuda.
	- version					Mostra a versao do programa.
	- update					Checa novas versoes, e atualiza o programa.
	- install					Instala a ultima versao obtida.
	
	"
# AQUI SE INICIA O PROGRAMA, TODAS AS FUNÇÕES SAO CARREGADAS A PARTIR DAQUI.

if test $WHO_CHECK = "help"
	then 
		echo "$HELP"
elif test $WHO_CHECK = "install"
	then
		Install
elif test $WHO_CHECK = "update"
	then
		Update
elif test $WHO_CHECK = "upgrade"
	then
		Upgrade
elif test $WHO_CHECK = "version"
	then
		echo $VERSION
elif test $WHO_CHECK = "authfail"
	then
		AuthFail
elif test $WHO_CHECK = "blacklist"
	then
		Blacklist $PAR2
elif test $WHO_CHECK = "fila"
	then
		Queue
elif test $WHO_CHECK = "tryfail"
		then
			TryFail $PAR1
elif test $WHO_CHECK = "sender"
	then
		echo "função em nivel alpha de desenvolvimento, não habilitar em produção, para habilitar descomente a linha no crontab"
		Sender
elif test $WHO_CHECK = "sent"
	then
		cat /etc/zabbix/scripts/send.txt | wc -l
elif test $WHO_CHECK = "serv_discovery"
	then
		Services_Discovery
elif test $WHO_CHECK = "serv_status"
	then 
		Services_Status $PAR1
elif test $WHO_CHECK = "Zversion"
	then
		cat /etc/zabbix/scripts/zimbra_monitor.conf | fgrep "Zversion=" | cut -d'=' -f 2
	else 
		echo "$BAD_PAR"
fi
