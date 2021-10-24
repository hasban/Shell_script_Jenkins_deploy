#!/bin/bash
set -e
  ## Check below 4 field before updation ##
  ## Adempiere Home  eg:- /home/admin/Adempiere ##
ADEMPIERE_HOME=/home/admin/LiteTestAdempiere
  ## Enter Postgres Home Directory eg:- /opt/PostgreSQL/9.5 ##
POSTGRES_HOME=/ssd/PostgreSQL/9.5
  ## Mention This Instance Name eg:- DWtest,8070,Randtest like that##
INSTANCE_NAME=LiteTest
  ## Mention 'Y' for enable backup else use 'N' ##
BACKUP_ENABLED=N

  #### Below 3 values are assign from central(from parent script) ####
UPDATEFILELIST="Adempiere.jar adempiereRoot.jar AdempiereService.war iCalPosibolt.war posterita.jar posteritaPatches.jar posterita.war"
ENABLESILENTSETUP=Y
DATE=20Nov20

ademp_values()
{
JENKINS_DIR=~/jenkins
export JAVA_HOME=`grep "JAVA_HOME" $ADEMPIERE_HOME/AdempiereEnv.properties  |  cut  -d"=" -f2`
DB_USER=`grep "ADEMPIERE_DB_USER" $ADEMPIERE_HOME/AdempiereEnv.properties  |  cut  -d"=" -f2`
DB_NAME=`grep "ADEMPIERE_DB_NAME" $ADEMPIERE_HOME/AdempiereEnv.properties  |  cut  -d"=" -f2`
DB_PORT=`grep "ADEMPIERE_DB_PORT" $ADEMPIERE_HOME/AdempiereEnv.properties  |  cut  -d"=" -f2`
DB_PASS=`grep "ADEMPIERE_DB_PASSWORD" $ADEMPIERE_HOME/AdempiereEnv.properties  |  cut  -d"=" -f2`
}

ademp_values
CTime=`date +%d%b%y-%H%M`
[ -d ~/jenkins/log ] || mkdir ~/jenkins/log
Astatuslog=~/jenkins/log/${INSTANCE_NAME}.$CTime.log
echo $INSTANCE_NAME > $Astatuslog

ademp_stop()
{   
        ademp_values
        AD_CHECK=`ps -ef | grep -w $ADEMPIERE_HOME | grep -v grep  | wc -l`
        while [ $AD_CHECK -gt 0 ];
        do
                echo  "Adempiere pid : $(ps -ef | grep -w $ADEMPIERE_HOME |grep -v grep | awk '{print $2}')"
                kill -9 $(ps -ef | grep -w $ADEMPIERE_HOME |grep -v grep | awk '{print $2}')
                sleep 5
                AD_CHECK=`ps -ef | grep -w $ADEMPIERE_HOME |grep -v grep  | wc -l`
        done
        set +e
        rm -rf $ADEMPIERE_HOME/jboss/server/adempiere/tmp $ADEMPIERE_HOME/jboss/server/adempiere/work 2>/dev/null
        set -e
        echo "$INSTANCE_NAME Adempiere Stopped" && echo "Adempiere Stopped" >> $Astatuslog
}

ademp_start()
{
        cd $ADEMPIERE_HOME/utils
        TIME=`date +%s`
        TIMEE=`expr $TIME + 900`
        /usr/bin/nohup  ./RUN_Server2.sh >> nohup.out &
        DS=`ps -ef | grep -w $DB_NAME | grep -v grep | wc -l`
        AS=`ps -ef | grep -w $ADEMPIERE_HOME | grep -v grep | wc -l`
        date +%T
        echo "$INSTANCE_NAME Adempiere Starting ......" && echo "Adempiere starting" >> $Astatuslog
        sleep 10
        NTC=`tac nohup.out | grep -m 1 -w "INFO  \[Server]\ Starting JBoss (MX MicroKernel)..." | awk '{print $1,$2}'`
        NS=`sed -n -e "/$NTC  \[Server]\ Starting JBoss (MX MicroKernel).../,/Started in/p" nohup.out | grep -w "Started in"  | wc -l`

        while  [ $DS -lt 4 ] || [ $AS -ne 2 ] || [ $NS -lt 1 ]
        do
                DS=`ps  -ef   |  grep -w $DB_NAME | grep -v grep | wc -l`
                AS=`ps -ef | grep -w $ADEMPIERE_HOME | grep -v grep | wc -l`
                NS=`sed -n -e "/$NTC  \[Server]\ Starting JBoss (MX MicroKernel).../,/Started in/p" nohup.out | grep -w "Started in"  | wc -l`
                if [ $TIME -gt $TIMEE ]
                then
                        set +e
                        echo "$INSTANCE_NAME Adempiere Failed to start" && echo "Adempiere Failed to start" >> $Astatuslog
                        exit 22
                else
                        TIME=`date +%s`
                fi
        done
        echo "$INSTANCE_NAME Adempiere started Successfully" && echo "Adempiere started Successfully" >> $Astatuslog
}

restart()
{
        echo "$INSTANCE_NAME Adempiere Restarting...."
        ademp_stop
        ademp_start
        exit 0
} 
        
case "$1" in
  restart)
        restart
        ;;
esac

if [ $BACKUP_ENABLED == Y ]
then
        FREESPACE=`df -m $ADEMPIERE_HOME --output=avail|tail -1`
        echo "Freespace $FREESPACE MB"
        REQUIRED_SPACE=$(($(du -sm $ADEMPIERE_HOME|awk '{print $1}') + $(du -sm $ADEMPIERE_HOME|awk '{print $1}') + 5120))
        echo "REQUIRED_SPACE $REQUIRED_SPACE MB"

        if [ $FREESPACE -lt $REQUIRED_SPACE ] || [ $(df -m $POSTGRES_HOME --output=avail|tail -1) -lt 500 ]
        then
                echo "$INSTANCE_NAME System Don't Have Free Space To Update" && echo "System Don't Have Free Space To Update" >> $Astatuslog
                exit 24
        else
                echo "Have free space" && echo "Have free space" >> $Astatuslog
                ademp_stop
                echo "$INSTANCE_NAME Adempiere Backup in Progress...."
                if ! [ -d $ADEMPIERE_HOME.$DATE ]
                then
                        cp -rf "$ADEMPIERE_HOME" "$ADEMPIERE_HOME.$DATE"
                        else
                        mv "$ADEMPIERE_HOME.$DATE" "$ADEMPIERE_HOME.$CTime"
                        cp -rf "$ADEMPIERE_HOME" "$ADEMPIERE_HOME.$DATE"
                fi
                sleep 10
                AD_SIZE=`du -sh $ADEMPIERE_HOME | awk '{print $1}'`
                ADB_SIZE=`du -sh $ADEMPIERE_HOME.$DATE | awk '{print $1}'`
                echo $AD_SIZE $ADB_SIZE
                if [ $AD_SIZE != $ADB_SIZE ]
                then
                        set +e
                        echo "$INSTANCE_NAME Adempiere Failed to Backup." && echo "Adempiere Failed to Backup" >> $Astatuslog
                        exit 23
                fi
        fi
else
        echo "Backup Not Enabled"
        ademp_stop
fi

cd $JENKINS_DIR/Release/$DATE
cp -f $UPDATEFILELIST $ADEMPIERE_HOME/lib
cd $ADEMPIERE_HOME
set +e
rm log/* 20*log jboss/server/adempiere/log/* utils/nohup.out utils/java*.hprof utils/hs_err*.log 2>/dev/null
set -e

if [ $ENABLESILENTSETUP == N ]
then
        echo "SilentSetup Not Enabled" && echo "SilentSetup Not Enabled" >> $Astatuslog
        cd $JENKINS_DIR/Release/$DATE
        cp $UPDATEFILELIST $ADEMPIERE_HOME/jboss/server/adempiere/deploy/adempiere.ear
        es=1
        ss=0
else 
        ./RUN_silentsetup.sh 2>&1 | tee silentsetup.log
        sleep 2 
        echo "##########################silent setup completed##########################" && echo "silent setup completed" >> $Astatuslog
        ss=`tac silentsetup.log | grep -m 1 -w "BUILD FAILED" | wc -l`
        es=`tac silentsetup.log | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
fi

if [ $es -eq 1 ] && [ $ss -eq 0 ]
then
        cd $JENKINS_DIR/Release/$DATE/SCRIPTS_$INSTANCE_NAME
        sl=`ls | grep .sql | wc -l`
        echo "Have $sl SQL Scripts to Run" 
        if [ $sl -gt 0 ]
        then
                mkdir INSERTED_SCRIPTS
                export PGPASSWORD=$DB_PASS
                for a in *.sql
                do
                        echo $a
                        $POSTGRES_HOME/bin/psql -U $DB_USER -d $DB_NAME -p $DB_PORT -f $a 2>>dbscript_$INSTANCE_NAME.log
                        echo $a >> dbscriptname_$INSTANCE_NAME.txt
                done
                mv *.sql INSERTED_SCRIPTS
                echo "script run completed" >> $Astatuslog
        fi
        /usr/bin/printf "\n"
        if [ -d $JENKINS_DIR/Release/$DATE/RESCRIPTS_$INSTANCE_NAME ]; then rsl=`ls $JENKINS_DIR/Release/$DATE/RESCRIPTS_$INSTANCE_NAME | grep .sql | wc -l`; else rsl=0; fi 
        if [ $rsl -gt 0 ]
        then
                echo >> $JENKINS_DIR/Release/$DATE/SCRIPTS_$INSTANCE_NAME/dbscriptname_$INSTANCE_NAME.txt
                echo >> $JENKINS_DIR/Release/$DATE/SCRIPTS_$INSTANCE_NAME/dbscript_$INSTANCE_NAME.log
                echo "Have $rsl SQL Scripts to ReRun"
                cd $JENKINS_DIR/Release/$DATE/RESCRIPTS_$INSTANCE_NAME
                mkdir INSERTED_SCRIPTS
                export PGPASSWORD=$DB_PASS
                for a in *.sql
                do
                        echo $a
                        $POSTGRES_HOME/bin/psql -U $DB_USER -d $DB_NAME -p $DB_PORT -f $a 2>> dbscript_$INSTANCE_NAME.log
                        echo $a >> $JENKINS_DIR/Release/$DATE/SCRIPTS_$INSTANCE_NAME/dbscriptname_$INSTANCE_NAME.txt
                done
                mv *.sql INSERTED_SCRIPTS
                echo "script rerun completed" >> $Astatuslog
        fi
        /usr/bin/printf "\n"
        ademp_start
else
        set +e
        echo "$INSTANCE_NAME Silent_Setup Failed" && echo "Silent_Setup Failed" >> $Astatuslog
        exit 21
fi
echo "Completed"

## JEN_POS_Rsh:3.0 Jboss ##
## hasban_mohammed ## 
## 24Oct2021 ## 204Lns ## Aligned #