# Module catalogue

- `hub-network`: hub VNet and Azure Firewall/Application Gateway subnets.
- `hub-network/peering`: bidirectional hub/spoke peering configuration.
- `spoke-network`: reusable VNet + workload/private-endpoint subnet.
- `firewall`: Azure Firewall Standard, Firewall Policy, Web-to-App and App-to-SQL flows, HTTPS egress baseline.
- `security`: tier NSGs and subnet NSG associations.
- `security/routes`: default route and explicit inter-spoke UDRs via the Firewall.
- `workload-vms`: private-only example Web and App Linux VMs.
- `application-gateway`: public HTTPS frontend, WAF policy and Web backend.
- `sql-private`: Azure SQL logical server/database, Private Endpoint, Private DNS zone and VNet links.
- `monitoring`: Log Analytics workspace and Firewall diagnostics.

Modules are composed from `environments/prod/main.tf`. Keep environment-specific values in the environment root, and avoid hard-coding secret values in module code.

Before production, fix and test the policy details against the exact AzureRM provider version; module syntax alone is not proof of a valid deployment.