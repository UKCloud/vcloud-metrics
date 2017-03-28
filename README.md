vCloud Director Utilisation Metrics
============
The UKCloud ECC platform (regions 5 & 6 only) expose VM utilisation metrics via an API endpoint. The metrics API is documented in [the knowledge centre](https://portal.skyscapecloud.com/support/knowledge_centre/964d37e0-0dfe-45a6-ae8d-733144e78d3e) - to summarise though, you have to make a HTTP GET request to the API for every VM, and the response you receive back is an XML structure that is not easy to process into an ELK stack or similar.
``` shell
GET https://api.vcd.portal.skyscapecloud.com/api/vApp/vm-12345678-aaaa-bbbb-cccc-1234567890ab/metrics/current

<CurrentUsage xmlns="http://www.vmware.com/vcloud/v1.5" ...>
          <Link
             rel="up"
             href="https://api.vcd.portal.skyscapecloud.com/api/vApp/vm-12345678-
       aaaa-bbbb-cccc-1234567890ab"
             type="application/vnd.vmware.vcloud.vm+xml">
          <Metric name="cpu.usage.average"
             unit="PERCENT"
             value="0.1"/>
          <Metric name="cpu.usage.maximum"
             unit="PERCENT"
             value="0.1"/>
          <Metric name="cpu.usagemhz.average"
             unit="MEGAHERTZ"
             value="2.0"/>
          <Metric name="mem.usage.average"
             unit="PERCENT"
             value="0.0"/>
          <Metric name="disk.write.average"
             unit="KILOBYTES_PER_SECOND"
             value="0.0"/>
          <Metric name="disk.read.average"
             unit="KILOBYTES_PER_SECOND"
             value="0.0"/>
          <Metric name="disk.provisioned.latest"
             unit="KILOBYTE"
             value="45410433"/>
          <Metric name="disk.used.latest"
             unit="KILOBYTE"
             value="111744.0"/>
       </CurrentUsage>
```


----------

The vcloud-metrics MicroService
-------------------------------
This is a microservice to mine the vCloud Director Metrics API and return a usable JSON structure intended for injecting directly into elastic search, using the logstash configuration also provided here. We have also provided some exported searches, visualisations and a dashboard that you can import into Kibana.
![Kibana Dashboard](raw/master/images/dashoard.png)

The microservice requires a JSON string containing the vCloud API endpoint and your user credentials:

```
{ "vcd_api_url": "https://api.vcd.z0000f.r00006.frn.portal.skyscapecloud.com/api",
  "vcd_username": "1234.1.456789@1-1-11-123456",
  "vcd_password": "Sup3rS3creT" }
```

This JSON is then POST'ed to the microservice /stats endpoint:

```
  curl -X POST -d '{"vcd_api_url": "https://api.vcd.z0000f.r00006.frn.portal.skyscapecloud.com/api","vcd_username": "1234.1.456789@1-1-11-123456", "vcd_password": "Sup3rS3creT" }' -i http://vcloud-metrics-url/stats
```

The microservice will then use the vCloud Query API to enumerate all VM instances in your account and iteratively call the relevant /metrics/current endpoint. All the metrics are returned as a JSON list structure:

```
[{"name":"cpu.usage.average","unit":"PERCENT","value":"0.09","vm_name":"node02.devops.ukcloud.com"},
{"name":"cpu.usage.maximum","unit":"PERCENT","value":"0.09","vm_name":"node02.devops.ukcloud.com"},
{"name":"cpu.usagemhz.average","unit":"MEGAHERTZ","value":"8.0","vm_name":"node02.devops.ukcloud.com"},
{"name":"disk.provisioned.latest","unit":"KILOBYTE","value":"19044612","vm_name":"node02.devops.ukcloud.com"},
{"name":"mem.usage.average","unit":"PERCENT","value":"0.0","vm_name":"node02.devops.ukcloud.com"},
{"name":"disk.used.latest","unit":"KILOBYTE","value":"10301699","vm_name":"node02.devops.ukcloud.com"},
{"name":"disk.write.average","unit":"KILOBYTES_PER_SECOND","value":"0.0","vm_name":"node02.devops.ukcloud.com"},
{"name":"disk.read.average","unit":"KILOBYTES_PER_SECOND","value":"0.0","vm_name":"node02.devops.ukcloud.com"},
...
]
```