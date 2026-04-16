"""
AI Gateway Load Simulator
=========================
Sends concurrent requests to the AI Gateway APIM endpoint as multiple consumers.
Reports token usage and response times per consumer.

Each consumer authenticates with both an APIM subscription key and an Entra ID
JWT (client_credentials flow). Reads configuration from a .env file with
optional CLI overrides. If KEY_VAULT_NAME is set, secrets are fetched from
Azure Key Vault for any values not provided via .env or CLI.

Usage:
    uv sync
    uv run load-test.py
    uv run load-test.py --requests 20 --concurrency 5
"""

import argparse
import asyncio
import os
import time
from dataclasses import dataclass, field
from pathlib import Path

import httpx
from dotenv import load_dotenv


@dataclass
class ConsumerConfig:
    name: str
    subscription_key: str
    bearer_token: str
    request_count: int = 20


@dataclass
class RequestResult:
    consumer: str
    model: str
    status_code: int
    duration_ms: float
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0
    remaining_tokens: str = ""
    error: str = ""


@dataclass
class LoadTestReport:
    consumer: str
    total_requests: int = 0
    successful: int = 0
    rate_limited: int = 0
    errors: int = 0
    total_tokens: int = 0
    avg_duration_ms: float = 0.0
    durations: list = field(default_factory=list)


async def send_request(
    client: httpx.AsyncClient,
    gateway_url: str,
    model: str,
    consumer: ConsumerConfig,
    prompt: str,
) -> RequestResult:
    url = f"{gateway_url}/openai/deployments/{model}/chat/completions?api-version=2024-12-01-preview"
    payload = {
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt},
        ],
        "max_completion_tokens": 200,
    }

    start = time.monotonic()
    try:
        resp = await client.post(
            url,
            json=payload,
            headers={
                "api-key": consumer.subscription_key,
                "Authorization": f"Bearer {consumer.bearer_token}",
                "Content-Type": "application/json",
            },
            timeout=60.0,
        )
        duration_ms = (time.monotonic() - start) * 1000

        result = RequestResult(
            consumer=consumer.name,
            model=model,
            status_code=resp.status_code,
            duration_ms=duration_ms,
            remaining_tokens=resp.headers.get("remaining-tokens", ""),
        )

        if resp.status_code == 200:
            body = resp.json()
            usage = body.get("usage", {})
            result.prompt_tokens = usage.get("prompt_tokens", 0)
            result.completion_tokens = usage.get("completion_tokens", 0)
            result.total_tokens = usage.get("total_tokens", 0)
        elif resp.status_code == 429:
            result.error = "Rate limited"
        else:
            result.error = resp.text[:200]

        return result

    except Exception as e:
        duration_ms = (time.monotonic() - start) * 1000
        return RequestResult(
            consumer=consumer.name,
            status_code=0,
            duration_ms=duration_ms,
            error=str(e),
        )


PROMPTS = [
    "What is Azure API Management?",
    "Explain token-based billing for AI APIs.",
    "How does semantic caching reduce AI costs?",
    "What are the benefits of using an AI gateway?",
    "Describe the difference between PTU and pay-as-you-go for Azure OpenAI.",
    "How do rate limits work in API Management?",
    "What is the role of Application Insights in monitoring AI usage?",
    "Explain the concept of chargeback in cloud cost management.",
    "What is Microsoft AI Foundry?",
    "How do APIM products and subscriptions enable multi-tenant AI access?",
]


async def run_consumer(
    client: httpx.AsyncClient,
    gateway_url: str,
    models: list[str],
    consumer: ConsumerConfig,
    concurrency: int,
) -> list[RequestResult]:
    semaphore = asyncio.Semaphore(concurrency)

    async def limited_request(i: int) -> RequestResult:
        async with semaphore:
            prompt = PROMPTS[i % len(PROMPTS)]
            model = models[i % len(models)]
            return await send_request(client, gateway_url, model, consumer, prompt)

    tasks = [limited_request(i) for i in range(consumer.request_count)]
    return await asyncio.gather(*tasks)


def build_report(consumer_name: str, results: list[RequestResult]) -> LoadTestReport:
    report = LoadTestReport(consumer=consumer_name)
    for r in results:
        report.total_requests += 1
        report.durations.append(r.duration_ms)
        if r.status_code == 200:
            report.successful += 1
            report.total_tokens += r.total_tokens
        elif r.status_code == 429:
            report.rate_limited += 1
        else:
            report.errors += 1
    if report.durations:
        report.avg_duration_ms = sum(report.durations) / len(report.durations)
    return report


def print_report(report: LoadTestReport) -> None:
    print(f"\n{'=' * 60}")
    print(f"  Consumer: {report.consumer}")
    print(f"{'=' * 60}")
    print(f"  Total requests:   {report.total_requests}")
    print(f"  Successful:       {report.successful}")
    print(f"  Rate limited:     {report.rate_limited}")
    print(f"  Errors:           {report.errors}")
    print(f"  Total tokens:     {report.total_tokens:,}")
    print(f"  Avg duration:     {report.avg_duration_ms:.0f} ms")
    if report.durations:
        print(f"  Min duration:     {min(report.durations):.0f} ms")
        print(f"  Max duration:     {max(report.durations):.0f} ms")


def print_model_breakdown(results: list[RequestResult]) -> None:
    """Print per-model summary across all consumers."""
    by_model: dict[str, list[RequestResult]] = {}
    for r in results:
        by_model.setdefault(r.model, []).append(r)

    print(f"\n{'=' * 60}")
    print("  Per-Model Breakdown")
    print(f"{'=' * 60}")
    for model, model_results in sorted(by_model.items()):
        ok = sum(1 for r in model_results if r.status_code == 200)
        limited = sum(1 for r in model_results if r.status_code == 429)
        tokens = sum(r.total_tokens for r in model_results)
        print(f"  {model:25s}  {len(model_results):3d} reqs  "
              f"{ok:3d} ok  {limited:3d} 429  {tokens:>6,} tokens")


async def main(args: argparse.Namespace) -> None:
    models = [m.strip() for m in args.models.split(",")]

    # Acquire JWT tokens upfront (client_credentials flow)
    print("Acquiring JWT tokens...")
    consumer_defs = [
        ("Team Alpha (Standard)", args.alpha_key, args.alpha_client_id, args.alpha_client_secret, args.requests * 2),
        ("Team Bravo (Premium)", args.bravo_key, args.bravo_client_id, args.bravo_client_secret, args.requests),
        ("Team Charlie (Standard)", args.charlie_key, args.charlie_client_id, args.charlie_client_secret, args.requests),
    ]

    scope = args.api_audience.rstrip("/") + "/.default"
    consumers = []
    for name, sub_key, client_id, client_secret, req_count in consumer_defs:
        token = acquire_token(args.tenant_id, client_id, client_secret, scope)
        consumers.append(
            ConsumerConfig(
                name=name,
                subscription_key=sub_key,
                bearer_token=token,
                request_count=req_count,
            )
        )
        print(f"  ✓ {name}")

    print(f"\nAI Gateway Load Test")
    print(f"  Gateway:     {args.gateway_url}")
    print(f"  Models:      {', '.join(models)}")
    print(f"  Requests:    Alpha={consumers[0].request_count}, "
          f"Bravo={consumers[1].request_count}, "
          f"Charlie={consumers[2].request_count}")
    print(f"  Concurrency: {args.concurrency}")
    print()

    async with httpx.AsyncClient() as client:
        all_results = await asyncio.gather(
            *[
                run_consumer(
                    client, args.gateway_url, models, c, args.concurrency
                )
                for c in consumers
            ]
        )

    all_flat = []
    for consumer, results in zip(consumers, all_results):
        report = build_report(consumer.name, results)
        print_report(report)
        all_flat.extend(results)

    print_model_breakdown(all_flat)

    print(f"\n{'=' * 60}")
    print("  Load test complete.")
    print(f"{'=' * 60}")


def acquire_token(tenant_id: str, client_id: str, client_secret: str, scope: str) -> str:
    """Acquire an Entra ID access token using client_credentials flow."""
    from azure.identity import ClientSecretCredential

    credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret,
    )
    token = credential.get_token(scope)
    return token.token


def fetch_secrets_from_key_vault(vault_name: str, secret_names: list[str]) -> dict[str, str]:
    """Fetch secrets from Azure Key Vault using DefaultAzureCredential."""
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient

    vault_url = f"https://{vault_name}.vault.azure.net"
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=vault_url, credential=credential)

    secrets = {}
    for name in secret_names:
        secrets[name] = client.get_secret(name).value

    return secrets


if __name__ == "__main__":
    load_dotenv(Path(__file__).parent / ".env")

    parser = argparse.ArgumentParser(
        description="AI Gateway load simulator. "
        "Reads defaults from .env file; CLI flags override .env values. "
        "If KEY_VAULT_NAME is set, missing secrets are fetched from Key Vault.",
    )
    parser.add_argument("--gateway-url", default=os.getenv("APIM_GATEWAY_URL"), help="APIM gateway base URL")
    parser.add_argument("--tenant-id", default=os.getenv("TENANT_ID"), help="Entra ID tenant ID")
    parser.add_argument("--api-audience", default=os.getenv("API_AUDIENCE"), help="API audience URI for JWT scope")
    parser.add_argument("--alpha-key", default=os.getenv("ALPHA_SUBSCRIPTION_KEY"), help="Subscription key for Team Alpha")
    parser.add_argument("--alpha-client-id", default=os.getenv("ALPHA_CLIENT_ID"), help="Team Alpha SP client ID")
    parser.add_argument("--alpha-client-secret", default=os.getenv("ALPHA_CLIENT_SECRET"), help="Team Alpha SP client secret")
    parser.add_argument("--bravo-key", default=os.getenv("BRAVO_SUBSCRIPTION_KEY"), help="Subscription key for Team Bravo")
    parser.add_argument("--bravo-client-id", default=os.getenv("BRAVO_CLIENT_ID"), help="Team Bravo SP client ID")
    parser.add_argument("--bravo-client-secret", default=os.getenv("BRAVO_CLIENT_SECRET"), help="Team Bravo SP client secret")
    parser.add_argument("--charlie-key", default=os.getenv("CHARLIE_SUBSCRIPTION_KEY"), help="Subscription key for Team Charlie")
    parser.add_argument("--charlie-client-id", default=os.getenv("CHARLIE_CLIENT_ID"), help="Team Charlie SP client ID")
    parser.add_argument("--charlie-client-secret", default=os.getenv("CHARLIE_CLIENT_SECRET"), help="Team Charlie SP client secret")
    parser.add_argument("--key-vault", default=os.getenv("KEY_VAULT_NAME"), help="Azure Key Vault name to fetch missing secrets")
    parser.add_argument("--models", default="gpt-4.1,gpt-4o-mini,gpt-5.1-chat", help="Comma-separated model deployment names (default: gpt-4.1,gpt-4o-mini,gpt-5.1-chat)")
    parser.add_argument("--requests", type=int, default=10, help="Base request count per consumer — Alpha gets 2x to demonstrate rate limiting (default: 10)")
    parser.add_argument("--concurrency", type=int, default=3, help="Max concurrent requests per consumer (default: 3)")

    args = parser.parse_args()

    # Fill missing secrets from Key Vault if configured
    if args.key_vault:
        kv_mapping = {
            "alpha-subscription-key": "alpha_key",
            "bravo-subscription-key": "bravo_key",
            "charlie-subscription-key": "charlie_key",
            "team-alpha-client-id": "alpha_client_id",
            "team-alpha-client-secret": "alpha_client_secret",
            "team-bravo-client-id": "bravo_client_id",
            "team-bravo-client-secret": "bravo_client_secret",
            "team-charlie-client-id": "charlie_client_id",
            "team-charlie-client-secret": "charlie_client_secret",
        }
        needed = [kv_name for kv_name, attr in kv_mapping.items() if not getattr(args, attr)]
        if needed:
            print(f"  Fetching {len(needed)} secret(s) from Key Vault: {args.key_vault}")
            kv_secrets = fetch_secrets_from_key_vault(args.key_vault, needed)
            for kv_name, attr in kv_mapping.items():
                if not getattr(args, attr) and kv_name in kv_secrets:
                    setattr(args, attr, kv_secrets[kv_name])

    missing = []
    if not args.gateway_url:
        missing.append("--gateway-url / APIM_GATEWAY_URL")
    if not args.tenant_id:
        missing.append("--tenant-id / TENANT_ID")
    if not args.api_audience:
        missing.append("--api-audience / API_AUDIENCE")
    for team, prefix in [("Alpha", "alpha"), ("Bravo", "bravo"), ("Charlie", "charlie")]:
        if not getattr(args, f"{prefix}_key"):
            missing.append(f"--{prefix}-key / {prefix.upper()}_SUBSCRIPTION_KEY")
        if not getattr(args, f"{prefix}_client_id"):
            missing.append(f"--{prefix}-client-id / {prefix.upper()}_CLIENT_ID")
        if not getattr(args, f"{prefix}_client_secret"):
            missing.append(f"--{prefix}-client-secret / {prefix.upper()}_CLIENT_SECRET")
    if missing:
        parser.error("Missing required values:\n  " + "\n  ".join(missing))

    asyncio.run(main(args))
