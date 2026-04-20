# Architecture Decisions — AI Gateway Billing Sample

## Overview

This document captures the key design decisions for the AI Gateway billing demo
and the rationale behind each choice.

## Decision 1: Microsoft AI Foundry over Direct Azure OpenAI

**Choice**: Deploy an `AIServices` (AI Foundry) resource rather than a standalone
`Microsoft.CognitiveServices/accounts` with kind `OpenAI`.

**Rationale**: AI Foundry is the evolution of Azure OpenAI — it provides the same
OpenAI-compatible endpoints (`*.openai.azure.com`) but also supports agents
(`*.services.ai.azure.com`), projects, and a unified management experience. This
makes the demo forward-looking and representative of how Microsoft recommends
deploying AI services.

## Decision 2: APIM Developer SKU

**Choice**: Developer SKU (not Basicv2 or StandardV2).

**Rationale**: Developer SKU is the cheapest option (~$50/month) and includes all
features (developer portal, all policies, VNet support). The trade-off is a
30–45 minute deployment time and no SLA, both acceptable for a demo.

## Decision 3: `llm-*` Policy Names (Not `azure-openai-*`)

**Choice**: Use the newer `llm-*` policy prefix throughout.

**Rationale**: APIM has transitioned from `azure-openai-emit-token-metric` to
`llm-emit-token-metric` (and similar). The `llm-*` policies are provider-agnostic
and work with any OpenAI-compatible backend (Azure, Gemini, etc.). This also
matches patterns observed in production environments.

## Decision 4: Two-Layer Consumer Identity

**Choice**: Both APIM Products/Subscriptions AND Entra ID Service Principals.

**Rationale**:
- **APIM Products** provide tiering (Standard vs Premium) and built-in rate limiting
  via `llm-token-limit` with `counter-key` per subscription.
- **Entra ID SPs** provide identity-based authentication (`validate-azure-ad-token`)
  and enable billing attribution by authenticated caller, not just API key.
- Together, they give two dimensions for chargeback: who called (identity) and
  what tier they're on (product).

## Decision 5: Semantic Caching

**Choice**: Include `llm-semantic-cache-lookup/store` with an embeddings backend.

**Rationale**: Semantic caching reduces redundant calls to the AI backend, which
directly reduces costs — making it especially relevant for a billing-focused demo.
The cache uses a separate embeddings deployment with managed identity auth,
demonstrating a dual-auth pattern (API key for chat, MI for embeddings).

## Decision 6: Application Insights for Metering

**Choice**: APIM + Application Insights via `llm-emit-token-metric`.

**Rationale**: This is the simplest path to production-grade metering without
introducing additional services (Event Hub, Functions, etc.). The custom metric
dimensions (Subscription ID, User ID, API ID, etc.) provide enough granularity
for per-consumer billing dashboards via KQL.

> **Important**: Application Insights must have **custom metrics with dimensions**
> enabled, otherwise the `llm-emit-token-metric` policy will send metrics but
> strip the dimension values — making per-consumer queries return empty results.
> This is configured automatically via `azapi_update_resource` in `main.tf`
> (setting `CustomMetricsOptedInType = "WithDimensions"`). If deploying
> manually, enable it in the portal under **Application Insights → Usage and
> estimated costs → Custom metrics (Preview) → With dimensions**.

## Decision 7: Single-Backend Routing with Model-Tier Fallback

**Choice**: Single AI Foundry backend per provider, with policy-level retry and
model-tier fallback on failure. No multi-region backend pools.

**Rationale**: Multi-region load balancing adds infrastructure complexity that
distracts from the billing/metering focus of this demo. Instead, the gateway
uses a circuit breaker + model-tier fallback pattern (see Decision 15) to
provide resilience within a single region. This demonstrates the policy
mechanics that also apply to production patterns (multi-region, PTU→PayGo)
without requiring additional Azure regions or PTU commitments.

> **Note on multi-provider routing**: This sample now demonstrates multi-provider
> routing with Google Gemini as a second backend (see Decision 12). The same
> pattern can be extended to route to OpenAI directly, Amazon Bedrock, or any
> OpenAI-compatible endpoint by adding additional backends and routing rules.

## Note: AI Foundry Project Management

The `azurerm_cognitive_account` resource supports `project_management_enabled = true`
natively (added in azurerm v4.x). This must be set to `true` for an `AIServices`
account to allow project creation. Without it, project creation fails with:

> *"Project can only created under AIServices Kind account with
> allowProjectManagement set to true."*

Earlier iterations of this demo used `azapi_update_resource` + `time_sleep` as a
workaround, but setting the attribute directly on the resource is cleaner and
avoids eventual consistency issues.

## Decision 8: Ignoring Model Version and Capacity Drift

**Choice**: All `azurerm_cognitive_deployment` resources include:

```hcl
lifecycle {
  ignore_changes = [sku[0].capacity, model[0].version, rai_policy_name]
}
```

**Rationale**: Azure may auto-upgrade model versions (e.g., from a preview to a
GA release), adjust provisioned capacity, or assign a default RAI (Responsible
AI) content filtering policy behind the scenes. Without `ignore_changes`,
Terraform would detect these as drift and propose replacing or updating the
deployment on every `terraform plan` — potentially causing downtime or data loss
(deployment replacement destroys and recreates the resource). By ignoring these
attributes:

- **`model[0].version`**: Terraform won't force-replace a deployment just
  because Azure promoted it to a newer version. You can still update the
  version intentionally by changing the variable and removing the ignore
  temporarily, or by using `terraform apply -replace`.
- **`sku[0].capacity`**: Allows manual capacity scaling in the portal or via
  Azure CLI without Terraform reverting it on the next apply.
- **`rai_policy_name`**: Azure automatically assigns a default content filtering
  policy (e.g., `Microsoft.DefaultV2`) to deployments. Since we don't set this
  in Terraform, it would show as drift (`"Microsoft.DefaultV2" -> null`) on
  every plan without the ignore.

This is especially important for the `additional_chat_models` map, where the
version values are initial deployment targets — not pinned constraints.

## Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Event Hub pipeline for billing | Over-engineered for a demo; App Insights is sufficient |
| CosmosDB for billing records | Adds infra; KQL over App Insights achieves the same queries |
| Multiple AI backends with load balancing | Distracts from billing focus; available as separate sample |
| Consumption SKU for APIM | Limited policy support; can't use developer portal |
| Bicep instead of Terraform | User's existing solutions use Terraform consistently |

---

## Decision 9: Full Request/Response Body Logging

**Choice**: The APIM diagnostic logs both frontend and backend request/response
bodies (up to 8 KB each) to Application Insights.

> **⚠️ WARNING: THIS CONFIGURATION IS FOR DEMONSTRATION PURPOSES ONLY.**
>
> **Logging request and response bodies means that full user prompts and AI
> completions are captured in Application Insights.** In a production
> environment, this has **significant privacy, compliance, and security
> implications**, including but not limited to:
>
> - **PII / sensitive data exposure**: User prompts may contain personal
>   information, proprietary business data, or regulated content (HIPAA, GDPR,
>   CCPA, etc.) that must not be stored in logs.
> - **Data residency**: Logged content is stored in the Log Analytics workspace
>   region and subject to that region's data governance rules.
> - **Retention and access control**: Anyone with read access to the Application
>   Insights resource or Log Analytics workspace can query full prompt/response
>   history.
> - **Cost**: Body logging at scale significantly increases Application Insights
>   ingestion volume and cost.
>
> **For production deployments**, disable body logging by removing the
> `frontend_request`, `frontend_response`, `backend_request`, and
> `backend_response` blocks from the diagnostic resource — or limit them to
> header-only logging. Consider dedicated, access-controlled audit pipelines
> (e.g., Event Hub → secured storage) if prompt logging is required for
> compliance.

**Rationale**: For this demo, full body logging enables direct inspection of
prompts and completions via KQL in Log Analytics, making it easy to verify
routing, caching, and billing behavior. Example query:

```kql
AppRequests
| extend requestBody = parse_json(tostring(Properties["Request-Body"]))
| extend prompt = tostring(requestBody.messages[-1].content)
| project TimeGenerated, Name, prompt, ResultCode
```

## Decision 10: Comprehensive APIM Diagnostic Settings

**Choice**: Enable `allLogs`, `AuditLogs`, `GatewayLogs`, and `AllMetrics` in
the APIM diagnostic setting to Log Analytics.

**Rationale**: For this demo, we enable all available log categories to provide
full visibility into gateway behavior, audit trails, and platform metrics. This
makes it easy to troubleshoot issues, correlate request data with token metrics,
and demonstrate the full observability stack.

> **Note for production**: You do not need all of these categories enabled. In a
> production environment, consider enabling only the categories you actively
> query to reduce Log Analytics ingestion costs:
>
> - **`GatewayLogs`** — Required for request-level visibility (status codes,
>   latency, backend routing). Most teams need this.
> - **`AuditLogs`** — Tracks control-plane changes (policy edits, subscription
>   key rotations, user management). Useful for compliance and change auditing.
> - **`allLogs`** — Superset category that includes all log types. Convenient
>   but can be redundant if you already enable specific categories.
> - **`AllMetrics`** — Platform metrics (request count, capacity, latency
>   percentiles). Useful for dashboards and autoscaling alerts.
>
> Disable categories you don't need to keep costs predictable.

## Decision 11: Per-Model Cost Estimation

**Choice**: Use a KQL `datatable` lookup to apply per-model token pricing
(prompt vs. completion) based on the `Model` dimension emitted by
`llm-emit-token-metric`. Pricing rates are injected into the workbook at
deploy time from the Terraform `model_pricing` variable.

**Rationale**: A flat cost-per-token rate across all models is inaccurate —
gpt-4o-mini is ~13× cheaper than gpt-4.1 per input token. The `Model`
dimension captures which deployment served each request, allowing the cost
query to join with a pricing table and produce realistic per-consumer bills.

**Default rates** (Global Standard, per 1K tokens):

| Model | Prompt | Completion |
|---|---|---|
| gpt-4.1 | $0.002 | $0.008 |
| gpt-4o-mini | $0.00015 | $0.0006 |
| gpt-5.1-chat | $0.00125 | $0.01 |

**Fallback**: If the `Model` dimension is missing (e.g., cached responses),
the query falls back to gpt-4.1 rates via `coalesce()`.

**Dynamic pricing option**: Azure publishes live token pricing via the
[Retail Prices API](https://prices.azure.com/api/retail/prices) — a public,
unauthenticated REST endpoint. Example query:

```
GET https://prices.azure.com/api/retail/prices?$filter=productName eq 'Azure OpenAI'
```

> **Note**: Newer models (e.g., gpt-5.x) may appear under `serviceName eq
> 'Foundry Models'` instead of `'Azure OpenAI'`. The API returns per-1K or
> per-1M token rates depending on the model, so normalize units before use.

This sample uses static rates for simplicity. A production system could call
the Retail Prices API on a schedule (e.g., daily Azure Function) and update
the pricing datatable in the workbook or a Log Analytics custom table.

## Decision 12: Multi-Provider Routing (Google Gemini)

**Choice**: Add Google Gemini as an optional second backend via the Google AI
Generative Language API's OpenAI-compatible endpoint, gated by `enable_gemini`.

**Rationale**: Demonstrates that APIM's `llm-*` policies are truly
provider-agnostic. The same billing, rate-limiting, and metering pipeline works
for both Azure AI Foundry and Google Gemini without modification to the metric
dimensions or workbook queries.

**Backend routing**: The APIM policy extracts the model deployment name from the
URL path and routes to the appropriate backend:
- Models listed in `gemini_models` → `gemini-chat` backend
  (Google AI `generativelanguage.googleapis.com/v1beta/openai`)
- All other models → `foundry-chat` backend (Azure AI Foundry)

**Auth patterns**:
- **Foundry**: Managed identity (`authentication-managed-identity` in policy,
  `Cognitive Services OpenAI User` RBAC). No API keys stored.
- **Gemini**: API key stored in Key Vault, referenced via Key Vault-backed APIM
  named value. APIM's managed identity has `Key Vault Secrets User` role.

**Request normalization for Gemini**: The Google AI OpenAI-compatible endpoint
expects `/v1/chat/completions` with `model` in the request body. The APIM
policy rewrites the Azure-style path (`/deployments/{model}/chat/completions`)
to `/v1/chat/completions`, strips the `api-version` query parameter, and
injects the `model` field into the JSON body.

**Semantic cache**: Disabled for Gemini requests because the embeddings backend
is hosted on AI Foundry. Cache is now partitioned by both subscription and model
to prevent cross-model contamination. A Gemini embeddings backend could be added
later to enable caching for Gemini requests.

## Decision 13: Foundry Managed Identity Auth (No API Key)

**Choice**: Switch the Foundry chat backend from API key authentication to
managed identity, matching the pattern already used by the embeddings backend.

**Rationale**: Eliminates a stored secret (Foundry API key in APIM named value)
and aligns with zero-trust best practices. The APIM managed identity already had
`Cognitive Services OpenAI User` RBAC on the Foundry account (for embeddings);
the same role is sufficient for chat completions. This reduces the secret surface
to just the Gemini API key (which must be an API key since Google AI doesn't
support Azure managed identities).

## Decision 15: Circuit Breaker with Model-Tier Fallback

**Choice**: Implement a circuit breaker on the Foundry backend with automatic
model-tier fallback within the same provider. Cross-provider fallback
(Foundry↔Gemini) is not included in this phase.

**Fallback matrix**:

| Requested Model | Falls Back To |
|---|---|
| `gpt-5.1-chat` | `gpt-4o-mini` |
| `gpt-4.1` | `gpt-4o-mini` |
| `gpt-4o-mini` | _(no fallback — returns error)_ |

**Mechanism**:
- **Native APIM circuit breaker** on the `foundry-chat` backend: trips after
  repeated 429 (rate limited) or 5xx (server error) responses within a
  configurable window. Once open, requests fail fast instead of queuing against
  a degraded backend.
- **Policy-level retry with model swap**: When a request receives 429 or 5xx
  and the model has a defined fallback, the policy retries the request against
  the cheaper model. The request body is buffered (`buffer-request-body`) to
  allow POST replays.
- **Observability headers**: `x-served-model` and `x-fallback-reason` response
  headers indicate when a fallback occurred and which model actually served the
  request.
- **Metrics**: `llm-emit-token-metric` emits both the originally-requested model
  and the model that actually served the request (`Served-Model` dimension),
  enabling accurate cost reporting even after fallback.
- **Semantic cache bypass**: When a fallback changes the serving model, the
  response is NOT stored in the semantic cache to prevent cross-model
  contamination.

**Rationale**: In a single-region deployment without PTU (Provisioned Throughput
Units), 429 errors are the most common failure mode — especially with
`GlobalStandard` deployments that share capacity across all Azure tenants.
Rather than propagating rate-limit errors to consumers, gracefully degrading to
a cheaper (and often less-congested) model provides a better experience.

### Production Alternatives

This sample uses model-tier fallback as a pragmatic single-region pattern.
**In production, stronger resilience patterns exist:**

| Pattern | How It Works | When to Use |
|---|---|---|
| **Multi-region failover** | Deploy the same model across 2+ Azure regions. Use APIM backend pools with priority-based routing and circuit breaker. When region A trips, traffic shifts to region B automatically. | When latency SLAs matter and you can accept cross-region data transfer. Most resilient option. |
| **PTU → PayGo spillover** | Deploy a Provisioned Throughput Unit (PTU) for guaranteed baseline capacity, with a `GlobalStandard` (pay-as-you-go) deployment as overflow. Backend pool routes to PTU first; when PTU returns 429, circuit breaker shifts traffic to PayGo. | When you have predictable baseline load + burst traffic. Optimizes cost while guaranteeing capacity. |
| **PTU → PayGo + Multi-region** | Combine both: PTU in primary region → PayGo in primary region → PTU/PayGo in secondary region. Priority-ordered backend pool with per-backend circuit breakers. | Maximum resilience for mission-critical workloads. |

> **Why this sample uses model-tier fallback instead**: The customer requires
> single-region only, and the demo environment uses `GlobalStandard` (PayGo)
> deployments exclusively. Model-tier fallback demonstrates the circuit breaker
> mechanics and policy patterns without requiring multi-region infrastructure or
> PTU commitments. The same APIM backend pool and circuit breaker primitives
> apply to all patterns above — only the backend topology changes.

### Future Enhancement: Cross-Provider Fallback

Cross-provider fallback (e.g., Foundry→Gemini when all Foundry models are
degraded) is architecturally possible but deferred because:
- Different providers have different request/response contracts requiring
  URL rewrites and body mutations
- Auth mechanisms differ (managed identity vs API key)
- Model equivalence is approximate — output quality may change
- Billing/cost attribution becomes more complex

When implemented, cross-provider fallback should be **opt-in** (via request
header or APIM product assignment) rather than always-on, so consumers can
control whether they accept model substitution.

## Decision 14: Key Vault for Backend Credentials

**Choice**: Key Vault is always deployed (not optional). Backend API keys
(currently just Gemini) are stored as Key Vault secrets and referenced via
Key Vault-backed APIM named values.

**Rationale**: This is the production-recommended pattern for APIM secrets. APIM's
managed identity reads secrets at runtime without Terraform needing to pass raw
key values into APIM named values. The Key Vault also continues to optionally
store consumer test credentials (gated by `enable_key_vault`).
