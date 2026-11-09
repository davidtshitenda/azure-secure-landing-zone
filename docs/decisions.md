## Phase 1: Remote state storage

- **Decision:** Terraform state lives in a separate storage account with versioning enabled.
- **Why:** State is the source of truth for the environment. A separate account means destroying the lab does not destroy the state, and versioning lets me recover from a bad apply or a corrupted file.
- **Alternative considered:** Local state on my laptop. Rejected because it cannot be shared with a pipeline and is lost if the machine fails.
- **Trade-off:** One extra resource to pay for and protect, which I locked against deletion.

![Blob versioning enabled](images/phase1-blob-versioning-enabled.png)

## Phase 2: Hub and spoke network

- **Decision:** Hub and spoke topology. `vnet-hub` holds Azure Bastion, and `vnet-prod` is the production spoke with `snet-web` and `snet-data`. The two are connected by VNet peering.
- **Why:** The hub centralises access, and the spoke isolates workloads. More spokes can be added later without changing the hub.
- **Alternative considered:** A single flat VNet. Rejected because every workload would share one network boundary and one set of rules.
- **Trade-off:** More resources to manage. Peering is not transitive, so spokes can't talk to each other unless traffic is routed through the hub.

![Hub peering connected](images/phase2-hub-peering-connected.png)

![Spoke peering connected](images/phase2-spoke-peering-connected.png)

![Hub subnet for Bastion](images/phase2-vnet-hub-bastion-subnet.png)

### NSG design

- **Decision:** One NSG per subnet, with default deny inbound. `web-nsg` on `snet-web` allows HTTP from the internet (a Standard load balancer passes client traffic through, so the NSG sees the original client IP) and allows management traffic only from the Bastion subnet.
- **Why:** Least privilege at the subnet boundary, with no management ports exposed to the internet.
- **Alternative considered:** Public IPs on the VMs with RDP or SSH restricted to my own IP. Rejected because it still exposes a management port to the internet.
- **Trade-off:** Rules need maintaining, and a mistake can block legitimate traffic. Each rule has a clear name so it can be audited.
- **Data tier:** `data-nsg` allows HTTPS (443) only from `snet-web`, with an explicit deny-all at priority 4096. Azure's default AllowVnetInBound rule would otherwise permit any traffic from inside the VNet or from the peered hub.
- **Private endpoint policy:** Set to Network security groups on `snet-data`, so NSG rules apply to private endpoint traffic. The default (Disabled) ignores NSGs for private endpoints.
- **Private subnet:** `snet-data` has default outbound access disabled, so nothing in the data tier can initiate connections to the internet.

![web-nsg associated to snet-web](images/phase2-web-nsg-associated-to-snet-web.png)

![Allow HTTP from internet](images/phase2-nsg-allow-http-from-internet.png)

![Allow management from Bastion](images/phase2-nsg-allow-rdp-from-bastion.png)

![data-nsg associated to snet-data](images/phase2-data-nsg-associated-to-snet-data.png)

![Allow HTTPS from snet-web](images/phase2-data-nsg-allow-https-from-snet-web.png)

![Deny all other inbound](images/phase2-data-nsg-deny-all-inbound.png)

![snet-data NSG and private endpoint policy](images/phase2-snet-data-nsg-and-private-endpoint-policy.png)

## Phase 3: Compute, Bastion and load balancer

- **Decision:** A Windows Server web VM (`web-vm`) in `snet-web` with no public IP, behind a Standard public load balancer (`lbe-web-prod`). Administration is only through Azure Bastion.
- **Why:** No public IP or open management port on the VM. The load balancer is the single public entry point and routes only to healthy instances.
- **Alternative considered:** A public IP on the VM with RDP restricted to my own address. Rejected because it still exposes a management port to the internet.
- **Trade-off:** A Standard load balancer and Bastion bill hourly. The load balancer works at layer 4 only, with no WAF or TLS termination, so traffic is plain HTTP in this lab. At production scale I'd use Application Gateway with a WAF and HTTPS.
- **Provisioning:** IIS was installed with Run Command from `scripts/install-iis.ps1`, which needs no outbound internet access. Terraform will run the same script in Phase 8.
- **Troubleshooting note:** The VM was redeployed once, and IIS had to be installed again. Scripting the install avoids that kind of drift.

![IIS page via the load balancer public IP](images/phase3-iis-page-via-public-ip.png)

![Custom IIS page on the VM](images/phase3-iis-custom-page-localhost.png)

![Backend pool](images/phase3-lb-backend-pool.png)

![Load balancing rule](images/phase3-lb-rule-http-80.png)

![Health probe](images/phase3-health-probe-on-port-80.png)

![Health probe status at 100%](images/phase3-lb-health-probe-100.png)

## Phase 4: Storage with private endpoint

- **Decision:** The storage account (`strgprod2026`) has public network access disabled and is reachable only through a blob private endpoint (`pe-snet-data`) in `snet-data`. The `privatelink.blob.core.windows.net` private DNS zone is linked to both VNets.
- **Why:** Data is unreachable from the internet. Inside the network, the storage name resolves to a private IP (`10.1.1.4`) and traffic stays on the Azure backbone.
- **Alternative considered:** A service endpoint with a firewall rule. Rejected because the storage account keeps a public endpoint and the traffic is not addressed privately.
- **Trade-off:** The private endpoint and DNS zone add cost and moving parts. Without the private DNS zone and VNet links, the name would resolve to the public address and access would fail.
- **Verification:** From `web-vm`, DNS resolves through the privatelink CNAME to a private address and TCP 443 succeeds. From my own computer, the name resolves to a public address and access is refused.
- **Hardening:** Anonymous blob access is disabled, secure transfer is required, and the minimum TLS version is 1.2. Shared key access is still enabled and will be disabled in Phase 5 once the managed identity works.

![Private endpoint creation](images/phase4-private-endpoint-create.png)

![Public network access disabled](images/phase4-storage-public-access-disabled.png)

![Private DNS zone links](images/phase4-private-dns-zone-vnet-links.png)

![VM resolves a private IP](images/phase4-vm-resolves-private-ip.png)

![Outside resolves a public IP](images/phase4-outside-resolves-public-ip.png)

![Outside access blocked](images/phase4-outside-access-blocked.png)
