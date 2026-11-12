# Secure Azure Landing Zone

A small Azure landing zone I built to reinforce what I learned while preparing for the AZ-104 exam. It has a hub and spoke network, a web server behind a load balancer, storage that can only be reached privately, identity controls, monitoring with alerts and a security posture review. I documented every step so anyone can follow what I did and why.

## The problem

A healthcare company needs an Azure environment that controls who has access, keeps sensitive data off the public internet, watches for unusual activity and lets the team measure its security posture.

## Architecture

![Architecture diagram](docs/architecture.png)

Visitors reach a public load balancer, which sends traffic to the web VM in the web subnet. The web VM talks to storage through a private endpoint in the data subnet. I manage the VM only through Azure Bastion, so no admin ports are open to the internet.

## What I built

| Area | What is in it |
|---|---|
| Network | Hub and spoke virtual networks with peering, and a network security group on each subnet |
| Access | Azure Bastion in the hub. The VM has no public IP |
| Web server | A Windows Server 2022 VM running IIS, behind a Standard load balancer |
| Data | A storage account with public access turned off, a private endpoint and a private DNS zone |
| Identity | Security groups, role assignments at resource group level, a managed identity on the VM, security defaults for MFA and an emergency access account |
| Monitoring | A Log Analytics workspace, the Azure Monitor Agent, KQL alert rules and a Logic App that sends the email |
| Posture | A Defender for Cloud review with four recommendations fixed, taking the Secure Score from 61% to 76% |

## Why I made these choices

- Hub and spoke keeps admin access in one place and keeps workloads separate from it.
- Bastion means I never open RDP to the internet.
- The private endpoint keeps storage off the public internet. Inside the network, the storage name points to a private IP.
- The VM uses a managed identity instead of storage keys, and shared key access is turned off.
- The data subnet only accepts HTTPS from the web subnet and blocks everything else.

The full reasoning and screenshots are in [docs/decisions.md](docs/decisions.md).

## Screenshots

![The web page loading through the load balancer](docs/images/phase3-iis-page-via-public-ip.png)

![The VM resolving the storage name to a private IP](docs/images/phase4-vm-resolves-private-ip.png)

![The managed identity can read but not write](docs/images/phase5-managed-identity-read-ok-write-denied.png)

## Security

- No VM has a public IP.
- Storage has public network access off, anonymous access off and a minimum of TLS 1.2.
- Access goes to groups, with the smallest role that does the job.
- Failed logons, role assignment changes and unauthorised storage requests raise alerts that email me through a Logic App.
- Security defaults require MFA, and the emergency access account keeps its credentials offline.
- Defender for Cloud flagged an outdated OpenSSL bundled with the Azure Monitor Agent. I updated the agent and turned on automatic updates.

## What I would change for production

- Application Gateway with a web application firewall and HTTPS
- Azure Firewall in the hub
- Key Vault for secrets and Azure Policy to enforce standards
- Diagnostic logs on every resource, sent to one workspace, with Microsoft Sentinel on top
- PIM and Conditional Access with MFA
- Zone redundant VMs and separate subscriptions for production and testing
- Terraform or Bicep with a GitHub Actions pipeline, so the whole environment can be rebuilt from code and every change is reviewed and approved first
- Patch windows and at least two VMs behind the load balancer, so patching does not take the site offline

## Limits of this lab

- PIM and Conditional Access need paid Entra ID licences, P2 for PIM and P1 for Conditional Access. My tenant did not have them after the trial ended, so I wrote down how I would set them up but did not build them.
- It uses plain HTTP and one VM to keep the cost down.
- I built everything by hand in the portal, so rebuilding it depends on the steps in docs/decisions.md.

## How to deploy

If you want to build this again, the steps are in docs/decisions.md, the KQL queries are in the queries folder and the web server script is in the scripts folder.

## Cost and clean up

The load balancer, Bastion, VM and private endpoint are billed by the hour. When I am not using them I stop the VM and delete Bastion. To remove everything, delete the resource groups rg-prod and rg-hub.

## About me

David Tshitenda
www.linkedin.com/in/david-tshitenda-75a20a141