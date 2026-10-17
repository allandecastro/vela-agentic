# Questions for the human

## Q1
Using vela-grill to resolve the story. I read the story as: an Account Create step that, after the account is saved, POSTs `{id, name}` as JSON to https://erp.zava-demo.com/api/accounts with the API key in `X-Api-Key` (the key held in the step's secure configuration, never in code).

Which existing unmanaged Dataverse solution (its unique name) should the plugin and its step be registered into? Vela does not create it; I will read its publisher prefix myself, read-only, with `vela solution show <uniquename> --json`.

Answer: the target solution is `ZavaSales` (publisher prefix `zava`). Use `Zava` as the namespace prefix.

## Q2
(Confirmed read-only: `vela solution show ZavaSales --json` -> {"solution":"ZavaSales","publisherPrefix":"zava"}, exit 0.)

When the ERP is down (or answers with an error), what should happen to that account's notification? The account is saved either way, because the call runs asynchronously after the save.
- (a) The call fails once and becomes a failed system job that an admin can see (`vela logs --jobs`). It is not retried automatically, so someone re-sends it if needed.
- (b) It must be delivered eventually, with automatic retries. A plugin alone can't guarantee this: it needs a queue or retry mechanism (e.g. Azure Service Bus or a flow), which would change the design and the scope.

Answer: (a) - no retry; a failed call should show as a failed system job, ops replays it.

## Q3
What exact JSON body does the ERP expect? My proposal: `{"id":"3f2b...-...","name":"Contoso"}`, with the keys `id` and `name` in lower case and `id` as the account GUID in the standard lower-case hyphenated form. Is that correct, or does the ERP use other key names or another format?

Answer: yes - `{"id": "<account guid>", "name": "<account name>"}`; the ERP answers 2xx on success.
