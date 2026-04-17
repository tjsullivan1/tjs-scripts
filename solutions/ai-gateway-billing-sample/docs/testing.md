# Testing Guide — AI Gateway Billing Sample

This guide covers all testing scenarios for the AI Gateway, including
prerequisites, environment setup, and interpreting results.

## Prerequisites

Before running any tests, you need a **deployed environment**. See the
[main README](../README.md) for deployment instructions.

You will also need:

| Requirement | Purpose |
|-------------|---------|
| Deployed APIM instance | Gateway URL for requests |
| Subscription keys (Alpha + Bravo) | Authenticate as different consumers |
| [uv](https://docs.astral.sh/uv/getting-started/installation/) | Run the Python load test (handles dependencies automatically) |
| [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) VS Code extension | `.http` smoke tests |

### Retrieving test credentials from Terraform

After deploying, extract the values you need:

```bash
cd infra

# Gateway URL
terraform output openai_api_path

# Subscription keys
terraform output subscription_key_alpha_standard
terraform output subscription_key_bravo_premium
```

Or get everything at once:

```bash
terraform output -json | jq '{
  gateway: .openai_api_path.value,
  alpha_key: .subscription_key_alpha_standard.value,
  bravo_key: .subscription_key_bravo_premium.value
}'
```

---

## Environment Setup (shared `.env` file)

Both the `.http` smoke tests and the Python load test read from the same `.env`
file. Create it once in the `tests/` directory:

```bash
APIM_GATEWAY_URL=https://apim-<name>.azure-api.net
TENANT_ID=<entra-tenant-id>
API_AUDIENCE=api://<name>-ai-gateway

ALPHA_SUBSCRIPTION_KEY=<key>
ALPHA_CLIENT_ID=<client-id>
ALPHA_CLIENT_SECRET=<secret>

BRAVO_SUBSCRIPTION_KEY=<key>
BRAVO_CLIENT_ID=<client-id>
BRAVO_CLIENT_SECRET=<secret>

CHARLIE_SUBSCRIPTION_KEY=<key>
CHARLIE_CLIENT_ID=<client-id>
CHARLIE_CLIENT_SECRET=<secret>
```

> **Tip**: Generate this file automatically from Terraform outputs:
> ```bash
> cd infra
> terraform output -json | jq -r '...' > ../tests/.env
> ```
> See the [README](../README.md) for the full `jq` command.

If you deployed with `enable_key_vault = true`, you can set only the
non-secret values and let the load test fetch the rest from Key Vault:

```bash
APIM_GATEWAY_URL=https://apim-<name>.azure-api.net
TENANT_ID=<entra-tenant-id>
API_AUDIENCE=api://<name>-ai-gateway
KEY_VAULT_NAME=kv-<name>
```

The load test will fetch subscription keys, client IDs, and client secrets
from Key Vault automatically using
[`DefaultAzureCredential`](https://learn.microsoft.com/python/api/azure-identity/azure.identity.defaultazurecredential).
You must be logged in via `az login` (or have another credential source
available) with **Key Vault Secrets User** access.

> **Note**: The `.http` smoke tests always read all values from `.env`
> directly — they do not support Key Vault lookup.

> **Tip**: The `.env` file contains secrets — never commit it.

---

## Test 1: Quick Smoke Test (REST Client `.http`)

The `tests/quick-test.http` file provides five manual request scenarios you can
run interactively in VS Code.

### Setup

1. Ensure the `.env` file exists in the `tests/` directory (see above).

2. Open `tests/quick-test.http` in VS Code with the REST Client extension
   installed.

### Scenarios

| # | Scenario | What to verify |
|---|----------|----------------|
| Auth | Acquire JWT tokens (Alpha, Bravo, Charlie) | `200 OK` with `access_token` in response body. **Run these first** — all other requests depend on the tokens. |
| 1 | Chat completion — Team Alpha (Standard) | `200 OK`, response contains `choices` array with assistant message |
| 2 | Chat completion — Team Bravo (Premium) | `200 OK`, same structure as scenario 1 |
| 3 | Repeat of scenario 1 | Faster response time (semantic cache hit). Look for `x-cache: HIT` or significantly lower latency |
| 4 | Large request to trigger rate limit | Repeat multiple times. Eventually returns `429 Too Many Requests` with `remaining-tokens` header |
| 5 | Chat completion — Team Charlie (Standard) | `200 OK`, validates third consumer works |
| 6 | List models (GET) | `200 OK`, response contains available model deployments |

### Running

First, click **Send Request** on the three auth blocks (`alphaAuth`,
`bravoAuth`, `charlieAuth`) to acquire JWT tokens. Then run the API requests
in any order — each one references the captured token from the corresponding
auth request.

### Interpreting results

- **200 OK** — The request succeeded. Check the `usage` field in the response
  body for token counts (`prompt_tokens`, `completion_tokens`, `total_tokens`).
- **401 Unauthorized** — Subscription key is invalid or missing. Double-check
  your `.env` values.
- **404 Not Found** — Gateway URL or deployment name is wrong.
- **429 Too Many Requests** — Rate limit hit (expected for scenario 4). The
  `remaining-tokens` header shows your remaining quota.

---

## Test 2: Load Test (Python)

The `tests/load-test.py` script sends concurrent requests as both consumers
simultaneously, simulating realistic multi-tenant load.

### Setup

```bash
cd tests
uv sync
```

This creates a virtual environment and installs all dependencies from
`pyproject.toml`. Re-run `uv sync` after any dependency changes.

### Running

Basic run with defaults (10 requests per consumer, concurrency of 3):

```bash
cd tests
uv run load-test.py
```

The script reads `APIM_GATEWAY_URL`, `ALPHA_SUBSCRIPTION_KEY`, and
`BRAVO_SUBSCRIPTION_KEY` from the shared `.env` file. CLI flags override
`.env` values:

```bash
uv run load-test.py \
  --requests 20 \
  --concurrency 5
```

> **Model deployments**: By default the load test round-robins requests across
> three models: `gpt-4.1`, `gpt-4o-mini`, and `gpt-5.1-chat`. All three must
> be deployed in your AI Foundry backend or the requests targeting a missing
> model will return `404`. To test with fewer models, pass `--models` with a
> comma-separated list:
>
> ```bash
> uv run load-test.py --models gpt-4.1
> ```

#### Using Key Vault

If `KEY_VAULT_NAME` is set in `.env` (or passed via `--key-vault`), the script
fetches subscription keys from Azure Key Vault instead of reading them from
`.env`. Explicit `--alpha-key` / `--bravo-key` flags still take precedence.

```bash
uv run load-test.py --key-vault kv-aigatewayferret
```

You can also override credentials via CLI if needed:

```bash
uv run load-test.py \
  --gateway-url "https://apim-<name>.azure-api.net" \
  --alpha-key "<key>" \
  --bravo-key "<key>"
```

### CLI arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `--gateway-url` | `APIM_GATEWAY_URL` | APIM gateway base URL |
| `--tenant-id` | `TENANT_ID` | Entra ID tenant ID |
| `--api-audience` | `API_AUDIENCE` | API audience URI for JWT scope |
| `--alpha-key` | `.env` or Key Vault | Subscription key for Team Alpha |
| `--alpha-client-id` | `.env` or Key Vault | Team Alpha SP client ID |
| `--alpha-client-secret` | `.env` or Key Vault | Team Alpha SP client secret |
| `--bravo-key` | `.env` or Key Vault | Subscription key for Team Bravo |
| `--bravo-client-id` | `.env` or Key Vault | Team Bravo SP client ID |
| `--bravo-client-secret` | `.env` or Key Vault | Team Bravo SP client secret |
| `--key-vault` | `KEY_VAULT_NAME` | Azure Key Vault name to fetch missing secrets |
| `--models` | `gpt-4.1,gpt-4o-mini,gpt-5.1-chat` | Comma-separated model deployment names (requests are round-robined across them) |
| `--requests` | `10` | Number of requests **per consumer** |
| `--concurrency` | `3` | Max concurrent requests per consumer |

### Understanding the output

The script prints a per-consumer report:

```
============================================================
  Consumer: Team Alpha (Standard)
============================================================
  Total requests:   10
  Successful:       8
  Rate limited:     2
  Errors:           0
  Total tokens:     1,240
  Avg duration:     850 ms
  Min duration:     420 ms
  Max duration:     1,800 ms
```

| Metric | What it means |
|--------|---------------|
| **Successful** | Requests that returned `200 OK` |
| **Rate limited** | Requests that returned `429` — expected once the TPM quota fills |
| **Errors** | Non-200/429 responses or connection failures |
| **Total tokens** | Sum of `total_tokens` across all successful requests |
| **Avg/Min/Max duration** | Response time distribution |

### What to look for

- **Standard vs Premium rate limiting**: Team Alpha (Standard, 10K TPM) should
  hit rate limits sooner than Team Bravo (Premium, 50K TPM) under the same load.
- **Semantic cache effect**: Requests with identical or similar prompts should
  return faster on subsequent runs.
- **No errors**: Errors (non-200/429) indicate a configuration problem —
  check gateway URL, keys, and model deployment name.

---

## Test 3: Verifying Billing Metrics

After running either test, verify that token usage metrics appear in Application
Insights:

1. Open the Azure portal → your **Application Insights** resource.
2. Navigate to **Logs** (Log Analytics).
3. Run this KQL query:

    ```kql
    customMetrics
    | where name == "Total Tokens"
    | where timestamp > ago(1h)
    | extend subscription_id = tostring(customDimensions["Subscription ID"])
    | summarize total_tokens = sum(value) by subscription_id
    | order by total_tokens desc
    ```

4. You should see rows for each APIM subscription, with token counts matching
   (approximately) the load test output.

> **Note**: Metrics may take 2–5 minutes to appear in Application Insights
> after the requests complete.

For a visual dashboard, upload `workbook/ai-gateway-billing.json` to Azure
Monitor Workbooks or run the queries in `workbook/sample-queries.kql`.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `401 Unauthorized` on all requests | Invalid subscription key or JWT | Re-check subscription keys and client credentials; ensure the auth requests in `.http` returned a valid token |
| `401` with `invalid_client` in token request | Wrong client_id or client_secret | Verify values match `terraform output team_alpha_client_id` / `team_alpha_client_secret` |
| `404 Not Found` | Wrong gateway URL or model name | Verify `terraform output openai_api_path` and `--model` value |
| `500 Internal Server Error` | Backend (AI Foundry) unreachable | Check APIM → APIs → Backend health; verify Foundry endpoint is active |
| `429` immediately on first request | Previous test consumed the quota | Wait for the token-limit window to reset (1 minute for TPM, 1 hour for hourly quota) |
| No metrics in Application Insights | Instrumentation key mismatch or delay | Confirm APIM logger points to the correct App Insights instance; wait 5 minutes |
| `ConnectionError` in load test | APIM not provisioned yet | APIM Developer SKU takes 30–45 minutes; verify it's in `Succeeded` state |
| Key Vault `ForbiddenError` | Missing RBAC role | Ensure your identity has `Key Vault Secrets User` on the vault. RBAC propagation can take a few minutes after deployment |
| Semantic cache never hits | Embeddings backend misconfigured | Check APIM managed identity has `Cognitive Services User` role on the Foundry resource |
