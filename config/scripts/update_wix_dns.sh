#!/bin/bash

# Updates Wix's A record for `inside.zymosbrewing.com`
# It does the following, in order:
## Gets the current external IP from a public website
## Gets the A record from Wix
## If the values are the same, exits
## Otherwise, deletes the A record and recreates it with the new value (Wix does not provide an update call)

# This whole thing is pretty brittle and subject to a bit of text parsing, so it's worth checking the logs occasionally (or maybe setting up a mailer)


API_TOKEN='<replace with API token, stored in Zymos Networking Log in Google Docs>'
ACCOUNT_ID='<replace with account ID for James: https://manage.wix.com/account/api-keys>'
LOG_FILE="/config/scripts/logs/dns_rotation.log"

log_line() {
  message=$1
  echo "[$(date)]: ${message}" | tee -a $LOG_FILE
}

get_current_external_ip_address() {
  curl -s http://checkip.dyndns.org | sed 's~.*<body>\(.*\)</body>.*~\1~' | sed 's~.* \([0-9]\)~\1~'
}

get_wix_a_value() {
  eval curl -s -X GET \'https://www.wixapis.com/domains/v1/dns-zones/zymosbrewing.com\' -H \'wix-account-id: ${ACCOUNT_ID}\' -H \'Authorization: ${API_TOKEN}\' | jq -r '.dnsZone.records | .[] | select(.hostName=="inside.zymosbrewing.com") | .values[0]'
}

delete_wix_a_value() {
  value_field=$1
  log_line "Deleting Wix A Record: ${value_field}"
  eval curl -s -X PATCH \'https://www.wixapis.com/domains/v1/dns-zones/zymosbrewing.com\' -H \'wix-account-id: ${ACCOUNT_ID}\' -H \'Authorization: ${API_TOKEN}\' -d \'{\"deletions\": [{\"hostName\": \"inside.zymosbrewing.com\", \"type\": \"A\", \"values\": [\"${value_field}\"]}], \"domainName\": \"zymosbrewing.com\"}\'
}

add_wix_a_value() {
  value_field=$1
  log_line "Adding Wix A Record: ${value_field}"
  eval curl -s -X PATCH \'https://www.wixapis.com/domains/v1/dns-zones/zymosbrewing.com\' -H \'wix-account-id: ${ACCOUNT_ID}\' -H \'Authorization: ${API_TOKEN}\' -d \'{\"additions\": [{\"hostName\": \"inside.zymosbrewing.com\", \"type\": \"A\", \"values\": [\"${value_field}\"], \"ttl\": 1800}], \"domainName\": \"zymosbrewing.com\"}\'
}

log_line "Starting DNS update"

current_external_ip=$(get_current_external_ip_address)
log_line "Current external IP: ${current_external_ip}"

if [ -z "${current_external_ip}" ] ; then
  log_line "Unable to determine current external IP, exiting"
  exit 1
fi

wix_ip=$(get_wix_a_value)
log_line "Found current Wix A Record: ${wix_ip}"

if [ "${current_external_ip}" == "${wix_ip}" ] ; then
  log_line "IP Addresses match, exiting without updating"
  exit 0
fi

delete_wix_a_value "${wix_ip}"
add_wix_a_value "${current_external_ip}"
