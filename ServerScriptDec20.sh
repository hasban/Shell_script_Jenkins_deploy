#!/bin/bash
set -e
  ### Check below values of Remote Servers ###
  ## Enter the Servers username and ip address or url ## give a space between servers details ##
  ## Eg:- SERVER_NAMEs=(admin1@192.168.0.1 admin2@192.168.0.2) ##
SERVER_NAMEs=()
  ## Enter the Jenkins SCRIPT Name of above servers in the above server order ##
  ## it is under jenkins directory under user home directory ##
  ## As default the script name is update.sh ,if 2 instance is running under same  
  ## user in the Servers please mention different names for each script ##
  ## Eg:- REM_SCRIPT_NAMEs=(update.sh update.sh) ##
REM_SCRIPT_NAMEs=()

  ### Set 'B' for BLUE Theme else set 'N' for NORMAL Theme ###
POSIBOLT_THEME='N'
  ### Enter the script no to RE-RUN  # give space between script nos  # eg:-(1185 1189) ##
RERUN_SCRIPT_NOs=()
  ### Set 'Y' for replce report directory else 'N' ###
REPLACE_REPORT_DIR='N'
  ## Enter Y to enable silentsetup and N for disable ##
ENABLE_SILENTSETUP=Y
  ### Enter Revision no to update ##
#REVISION_NO=
POSIBOLT_BRANCH="POSRetail"

### Mail Address ###
ADMIN_MAIL_IDs="admins@abcd.com"
DEVELOPER_MAIL_IDs="abc@abcd.com def@abc.com"
CC_LIST="sha@abc.com"

####################################### Workspace Setup ####################################### 

### Export Path ###
ANT="apache-ant-1/bin/ant"
export JAVA_HOME="/jdk1.6.0"
export _JAVA_OPTIONS=-Djava.io.tmpdir=/periyarOS/tmp

#set svn working copy location
if [ $POSIBOLT_BRANCH == "POSRetail" ]
then
   SVNDIR=/workspace/POSRetail
   WORK_NAME="POSRetail"
elif [ $POSIBOLT_BRANCH == "POSTrunk" ]
then
   SVNDIR=/workspace/POSTrunk
   WORK_NAME="POSTrunk"
elif [ $POSIBOLT_BRANCH == "POSibolt-7.8" ]
then
   SVNDIR=/workspace/POSibolt-7.8
   WORK_NAME="POSibolt-7.8"
elif [ $POSIBOLT_BRANCH == "POScw" ]
then
   SVNDIR=/workspace/POScw
   WORK_NAME="POScw"
elif [ $POSIBOLT_BRANCH == "POSIndigo" ]
then
   SVNDIR=/workspace/PosiboltIndigo
   WORK_NAME="POSIndigo"
else
   echo "Please Choose Posibolt Branch for Update"
   exit 0
fi

########################################## Preparation ##############################################

/usr/bin/printf "\n"
echo "Building $WORK_NAME Branch "
echo "Source Code Location : $SVNDIR"
echo "Workspace : $WORKSPACE"
/usr/bin/printf "\n"

export JRE_HOME=${JAVA_HOME}/jre
export PATH=${JAVA_HOME}/bin:$PATH

DATE=`date +%d%b%y`
RF="${WORKSPACE}/Release"
LF="${WORKSPACE}/log"
JF="${WORKSPACE}/log/journal"
SLF="${SVNDIR}/log"

[ -d $JF ] || mkdir -p $JF
[ -d $RF ] || mkdir -p $RF
[ -d $SLF ] || mkdir $SLF

cd $SVNDIR
svn info 360trunk AdempiereService iCalPosibolt 1>/dev/null || svn upgrade 360trunk AdempiereService iCalPosibolt
if ! [ -z "$REVISION_NO" ]
then
   svn up -r "$REVISION_NO" 360trunk AdempiereService iCalPosibolt
   svn up -r "$REVISION_NO" 360trunk AdempiereService iCalPosibolt > ${SLF}/svnstatus.log
else
   svn up 360trunk AdempiereService iCalPosibolt
   svn up 360trunk AdempiereService iCalPosibolt > ${SLF}/svnstatus.log
fi

set +e
/usr/bin/grep "conflict" ${SLF}/svnstatus.log
if [ $? -eq 0 ]
then
      /usr/bin/printf "$WORK_NAME Working copy Found conflict \n \nLog \n$(/bin/cat ${SLF}/svnstatus.log)" | mail -s "$WORK_NAME Found conflict" $ADMIN_MAIL_IDs
fi
set -e
#find $RF -maxdepth 1 -type d -mtime +4 -name '[0-3][0-9][A-Z][a-z][a-z][0-9][0-9]' -exec rm -rf {} \;
 
########################################### 360 build ###############################################

function 360_build()
{
   cd $SVNDIR/360trunk/utils_dev
   echo "Building 360..."
   ./RUN_build.sh > out.txt 2>&1
   es=$?
   bs=`tac out.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
   if [ $es -eq 0 ] && [ $bs -eq 0 ] && [ $bss -ne 0 ]
   then
         echo "360 Build Successfully"
         echo "${TV}" > $SLF/360trunksvn.revn
   else
         echo "360 Build Failed"
         cat out.txt | mail -s "$WORK_NAME 360Trunk Build Failed"  $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
         exit
   fi
}

function 360bluetheme_build()
{
   cd $SVNDIR/360trunk/posterita/posterita
   echo "Building Posterita blue..."
   $ANT clean > out.txt 2>&1
   es=$?
   bs=`tac out.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
   if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]             
   then
         $ANT posblue > out1.txt 2>&1
         es=$?
         bs=`tac out1.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
         if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
         then
               echo "Posterita Build Successfully"
               echo "${TV}" > $SLF/360trunksvn.revn
         else
               echo "Posterita Build Failed"
               cat out1.txt | mail -s "$WORK_NAME Posterita Build Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
               exit ;
         fi
   else
         echo "Posterita Build Failed"
         cat out.txt | mail -s "$WORK_NAME Posterita Build Failed"  -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
         exit ;
   fi
}

/usr/bin/printf "\n"
cd $SVNDIR/360trunk
TV=`svn info |  grep -w Revision |  cut -d":"  -f2 | sed 's/^[ \t]*//'`${POSIBOLT_THEME}
[ -s  ${SLF}/360trunksvn.revn ] || echo 0 > ${SLF}/360trunksvn.revn
OTV=`cat ${SLF}/360trunksvn.revn`
echo $TV  $OTV
if [ $TV  !=  $OTV ]
then
      360_build
      if [ $POSIBOLT_THEME == 'B' ]
      then
            360bluetheme_build
      fi
else
   echo "360Trunk Already Builded"
fi

###################################### AdempiereService build #######################################

/usr/bin/printf "\n"
cd  ${SVNDIR}/AdempiereService
cp  ${SVNDIR}/360trunk/lib/Adempiere.jar   lib/
AV=`svn info |  grep -w Revision |  cut -d":"  -f2 | sed 's/^[ \t]*//'`${POSIBOLT_THEME}
[ -s  ${SLF}/adempiereservicesvn.revn ] || echo 0 > ${SLF}/adempiereservicesvn.revn
OAV=`cat ${SLF}/adempiereservicesvn.revn`
echo $AV $OAV
if [ $AV !=  $OAV ]
then
      echo "Building AdempiereService..."
      $ANT ical-clean > out.txt 2>&1
      es=$?
      bs=`tac out.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
      if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
      then
            $ANT > out1.txt 2>&1
            es=$?
            bs=`tac out1.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
            if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
            then
                  echo "AdempiereService Build Successfully"
                  echo $AV >  $SLF/adempiereservicesvn.revn
            else
                  echo "AdempiereService Build Failed"
                  cat out1.txt | mail -s "$WORK_NAME AdempiereService Build Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
                  exit ;
            fi
      else
            echo "AdempiereService Build Failed"
            cat out.txt | mail -s "$WORK_NAME AdempiereService Build Failed"  -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
            exit ;
      fi
fi

######################################## iCalPosibolt build #########################################

function ical_build()
{
   echo "Building iCalPosibolt..."
   $ANT clean > out.txt 2>&1
   es=$?
   bs=`tac out.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
   if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
   then
         if [ $POSIBOLT_THEME == 'B' ]
         then
               echo "Building iCalPosibolt blue..."
               $ANT posblue > out1.txt 2>&1
               es=$?
               bs=`tac out1.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
               if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
               then
                     echo "iCalPosibolt Build Successfully"
                     echo "${IV}" >  $SLF/icalposiboltsvn.revn
               else
                     echo "iCalPosibolt Build Failed"
                     cat out1.txt | mail -s "$WORK_NAME iCalPosibolt Build Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
                     exit ;
               fi
         else
               $ANT > out1.txt 2>&1
               es=$?
               bs=`tac out1.txt | grep -m 1 -w "BUILD FAILED" | wc -l` && bss=`tac out.txt | grep -m 1 -w "BUILD SUCCESSFUL" | wc -l`
               if [ $es -eq 0 ] && [ $bs -eq 0 ]  && [ $bss -ne 0 ]
               then
                     echo "iCalPosibolt Build Successfully"
                     echo "${IV}" >  $SLF/icalposiboltsvn.revn
               else
                     echo "iCalPosibolt Build Failed"
                     cat out1.txt | mail -s "$WORK_NAME iCalPosibolt Build Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
                     exit ;
               fi
         fi
   else
         echo "iCalPosibolt Build Failed"
         cat out.txt | mail -s "$WORK_NAME iCalPosibolt Build Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
         exit
   fi
}

/usr/bin/printf "\n"
cd  ${SVNDIR}/iCalPosibolt
IV=`svn info |  grep -w Revision |  cut -d":"  -f2 | sed 's/^[ \t]*//'`${POSIBOLT_THEME}
[ -s  ${SLF}/icalposiboltsvn.revn ] || echo 0 > ${SLF}/icalposiboltsvn.revn
OIV=`cat ${SLF}/icalposiboltsvn.revn`
echo $IV $OIV
if [ $IV !=  $OIV ]
then 
      ical_build
else
      echo "iCalPosibolt Already Builded"
fi

/usr/bin/printf "\n"
FILE_REV_CUR=`cat $SVNDIR/web/jsp/include/version.jsp | awk -F ' ' '{print $NF}' `
echo "Current File Version : $FILE_REV_CUR"

##################################### Checking & Copying Files #######################################

FILE_REV=0
if [ -s $RF/$DATE/.files.revn ]
then
      FILE_REV=`cat $RF/$DATE/.files.revn`
else  
      mkdir -p $RF/$DATE
fi
if [ $FILE_REV_CUR == $FILE_REV ] 
then
      echo "$DATE Directory Already Have Updated Files"
else 
      rm -rf $RF/$DATE
      mkdir -p $RF/$DATE
      
      cp -f ${SVNDIR}/360trunk/lib/Adempiere.jar                              $RF/$DATE
      cp -f ${SVNDIR}/360trunk/lib/adempiereRoot.jar                          $RF/$DATE
      cp -f ${SVNDIR}/360trunk/posterita/commons/posibolt/dist/posterita*     $RF/$DATE
      cp -f ${SVNDIR}/iCalPosibolt/iCalPosibolt.war                           $RF/$DATE
      cp -f ${SVNDIR}/AdempiereService/dist/AdempiereService.war              $RF/$DATE

      echo $FILE_REV_CUR > $RF/$DATE/.files.revn
      echo $TV > $RF/$DATE/.svns.revn
      echo "Now copied Updated Files to $DATE"   
fi

####################################### REMOTE PROCESS BEGINS #######################################
################################ Fetching Data From Remote Machine ##################################

function adempiere_updation()
{
echo "================================================================================="
echo "####################### ${SERVER_NAMEs[$i]} Process Begins ######################"
echo "================================================================================="

SERVER=${SERVER_NAMEs[$i]}
REM_SCRIPT=${REM_SCRIPT_NAMEs[$i]}
REM_DIR='~/jenkins'

set +e
ssh $SERVER exit 2>/dev/null || return 51;
set -e
R_DATA1=($(ssh $SERVER "(grep -w "ADEMPIERE_HOME=" $REM_DIR/$REM_SCRIPT) && (grep -w "POSTGRES_HOME=" $REM_DIR/$REM_SCRIPT) &&  (grep "INSTANCE_NAME=" $REM_DIR/$REM_SCRIPT)" | cut -d"=" -f 2 ))
R_ADEMPIERE_HOME=${R_DATA1[0]}
R_POSTGRES_HOME=${R_DATA1[1]}
R_INSTANCE_NAME=${R_DATA1[2]}
printf "SERVER : $SERVER\nREM_DIR : $REM_DIR\nREM_SCRIPT : $REM_SCRIPT\nADEMPIERE_HOME : $R_ADEMPIERE_HOME\nPOSTGRES_HOME : $R_POSTGRES_HOME\nINSTANCE_NAME : $R_INSTANCE_NAME\n"

#################################### CHECKING ADEMPIERE VERSION #####################################

ADM_VERSION_CUR=$(ssh $SERVER "find $R_ADEMPIERE_HOME -iname version.jsp | xargs cat" | awk -F ' ' '{print $NF }')
if [ -z $ADM_VERSION_CUR ]
then
      echo "$R_INSTANCE_NAME is Down"
else
      echo "Current Adempiere Version : $ADM_VERSION_CUR" 
      if [ $ADM_VERSION_CUR == $FILE_REV_CUR ]
      then
            echo "$R_INSTANCE_NAME Instance is Already in Latest Version ($ADM_VERSION_CUR)"
            /usr/bin/printf "$R_INSTANCE_NAME Instance is Already in Latest Version -V[ $ADM_VERSION_CUR ] \n \n \n \n[ svn-V($TV) ]" | mail -s "$R_INSTANCE_NAME Adempiere Update" $ADMIN_MAIL_IDs
            set +e
            return ; 
      fi 
fi

############################## Scripts Checking & Copying For Instance ##############################

SF=$RF/$DATE/SCRIPTS_$R_INSTANCE_NAME
RSF=$RF/$DATE/RESCRIPTS_$R_INSTANCE_NAME
SCRIPT_REV=0
if [ -s $SF/.script.revn ] 
then
      SCRIPT_REV=`cat $SF/.script.revn`
else  
      mkdir -p $SF
fi

if  [ $FILE_REV_CUR != $SCRIPT_REV ]
then
      rm -rf $SF
      R_DATA2=($(ssh $SERVER "(grep -w "ADEMPIERE_DB_USER" $R_ADEMPIERE_HOME/AdempiereEnv.properties ) && (grep -w "ADEMPIERE_DB_NAME" $R_ADEMPIERE_HOME/AdempiereEnv.properties ) && (grep -w "ADEMPIERE_DB_PORT" $R_ADEMPIERE_HOME/AdempiereEnv.properties) && (grep -w "ADEMPIERE_DB_PASSWORD" $R_ADEMPIERE_HOME/AdempiereEnv.properties)" | cut -d"=" -f 2))
      R_DB_USER=${R_DATA2[0]}
      R_DB_NAME=${R_DATA2[1]}
      R_DB_PORT=${R_DATA2[2]}
      R_DB_PASSWORD=${R_DATA2[3]}
      printf "DB_USER : $R_DB_USER\nDB_NAME : $R_DB_NAME\nDB_PORT : $R_DB_PORT\n"

      ssh $SERVER "export PGPASSWORD="$R_DB_PASSWORD" && $R_POSTGRES_HOME/bin/psql -U $R_DB_USER -d $R_DB_NAME -p $R_DB_PORT -c 'select name,created from ad_migrationscript order by name ;' | grep '|' | cut -d '|' -f 1 | grep -o '\([[:digit:]]\)\{4\}' | sort -nu" > $LF/sqlscripts_name_in_$R_INSTANCE_NAME.log
      if ! [ -s $LF/sqlscripts_name_in_$R_INSTANCE_NAME.log ]
      then
            ssh $SERVER "export PGPASSWORD="$R_DB_PASSWORD" && $R_POSTGRES_HOME/bin/psql -U $R_DB_USER -d $R_DB_NAME -p $R_DB_PORT -c 'select name,created from ad_migrationscript order by name ;' | grep '|' | cut -d '|' -f 1 | grep -o '\([[:digit:]]\)\{3\}' | sort -nu" > $LF/sqlscripts_name_in_$R_INSTANCE_NAME.log
            if ! [ -s $LF/sqlscripts_name_in_$R_INSTANCE_NAME.log ]
            then
                  echo "Unable to Fetch Data from $R_INSTANCE_NAME Instance Database"
                  /usr/bin/printf "Unable to Fetch data from $R_INSTANCE_NAME Database \n" |  mail -s "Unable to Fetch data from $R_INSTANCE_NAME Database"  $ADMIN_MAIL_IDs 
                  echo "================================================================================="
                  echo "####################### ${SERVER_NAMEs[$i]} Process Failed ######################"
                  echo "================================================================================="
                  set +e
                  return ; 
            else
                  echo "$R_INSTANCE_NAME Database Only have below 1000 Sql Scripts"
                  /usr/bin/printf "$R_INSTANCE_NAME Database Only have below 1000 Sql Scripts \n" |  mail -s "Failed to update $R_INSTANCE_NAME"  $ADMIN_MAIL_IDs
                  echo "================================================================================="
                  echo "####################### ${SERVER_NAMEs[$i]} Process Failed ######################"
                  echo "================================================================================="
                  mv sqlscripts_name_in_$R_INSTANCE_NAME.log /tmp 
                  set +e
                  return ;
            fi
      fi
            mkdir -p $SF
            cd $SVNDIR/360trunk/migration
            LASTSCRIPT=`find posibolt-[0-9].[0-9] -name '[0-9][0-9][0-9][0-9]*.sql' | cut -d'/' -f 2 |sort -n |tail -1 | cut -d'_' -f 1`
            echo "Last script = $LASTSCRIPT"
            if [ -n $LASTSCRIPT ] && [ $LASTSCRIPT -gt 1000 ]
            then
                  seq 1000 $LASTSCRIPT >/tmp/nos.log
                  diff /tmp/nos.log $LF/sqlscripts_name_in_$R_INSTANCE_NAME.log  | grep '^<' | awk -F '< ' '{print $2}' > $LF/missing_sqlscripts_in_$R_INSTANCE_NAME.log
                  COUNT_MS=$(cat $LF/missing_sqlscripts_in_$R_INSTANCE_NAME.log | wc -l)
                  LINE_NO=1
                  echo $R_INSTANCE_NAME  > $LF/invalid_script_no_$R_INSTANCE_NAME.log
                  [ -f $LF/scriptsdir.log ] && rm $LF/scriptsdir.log
                  while [ $LINE_NO -le $COUNT_MS  ]
                  do
                        SCRIPT_NAME=$(head -n $LINE_NO $LF/missing_sqlscripts_in_$R_INSTANCE_NAME.log | tail -1)
                        (find posibolt-[0-9].[0-9] -name "$SCRIPT_NAME*.sql" | xargs cp -t $SF || echo "$SCRIPT_NAME") >> $LF/invalid_script_no_$R_INSTANCE_NAME.log 2>/dev/null
                        find posibolt-[0-9].[0-9] -name "$SCRIPT_NAME*.sql" | cut -d'/' -f 1 >> $LF/scriptsdir.log
                        LINE_NO=`expr $LINE_NO + 1`
                  done
                  (echo `ls -l $SF/*.sql | wc -l` "Scripts Missing in $R_INSTANCE_NAME Instance") 2>/dev/null
                  ls -l $SF/*.sql 2>/dev/null | awk -F/ '{print $NF}'
##### RERUN Process #####
                  
                  [ -d $RSF ] && rm $RSF/*
                  mkdir -p $RSF
                  find posibolt-[0-9].[0-9] -name '[0-9][0-9][0-9][0-9]*.sql' | cut -d'/' -f 1 |sort -n |tail -1 | cut -d'_' -f 1 >> $LF/scriptsdir.log
                  sort -u $LF/scriptsdir.log > $LF/ad_msgdirlist.log
                  while IFS= read -r line; do cp $line/*_AD_Message*.sql $SF 2>/dev/null ; done < $LF/ad_msgdirlist.log
                  mv $SF/*_AD_Message*.sql $RSF
                  /usr/bin/printf "\nAD_Messages\n"
                  ls -l $RSF/*.sql 2>/dev/null | awk -F/ '{print $NF}'

                  RERUN_SCRIPT_COUNT=${#RERUN_SCRIPT_NOs[@]}
                  if [ $RERUN_SCRIPT_COUNT -gt 0 ] 
                  then
                        cd ${SVNDIR}/360trunk/migration
                        /usr/bin/printf "\nRe-Run Script Names\n"
                        j=0
                        while [ $j -lt $RERUN_SCRIPT_COUNT ]
                        do
                              RERUN_SCRIPT=${RERUN_SCRIPT_NOs[$j]}
                              find posibolt-[0-9].[0-9] -name "$RERUN_SCRIPT*.sql" | cut -d'/' -f 2
                              (find posibolt-[0-9].[0-9] -name "$RERUN_SCRIPT*.sql" | xargs cp -t $SF || echo "$RERUN_SCRIPT") >> $LF/invalid_script_no_$R_INSTANCE_NAME.log 2>/dev/null
                              mv $SF/${RERUN_SCRIPT}*.sql $RSF
                              j=`expr $j + 1`
                        done
                        /usr/bin/printf "Re-Run Script Process Completed\n \n"
                  fi
##### RERUN Process End #####

            echo $FILE_REV_CUR > $RF/$DATE/SCRIPTS_$R_INSTANCE_NAME/.script.revn
            echo "$R_INSTANCE_NAME SCRIPTS NOW COPIED TO $DATE/SCRIPTS_$R_INSTANCE_NAME"
            else
                  /usr/bin/printf "$R_INSTANCE_NAME Script Check Fails\nPlease Run Missing SQLs Manually" | mail -s "$R_INSTANCE_NAME SQL Script check Failed" $ADMIN_MAIL_IDs
            fi
else
      echo "$R_INSTANCE_NAME SCRIPTS ALREADY COPIED TO $DATE/SCRIPTS_$R_INSTANCE_NAME"  
fi
/usr/bin/printf "$R_INSTANCE_NAME Script Process Completed \n \n"

########################################## Remote Check #############################################
############################ CHECKING from Instance & SCP to Instance ###############################

SPACECHECK=$(ssh $SERVER df -m $REM_DIR --output=avail|tail -1)
if  [ $SPACECHECK -lt 500 ]
then
      echo "No Space Left on $R_INSTANCE_NAME Device"
      /usr/bin/printf "No Space Left on $R_INSTANCE_NAME Device" |  mail -s "$R_INSTANCE_NAME Update Failed" $ADMIN_MAIL_IDs
      set +e
      return ;
fi

R_FILE_REV=$(ssh $SERVER "if [ -s $REM_DIR/Release/$DATE/.files.revn ];then cat $REM_DIR/Release/$DATE/.files.revn ; else echo 0 ;fi")
echo "Remote File Version : $R_FILE_REV" 
if [ $R_FILE_REV == $FILE_REV_CUR ]
then 
      echo "$DATE Dir Already Copied to $R_INSTANCE_NAME Machine"
      R_SCRIPT_REV=$(ssh $SERVER "if [ -s $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/.script.revn ] ;then cat $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/.script.revn ; else echo 0 ;fi")
      echo "Remote Script Version : $R_SCRIPT_REV"
      if [ $R_SCRIPT_REV ==  $FILE_REV_CUR ]
      then
            echo "SCRIPTS Already Copied to  $R_INSTANCE_NAME Machine"
      else
            ssh  $SERVER "if [ -d $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME ]; then rm -rf $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME  ;fi"
            echo "Copying Sql Scripts...."            
            scp -r $SF $SERVER:$REM_DIR/Release/$DATE
            scp -r $RSF $SERVER:$REM_DIR/Release/$DATE
            echo "now copied $DATE/SCRIPTS_$R_INSTANCE_NAME Dir to $R_INSTANCE_NAME Machine"  
      fi          
else
      ssh  $SERVER  "if [ -d $REM_DIR/Release/$DATE ];then rm -rf $REM_DIR/Release/$DATE ;fi"
      echo "Copying Update Files....."
      scp -r $RF/$DATE/ $SERVER:$REM_DIR/Release
      echo "now copied $DATE Dir to $R_INSTANCE_NAME Machine"
fi


#################################### Updation Process of Instance ###################################

set +e
if [ $REPLACE_REPORT_DIR == 'Y' ]
then
echo "Copying Reports...."
rsync -avz ${SVNDIR}/360trunk/install/Adempiere/reports/ $SERVER:$R_ADEMPIERE_HOME/reports 2>&1 > ${JF}/jenkinsrsync.txt
fi

cd $RF/$DATE
UPDATEFILELIST=\"`ls *.*ar`\"
ssh $SERVER "sed -i -e '/UPDATEFILELIST=/ s/=.*/="$UPDATEFILELIST"/' $REM_DIR/$REM_SCRIPT"
ssh $SERVER "sed -i -e '/ENABLESILENTSETUP=/ s/=.*/="$ENABLE_SILENTSETUP"/' $REM_DIR/$REM_SCRIPT"
ssh $SERVER "sed -i -e '/DATE=/ s/=.*/="$DATE"/' $REM_DIR/$REM_SCRIPT"

ssh  $SERVER $REM_DIR/$REM_SCRIPT
ss=$?
echo "Remote Process Exist Status : $ss"

if [ $ss -eq 0 ]
then      
      echo "$R_INSTANCE_NAME Adempiere Started Successfully"  
      ADM_VERSION=$(ssh $SERVER "find $R_ADEMPIERE_HOME -iname version.jsp | xargs cat" | awk -F ' ' '{print $NF }')      
      if ssh $SERVER [ -s $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscript_$R_INSTANCE_NAME.log ];
      then 
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscript_$R_INSTANCE_NAME.log $LF
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt $LF
            /usr/bin/printf "$R_INSTANCE_NAME Updated Successfully -V[ $ADM_VERSION ] \n \nSQL Script Name \n$(/bin/cat $LF/dbscriptname_$R_INSTANCE_NAME.txt) \n \nSQL Script Error \n$(/bin/cat $LF/dbscript_$R_INSTANCE_NAME.log) \n \n[ svn-V($TV) ]" |  mail -s "$R_INSTANCE_NAME Updated Successfully" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs
      elif  ssh $SERVER [ -f $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt ];
      then
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt $LF           
            /usr/bin/printf "$R_INSTANCE_NAME Updated Successfully -V[ $ADM_VERSION ] \n \nSQL Script Name \n$(/bin/cat $LF/dbscriptname_$R_INSTANCE_NAME.txt) \n \n[ svn-V($TV) ]" |  mail -s "$R_INSTANCE_NAME Updated Successfully" -c $CC_LIST $ADMIN_MAIL_IDs
      else
            /usr/bin/printf "$R_INSTANCE_NAME Updated Successfully -V[ $ADM_VERSION ] \n \n \n[ svn-V($TV) ]" |  mail -s "$R_INSTANCE_NAME Updated Successfully" -c $CC_LIST $ADMIN_MAIL_IDs 
      fi

elif [ $ss -eq 21 ]
then
      scp $SERVER:$R_ADEMPIERE_HOME/silentsetup.log $LF
      /usr/bin/printf "$R_INSTANCE_NAME Silent Setup Failed \n \nError Log \n$(/bin/cat $LF/silentsetup.log)" |  mail -s "$R_INSTANCE_NAME SilentSetup Failed" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs

elif [ $ss -eq 22 ]
then
      scp $SERVER:$R_ADEMPIERE_HOME/utils/nohup.out $LF
      /usr/bin/printf "$R_INSTANCE_NAME Failed To Start \n \nNohup Log \n \n$(/bin/cat $LF/nohup.out)" |  mail -s "$R_INSTANCE_NAME Failed To Start" -c $CC_LIST $ADMIN_MAIL_IDs
      if ssh $SERVER [ -s $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscript_$R_INSTANCE_NAME.log ];
      then            
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscript_$R_INSTANCE_NAME.log $LF
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt $LF
            /usr/bin/printf "$R_INSTANCE_NAME Failed to Start, SQL Script Log \n \nSQL Script Name \n$(/bin/cat $LF/dbscriptname_$R_INSTANCE_NAME.txt) \n \nSQL Script Error \n$(/bin/cat $LF/dbscript_$R_INSTANCE_NAME.log)" |  mail -s "$R_INSTANCE_NAME Sql Script Log" -c $CC_LIST $ADMIN_MAIL_IDs $DEVELOPER_MAIL_IDs

      elif  ssh $SERVER [ -f $REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt ];
      then
            scp $SERVER:$REM_DIR/Release/$DATE/SCRIPTS_$R_INSTANCE_NAME/dbscriptname_$R_INSTANCE_NAME.txt $LF           
            /usr/bin/printf "$R_INSTANCE_NAME Failed to Start, SQL Script Log  \n \nSQL Script Name \n$(/bin/cat $LF/dbscriptname_$R_INSTANCE_NAME.txt)" |  mail -s "$R_INSTANCE_NAME Sql Script Log" -c $CC_LIST $ADMIN_MAIL_IDs
      fi      

elif [ $ss -eq 23 ]
then
      echo "$R_INSTANCE_NAME Adempiere Failed to Backup. Please Check and Start the Adempiere(Currently Down)"
      /usr/bin/printf "$R_INSTANCE_NAME Adempiere Failed to Backup. \nPlease Check and Start the Adempiere(Currently Down)" | mail -s "$R_INSTANCE_NAME Update Failed" -c $CC_LIST $ADMIN_MAIL_IDs 

elif [ $ss -eq 24 ]
then
      echo "$R_INSTANCE_NAME System Don't Have Free Space To Update."
      /usr/bin/printf "$R_INSTANCE_NAME System Don't Have Free Space To Update." | mail -s "$R_INSTANCE_NAME Update Failed" $ADMIN_MAIL_IDs

elif [ $ss -eq 255 ]
then  
      echo "No Connection to $SERVER"
      echo "No Connection to SERVER: $SERVER" | mail -s "$R_INSTANCE_NAME Update Failed" -c $CC_LIST $ADMIN_MAIL_IDs 
      
else
      echo "$R_INSTANCE_NAME $SERVER Adempiere Update Failed Reason Unknown"
      echo "$R_INSTANCE_NAME Update Failed Reason Unknown" | mail -s "$R_INSTANCE_NAME Update Failed" -c $CC_LIST $ADMIN_MAIL_IDs
fi

############################################ Journal log #############################################

Jtime=`date +%d%b%y-%H:%M`
cd $LF
mv nohup.out                                         "${JF}/${R_INSTANCE_NAME}.${Jtime}.nohup.out"                   2>>error.out
mv silentsetup.log                                   "${JF}/${R_INSTANCE_NAME}.${Jtime}.silentsetup.log"             2>>error.out
mv "dbscript_${R_INSTANCE_NAME}.log"                 "${JF}/${R_INSTANCE_NAME}.${Jtime}.dbscript.log"                2>>error.out
mv "dbscriptname_${R_INSTANCE_NAME}.txt"             "${JF}/${R_INSTANCE_NAME}.${Jtime}.dbscriptname.txt"            2>>error.out
mv "invalid_script_no_${R_INSTANCE_NAME}.log"        "${JF}/${R_INSTANCE_NAME}.${Jtime}.invalid_script_no.log"       2>>error.out
mv "sqlscripts_name_in_${R_INSTANCE_NAME}.log"       "${JF}/${R_INSTANCE_NAME}.${Jtime}.sqlscripts_name.log"         2>>error.out
mv "missing_sqlscripts_in_${R_INSTANCE_NAME}.log"    "${JF}/${R_INSTANCE_NAME}.${Jtime}.missing_sqlscripts.log"      2>>error.out

echo "================================================================================="
echo "####################### ${SERVER_NAMEs[$i]} Process Completed ###################"
echo "================================================================================="

################################ INSTANCE UPDATION PROCESS COMPLETED ################################
######################################## REMOTE PROCESS ENDS ########################################
}

########################################## Function Calling #########################################

SERVER_NOs=${#SERVER_NAMEs[@]}
if [ $SERVER_NOs -gt 0 ] 
then
echo "$SERVER_NOs Servers have to Update"
i=0
while [ $i -lt $SERVER_NOs ]
do
      set -e
      adempiere_updation
      fes=$?
      if [ $fes -ne 0 ]
      then  
            echo "No Connection to $SERVER"
            /usr/bin/printf "No Connection to $SERVER" |  mail -s "No Connection to $SERVER" $ADMIN_MAIL_IDs 
            echo "================================================================================="
            echo "####################### ${SERVER_NAMEs[$i]} Process Failed ######################"
            echo "================================================================================="
      fi
      i=`expr $i + 1`      
done
else
      /usr/bin/printf "$WORK_NAME Build Successfully \nFiles Copied To  $RF/$DATE\n"
      /usr/bin/printf "$WORK_NAME Build Successfully -V[ $FILE_REV_CUR ]\nFiles Copied To  $RF/$DATE \n \n \n \n[ svn-V($TV) ]" | mail -s "$WORK_NAME Build Successful" $ADMIN_MAIL_IDs
fi

echo "################################ Process Finished ##############################"

############################################### THE ENDS ###############################################
#;========================================
#; Title    : Jenkins Automation Script
#; Author   : Hasban_Mohammed
#; Date     : 20Nov20
#; Version  : 3.0-C 600 #changed version.jsp 
#;========================================
