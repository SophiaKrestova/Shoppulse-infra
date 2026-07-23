# ShopPulse Terraform

Infrastructure for ShopPulse on Azure (multi-stack Terraform under `infra/`).

---

## Task: Provision ShopPulse data layer — result

**Assignment scope:** Terraform for ACR, Key Vault, Redis, PostgreSQL Flexible Server inside an existing RG/VNet — private networking, no hardcoded secrets.  
**Not in scope:** public website, AKS, Application Gateway, deploying `repo/shoppulse` containers.

So it is **expected** that there is **no** browser URL like the old demo `http://4.225.28.41/`. That link was from an earlier study deploy with AKS+App Gateway. This task only provisions the **data / security layer**.

### Checklist vs assignment

| Requirement | Result |
|-------------|--------|
| ACR Premium, admin disabled, public disabled, PE + `privatelink.azurecr.io` | Done |
| Key Vault standard, soft delete + purge protection, public disabled, PE + `privatelink.vaultcore.azure.net`, RBAC | Done |
| Secrets `postgres-password`, `redis-password`, `servicebus-connection-string` via `random_password` | Done |
| Redis private-only + PE | Done via **Azure Managed Redis** (see Redis section — classic Cache for Redis blocked by Microsoft) |
| PostgreSQL 16, `GP_Standard_D2s_v3`, 32768 MB, delegated subnet, DNS zone, DB `shoppulse`, backup 7d / no geo-redundant, password from random → KV | Done |
| No public endpoints / no secrets in tfvars | Done |

### What was verified in Azure (before teardown)

- Resources in `ShopPulse-ResGroup` reached `Succeeded`
- Private endpoints: Key Vault, ACR, Managed Redis
- PostgreSQL on delegated `postgres-subnet` (not PE), database `shoppulse`
- Terraform configs under `infra/security/{acr,keyvault}` and `infra/dbs/{redis,postgresql}`

### What “works” means here

| Layer | Status |
|-------|--------|
| Azure PaaS + networking (this task) | Provisioned successfully (then torn down to save cost — see below) |
| App UI in browser | **Not part of this task** — needs AKS + images + ingress |
| Local app from `repo/shoppulse` | Use `docker compose up --build` → http://localhost:3000 |

---

## Why Redis does not match the original task wording

### What the task asked for

The assignment required **Azure Cache for Redis** with:

- SKU: **Premium**
- Family: **P**, capacity: **1** (P1 — minimum for private endpoints)
- Non-SSL port disabled
- Minimum TLS 1.2
- No public network access
- Private endpoint in the private-endpoints subnet
- Private DNS zone: `privatelink.redis.cache.windows.net` linked to the VNet

Terraform was first written to match that exactly (`Azure/avm-res-cache-redis` → `azurerm_redis_cache` with `sku_name = "Premium"`, `capacity = 1`, family `P` inferred by the module).

### What Azure returned on apply

```text
Error: creating Redis ... unexpected status 400 (400 Bad Request)
BadRequest: Azure Cache for Redis is retiring,
create Azure Managed Redis instance instead.
Learn more: https://aka.ms/AzureCacheForRedisRetirement
```

This is **not** a student-subscription quota error and **not** a Terraform syntax error. Microsoft is retiring Azure Cache for Redis (Basic / Standard / Premium). For **new customers**, creation of new Cache for Redis instances has been **blocked since 1 April 2026**. The platform rejects the create API call and points to the replacement product: **Azure Managed Redis**.

Official overview: [Azure Cache for Redis retirement](https://aka.ms/AzureCacheForRedisRetirement).

### How that conflicts with the task

| Task requirement | Reality (from April 2026) |
|------------------|---------------------------|
| Create Azure Cache for Redis | New creates blocked for new subscriptions/customers |
| Premium + family P + capacity 1 | SKU model of the **retired** product |
| DNS `privatelink.redis.cache.windows.net` | Private Link zone for the **old** Cache for Redis |
| Same AVM module / `azurerm_redis_cache` | Targets the product Azure no longer provisions |

### What we used instead

**Azure Managed Redis** (`azurerm_managed_redis` in `infra/dbs/redis/`):

| Concern | Implementation |
|---------|----------------|
| Product | Azure Managed Redis (successor) |
| SKU | `Balanced_B0` (study cost) |
| HA | Disabled (not supported on B0) |
| Public access | `Disabled` |
| Private endpoint | `pe-subnet`, subresource `redisEnterprise` |
| Private DNS | `privatelink.redis.azure.net` linked to the VNet |
| Client port | **10000** (NSG pe-subnet updated accordingly) |

Security intent kept: cache only reachable privately inside the VNet.

### Other notes from apply

- **Key Vault:** creating secrets from a laptop fails while public access is disabled. Bootstrap temporarily allowed access, wrote the three secrets, then set public access back to disabled.
- **PostgreSQL:** delegated subnet per task (diagram shows PE; assignment overrides).

---

## Stack layout

```text
infra/base              Resource group
infra/network           VNet, subnets (appgw, aks, pe, postgres), NSGs
infra/security/identity Workload user-assigned identity
infra/security/keyvault Key Vault + PE + secrets
infra/security/acr      ACR + PE
infra/dbs/redis         Azure Managed Redis + PE
infra/dbs/postgresql    Flexible Server + delegated subnet
```

Remote-state helpers: `shared/remote_state/` (linked by `scripts/link-env.sh`).  
Shared vars/providers: `env/`.

---

## Apply order (if recreating)

```bash
cd ~/STUDY/terraform
bash scripts/link-env.sh

cd infra/base && terraform apply
cd ../network && terraform apply
cd ../security/identity && terraform apply
cd ../security/keyvault && terraform apply
cd ../security/acr && terraform apply
cd ../../dbs/redis && terraform apply
cd ../postgresql && terraform apply
```

## Teardown / cost

Paid SKUs (Postgres GP, Managed Redis, ACR Premium, etc.) should not be left running on a student subscription.

```bash
az group delete -n ShopPulse-ResGroup --yes --no-wait
```

**Note:** Key Vault has **purge protection**. After RG delete the vault may remain in a soft-deleted state until the retention period ends; it cannot be purged early. That is normal and cheap compared to live Postgres/Redis/ACR.
