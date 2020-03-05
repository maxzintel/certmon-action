#!/bin/bash
# Monitor Certs for all provided URL's
set -e
echo "************************************************************"
echo "*                       HELLO                              *"
echo "*                                                          *"
echo "*  This script is designed to check each URL in the        *"
echo "*  siteinfo.json file, with its corresponding information. *"
echo "*  If something is awry with one of those certs, a slack   *"
echo "*  notification is sent to the #cloud-ops channel.         *"
echo "*                                                          *"
echo "*                       ^  ^                               *"
echo "*                      _|__|_                              *"
echo "*                    <| O  O |>                            *"
echo "*                     |_[~~]_|                             *"
echo "*                     ___||___                             *"
echo "*                 Cert-O-Tron-9000                         *"
echo "*                                                          *"
echo "************************************************************"

ARRAYCOUNT="$(cat siteinfo.json | jq '.siteinfo | length')"

for (( i = 0; i < $ARRAYCOUNT; i++ ));
do
  URL="$(cat siteinfo.json | jq -r .siteinfo[$i].url)"
  PORT="$(cat siteinfo.json | jq -r .siteinfo[$i].port)"
  PUBLICBOOL="$(cat siteinfo.json | jq -r .siteinfo[$i].public)"

  if $PUBLICBOOL == "true";
    then
      proxy=${EV_PROXY}
      echo "Checking cert in: $URL on port $PORT, with proxy $proxy"
      output=$(echo | openssl s_client -servername $URL -connect $URL:$PORT -proxy $proxy 2>/dev/null |\
      openssl x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##' | sed -e 's/GMT//g' | sed -e 's/ $//g')
      echo $output

      issuer=$(echo | openssl s_client -servername $URL -connect $URL:$PORT -proxy $proxy 2>/dev/null |\
      openssl x509 -noout -issuer | grep CN | sed -e 's/.*CN=\(.*\)/\1/g')
    else
      echo "Checking cert in: $URL on port $PORT, without explicit proxy set"
      output=$(echo | openssl s_client -servername $URL -connect $URL:$PORT 2>/dev/null |\
      openssl x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##' | sed -e 's/GMT//g' | sed -e 's/ $//g')
      echo $output

      issuer=$(echo | openssl s_client -servername $URL -connect $URL:$PORT 2>/dev/null |\
      openssl x509 -noout -issuer | grep CN | sed -e 's/.*CN=\(.*\)/\1/g')
  fi

  end_epoch=$(date -j -f '%b %d %T %Y' "$output" +%s)
  current_epoch=$(date +%s)
  secs_to_expire=$(($end_epoch - $current_epoch))
  days_to_expire=$(($secs_to_expire / 86400))
  gracedays=30
  danger_close=14
  comp_val=-17000

  echo " - Days to expire: $days_to_expire"
  if test "$days_to_expire" -lt "$danger_close";
    then
      export warning_color="#fe0000"
    else
      export warning_color="#fce903"
  fi

  if test "$days_to_expire" -lt "$gracedays";
    then
      echo " - WARNING: The cert for [$URL] will expire soon!"
      touch $URL-expiring.txt
    else
      echo " - This certificate does not expire soon."
  fi

  if [[ -f $URL-expiring.txt ]];
    then
      if [[ "$days_to_expire" -lt "$comp_val" ]];
        then
          cat slack_payload.json | jq -cr ".attachments[0].color = \"$warning_color\"" | jq -cr ".channel = \"${EV_SLACK-CHANNEL-ID}\" " | jq -cr ".attachments[0].blocks[0].text.text = \"*URL:* $URL\n *Issuer:* $issuer\n\"" | jq -cr ".text = \"*<${EV_BUILD-LOG-LINK}|ERROR: Could not connect to certificate!>*\"" | jq -c . > slack.json
          curl -X POST -H 'Content-type: application/json' --data '@slack.json' ${EV_SLACKHOOK}
          rm -rf $URL-expiring.txt
        else
          cat slack_payload.json | jq -cr ".attachments[0].color = \"$warning_color\"" | jq -cr ".channel = \"${EV_SLACK-CHANNEL-ID}\" " | jq -cr ".attachments[0].blocks[0].text.text = \"*URL:* $URL\n *Issuer:* $issuer\n\"" | jq -cr ".text = \"*<${EV_BUILD-LOG-LINK}|Certificate expiring in $days_to_expire days!>*\"" | jq -c . > slack.json
          curl -X POST -H 'Content-type: application/json' --data '@slack.json' ${EV_SLACKHOOK}
          rm -rf $URL-expiring.txt
      fi
    else
      echo " - No message will be posted to Slack."
  fi
done
