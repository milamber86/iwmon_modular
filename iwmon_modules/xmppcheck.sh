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
toolSh="/opt/icewarp/tool.sh";
ctimeout=60;

# MAIN
touch ${outputpath}/${myname}.lck
ismaster=$(head -14 /opt/icewarp/path.dat 2>/dev/null | tail -1 | tr -d '\r');
if [[ ${ismaster} -ne 1 ]]
  then
    XMPP_RESPONSE="$(echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | timeout -k ${ctimeout} ${ctimeout} nc -w 60 "127.0.0.1" 5222 | egrep -o "^<stream:stream xmlns" | egrep -o "xmlns")"
    if [[ "${XMPP_RESPONSE}" == "xmlns" ]]
      then
        echo "OK" > ${outputpath}/${myname}.mon;slog "INFO" "IceWarp master XMPP OK.";
      else
        echo "FAIL" > ${outputpath}/${myname}.mon;slog "ERROR" "IceWarp master XMPP FAIL!";exit 1;
    fi
  else
    if echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | timeout -k ${ctimeout} ${ctimeout} nc -w 60 "127.0.0.1" 5222
      then
        echo "OK" > ${outputpath}/${myname}.mon;slog "INFO" "IceWarp slave XMPP OK.";
      else
        echo "FAIL" > ${outputpath}/${myname}.mon;slog "ERROR" "IceWarp slave XMPP FAIL!";exit 1;
    fi
fi
exit 0

