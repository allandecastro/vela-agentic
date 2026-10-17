# vela-reviewer (isolated subagent) - review 1 on git diff a8b2aba...HEAD (HEAD 1f6de50)

Verdict: **PASS** - no Critical / Required findings.

Spec axis: AC1-AC11 each mapped to a test that would fail if the behaviour broke (AC9/AC10 via PluginPipeline);
RED evidence valid (14 failing for the right reasons; 4 guard/constant cases passing early, expected); message/stage/
mode match the Canvas; no drift, no scope creep, no Dataverse write; publisher prefix confirmed; open questions
(ErpApiKey supplier, signing) recorded as blocking apply; AC9 residual risk recorded.

Standards axis: registration legal (Async at PostOp, no images, FilterOn present; build 0 warnings, no suppression);
outbound: HTTPS DNS name, explicit 30 s timeout, Async PostOp, Integrations project, public [DataContract] payload;
secret only in secure config (never in code/unsecure config/trace/messages); thin handler, service behind DI interface,
WithService in tests, no test seam in the plugin, no mutable fields, only InvalidPluginExecutionException.

Findings (all Nit):
1. Nit - ErpAccountSender.cs:62 - API key passed untrimmed to request.Headers.Add; a padded/newline value (e.g. from @file) is sent padded or throws FormatException (not IPE) - trim the key or map FormatException to IPE without the value.
2. Nit - ErpAccountSender.cs:70-73 - TaskCanceledException not kept as inner exception - pass it as inner.
3. Nit - AccountErpNotifyTests.cs:127-137 - AC11 only checks the success-path trace - also assert in AC2/AC8 tests.
4. Nit - ErpAccountSenderTests.cs:~91-115 - AC7 round-trips through the same serializer family - optionally use an independent parser in tests.
5. Nit - Canvas assumption "null name -> JSON null" has no test - add one or drop the assumption.
6. Nit - Canvas status: proposed after implementation - update when the Build Report is written.
7. Nit - AccountErpNotifyTests.cs:6 - unused using System.Linq.

Canvas decisions checked:
- Sync/Async + stage: Create / PostOperation / Async(deleteJobOnSuccess: true) - right for a non-blocking outbound call; new id exists only post-create.
- Reuse vs new: new plugin AccountErpNotify via vela add plugin into Integrations; no hand-created class.
- Service vs helper: new service IErpAccountSender/ErpAccountSender via vela add service; real logic, DI-resolved.
- Filter: FilterOn(e => e.Name); API create without name is a recorded residual risk (AC9), proven with a pipeline test.
