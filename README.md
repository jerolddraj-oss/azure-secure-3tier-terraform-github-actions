# Azure Secure 3-Tier Hub-and-Spoke — Terraform Modules

This repository deploys a hub with Azure Firewall and Application Gateway WAF, plus Web, App and SQLDB spokes. It is a modularized starter: test in a sandbox and review plans before production.

## Repository structure
```
.
├── environments/prod/        # root deployment composition + inputs + backend example
├── modules/
│   ├── hub-network/           # hub VNet and reserved subnets
│   │   └── peering/           # six hub/spoke peering links
│   ├── spoke-network/         # reusable VNet/subnet module
│   ├── firewall/              # Azure Firewall, policy and tier rules
│   ├── security/
│   │   └── routes/            # UDRs and subnet associations
│   ├── workload-vms/          # example private Web and App Linux VMs
│   ├── application-gateway/   # public HTTPS entry and WAF policy
│   ├── sql-private/           # Azure SQL, Private Endpoint and DNS
│   └── monitoring/            # Log Analytics and Firewall diagnostics
├── .github/workflows/terraform.yml
├── .tflint.hcl
├── SECURITY_RULES.md
└── README.md
```

## Architecture and controls
- Hub: `10.0.0.0/16`; Azure Firewall subnet `10.0.0.0/26`; Application Gateway subnet `10.0.1.0/24`.
- Web spoke: `10.1.0.0/16`; subnet `10.1.1.0/24`.
- App spoke: `10.2.0.0/16`; subnet `10.2.1.0/24`.
- SQLDB spoke: `10.3.0.0/16`; Private Endpoint subnet `10.3.1.0/24`.
- Public HTTPS enters through Application Gateway WAF. Workload VMs do not have public IPs.
- UDRs send Internet and inter-spoke flows to Azure Firewall.
- Intended allow flows: Web -> App TCP/8080 and App -> SQL private endpoint TCP/1433. Web -> SQLDB is denied.
- Azure SQL public network access is disabled and a private endpoint is created.

## Use the modular root
Run Terraform from `environments/prod`, not the repository root:
```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan
```
First provision the remote-state Storage Account and create a private or suitably restricted access path for the CI runner. Copy and customize `backend.hcl.example` as `backend.hcl`. Never commit real secrets or Terraform state.

## GitHub Actions setup
Repository/environment variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`.

Secrets: `SSH_PUBLIC_KEY`, `SQL_ADMIN_PASSWORD`, `TLS_CERTIFICATE_PFX_BASE64`, `TLS_CERTIFICATE_PASSWORD`.

The workflow uses Azure OIDC, runs format/validate/TFLint/Trivy checks, generates a Terraform plan and gates production apply with the GitHub `production` environment. Verify the OIDC federated credential subject and required reviewers before enabling production deployments.

## Before production
This modular starter has not been applied to a live subscription. Review current provider schemas, Azure Firewall stateful routing/return paths, NSG behavior on Private Endpoint subnets, DNS resolution, App Gateway certificate deployment and regional service availability. Replace broad HTTPS egress wildcard with approved destination FQDN allowlists. Prefer Key Vault + managed identity for certificates and Microsoft Entra-only SQL authentication. The demo VMs and app bootstraps must be replaced with your actual app artifacts and patching strategy.