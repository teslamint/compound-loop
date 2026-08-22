<!-- plan-consumer-contract: retrospective/v1 -->
~~~json
{"decision":"origin","fixture":"origin-repo-relative","expected":"accept","diagnostic":"repo-relative origin"}
{"decision":"coverage","fixture":"no-plan-no-flip","expected":"no-flip","diagnostic":"no-plan"}
{"decision":"coverage","fixture":"ledger-plan","expected":"transition","diagnostic":"same-commit"}
{"decision":"coverage","fixture":"body-cited-plan","expected":"transition","diagnostic":"same-commit"}
{"decision":"coverage","fixture":"multi-plan","expected":"transition","diagnostic":"all-plans"}
{"decision":"applicability","fixture":"pre-contract","expected":"no-flip","diagnostic":"pre-contract"}
{"decision":"applicability","fixture":"non-approved","expected":"no-flip","diagnostic":"non-approved"}
{"decision":"transition","fixture":"missing-landed-commit","expected":"reject","diagnostic":"completed_by"}
{"decision":"transition","fixture":"split-commit","expected":"reject","diagnostic":"same-commit"}
{"decision":"transition","fixture":"omission-commit","expected":"reject","diagnostic":"all-plans"}
{"decision":"immutability","fixture":"body-mutation","expected":"reject","diagnostic":"body"}
{"decision":"immutability","fixture":"dirty-worktree-body-mutation","expected":"reject","diagnostic":"body"}
{"decision":"immutability","fixture":"other-frontmatter-mutation","expected":"reject","diagnostic":"frontmatter"}
~~~
<!-- end-plan-consumer-contract -->
