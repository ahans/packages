#!/bin/sh
# captive portal auto-login script for m3connect @ Novotel Arnulfpark Munich
# Copyright (c) 2022 Alexander Hans (openwrt@ahans.de)
# This is free software, licensed under the GNU General Public License v3.

# set (s)hellcheck exceptions
# shellcheck disable=1091,2039,2181,3040

. "/lib/functions.sh"

export LC_ALL=C
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
set -o pipefail

trm_domain="1286.accor-group.conn4.com"
trm_useragent="$(uci_get travelmate global trm_useragent "Mozilla/5.0 (Linux x86_64; rv:90.0) Gecko/20100101 Firefox/90.0")"
trm_captiveurl="$(uci_get travelmate global trm_captiveurl "http://detectportal.firefox.com")"
trm_maxwait="$(uci_get travelmate global trm_maxwait "30")"
trm_fetch="$(command -v curl)"

rm -f "/tmp/${trm_domain}.cookie"

# get redirect url
#
redirect_url="$(${trm_fetch} --user-agent "${trm_useragent}" --referer "http://www.example.com" --connect-timeout $((trm_maxwait / 6)) --write-out "%{redirect_url}" --silent --show-error --output /dev/null "${trm_captiveurl}")"
[ -z "${redirect_url}" ] && exit 1

# get token
#
${trm_fetch} --user-agent "${trm_useragent}" --cookie-jar "/tmp/${trm_domain}.cookie" --cookie "/tmp/${trm_domain}.cookie" ${redirect_url}
token=$(${trm_fetch} --user-agent "${trm_useragent}" --cookie-jar "/tmp/${trm_domain}.cookie" --cookie "/tmp/${trm_domain}.cookie" "https://1286.accor-group.conn4.com/" | sed -n 's/^.*wbsToken = {"token":"\([^"]*\)".*$/\1/p')

# get session cookie
#
"${trm_fetch}" --user-agent "${trm_useragent}" -X POST -F session_id= -F with-tariffs=1 -F locationId=1286 -F locale=en_US -F authorization="token=${token}" --cookie-jar "/tmp/${trm_domain}.cookie" --cookie "/tmp/${trm_domain}.cookie" https://1286.accor-group.conn4.com/wbs/api/v1/create-session/
ses_id="$(awk '/PHPSESSID/{print $7}' "/tmp/${trm_domain}.cookie" 2>/dev/null)"

# final login request
#
"${trm_fetch}" --user-agent "${trm_useragent}" -X POST -F authorization="session=${ses_id}" -F "registration_type"="terms-only" -F "registration[terms]"=1 --cookie-jar "/tmp/${trm_domain}.cookie" --cookie "/tmp/${trm_domain}.cookie" https://1286.accor-group.conn4.com/wbs/api/v1/register/free/

[ "${?}" = "0" ] && exit 0 || exit 255