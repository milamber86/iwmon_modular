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
msgout) local smtp_msg_out="$(iwsnmpget "16.1")";
      if [[ "${smtp_msg_out}" != "Fail" ]]
        then
        echo "${smtp_msg_out}" > ${outputpath}/${myname}_msgout.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgout.mon;
      fi
;;
msgin) local smtp_msg_in="$(iwsnmpget "17.1")";
      if [[ "${smtp_msg_in}" != "Fail"  ]]
        then
        echo "${smtp_msg_in}" > ${outputpath}/${myname}_msgin.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgin.mon;
      fi
;;
msgfail) local smtp_msg_fail="$(iwsnmpget "18.1")";
      if [[ "${smtp_msg_fail}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail}" > ${outputpath}/${myname}_msgfail.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfail.mon;
      fi
;;
msgfaildata) local smtp_msg_fail_data="$(iwsnmpget "19.1")";
      if [[ "${smtp_msg_fail_data}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_data}" > ${outputpath}/${myname}_msgfaildata.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfaildata.mon;
      fi
;;
msgfailvirus) local smtp_msg_fail_virus="$(iwsnmpget "20.1")";
      if [[ "${smtp_msg_fail_virus}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_virus}" > ${outputpath}/${myname}_msgfailvirus.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailvirus.mon;
      fi
;;
msgfailcf) local smtp_msg_fail_cf="$(iwsnmpget "21.1")";
      if [[ "${smtp_msg_fail_cf}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_cf}" > ${outputpath}/${myname}_msgfailcf.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailcf.mon;
      fi
;;
msgfailextcf) local smtp_msg_fail_extcf="$(iwsnmpget "22.1")";
      if [[ "${smtp_msg_fail_extcf}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_extcf}" > ${outputpath}/${myname}_msgfailextcf.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailextcf.mon;
      fi
;;
msgfailrule) local smtp_msg_fail_rule="$(iwsnmpget "23.1")";
      if [[ "${smtp_msg_fail_rule}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_rule}" > ${outputpath}/${myname}_msgfailrule.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailrule.mon;
      fi
;;
msgfaildnsbl) local smtp_msg_fail_dnsbl="$(iwsnmpget "24.1")";
      if [[ "${smtp_msg_fail_dnsbl}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_dnsbl}" > ${outputpath}/${myname}_msgfaildnsbl.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfaildnsbl.mon;
      fi
;;
msgfailips) local smtp_msg_fail_ips="$(iwsnmpget "25.1")";
      if [[ "${smtp_msg_fail_ips}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_ips}" > ${outputpath}/${myname}_msgfailips.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailips.mon;
      fi
;;
msgfailspam) local smtp_msg_fail_spam="$(iwsnmpget "26.1")";
      if [[ "${smtp_msg_fail_spam}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_spam}" > ${outputpath}/${myname}_msgfailspam.mon;
        else
        echo "99999" > ${outputpath}/${myname}_msgfailspam.mon;
      fi
;;
*)    echo "Invalid argument. SMTP stats: msgout, msgin, msgfail, msgfaildata, msgfailvirus, msgfailcf, msgfailextcf, msgfailrule, msgfaildnsbl, msgfailips, msgfailspam"
;;
esac
}

myname="$(basename "$0" | awk -F'.' '{print $1}')";
configdir="/opt/icewarp/scripts/";
outputpath="$(readcfg outputpath)";
outputfile="${outputpath}/${myname}.mon";
toolSh="/opt/icewarp/tool.sh";

# MAIN
touch ${outputpath}/${myname}_${1}.lck
statname="${1}";
getstat "${statname}" &
exit 0

