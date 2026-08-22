<!-- plan-consumer-contract: implementing/v1 -->
```json
{"decision":"literal","fixture":"schema","expected":"plan/v1","diagnostic":""}
{"decision":"literal","fixture":"statuses","expected":"draft | approved | done | superseded","diagnostic":""}
{"decision":"literal","fixture":"seal-format","expected":"64-char lowercase hex SHA-256","diagnostic":""}
{"decision":"literal","fixture":"seal-extraction","expected":"text.split('---', 2)[2]","diagnostic":""}
{"decision":"schema","fixture":"schema-plan-v1","expected":"accept","diagnostic":""}
{"decision":"schema","fixture":"schema-missing","expected":"reject","diagnostic":"schema"}
{"decision":"schema","fixture":"schema-unknown","expected":"reject","diagnostic":"schema"}
{"decision":"status","fixture":"status-approved","expected":"accept","diagnostic":""}
{"decision":"status","fixture":"status-draft","expected":"reject","diagnostic":"pending approval"}
{"decision":"status","fixture":"status-done","expected":"reject","diagnostic":"completed_by=0123456789abcdef0123456789abcdef01234567"}
{"decision":"status","fixture":"status-done-missing-evidence","expected":"reject","diagnostic":"completed_by missing"}
{"decision":"status","fixture":"status-superseded","expected":"reject","diagnostic":"superseded_by=docs/plans/successor.md"}
{"decision":"status","fixture":"status-missing","expected":"reject","diagnostic":"status"}
{"decision":"status","fixture":"status-unknown","expected":"reject","diagnostic":"status"}
{"decision":"seal","fixture":"seal-correct","expected":"accept","diagnostic":""}
{"decision":"seal","fixture":"seal-malformed","expected":"reject","diagnostic":"stored= computed="}
{"decision":"seal","fixture":"seal-mismatch","expected":"reject","diagnostic":"stored= computed="}
{"decision":"seal","fixture":"seal-never-sealed","expected":"accept","diagnostic":""}
{"decision":"seal","fixture":"seal-removed","expected":"reject","diagnostic":"removed seal"}
{"decision":"reseal","fixture":"reseal-post-approval","expected":"reject","diagnostic":"interactive deepening"}
{"decision":"unit","fixture":"unit-code","expected":"accept","diagnostic":""}
{"decision":"unit","fixture":"unit-non-code","expected":"accept","diagnostic":""}
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
