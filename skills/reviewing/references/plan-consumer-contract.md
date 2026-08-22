<!-- plan-consumer-contract: reviewing/v1 -->
```json
{"decision":"adoption","fixture":"adoption-complete","expected":"accept","diagnostic":"adoption-approved"}
{"decision":"adoption","fixture":"adoption-changed-body","expected":"reject","diagnostic":"changed-body"}
{"decision":"adoption","fixture":"adoption-missing-baseline","expected":"reject","diagnostic":"missing-baseline"}
{"decision":"adoption","fixture":"adoption-missing-approval","expected":"reject","diagnostic":"approval"}
{"decision":"adoption","fixture":"adoption-missing-plan-path","expected":"reject","diagnostic":"plan path"}
{"decision":"adoption","fixture":"adoption-missing-old-seal","expected":"reject","diagnostic":"old seal"}
{"decision":"adoption","fixture":"adoption-missing-new-seal","expected":"reject","diagnostic":"new seal"}
{"decision":"adoption","fixture":"adoption-missing-reproduction-command","expected":"reject","diagnostic":"reproduction command"}
{"decision":"adoption","fixture":"reseal-after-adoption","expected":"reject","diagnostic":"interactive deepening"}
{"decision":"adoption-policy","policy":{"required_evidence":["approval","baseline","plan_path","old_seal","new_seal","reproduction_command"],"baseline_current_body":"equal","migration_commit":{"path":"repo-relative-evidence","diff":"seal-only","message_fields":["baseline","plan","old-seal","new-seal","reproduction-command","approval"],"command":"exact","approval":"first-hand-explicit"},"later_reseal":"reject-unless-interactive-deepening","interrupted_retry":{"compensation":"target-only","fresh_approval":true}}}
```
<!-- end-plan-consumer-contract -->
