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
nfsmaxspeed=5000;

# MAIN
touch ${outputpath}/${myname}.lck
nfstestdir="$(readcfg nfstestdir)";
max=$((nfsmaxspeed*1000))
# grep AVG speed for ioping test
result=$(/usr/bin/ioping -c 4 -BD ${nfstestdir} | tail -1 | awk '{print $7}')
#echo "read speed: $((result/1000)) us"
if [ $result -lt $max ]; then
  freturn=OK;slog "INFO" "NFS read speed is OK.";
else
  freturn=FAIL;slog "ERROR" "NFS read speed FAIL! Is slower than $nfsmaxspeed ms.";
fi

echo "${freturn}" > ${outputpath}/${myname}.mon;
echo "$(dc <<<"2 k $result 1000 / p" | awk '{printf "%f", $0}')" > ${outputpath}/nfsreadspeed.mon;
if [[ "${freturn}" == "OK" ]]; then exit 0;else exit 1;fi

