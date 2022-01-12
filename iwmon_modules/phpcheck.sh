#!/bin/bash
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
# Multiple PHP Master processes check
touch ${outputpath}/${myname}.lck
phpmasters="$(ps aux | grep "php-fpm: master process" | grep -v grep | wc -l)";
echo ${phpmasters} > ${outputpath}/phpmaster.mon;
if [[ ${phpmasters} -gt 1 ]]
  then
    slog "WARNING" "Multiple PHP Master processes";
  else
    slog "OK" "PHP Master check OK";
fi
# PHP Worker amount check
phpworkers="$(ps aux | grep "php-fpm: pool www" | grep -v grep | wc -l)";
configpath="$(timeout -k 6 6 ${toolSh} get system C_ConfigPath | awk '{print $2}')";
workerconfig="$(cat ${configpath}/webserver.dat | grep "<FCGI_THREADPOOL>" | sed -r 's|<FCGI_THREADPOOL>(.*)</FCGI_THREADPOOL>|\1|' | tr -dc '[:digit:]')";
echo ${workerconfig} > ${outputpath}/phpslavemax.mon;
echo ${phpworkers} > ${outputpath}/phpslave.mon;
if [[ ${phpworkers} -gt 0 ]]
  then
    slog "OK" "PHP Workers running (${phpworkers})";
  else
    slog "INFO" "PHP Workers not running";
fi
exit 0

