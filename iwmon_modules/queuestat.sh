cleanup() {
/usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
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
outputfile="${outputpath}/${myname}_${1}.mon";
toolSh="/opt/icewarp/tool.sh";
ctimeout=60;

# MAIN
touch ${outputpath}/${myname}_${1}.lck
mail_outpath=$(readcfg "mail_outpath");
mail_inpath=$(readcfg "mail_inpath");
mail_tmppath=$(readcfg "mail_tmppath");
case "${1}" in
outg) queue_outgoing_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_outpath} -maxdepth 1 -type f | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_outgoing_count}" > ${outputfile};
                           else
                           echo "9999" > ${outputfile};exit 1;
      fi
;;
inc)  queue_incoming_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_inpath} -maxdepth 1 -type f -name "*.dat" | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_incoming_count}" > ${outputfile};
                           else
                           echo "9999" > ${outputpath}/${outputfile};exit 1;
      fi
;;
retr) queue_outgoing_retry_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_outpath}retry/ ${mail_outpath}priority_* -type f | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_outgoing_retry_count}" > ${outputfile};
                           else
                           echo "9999" > ${outputfile};exit 1;
      fi
;;
tmp)  queue_tmp_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_tmppath}SMTP/ -type f | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_tmp_count}" > ${outputfile};
                           else
                           echo "9999" > ${outputfile};exit 1;
      fi
;;
*)    echo "Invalid argument. Use IceWarp queue name: outg, inc, retr"
;;
esac
exit 0

