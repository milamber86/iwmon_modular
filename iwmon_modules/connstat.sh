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
slog() {
local logsvr="${1}";
local logmsg="${2}";
local logdate="$(date '+%b %d %H:%M:%S')";
timeout -k 2 2 /usr/bin/logger "${logdate} ${HOSTNAME} IWMON: ${logsvr} ${logmsg}"
}

# get value from IceWarp snmp ( https://esupport.icewarp.com/index.php?/Knowledgebase/Article/View/180/16/snmp-in-icewarp )
iwsnmpget() { # ( iw snmp SvcID.SVC -> snmp response value )
local test="$(snmpget -r 1 -t 1 -v 1 -c private ${HOST}:${SNMPPORT} "1.3.6.1.4.1.23736.1.2.1.1.2.${1}")"
      if [[ ${?} != 0 ]]
        then
          echo "Fail";
          return 1;
        else
          local result="$(echo "${test}" | sed -r 's|^.*INTEGER:\s(.*)$|\1|')";
          echo "${result}";
          return 0
      fi
}

getstat() {
case "${1}" in
smtp) local conn_smtp_count="$(iwsnmpget "8.1")";
      if [[ "${conn_smtp_count}" != "Fail" ]]
              then
              echo "${conn_smtp_count}" > ${outputpath}/${myname}_smtp.mon;
              else
              echo "99999" > ${outputpath}/${myname}_smtp.mon;
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
pop)  local conn_pop3_count="$(iwsnmpget "8.2")";
      if [[ "${conn_pop3_count}" != "Fail" ]]
              then
              echo "${conn_pop3_count}" > ${outputpath}/${myname}_pop.mon;
              else
              echo "99999" > ${outputpath}/${myname}_pop.mon;
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
imap) local conn_imap_count="$(iwsnmpget "8.3")";
      if [[ "${conn_imap_count}" != "Fail" ]]
              then
              echo "${conn_imap_count}" > ${outputpath}/${myname}_imap.mon;
              else
              echo "99999" > ${outputpath}/${myname}_imap.mon;
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
xmpp) local conn_im_count_server="$(iwsnmpget "8.4")";
      local conn_im_count_client="$(iwsnmpget "10.4")";
      if [[ "${conn_im_count_server}" != "Fail" ]];then if [[ "${conn_im_count_client}" != "Fail" ]]
            then
            local conn_im_count=$((${conn_im_count_server} + ${conn_im_count_client}));
            echo "${conn_im_count}" > ${outputpath}/${myname}_xmpp.mon;
            else
            echo "99999" > ${outputpath}/${myname}_xmpp.mon;
            fi
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
grw)  local conn_gw_count="$(iwsnmpget "8.5")";
      if [[ "${conn_gw_count}" != "Fail" ]]
              then
              echo "${conn_gw_count}" > ${outputpath}/connstat_grw.mon;
              else
              echo "99999" > ${outputpath}/${myname}_grw.mon;
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
http) local conn_web_count="$(iwsnmpget "8.7")";
      if [[ "${conn_web_count}" != "Fail" ]]
              then
              echo "${conn_web_count}" > ${outputpath}/${myname}_http.mon;
              else
              echo "99999" > ${outputpath}/${myname}_web.mon;
      fi
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
*)    echo "Invalid argument. Use IceWarp service snmp name: smtp, pop, imap, xmpp, grw, http,"
      /usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
;;
esac
}

myname="$(basename "$0" | awk -F'.' '{print $1}')";
configdir="/opt/icewarp/scripts/";
outputpath="$(readcfg outputpath)";
outputfile="${outputpath}/${myname}_${1}.mon";
toolSh="/opt/icewarp/tool.sh";

cleanup() {
/usr/bin/rm -f "${outputpath}/${myname}_${1}.lck"
}
trap cleanup INT TERM ERR EXIT

# MAIN
touch ${outputpath}/${myname}_${1}.lck
statname="${1}";
getstat "${statname}" &
exit 0

