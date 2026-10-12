# Security rule matrix

| Flow | Expected | Enforcement |
|---|---|---|
| Internet -> Web | Allow HTTPS only to Application Gateway WAF | Public IP/listener and WAF |
| Internet -> Web VM | Deny | No public IP; Web NSG allows only App Gateway subnet |
| Internet -> App VM | Deny | No public IP; App NSG allows Web tier only |
| Web -> App TCP/8080 | Allow | UDR through Firewall, Firewall network rule, App NSG |
| App -> SQL TCP/1433 | Allow | UDR through Firewall, Firewall network rule, SQL NSG |
| Web -> SQLDB | Deny | No Firewall allow rule; SQL NSG explicit deny |
| Spoke -> Internet TCP/443 | Allow through Firewall | UDR + Firewall application rule |
| Spoke -> Internet other ports | Deny by default | Firewall policy default deny |
| SQL public endpoint | Disabled | Azure SQL public_network_access_enabled=false |
| Management SSH from Internet | Deny | No public IPs; use Bastion/VPN/private admin path |

## Important caveat
The sample uses an Azure Firewall application rule allowing HTTPS to arbitrary FQDNs as a generic baseline. Production environments should replace this with an approved FQDN allowlist and review Azure Firewall DNS proxy behavior. Do not assume NSGs alone provide application-layer controls.
