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
smtpserver="127.0.0.1";
imapserver="127.0.0.1";
smtpport="25";
smtpfrom="$(readcfg smtpfrom)";
smtpto="$(readcfg smtpto)";
imapuser="$(readcfg imapuser)";
imappassword="$(readcfg imappass)";
checkcmd="--mailto ${smtpto} --mailfrom ${smtpfrom} --smtp-server ${smtpserver} --smtp-port ${smtpport} --imap-server ${imapserver} --username ${imapuser} --password ${imappassword} --warning 150 --critical 300 --libexec ${configdir}"
result="$(timeout -k 350 350 ${configdir}/check_email_delivery ${checkcmd})"
if [[ "${result}" =~ "EMAIL DELIVERY OK" ]]
  then
    echo "OK: ${result}" > ${outputpath}/${myname}.mon;
    slog "INFO" "Email delivery check OK: ${result}"
    exit 0
  else
    echo "FAIL: ${result}" > ${outputpath}/${myname}.mon;
    slog "ERROR" "Email delivery check FAIL: ${result}"
    exit 1
fi

