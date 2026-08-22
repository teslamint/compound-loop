<!-- plan-consumer-contract: release-loop/v1 -->
```json
{"decision":"literal","fixture":"required-fields","expected":"schema,title,type,status,date,execution","diagnostic":""}
{"decision":"literal","fixture":"schema","expected":"plan/v1","diagnostic":""}
{"decision":"literal","fixture":"approved-status","expected":"approved","diagnostic":""}
{"decision":"literal","fixture":"plan-argument","expected":"--plan <path>","diagnostic":""}
{"decision":"required","fixture":"required-missing-schema","expected":"reject","diagnostic":"schema"}
{"decision":"required","fixture":"required-empty-schema","expected":"reject","diagnostic":"schema"}
{"decision":"required","fixture":"required-missing-title","expected":"reject","diagnostic":"title"}
{"decision":"required","fixture":"required-empty-title","expected":"reject","diagnostic":"title"}
{"decision":"required","fixture":"required-missing-type","expected":"reject","diagnostic":"type"}
{"decision":"required","fixture":"required-empty-type","expected":"reject","diagnostic":"type"}
{"decision":"required","fixture":"required-missing-status","expected":"reject","diagnostic":"status"}
{"decision":"required","fixture":"required-empty-status","expected":"reject","diagnostic":"status"}
{"decision":"required","fixture":"required-missing-date","expected":"reject","diagnostic":"date"}
{"decision":"required","fixture":"required-empty-date","expected":"reject","diagnostic":"date"}
{"decision":"required","fixture":"required-missing-execution","expected":"reject","diagnostic":"execution"}
{"decision":"required","fixture":"required-empty-execution","expected":"reject","diagnostic":"execution"}
{"decision":"eligibility","fixture":"valid-validator-exit0","expected":"accept","diagnostic":"validator=available exit=0"}
{"decision":"eligibility","fixture":"valid-validator-nonzero","expected":"reject","diagnostic":"validator=available nonzero"}
{"decision":"eligibility","fixture":"valid-validator-fallback","expected":"accept","diagnostic":"validator=fallback"}
{"decision":"eligibility","fixture":"unknown-schema","expected":"reject","diagnostic":"schema"}
{"decision":"eligibility","fixture":"non-approved-status","expected":"reject","diagnostic":"status"}
```
<!-- end-plan-consumer-contract -->
