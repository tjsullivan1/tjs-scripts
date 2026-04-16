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

## Decision 7: Simple Single-Backend Routing

**Choice**: Single AI Foundry backend, no load balancing or failover.

**Rationale**: More complex routing (priority-based, affinity, health tracking)
is valuable but orthogonal to billing/metering. Keeping routing simple keeps
the demo focused and the policy XML readable. The sophisticated routing policy
exists as a separate reference in the `tjs-apim-test` environment.

## Note: AI Foundry Project Management

The `azurerm_cognitive_account` resource supports `project_management_enabled = true`
natively (added in azurerm v4.x). This must be set to `true` for an `AIServices`
account to allow project creation. Without it, project creation fails with:

> *"Project can only created under AIServices Kind account with
> allowProjectManagement set to true."*

Earlier iterations of this demo used `azapi_update_resource` + `time_sleep` as a
workaround, but setting the attribute directly on the resource is cleaner and
avoids eventual consistency issues.

## Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Event Hub pipeline for billing | Over-engineered for a demo; App Insights is sufficient |
| CosmosDB for billing records | Adds infra; KQL over App Insights achieves the same queries |
| Multiple AI backends with load balancing | Distracts from billing focus; available as separate sample |
| Consumption SKU for APIM | Limited policy support; can't use developer portal |
| Bicep instead of Terraform | User's existing solutions use Terraform consistently |
