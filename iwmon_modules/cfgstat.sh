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
nfstestfile="/mnt/data/storage.dat";
toolSh="/opt/icewarp/tool.sh";

# MAIN
touch ${outputpath}/${myname}.lck
super="$(readcfg "super")";
tst="$(timeout -k 6 6 ${toolSh} get system C_Accounts_Policies_SuperUserPassword)"
if [[ $? -eq 0 ]]
  then
  result="$(echo "${tst}" | awk '{print $2}')";
  else
  echo "NA" > ${outputpath}/${myname}.mon;slog "ERROR" "Failed to get value from API using tool.sh during IceWarp config check!";
  exit 1
fi
if [[ "${super}" == "${result}" ]]
  then
  echo "OK" > ${outputpath}/${myname}.mon;slog "INFO" "IceWarp config reset check OK.";
  exit 0
  else
  echo "FAIL" > ${outputpath}/${myname}.mon;slog "ERROR" "IceWarp config reset check FAIL!";
  exit 1
fi

