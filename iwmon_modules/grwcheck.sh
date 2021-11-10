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
toolSh="/opt/icewarp/tool.sh";

# MAIN
touch ${outputpath}/${myname}.lck
GRW_RESPONSE="$(echo "test" | timeout -k ${ctimeout} ${ctimeout} nc -w 3 "127.0.0.1" 5229 | egrep -o "<greeting" | egrep -o "greeting")"
if [ "${GRW_RESPONSE}" == "greeting" ]; then
                        echo "OK" > ${outputpath}/${myname}.mon;slog "INFO" "IceWarp GRW OK.";
                          else
                        echo "FAIL" > ${outputpath}/${myname}.mon;slog "ERROR" "IceWarp GRW FAIL!";exit 1;
fi
exit 0


