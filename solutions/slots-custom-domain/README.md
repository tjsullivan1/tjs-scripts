# Slot Cookie Cross-Domain Demo

Demonstrates how Azure App Service deployment slot traffic routing cookies (`x-ms-routing-name`, `TiPMix`) become cross-domain when accessed through Azure Front Door, causing browsers to block them and breaking slot stickiness.

## Architecture

```
User → Custom Domain (DNS) → Azure Front Door → App Service
                                                   ├── Production slot (blue banner)
                                                   └── Staging slot (red banner)
```

- **Custom domain / Front Door URL**: Cookies are set with `Domain=*.azurewebsites.net` but the browser is on a different domain — cross-domain → blocked → stickiness breaks
- **Direct URL**: Cookies match the domain — first-party → works correctly

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (logged in)
- An Azure subscription
- An existing Azure DNS Zone for the custom domain

## Deploy

### 1. Infrastructure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

Note the outputs — you'll need `app_name` and the URLs.

### 2. Application (both slots)

```bash
cd src/SlotDemo
dotnet publish -c Release -o ./publish

# Create deployment zip from published output
cd publish
zip -r ../deploy.zip .
cd ..

# Deploy to production slot
az webapp deploy --resource-group rg-slotdemo --name <app_name> --src-path deploy.zip --type zip

# Deploy to staging slot
az webapp deploy --resource-group rg-slotdemo --name <app_name> --slot staging --src-path deploy.zip --type zip
```

### 3. Verify health checks

```bash
curl -s -o /dev/null -w "%{http_code}" https://<app_name>.azurewebsites.net/healthz
# Expected: 200
```

## Reproduce the Issue

### Working scenario (direct access)

1. Open the **direct App Service URL** from Terraform output (`app_direct_url`)
2. Navigate between Home and Cart pages, add items, refresh
3. Notice in the diagnostics panel:
   - `x-ms-routing-name` cookie is **present**
   - Session ID stays **consistent**
   - Visit counter increments reliably
   - Cart items persist

### Broken scenario (Front Door / custom domain access)

1. Open the **Front Door URL** or **custom domain URL** from Terraform output
2. Add items to cart, then refresh the page several times
3. Observe:
   - The **slot banner color alternates** between blue (production) and red (staging)
   - `x-ms-routing-name` cookie shows as **missing** in the diagnostics panel
   - Visit counter **resets** when you bounce to the other slot
   - Cart items **disappear** on slot switches
   - Session ID **changes** between requests

### What's happening

The App Service platform sets these response headers:

```
Set-Cookie: x-ms-routing-name=staging; Domain=wa-slotdemo.azurewebsites.net; ...
Set-Cookie: TiPMix=...; Domain=wa-slotdemo.azurewebsites.net; ...
```

When you access via Front Door or a custom domain, the browser sees these cookies as **third-party** (different domain) and blocks them. Without the routing cookie, each request gets randomly assigned to a slot based on the 50/50 traffic split.

## Health Checks

The app exposes a `/healthz` endpoint used by:
- **App Service** health check (configured via `health_check_path`) — unhealthy instances are evicted after 5 minutes
- **Front Door** health probe — probes `/healthz` over HTTPS every 30 seconds to determine origin health

## Custom Domain

The infrastructure creates:
- A **Front Door custom domain** with managed TLS certificate
- A **CNAME record** pointing your subdomain to the Front Door endpoint
- A **TXT record** (`_dnsauth.<subdomain>`) for domain ownership validation

You must have an existing Azure DNS Zone. Configure it via the `dns_zone_name`, `dns_zone_resource_group`, and `custom_domain_name` variables.

## Key Files

| File | Purpose |
|------|---------|
| `infra/main.tf` | App Service, slot, Front Door, custom domain, DNS records, traffic routing, health checks |
| `infra/variables.tf` | Configurable parameters (location, traffic %, custom domain) |
| `infra/terraform.tfvars.example` | Example variable values |
| `src/SlotDemo/Program.cs` | App startup with session, shared Data Protection, and health checks |
| `src/SlotDemo/Pages/Index.cshtml` | Visit counter demo |
| `src/SlotDemo/Pages/Cart.cshtml` | Shopping cart demo |
| `src/SlotDemo/Pages/Shared/_Layout.cshtml` | Diagnostics panel showing slot/cookie/session info |

## Design Notes

- **Data Protection keys are shared** across both slots via Azure Blob Storage. This ensures that session cookie decryption works on either slot — so when the session breaks, it's provably due to the routing cookie being blocked, not a key mismatch.
- **In-memory session** means each slot has its own session store. With working slot stickiness, the user stays on one slot and session works. Without it, requests bounce and session data is lost.
- **50% traffic routing** maximizes the visibility of the bouncing behavior.

## Cleanup

```bash
cd infra
terraform destroy
```

## Cost Considerations

- **App Service Plan (S1)**: ~$73/month (minimum SKU for deployment slots)
- **Azure Front Door (Standard)**: ~$35/month base + per-request charges
- **Storage Account**: Negligible (single small blob for DP keys)

**Recommendation**: Destroy resources after testing to avoid ongoing charges.
