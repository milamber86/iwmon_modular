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

# VARS
myname="$(basename "$0" | awk -F'.' '{print $1}')";
configdir="/opt/icewarp/scripts/";
outputpath="$(readcfg outputpath)";
outputfile="${outputpath}/${myname}.mon";
nfstestfile="/mnt/data/storage.dat";
toolSh="/opt/icewarp/tool.sh";
ctimeout=60;

# MAIN
touch ${outputpath}/${myname}.lck
# iw web client login healthcheck
iwserver="127.0.0.1"
start=`date +%s%N | cut -b1-13`
email="$(readcfg 'wctestemail' | tail -1)";
admemail="globaladmin";
admpass="$(readcfg 'globaladm' | tail -1)";
# get admin auth token
atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
if [ -z "${wcatoken}" ];
  then
  testadmpass="$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system 'c_accounts_policies_globaladminpassword')";
  if [[ ${?} -eq 0 ]]
    then
    newadmpass="$(echo "${testadmpass}" | awk '{print $2}')";
    if [[ "${newadmpass}" != "${admpass}" ]]
      then
      admpass="${newadmpass}";
      atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
      wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
      if [ -z "${wcatoken}" ];
        then
        freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
        slog "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
        exit 1;
        else
        writecfg "globaladm" "${admpass}"
      fi
      else
      freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
      slog "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
      exit 1;
    fi
    else
    freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
    slog "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
    exit 1;
  fi
fi
# impersonate webclient user
imp_request="<iq sid=\"${wcatoken}\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>impersonatewebclient</commandname><commandparams><email>${email}</email></commandparams></query></iq>"
wclogintmp="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${imp_request}" "https://${iwserver}/icewarpapi/" | egrep -o '<result>(.*)</result>' | sed -r 's|<result>(.*)</result>|\1|')"
wclogin="$(echo ${wclogintmp} | sed -r 's|//.*/webmail/|//127.0.0.1/webmail/|')";
if [ -z "${wclogin}" ];
  then
  freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 2 fail - Error impersonating webclient user!";
  exit 1;
fi
# get user phpsessid
wcphpsessid="$(curl -s --connect-timeout 8 -m 8 -ikL "${wclogin}" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
if [ -z "${wcphpsessid}" ];
  then
  freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 3 fail - Error getting php session ID";
  exit 1;
fi
# auth user webclient session
auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
wcsid="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [ -z "${wcsid}" ];
  then
  freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 4 fail - Error logging to the webclient ( check PHP session store is available if Redis/KeyDB used )";
  exit 1;
fi
# get settings
get_settings_request="<iq sid=\"wm-"${wcsid}"\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:private\"><resources><skins/><banner_options/><im/><sip/><chat/><mail_settings_default/><mail_settings_general/><login_settings/><layout_settings/><homepage_settings/><calendar_settings/><default_calendar_settings/><cookie_settings/><default_reminder_settings/><event_settings/><spellchecker_languages/><signature/><groups/><restrictions/><aliases/><read_confirmation/><global_settings/><paths/><streamhost/><password_policy/><fonts/><certificate/><timezones/><external_settings/><gw_mygroup/><default_folders/><documents/></resources></query></iq>";
get_settings_response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${get_settings_request}" "https://${iwserver}/webmail/server/webmail.php")";
if [[ "${get_settings_response}" =~ "result" ]];
  then
   freturn=OK;
  else
   freturn=FAIL;slog "ERROR" "Stage 5 fail - Error getting settings, possible API problem";
fi
# refresh folders and look for INBOX
refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"INBOX\"")"
if [[ "${response}" =~ "INBOX" ]];
  then
   freturn=OK;
  else
   freturn=FAIL;slog "ERROR" "Webclient Stage 6 fail - No INBOX in folder sync response";
fi
# session logout
logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
end=`date +%s%N | cut -b1-13`
runtime=$((end-start))
echo "${freturn}" > ${outputpath}/${myname}.mon;
echo "${runtime}" > ${outputpath}/wcresponse.mon;
if [[ "${freturn}" == "OK" ]]; then slog "INFO" "Webclient check OK. Login time: ${runtime}.";exit 0;else exit 1;fi

