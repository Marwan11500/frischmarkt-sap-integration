# FM_StockAPI: policies in execution order

All seven policies run in **ProxyEndpoint · PreFlow · Incoming Request** (the request side, before the backend call):

| # | Policy | Type | Purpose |
|---|---|---|---|
| 1 | CheckAPIKey | Verify API Key | Which partner app is calling? (header `APIKey`) |
| 2 | OnlyShelvesWindow | Raise Fault (403) | Only `GET` on `/Stock`, `/Products`, `/Stores` |
| 3 | SpeedLimit | Spike Arrest | Smooths bursts |
| 4 | HourlyBudget | Quota | Calls per hour per application |
| 5 | RemovePartnerKey | Assign Message | The partner key never reaches the backend |
| 6 | GetERPCredentials | Key Value Map Operations | Reads the technical user from the encrypted map `FM_ERP_KVM` |
| 7 | SetERPLogin | Basic Authentication | Adds the backend login |

Lessons learned: the ERP login must sit on the **request** side. When it landed in the response flow, the backend returned 401; the Debug tool showed that policies 6–7 never ran before the target call. Also: the Quota XML elements must follow the schema order (`TimeUnit` last), and the Key Value Map policy needed `async="false"` to deploy.
