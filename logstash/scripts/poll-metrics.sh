#!/usr/bin/bash
#

echo "{\"vcd_api_url\": \"https://${VCD_API_HOST}/api\", \"vcd_username\": \"${VCD_USERNAME}@${VCD_ORG}\", \"vcd_password\": \"${VCD_PASSWORD}\" }" | \
  curl -X POST -d @- http://${METRICS_SERVICE_HOST}:${METRICS_SERVICE_PORT}/stats
