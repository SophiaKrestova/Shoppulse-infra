# ShopPulse data layer — update notes

Date: 2026-08-03  
Resource group: `ShopPulse-ResGroup`  
Region (main): `swedencentral`  
Subscription: Azure for Students

This note summarizes what was done for the **data / security / messaging** Terraform work on top of the existing ShopPulse AKS study setup, why some decisions differ from the original task wording, and how to verify resources from the CLI.

---

## Goal

Provision a production-leaning Azure data layer for ShopPulse:

- Azure Container Registry (ACR)
- Azure Key Vault
- Azure Cache for Redis (task) / Azure Managed Redis (what Azure allowed)
- Azure Database for PostgreSQL Flexible Server
- Azure Service Bus (Premium + private endpoint)

Existing resource group and VNet were treated as given (referenced via Terraform remote state from `infra/base` and `infra/network`).

---

## What changed in code

### Network (`terraform/infra/network`)

- Added dedicated `postgres-subnet` (`10.0.10.0/24`) with delegation  
  `Microsoft.DBforPostgreSQL/flexibleServers`  
  (Flexible Server uses VNet integration, not a private endpoint.)

### ACR (`terraform/infra/security/acr`)

- Premium SKU
- Admin disabled
- Public network access disabled
- Private endpoint + DNS `privatelink.azurecr.io`
- Registry renamed to **`shoppulseskacr01`** because `shoppulseacr` DNS name was globally taken

### Key Vault (`terraform/infra/security/keyvault`)

- SKU standard, soft delete, purge protection
- RBAC (not access policies)
- Private endpoint + DNS `privatelink.vaultcore.azure.net`
- Secrets generated with `random_password`:
  - `postgres-password`
  - `redis-password`
- `servicebus-connection-string` is written by the Service Bus stack (real connection string, not a random placeholder)
- Vault name: **`shoppulseskkv01`** (previous `shoppulsekv01` was soft-deleted with purge protection)
- For laptop Terraform apply, public network access / firewall had to be opened temporarily; PE still present

### PostgreSQL (`terraform/infra/dbs/postgresql`)

- Version 16, SKU `GP_Standard_D2s_v3`, storage 32768 MB
- Delegated subnet + private DNS `privatelink.postgres.database.azure.com`
- Admin password from Key Vault secret `postgres-password` (generated via `random_password`)
- Database `shoppulse`
- Backup retention 7 days, geo-redundant backup disabled
- No private endpoint for Postgres (VNet injection only)

### Redis (`terraform/infra/dbs/redis`)

**Important platform constraint**

- Creating classic **Azure Cache for Redis** (`azurerm_redis_cache`, Premium P1) failed: Azure requires **Azure Managed Redis** instead (retirement of Cache for Redis on this subscription).
- Creating Managed Redis in **`swedencentral`** failed with **`InsufficientCapacity`**.
- Students policy allows only: `spaincentral`, `norwayeast`, `swedencentral`, `uaenorth`, `italynorth`.

**What was deployed instead**

- Azure Managed Redis (`azurerm_managed_redis`), SKU `Balanced_B0`
- Location: **`norwayeast`**
- Public network access disabled
- Private endpoint in the ShopPulse `pe-subnet` (swedencentral) + DNS `privatelink.redis.azure.net`

So Redis is live and private-linkable, but it is **not** the classic Premium family `P` capacity `1` from the written task — that combination was blocked by Azure.

### Service Bus (`terraform/infra/dbs/servicebus`)

- Premium, capacity 1 (required for private endpoints)
- Public network access disabled
- Private endpoint + DNS `privatelink.servicebus.windows.net`
- Queue `sales-events`
- Primary connection string stored in Key Vault as `servicebus-connection-string`

### AKS / k8s wiring (partial)

- AKS + App Gateway ingress already in stack; cluster provisioned successfully
- k8s image refs updated to `shoppulseskacr01.azurecr.io`
- kustomization fixed; worker included; emulator wait-container removed from worker
- **Not finished tonight:** push app images, switch app fully from in-cluster deps to Azure PaaS, prove Service Bus E2E from api/worker

---

## How to raise (for a teammate / fresh laptop)

Assumes WSL, `az login`, Terraform, Docker, `kubectl` (`az aks install-cli`).

Repo helpers (only these two under `terraform/scripts/`):

- `link-env.sh` — symlinks `env/*.tfvars` + remote-state stubs into each stack
- `tf.sh <stack> plan|apply` — runs Terraform inside `infra/<stack>`

### 1. Config

```bash
cd ~/STUDY/terraform/env
cp common.tfvars.example common.tfvars
cp acr.tfvars.example acr.tfvars
cp keyvault.tfvars.example keyvault.tfvars
cp postgresql.tfvars.example postgresql.tfvars
cp redis.tfvars.example redis.tfvars
cp servicebus.tfvars.example servicebus.tfvars
# fill common + names (ACR: shoppulseskacr01, KV: shoppulseskkv01, etc.)
# real *.tfvars are gitignored — never commit them

cp ~/STUDY/k8s/secret.yaml.example ~/STUDY/k8s/secret.yaml
```

```bash
cd ~/STUDY/terraform
bash scripts/link-env.sh
```

### 2. Terraform apply order

```bash
cd ~/STUDY/terraform

bash scripts/tf.sh base init
bash scripts/tf.sh base apply

bash scripts/tf.sh network init
bash scripts/tf.sh network apply

bash scripts/tf.sh security/identity init
bash scripts/tf.sh security/identity apply

bash scripts/tf.sh security/acr init
bash scripts/tf.sh security/acr apply

bash scripts/tf.sh security/keyvault init
bash scripts/tf.sh security/keyvault apply
# If secret writes fail with ForbiddenByFirewall: temporarily allow public
# access / your IP on the vault, apply again, then tighten if required.

bash scripts/tf.sh dbs/postgresql init
bash scripts/tf.sh dbs/postgresql apply

bash scripts/tf.sh dbs/servicebus init
bash scripts/tf.sh dbs/servicebus apply

bash scripts/tf.sh aks init
bash scripts/tf.sh aks apply
# App Gateway / AGIC often takes 10–20 minutes on first create

bash scripts/tf.sh dbs/redis init
bash scripts/tf.sh dbs/redis apply
# Managed Redis in norwayeast — see Redis section above for why
```

Same order without `tf.sh`:

```bash
cd infra/<stack> && terraform init && terraform apply
```

### 3. Images → ACR (ACR is private by default)

```bash
az acr update -n shoppulseskacr01 --public-network-enabled true
az acr login -n shoppulseskacr01

cd ~/STUDY/repo/shoppulse
docker build -t shoppulseskacr01.azurecr.io/api:latest ./api
docker build -t shoppulseskacr01.azurecr.io/worker:latest ./worker
docker build --build-arg VITE_API_BASE_URL= -t shoppulseskacr01.azurecr.io/front-end:latest ./frontend
docker push shoppulseskacr01.azurecr.io/api:latest
docker push shoppulseskacr01.azurecr.io/worker:latest
docker push shoppulseskacr01.azurecr.io/front-end:latest
```

`az acr build` is blocked on Azure for Students (`TasksOperationsNotAllowed`).

### 4. Kubernetes

```bash
az aks get-credentials -g ShopPulse-ResGroup -n shoppulse-aks
kubectl apply -k ~/STUDY/k8s/
```

If Ingress `ADDRESS` stays empty while App Gateway is Running:

```bash
kubectl annotate ingress shoppulse -n shoppulse \
  appgw.ingress.azure.io/force-sync=true --overwrite
kubectl get ingress shoppulse -n shoppulse
```

### 5. Sanity checks

```bash
az resource list -g ShopPulse-ResGroup -o table
kubectl get nodes
kubectl get pods -n shoppulse
curl -s http://<APPGW_IP>/api/events
```

Open `http://<APPGW_IP>/` → Submit Event → Dashboard.

**Note:** full switch from in-cluster Postgres/Redis/SB emulator to Azure PaaS + worker E2E is still leftover (see below). Infra stacks above are what was raised and verified.

---

## Current status (honest)

| Area | Status |
|------|--------|
| ACR / Key Vault / Postgres / Service Bus / AKS | Deployed and healthy |
| Redis | Deployed as **Managed Redis** in norwayeast (not classic Premium P1) |
| App E2E on AKS using Azure SB/Postgres/Redis | **Not completed** — infra ready, app wiring left for later |
| Service Bus broker | **Active** (namespace + queue). App publish/consume still TODO |

---

## How to verify from CLI

```bash
az resource list -g ShopPulse-ResGroup -o table

az aks show -g ShopPulse-ResGroup -n shoppulse-aks -o table
az postgres flexible-server show -g ShopPulse-ResGroup -n shoppulse-pgsql -o table
az acr show -g ShopPulse-ResGroup -n shoppulseskacr01 -o table
az servicebus namespace show -g ShopPulse-ResGroup -n shoppulse-messaging -o table
az keyvault secret list --vault-name shoppulseskkv01 -o table

az resource show \
  --ids /subscriptions/305786b3-cf30-4c72-808e-ae6bbd7d649f/resourceGroups/ShopPulse-ResGroup/providers/Microsoft.Cache/redisEnterprise/shoppulse-redis \
  -o table
```

---

## Verification logs (2026-08-03)

### `az resource list -g ShopPulse-ResGroup -o table`

```text
Name                                                              ResourceGroup       Location       Type                                                   Status
----------------------------------------------------------------  ------------------  -------------  -----------------------------------------------------  ---------
ShopPulse-VNetwork                                                ShopPulse-ResGroup  swedencentral  Microsoft.Network/virtualNetworks                      Succeeded
shoppulse-appgw-nsg                                               ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkSecurityGroups                Succeeded
shoppulse-aks-nsg                                                 ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkSecurityGroups                Succeeded
shoppulse-pe-nsg                                                  ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkSecurityGroups                Succeeded
shoppulse-workload                                                ShopPulse-ResGroup  swedencentral  Microsoft.ManagedIdentity/userAssignedIdentities       Succeeded
shoppulseskacr01                                                  ShopPulse-ResGroup  swedencentral  Microsoft.ContainerRegistry/registries                 Succeeded
privatelink.azurecr.io                                            ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones                      Succeeded
privatelink.azurecr.io/shoppulse-acr-dns-link                     ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones/virtualNetworkLinks  Succeeded
pe-shoppulseskacr01                                               ShopPulse-ResGroup  swedencentral  Microsoft.Network/privateEndpoints                     Succeeded
pe-shoppulseskacr01.nic.a48efe0f-10ae-4b18-a2a8-ad546b520f22      ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkInterfaces                    Succeeded
privatelink.vaultcore.azure.net                                   ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones                      Succeeded
shoppulseskkv01                                                   ShopPulse-ResGroup  swedencentral  Microsoft.KeyVault/vaults                              Succeeded
privatelink.vaultcore.azure.net/shoppulse-kv-dns-link             ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones/virtualNetworkLinks  Succeeded
pe-shoppulseskkv01                                                ShopPulse-ResGroup  swedencentral  Microsoft.Network/privateEndpoints                     Succeeded
pe-shoppulseskkv01.nic.73af8a61-ec49-4fec-a055-837d2cdc3057       ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkInterfaces                    Succeeded
shoppulse-messaging                                               ShopPulse-ResGroup  swedencentral  Microsoft.ServiceBus/namespaces                        Succeeded
privatelink.servicebus.windows.net                                ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones                      Succeeded
privatelink.servicebus.windows.net/shoppulse-sb-dns-link          ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones/virtualNetworkLinks  Succeeded
pep-shoppulse-messaging                                           ShopPulse-ResGroup  swedencentral  Microsoft.Network/privateEndpoints                     Succeeded
pep-shoppulse-messaging.nic.e676725e-7e3d-4440-8bbf-344910617523  ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkInterfaces                    Succeeded
shoppulse-aks                                                     ShopPulse-ResGroup  swedencentral  Microsoft.ContainerService/managedClusters             Succeeded
privatelink.postgres.database.azure.com                           ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones                      Succeeded
privatelink.postgres.database.azure.com/shoppulse-pgsql-dns-link  ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones/virtualNetworkLinks  Succeeded
shoppulse-pgsql                                                   ShopPulse-ResGroup  swedencentral  Microsoft.DBforPostgreSQL/flexibleServers              Succeeded
shoppulse-redis                                                   ShopPulse-ResGroup  norwayeast     Microsoft.Cache/redisEnterprise                        Succeeded
privatelink.redis.azure.net                                       ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones                      Succeeded
privatelink.redis.azure.net/shoppulse-redis-dns-link              ShopPulse-ResGroup  global         Microsoft.Network/privateDnsZones/virtualNetworkLinks  Succeeded
pe-shoppulse-redis                                                ShopPulse-ResGroup  swedencentral  Microsoft.Network/privateEndpoints                     Succeeded
pe-shoppulse-redis.nic.66a916ca-46f5-42c0-8344-49f1789b5230       ShopPulse-ResGroup  swedencentral  Microsoft.Network/networkInterfaces                    Succeeded
```

### AKS

```text
Name           Location       ResourceGroup       KubernetesVersion    CurrentKubernetesVersion    ProvisioningState    Fqdn
-------------  -------------  ------------------  -------------------  --------------------------  -------------------  --------------------------------------------------
shoppulse-aks  swedencentral  ShopPulse-ResGroup  1.35                 1.35.6                      Succeeded            shoppulse-aks-0jnn6jix.hcp.swedencentral.azmk8s.io
```

### PostgreSQL Flexible Server

```text
AdministratorLogin    AvailabilityZone    FullyQualifiedDomainName                     Location        MinorVersion    Name             ReplicaCapacity    ReplicationRole    ResourceGroup       State    Version
--------------------  ------------------  -------------------------------------------  --------------  --------------  ---------------  -----------------  -----------------  ------------------  -------  ---------
psqladmin             1                   shoppulse-pgsql.postgres.database.azure.com  Sweden Central  14              shoppulse-pgsql  5                  Primary            ShopPulse-ResGroup  Ready    16
```

### ACR

```text
NAME              RESOURCE GROUP      LOCATION       SKU      LOGIN SERVER                 CREATION DATE         ADMIN ENABLED
----------------  ------------------  -------------  -------  ---------------------------  --------------------  ---------------
shoppulseskacr01  ShopPulse-ResGroup  swedencentral  Premium  shoppulseskacr01.azurecr.io  2026-08-03T18:12:18Z  False
```

### Service Bus

```text
CreatedAt                     DisableLocalAuth    Location       MetricId                                                  MinimumTlsVersion    Name                 PremiumMessagingPartitions    ProvisioningState    PublicNetworkAccess    ResourceGroup       ServiceBusEndpoint                                       Status    UpdatedAt                     ZoneRedundant
----------------------------  ------------------  -------------  --------------------------------------------------------  -------------------  -------------------  ----------------------------  -------------------  ---------------------  ------------------  -------------------------------------------------------  --------  ----------------------------  ---------------
2026-08-03T18:19:23.5320256Z  False               swedencentral  305786b3-cf30-4c72-808e-ae6bbd7d649f:shoppulse-messaging  1.2                  shoppulse-messaging  1                             Succeeded            Disabled               ShopPulse-ResGroup  https://shoppulse-messaging.servicebus.windows.net:443/  Active    2026-08-03T18:19:23.5320256Z  True
```

### Key Vault secrets

```text
Name                          Id                                                                            ContentType    Enabled    Expires
----------------------------  ----------------------------------------------------------------------------  -------------  ---------  ---------
postgres-password             https://shoppulseskkv01.vault.azure.net/secrets/postgres-password                            True
redis-password                https://shoppulseskkv01.vault.azure.net/secrets/redis-password                               True
servicebus-connection-string  https://shoppulseskkv01.vault.azure.net/secrets/servicebus-connection-string                 True
```

### Redis (Managed)

```text
Kind    Location     Name             ResourceGroup
------  -----------  ---------------  ------------------
v2      Norway East  shoppulse-redis  ShopPulse-ResGroup
```

---

## Tomorrow / leftover for full app readiness

1. Put Azure Service Bus connection string into `k8s/secret.yaml`
2. Remove Service Bus emulator from k8s deps
3. Build/push images to `shoppulseskacr01` (ACR is private — may need temporary public access or in-VNet build)
4. `kubectl apply -k k8s/` and test POST event → queue → worker

---

## Cost / cleanup note

This stack includes Premium ACR, Premium Service Bus, GP Postgres, Managed Redis, and AKS. Delete the resource group when finished to avoid Students-subscription burn:

```bash
az group delete -n ShopPulse-ResGroup --yes
```
