FROM alpine:3.10

RUN apk update && apk add bash && apk add openssl && apk add sed && apk add grep && apk add jq && apk add curl

COPY certmon.sh /certmon.sh
COPY slack_payload.json /slack_payload.json

ENTRYPOINT [ "/certmon.sh" ]
