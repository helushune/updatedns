#!/usr/bin/env bash

# https://gitlab.com/helushune/updatedns

# requirements:
# dig, curl, nsupdate (bind-utils/samba-nsupdate)

# usage:
# updatedns.sh [A | AAAA] [host-to-update]


TSIGKEY="/path/to/dns-tsig.key"                     # tsig-keygen -a hmac-sha512/hmac-sha256 ddnsupdatekey
DIGHOST="9.9.9.9"                                   # DNS server to query for current DNS record
DNSZONE="name.tld."                                 # DNS zone expecting the DDNS update.  Varies depending on DNS server configuration.
DATE=$(date +"%m_%d_%Y")
TEMPFILE="/tmp/updatedns_$COMPAREHOST_$DATE"        # Temporary file to store commands to send to nsupdate.  This shouldn't need changing.
LOGFILE="/tmp/updatedns_$COMPAREHOST_$DATE.log"     # Debug output of nsupdate in case anything goes wrong
NSUPDATESERVER="ns.name.tld|x.x.x.x"                # Server to send the Dynamic DNS update to
DNSTTL="1800"                                       # TTL to send with dynamic dns zone
RECORDTYPE=$1
COMPAREHOST=$2
ECHO=$(which echo)
NSUPDATE=$(which nsupdate)
CURL=$(which curl)
DIG=$(which dig)


do_output() {
  $ECHO "Variables:"
  $ECHO "Check URL - ${CHECKURL}"
  $ECHO "Current IP - ${CURRENTIP}"
  $ECHO "Current DNS entry - ${RECORDIP}"
  $ECHO "Dig host - ${DIGHOST}"
  $ECHO "TSIG key file - ${TSIGKEY}"
  $ECHO "Record Type - ${RECORDTYPE}"
  $ECHO "Compare host - ${COMPAREHOST}"
  $ECHO "nsupdate server - ${NSUPDATESERVER}"
  $ECHO "DNS zone name - ${DNSZONE}"
  $ECHO "DNS TTL - ${DNSTTL}"
  $ECHO "Temp file - ${TEMPFILE}"
  $ECHO "nsupdate - ${NSUPDATE}"
  $ECHO "echo - ${ECHO}"
  $ECHO "curl - ${CURL} ${CURLFLAGS}"
  $ECHO "dig - ${DIG}"
}

do_setvars() {
  if [[ $RECORDTYPE == "A" ]]; then
    CHECKURL="ifconfig.co"
    CURLFLAGS="-4 -s"
  elif [[ $RECORDTYPE == "AAAA" ]]; then
    CHECKURL="ifconfig.co"
    CURLFLAGS="-6 -s"
  fi
}

do_getip() {
  $ECHO "Checking external IP..."
  CURRENTIP=$($CURL $CURLFLAGS $CHECKURL)
  $ECHO "External IP is $CURRENTIP"
}

do_compareip() {
  $ECHO "Comparing external IP and $RECORDTYPE record for $COMPAREHOST"
  RECORDIP=$(dig "$COMPAREHOST" "$RECORDTYPE" +short @"$DIGHOST")
  $ECHO "$RECORDTYPE record for host $COMPAREHOST is $RECORDIP"
  if [[ $CURRENTIP == "$RECORDIP" ]]; then
#    do_output
    do_quit_no_update
  else
    $ECHO "$RECORDTYPE record update required"
    do_nsupdate
  fi
}

do_quit_no_update() {
  $ECHO "No $RECORDTYPE record update needed..."
  exit
}

do_quit() {
  $ECHO "$RECORDTYPE record update sent for zone $COMPAREHOST"
  exit
}

do_nsupdate() {
  $ECHO "Preparing nsupdate commands"
  $ECHO "server $NSUPDATESERVER" >> "$TEMPFILE"
  $ECHO "debug yes" >> "$TEMPFILE"
  $ECHO "zone $DNSZONE" >> "$TEMPFILE"
  $ECHO "update delete $COMPAREHOST $RECORDTYPE" >> "$TEMPFILE"
  $ECHO "update add $COMPAREHOST $DNSTTL $RECORDTYPE $CURRENTIP" >> "$TEMPFILE"
  $ECHO "send" >> "$TEMPFILE"
  $ECHO "Sending $RECORDTYPE update for $COMPAREHOST to $NSUPDATESERVER"
  $NSUPDATE -k ${TSIGKEY} -v "${TEMPFILE}" > "$LOGFILE" 2>&1
  rm -rf "$TEMPFILE"
} 


main() {
 do_setvars
 do_getip
 do_compareip
# do_output
 do_quit
}

main "$@"
