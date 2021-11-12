#!/bin/bash
#VARS
HOST="127.0.0.1";
SNMPPORT="161"
ctimeout=15;
EASFOLDER="INBOX";
scriptdir="$(cd $(dirname $0) && pwd)"
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/iwmon_${logdate}.log"
toolSh="/opt/icewarp/tool.sh";
#outputpath="/opt/icewarp/var";                               # results output path ( now in iwmon.cfg )
nfstestfile="/mnt/data/storage.dat"                          # path to nfs mount test file
nfstestdir="/mnt/data/tmp/"                                  # path to nfs mount test directory
nfsmaxspeed=5000                                             # maximal allowed access time for storage in ms
icewarpdSh="/opt/icewarp/icewarpd.sh";
/usr/bin/touch "${scriptdir}/iwmon.cfg"
/usr/bin/chmod 600 "${scriptdir}/iwmon.cfg"
smtpserver="127.0.0.1"
smtpport="25"
imapserver="127.0.0.1"
imapport="143"
valfile="${scriptdir}/val_iwmon.mon"
moduledir="iwmon_modules";

#FUNC
# write log to local syslog
function slog
{
local logsvr="${1}";
local logmsg="${2}";
local logdate="$(date '+%b %d %H:%M:%S')";
timeout -k 2 2 /usr/bin/logger "${logdate} ${HOSTNAME} IWMON: ${logsvr} ${logmsg}"
}

# write setting to configfile
function writecfg() # ( setting_name, setting_value )
{
tmpcfg="$(cat ${scriptdir}/iwmon.cfg | grep -v "${1}")";
echo "${tmpcfg}" > "${scriptdir}"/iwmon_tmp.cfg
echo "${1}:${2}" >> "${scriptdir}"/iwmon_tmp.cfg
mv -f "${scriptdir}"/iwmon_tmp.cfg "${scriptdir}"/iwmon.cfg
return 0
}

# read setting from configfile
function readcfg() # ( setting_name -> setting_value )
{
result="$(/usr/bin/grep "${1}" ${scriptdir}/iwmon.cfg | awk -F ':' '{print $2}' )";
if [ -z "${result}" ]
  then
  echo "Variable ${1} empty or not found";
  return 1
  else
  echo "${result}"
  return 0
fi
}

# set initial settings to iwmon.cfg
function init()
{
mkdir -p "${nfstestdir}"
touch "${nfstestfile}"
local FILE="/opt/icewarp/path.dat"
if [ -f "${FILE}" ]
  then
  local mail_outpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _outgoing | dos2unix)
  [ -z "${mail_outpath}" ] && local mail_outpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|')
  local mail_inpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _incoming | dos2unix)
  [ -z "${mail_inpath}" ] && local mail_inpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|')
  else
  local mail_outpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|');
  local mail_inpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|');
fi
local mail_tmppath=$(${toolSh} get system C_System_Storage_Dir_TempPath | awk '{print $2}')
writecfg "mail_outpath" "${mail_outpath}";
writecfg "mail_inpath" "${mail_inpath}";
writecfg "mail_tmppath" "${mail_tmppath}";
${toolSh} set system C_Accounts_Policies_EnableGlobalAdmin 1
local super="$(timeout -k 30 30 ${toolSh} get system C_Accounts_Policies_SuperUserPassword | awk '{print $2}')";
writecfg "super" "${super}";
local admpass="$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system 'c_accounts_policies_globaladminpassword' | awk '{print $2}')";
writecfg "globaladm" "${admpass}";
declare DBUSER=$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBUser | sed -r 's|^C_ActiveSync_DBUser: (.*)$|\1|')
declare DBPASS=$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBPass | sed -r 's|^C_ActiveSync_DBPass: (.*)$|\1|')
read DBHOST DBPORT DBNAME <<<$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBConnection | sed -r 's|^C_ActiveSync_DBConnection: mysql:host=(.*);port=(.*);dbname=(.*)$|\1 \2 \3|')
read -r USER aURI aTYPE aVER aKEY <<<$(echo "select * from devices order by last_sync asc\\G" | timeout -k 3 3 mysql -u ${DBUSER} -p${DBPASS} -h ${DBHOST} -P ${DBPORT} ${DBNAME} | tail -24 | egrep "user_id:|uri:|type:|protocol_version:|synckey:" | xargs -n1 -d'\n' | tr -d '\040\011\015\012' | sed -r 's|^user_id:(.*)uri:(.*)type:(.*)protocol_version:(.*)synckey:(.*)$|\1 \2 \3 \4 \5|')
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_DenyExport 0 > /dev/null 2>&1
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_AllowAdminPass 1 > /dev/null 2>&1
declare PASS=$(timeout -k 3 3 ${toolSh} export account "${USER}" u_password | sed -r 's|^.*,(.*),$|\1|')
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_AllowAdminPass 1 > /dev/null 2>&1
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_DenyExport 1 > /dev/null 2>&1
writecfg "EASUser" "${USER}"
writecfg "EASPass" "${PASS}"
writecfg "EASVers" "${aVER}"
writecfg "nfstestdir" "${nfstestdir}"
writecfg "wctestemail" "$(/opt/icewarp/tool.sh export account "*@*" u_type | grep ",0" | sed -r 's|,0,||' | head -1)"
echo "Select and configure test account email for webclient monitoring."
echo "Example config for account webtest@testdomain.local:"
echo
echo 'echo "wctestemail:webtest@testdomain.loc" >> /opt/icewarp/scripts/iwmon.cfg'
}

# install dependencies
function installdeps()
{
utiltest="$(/usr/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
which curl > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing curl"
  /usr/bin/yum -y install curl
fi
which nc > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing nc"
  /usr/bin/yum -y install nc
fi
which wget > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing wget"
  /usr/bin/yum -y install nc
fi
which dos2unix > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing dos2unix"
  /usr/bin/yum -y install dos2unix
fi
which mysql > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing mysql client"
  /usr/bin/yum -y install mysql
fi
which snmpget > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing net-snmp-utils"
  /usr/bin/yum -y install net-snmp-utils
fi
which ioping > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing ioping"
  /usr/bin/yum -y install ioping
fi
which bc > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing bc"
  /usr/bin/yum -y install bc
fi
if [ ! -f ${scriptdir}/activesync.txt ]
  then
  cd "${scriptdir}"
  wget --no-check-certificate https://mail.icewarp.cz/webdav/ticket/eJwNy0EOhCAMAMDf9KZbKw1w6NUP.IICZWNMNFE06.,duc9XWF0cCpY4qkGVeb,SfjyQZYJT2CeqgRHNEA7paHDeMfrgwASWfyZS5opa.KO5Lbedz5b79muwCuUQNOKY0gsMHR5N/activesync.txt
fi
if [ ! -f ${scriptdir}/check_email_delivery ]
  then
  cd "${scriptdir}"
  wget --no-check-certificate https://raw.githubusercontent.com/milamber86/dwn/main/check_email_delivery
  chmod u+x check_email_delivery
  wget --no-check-certificate https://raw.githubusercontent.com/milamber86/dwn/main/check_smtp_send
  chmod u+x check_smtp_send
  wget --no-check-certificate https://raw.githubusercontent.com/milamber86/dwn/main/check_imap_receive
  chmod u+x check_imap_receive
  /usr/bin/yum -y install perl-Mail-IMAPClient
fi
utiltest="$(${toolSh} get system C_System_Adv_Ext_SNMPServer | awk '{print $2}')"
if [[ ${utiltest} != "1" ]]
  then
  log "Enabling IceWarp SNMP and restarting control service"
  ${toolSh} set system C_System_Adv_Ext_SNMPServer 1
  ${icewarpdSh} --restart control
fi
}

# print all stats for "all verbose" mode
function printStats() {
local outputpath="$(readcfg outputpath)";
echo "IceWarp stats for ${HOSTNAME} at $(date)"
echo "last value update - service: check result"
echo "--- Status ( OK | FAIL ):"
for SIMPLECHECK in iwvercheck smtpcheck imapcheck xmppcheck grwcheck wccheck nfsmntstat nfsreadstat nfswritestat cfgstat iwbackupcheck
    do
    echo -n "$(stat -c'%y' "${outputpath}/${SIMPLECHECK}.mon") - "
    echo -n "${SIMPLECHECK}: "
    getstat "${SIMPLECHECK}"
done
echo "--- Number of connections:"
for CONNCHECK in smtp imap xmpp http
    do
    echo -n "$(stat -c'%y' "${outputpath}/connstat_${CONNCHECK}.mon") - "
    echo -n "${CONNCHECK}: "
    getstat "connstat" "${CONNCHECK}"
done
echo "--- SMTP queues number of messages:"
for QUEUECHECK in inc outg retr tmp
    do
    echo -n "$(stat -c'%y' "${outputpath}/queuestat_${QUEUECHECK}.mon") - "
    echo -n "${QUEUECHECK}: "
    getstat "queuestat" "${QUEUECHECK}"
done
echo "--- SMTP message stats:"
for SMTPSTAT in msgout msgin msgfail msgfaildata msgfailvirus msgfailcf msgfailextcf msgfailrule msgfaildnsbl msgfailips msgfailspam
    do
    echo -n "$(stat -c'%y' "${outputpath}/smtpstat_${SMTPSTAT}.mon") - "
    echo -n "${SMTPSTAT}: "
    getstat "smtpstat" "${SMTPSTAT}"
done
echo "--- PHP-FPM workers running:"
echo -n "$(stat -c'%y' "${outputpath}/phpmaster.mon") - master ( should be exactly 1 ): "
getstat "phpmaster"
echo -n "$(stat -c'%y' "${outputpath}/phpmaster.mon") - slaves ( should be less or equal to slaves max ): "
getstat "phpslave"
echo -n "$(stat -c'%y' "${outputpath}/phpmaster.mon") - slaves max ( from FCGI_THREADPOOL in <iwconfigpath>/webserver.dat ): "
getstat "phpslavemax"
echo "--- WebClient and ActiveSync:"
echo -n "$(stat -c'%y' "${outputpath}/wclogin.mon") - "
echo -n "WebClient login: "
getstat "wclogin"
echo -n "$(stat -c'%y' "${outputpath}/wcresponse.mon") - "
echo -n "time spent (ms): "
getstat "wcresponse"
echo -n "$(stat -c'%y' "${outputpath}/easlogin.mon") - "
echo -n "ActiveSync login: "
getstat "easlogin"
echo -n "$(stat -c'%y' "${outputpath}/easresponse.mon") - "
echo -n "time spent (ms): "
getstat "easresponse"
echo "--- Email delivery status"
echo -n "$(stat -c'%y' "${outputpath}/emaildelivery.mon") - "
getstat "emaildelivery"
echo "--- NFS speed stats (ms):"
echo -n "$(stat -c'%y' "${outputpath}/nfsreadspeed.mon") - read: "
getstat "nfsreadspeed"
echo -n "$(stat -c'%y' "${outputpath}/nfswritespeed.mon") - write: "
getstat "nfswritespeed"
}

function printUsage() {
    cat <<EOF

Synopsis
    iwmon.sh run setup
    checks and installs dependencies, sets initial runtime configuration

    iwmon.sh run/get check_name [ check_parameter ]
    supported health-checks: iwbackup, iwver, cfg, nfs, nfsreadspeed, nfswritespeed, smtp, imap, xmpp, grw, wc, wclogin, easlogin, emaildelivery

    iwmon.sh run/get connstat [ service_name ]
    supported services: smtp, imap, xmpp, grw, http

    iwmon.sh run/get queuestat [ smtp_queue_name ]
    available queues: inc ( incoming ), outg ( outgoing ), retr ( outgoing-retry ), tmp ( smtp temp dir )

    iwmon.sh run/get connstat [ smtp_msg_stat_name ]
    available smtp stats: msgout, msgin, msgfail, msgfaildata, msgfailvirus, msgfailcf, msgfailextcf, msgfailrule
    ( for more details, see https://esupport.icewarp.com/index.php?/Knowledgebase/Article/View/180/16/snmp-in-icewarp )

    iwmon.sh get all
    prints all gathered stats to STDOUT

    iwmon.sh run all
    performs all checks in one run

    ---
    Performs healthchecks and queries service connection number stats and smtp
    queue lengths for IceWarp server.

    run command performs the check asynchronously
    get command prints the check last result if it is not older than 3 minutes

EOF
}

runcheck()
{
local outputpath="$(readcfg outputpath)";
local checkname="${1}";
if [[ ("${checkname}" =~ "connstat") || ("${checkname}" =~ "queuestat") || ("${checkname}" =~ "smtpstat") ]]
  then
    lockfile="${outputpath}/${checkname}_${2}.lck";
  else
    lockfile="${outputpath}/${checkname}.lck";
fi
if [[ -f ${lockfile} ]]
  then
    local now=$(date +%s)
    local lockdate=$(stat -L --format %Y $lockfile)
    local timediff=$(( $now - $lockdate ))
    if [[ (-f ${lockfile}) && ${timediff} -le 180 ]]
      then
        slog "WARNING" "Previous check ${checkname} still running, now for ${timediff}s. Will not perform another check this time."
        return 1
      else
        slog "WARNING" "Previous check ${checkname} running too long: ${timediff}s. Attempting to kill it and run the check again."
        pkill -9 -f "${checkname}.sh ${2}"
        rm -f ${lockfile}
        timeout -k 60 60 ${scriptdir}/${moduledir}/${checkname}.sh ${2} &
    fi
  else
    timeout -k 60 60 ${scriptdir}/${moduledir}/${checkname}.sh ${2} &
fi
return 0
}

getstat() { # ( metric name -> metric value  )
local outputpath="$(readcfg outputpath)";
local metric_name="${1}";
if [[ ("${metric_name}" =~ "connstat") || ("${metric_name}" =~ "queuestat") || ("${metric_name}" =~ "smtpstat") ]]
  then
    local filename=${outputpath}/${metric_name}_${2}.mon;
  else
    local filename=${outputpath}/${metric_name}.mon;
fi
if [[ ! -f ${filename} ]]
  then
    echo "Failed. Metric ${metric_name} file ${filename} does not exist."
    return 1
fi
local now=$(date +%s)
local filedate=$(stat -L --format %Y $filename)
local timediff=$(( $now - $filedate ))
if [[ ${timediff} -gt 180 ]]
  then
    echo "Failed. Metric ${metric_name} value too old ( not updated for ${timediff} sec. )."
    return 1
  else
    echo "$(cat ${filename})"
    return 0
fi
}

#MAIN
if [[ "${1}" == "run" ]]
  then 
    case ${2} in
    setup) installdeps;
           init;
    ;;
    iwbackup) runcheck iwbackupcheck;
    ;;
    iwver) runcheck iwvercheck;
    ;;
    cfg) runcheck cfgstat;
    ;;
    nfs) runcheck nfsmntstat;
    ;;
    nfsreadstat) runcheck nfsreadstat;
    ;;
    nfswritestat) runcheck nfswritestat;
    ;;
    smtp) runcheck smtpcheck;
    ;;
    imap) runcheck imapcheck;
    ;;
    xmpp) runcheck xmppcheck;
    ;;
    grw) runcheck grwcheck;
    ;;
    wc) runcheck wccheck;
    ;;
    wclogin) runcheck wclogin;
    ;;
    easlogin) runcheck easlogin;
    ;;
    connstat) runcheck connstat "${3}";
    ;;
    queuestat) runcheck queuestat "${3}";
    ;;
    smtpstat) runcheck smtpstat "${3}";
    ;;
    emaildelivery) runcheck emaildelivery;
    ;;
    phpcheck) runcheck phpcheck;
    ;;
   all) for I in smtpcheck imapcheck xmppcheck grwcheck wccheck wclogin easlogin emaildelivery nfsmntstat nfsreadstat nfswritestat cfgstat iwvercheck iwbackupcheck phpcheck;
      do
      runcheck ${I}
      done
      for STATNAME in smtp imap xmpp grw http;
        do runcheck connstat "${STATNAME}"
      done
      for STATNAME in msgout msgin msgfail msgfaildata msgfailvirus msgfailcf msgfailextcf msgfailrule msgfaildnsbl msgfailips msgfailspam;
        do runcheck smtpstat "${STATNAME}"
      done   
      for QUEUENAME in inc outg retr tmp
        do runcheck queuestat "${QUEUENAME}"
      done
    ;;
    *) printUsage;
    ;;
    esac
elif [[ "${1}" == "get" ]]
  then
      case ${2} in
    setup) installdeps;
           init;
    ;;
    iwbackup) getstat iwbackupcheck;
    ;;
    iwver) getstat iwvercheck;
    ;;
    cfg) getstat cfgstat;
    ;;
    nfs) getstat nfsmntstat;
    ;;
    nfsreadstat) getstat nfsreadstat;
    ;;
    nfswritestat) getstat nfswritestat;
    ;;
    nfsreadspeed) getstat nfsreadspeed;
    ;;
    nfswritespeed) getstat nfswritespeed;
    ;;
    smtp) getstat smtpcheck;
    ;;
    imap) getstat imapcheck;
    ;;
    xmpp) getstat xmppcheck;
    ;;
    grw) getstat grwcheck;
    ;;
    wc) getstat wccheck;
    ;;
    wclogin) getstat wclogin;
    ;;
    wcresponse) getstat wcresponse;
    ;;
    easlogin) getstat easlogin;
    ;;
    easresponse) getstat easresponse;
    ;;
    connstat) getstat connstat "${3}";
    ;;
    queuestat) getstat queuestat "${3}";
    ;;
    emaildelivery) getstat emaildelivery;
    ;;
    phpmaster) getststat phpmaster;
    ;;
    phpslave) getstat phpslave;
    ;;
    phpslavemax) getstat phpslavemax;
    ;;
    all) printStats;
    ;;
    *) printUsage;
    ;;
    esac
elif [[ ("${1}" != "run") || ("${1}" != "get") ]]
  then
    printUsage;
fi
exit $?
