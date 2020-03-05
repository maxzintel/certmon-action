# CertMon
**WORK IN PROGRESS: NOT PROD READY**
### Use Case:
Monitor certificate expiration and send an automatic slack alert if expiration is nearing.
Best used in a cron-scheduled build plan, grouped with other daily monitoring tasks.

### Data Format:
```json
{
  "siteinfo":[
    {
      "url": "url-you-want-to-monitor.com",
      "port": "443",
      "public": "true"
    }
  ]
}
```
* `"port"` is usually `"443"` in my experience.
* `"public"` determines whether we apply proxy settings in the script or not.

 ### ENV VARS Explained:
 * `${EV_PROXY}` is the proxy address through which your builds may access any internal (intranet) certificates you are trying to monitor. If `"public"` is `"false"` for any url's in your json file, you will need set this. It may require additional configuration outside of the scope of this action, ssh configuration on your builds, for example.
 * `${EV_SLACK-CHANNEL-ID}` is a unique id Slack creates for individual channels and conversations in Slack. Without setting this correctly the alert will likely be sent to your default channel.
* `${EV_BUILD-LOG-LINK}` is the link to your github action build logs. Setting this will allow your engineers to quickly access the logs in the event of a alert being sent.
* `${EV_SLACKHOOK}` is your team's slack hook, which you should be able to get from your Slack Admin. Without this the alerts will not be sent.

### APK Packages Needed:
* bash
* openssl
* sed
* grep
* jq
* curl

