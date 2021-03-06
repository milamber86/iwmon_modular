cleanup() {
/usr/bin/rm -f "${outputpath}/${myname}.lck"
}
trap cleanup INT TERM ERR EXIT

# read setting from configfile
readcfg() { # ( setting_name -> setting_value )
result="$(/usr/bin/grep "${1}" ${configdir}/iwmon.cfg | awk -F ':' '{print $2}' )";
if [ -z "${result}" ]
  then
  echo "Variable ${1} empty or not found";
  return 1
  else
  echo "${result}"
  return 0
fi
}

# write log to local syslog
function slog
{
local logsvr="${1}";
local logmsg="${2}";
local logdate="$(date '+%b %d %H:%M:%S')";
timeout -k 2 2 /usr/bin/logger "${logdate} ${HOSTNAME} IWMON: ${logsvr} ${logmsg}"
}

myname="$(basename "$0" | awk -F'.' '{print $1}')";
configdir="/opt/icewarp/scripts/";
outputpath="$(readcfg outputpath)";
outputfile="${outputpath}/${myname}.mon";
ctimeout=60;
HOST="127.0.0.1";
toolSh="/opt/icewarp/tool.sh";
FOLDER="INBOX";
aURI="000EASHealthCheck000"
aTYPE="IceWarpAnnihilator"

# MAIN
touch ${outputpath}/${myname}.lck
USER=$(readcfg "EASUser");
PASS=$(readcfg "EASPass");
aVER=$(readcfg "EASVers");
start=`date +%s%N | cut -b1-13`
result=`/usr/bin/curl -s -k --connect-timeout ${ctimeout} -m ${ctimeout} --basic --user "$USER:$PASS" -H "Expect: 100-continue" -H "Host: $HOST" -H "MS-ASProtocolVersion: ${aVER}" -H "Connection: Keep-Alive" -A "${aTYPE}" --data-binary @${configdir}/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$HOST/Microsoft-Server-ActiveSync?User=$USER&DeviceId=$aURI&DeviceType=$aTYPE&Cmd=FolderSync" | strings`
end=`date +%s%N | cut -b1-13`
runtime=$((end-start))
if [[ $result == *$FOLDER* ]]
  then
    freturn=OK;slog "INFO" "ActiveSync login check OK.";
  else
    freturn=FAIL;slog "ERROR" "ActiveSync login check FAIL!";
fi
echo "${freturn}" > ${outputpath}/${myname}.mon;
echo "${runtime}" > ${outputpath}/easresponse.mon;
if [[ "${freturn}" == "OK" ]]; then exit 0;else exit 1;fi

