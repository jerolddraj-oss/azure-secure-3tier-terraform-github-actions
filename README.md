# Azure Secure 3-Tier Hub-and-Spoke (Terraform + GitHub Actions)

This is a production-oriented **starter baseline**, not a substitute for a workload-specific security review.

## Design
- Hub VNet `10.0.0.0/16`: Azure Firewall Standard, Application Gateway WAF v2, Log Analytics.
- Web spoke `10.1.0.0/16`, App spoke `10.2.0.0/16`, SQLDB spoke `10.3.0.0/16`.
- No public IPs on workload VMs. Public HTTPS terminates at Application Gateway WAF.
- Spoke default routes and cross-spoke routes point to Azure Firewall.
- Firewall policy allows Web -> App TCP/8080 and App -> SQL private endpoint TCP/1433; Web -> SQLDB is explicitly denied.
- Azure SQL logical server has public network access disabled and a Private Endpoint in the SQLDB spoke.
- NSGs enforce the same tier boundaries as defense in depth.
- GitHub Actions uses Azure OIDC; no client secret is stored in GitHub.

## Important implementation notes
1. The Web and App Linux VMs are demonstration placeholders. The Web VM installs Nginx and the App VM listens on TCP/8080. Replace this bootstrap with your signed application artifact/configuration-management process.
2. The web VM bootstrap currently serves a basic static page; it does not automatically proxy to the App VM. Configure your real web tier to call the App tier using the private App VM IP or internal service discovery.
3. SQL private DNS zone is linked to all three VNets for name resolution. Network controls still prevent Web -> SQLDB.
4. Azure Firewall Standard is used as the NVA. If you use a third-party NVA, replace the firewall resources and route next-hop configuration with that vendor's HA design.
5. Terraform remote state storage must be bootstrapped separately before running the workflow. Never store state in the workload repository.
6. Pin provider and action versions, review plans, and use GitHub environment protection for production. Update versions under your organization's patch policy.
7. This sample uses a single Azure SQL database. For a private SQL Server VM, replace Azure SQL resources with a hardened SQL VM and private-only NIC.
8. Application Gateway and Azure Firewall incur ongoing charges. Review regional availability, SKU limits, quotas, and cost before applying.

## Address plan
| Network | CIDR | Subnets |
|---|---|---|
| Hub | `10.0.0.0/16` | `AzureFirewallSubnet 10.0.0.0/26`, `AppGatewaySubnet 10.0.1.0/24` |
| Web | `10.1.0.0/16` | `web 10.1.1.0/24` |
| App | `10.2.0.0/16` | `app 10.2.1.0/24` |
| SQLDB | `10.3.0.0/16` | `private-endpoints 10.3.1.0/24` |

## Prerequisites
- Azure subscription and permissions to create network, compute, firewall, SQL, and monitoring resources.
- Terraform 1.8+ and Azure CLI for local use.
- GitHub repository variables:
  - `AZURE_CLIENT_ID` — federated identity application/client ID
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `TFSTATE_RESOURCE_GROUP`
  - `TFSTATE_STORAGE_ACCOUNT`
  - `TFSTATE_CONTAINER`
- GitHub environment named `validation` (no approval gate) and `production` (required reviewers) with required reviewers for apply.
- GitHub OIDC federated credential scoped to `repo:ORG/REPO:environment:production` (and a separate `repo:ORG/REPO:pull_request` or branch subject if PR plan is enabled).

## Remote state bootstrap
Create a dedicated state resource group and Storage Account out-of-band, with:
- public network access disabled where compatible with the runner's network path, or restricted to trusted runner egress;
- HTTPS-only, TLS 1.2+, secure transfer, minimum TLS 1.2;
- blob versioning, soft delete, and storage account deletion protection;
- private endpoint if using self-hosted runners in the connected network;
- least-privilege data-plane RBAC for the deployment identity.
The backend block is supplied by `-backend-config` in the workflow.

## Deploy
1. Review and customize `terraform.tfvars.example`.
2. Commit to `main`.
3. Pull requests run format, validate, TFLint and Trivy checks.
4. A push to `main` creates a plan and uploads it as an artifact.
5. The `production` environment approval gate must be configured in GitHub. After approval, apply uses the saved plan.
6. Review Azure Firewall logs, WAF logs, NSG flow/traffic logs where available, SQL auditing, and alerts after deployment.

## Limitations / before production
- Add application-specific inbound and outbound allowlists. The sample Firewall policy includes narrowly scoped tier rules plus HTTPS egress; many workloads need additional destinations.
- The sample requires a real PFX certificate for Application Gateway. For production, store the certificate in Key Vault and configure Application Gateway's managed identity/Key Vault integration rather than passing certificate material through CI variables.
- Add Defender for Cloud, Azure Policy initiatives, alert action groups, backup/DR, patch management, endpoint protection, DDoS Network Protection where justified, and private management access (Bastion/VPN/ExpressRoute).
- The workload VMs are intentionally small example Linux VMs. Adapt OS, images, sizing, availability zones, autoscaling and patching to your actual application.
- Avoid using a static SQL administrator password in real deployments. This sample requires `sql_admin_password` as a sensitive Terraform variable; prefer Microsoft Entra-only SQL authentication and managed identities where the application supports it.
