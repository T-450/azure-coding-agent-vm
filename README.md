# Azure Coding Agent VM -- Terraform

Provisions an Azure Linux VM (Standard_B2ms) pre-configured with Docker sandboxes, OpenCode, Pi Coding Agent, and Hermes Agent. Accessible through corporate VPN + VS Code Remote SSH.

## Architecture

```
  Your Machine                Azure
  ┌──────────┐    VPN     ┌──────────────────────┐
  │ VS Code  │─── SSH ───▶│  vm-coding-agent      │
  │ Remote   │            │  (B2ms, 8GB RAM)      │
  │ SSH      │            │  Ubuntu 22.04 LTS     │
  └──────────┘            │                      │
                          │  ┌────────────────┐  │
                          │  │ Docker Sandbox  │  │
                          │  │  coding-agent   │──▶ Anthropic / OpenAI / OpenRouter API
                          │  │  (isolated)     │  │
                          │  │  OpenCode       │  │
                          │  │  Pi Agent       │  │
                          │  └────────────────┘  │
                          │                      │
                          │  ┌────────────────┐  │
                          │  │ Hermes Agent    │  │──▶ Provider of your choice
                          │  │ (Docker backend)│  │
                          │  └────────────────┘  │
                          └──────────────────────┘
```

## What gets installed

| Tool | Install method | Notes |
|------|---------------|-------|
| **Docker** | apt (docker.io) | Sandboxed agent execution |
| **OpenCode** | `npm i -g opencode-ai` | Open-source coding agent CLI |
| **Pi Coding Agent** | `npm i -g @earendil-works/pi-coding-agent` | Minimal coding agent harness |
| **Hermes Agent** | Official install.sh | Multi-platform AI agent framework |
| **code-server** | code-server.dev | VS Code in browser (optional) |
| **tmux** | apt | Persistent terminal sessions |
| **UFW + fail2ban** | apt | Firewall + brute-force protection |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) logged in (`az login`)
- An SSH key pair (`ssh-keygen -t ed25519`)
- API keys for your desired LLM providers (set on the VM post-deploy)

## Corporate Network Considerations

Your network uses an active firewall cluster with Deep Packet Inspection (DPI) and SSL/TLS decryption. HTTPS traffic to/from the VM is re-encrypted with a corporate CA certificate (`MU-prisma-ssldecryptca.volvo.net` / `got-fw-subca.volvo.net`). This affects how the VM connects to the internet and how you access it.

### Access: Private IP Only (No Public IP Needed)

The VM is accessed through your corporate VPN -- no public IP required.

```hcl
# In terraform.tfvars
create_public_ip = false    # default, access over VPN
```

Your corporate VPN routes traffic into the Azure VNet. The VM gets a private IP that you reach directly from your corporate network. The NSG only allows SSH from your corporate IP range.

### Corporate CA Certificate

Without the corporate CA installed, every HTTPS request on the VM will fail:

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

**Export the CA from your Windows machine:**

```powershell
# Option 1: certmgr.msc GUI
#   Win+R → certmgr.msc
#   Navigate to: Trusted Root Certification Authorities → Certificates
#   Find "MU-prisma-ssldecryptca.volvo.net" or "got-fw-subca.volvo.net"
#   Right-click → All Tasks → Export
#   Format: Base-64 encoded X.509 (.cer)
#   Save as corporate-ca.cer

# Option 2: PowerShell
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match "volvo.net" }
$cert | Export-Certificate -FilePath "$env:USERPROFILE\corporate-ca.cer" -Type CERT
```

**Install on the VM:**

```bash
# SCP the cert to the VM (over VPN)
scp corporate-ca.cer agent@<vm-private-ip>:/tmp/corporate-ca.crt

# SSH in and install
ssh agent@<vm-private-ip>
sudo cp /tmp/corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
sudo update-ca-certificates

# Verify it works
curl -s https://ifconfig.me
```

### Corporate Proxy (if required)

If your VPN routes internet traffic through a corporate HTTP proxy, uncomment the proxy configuration in `cloud-init.yaml` (search for "proxy.volvo.net") and fill in the actual proxy address. Then re-deploy or apply manually:

```bash
export HTTP_PROXY="http://proxy.volvo.net:8080"
export HTTPS_PROXY="http://proxy.volvo.net:8080"
export NO_PROXY="localhost,127.0.0.1,.azure.com,.volvo.net"
```

Docker also needs the proxy -- the docker-compose and Hermes Docker backend in the cloud-init have commented proxy blocks for this.

## VPN Egress IP Discovery (WSL 2 / Windows)

Before deploying, you need to know the public IP your VPN traffic egresses from. This is the IP you put in `ssh_allowed_ip`.

### WSL 2

```bash
# From inside WSL 2, the VPN tunnel is on the Windows host.
# Run this from PowerShell (Windows host):
#   curl ifconfig.me

# Or from WSL, force traffic through the Windows host's connection:
curl -s https://ifconfig.me

# If the VPN routes all traffic, this shows your VPN egress IP.
# If the VPN only routes Azure traffic (split tunnel), verify by
# curling through the VPN interface specifically:
curl -s --interface eth0 https://ifconfig.me 2>/dev/null || curl -s https://ifconfig.me
```

### PowerShell (Windows)

```powershell
# Get your public IP (this is your VPN egress IP if VPN is connected)
(Invoke-WebRequest https://ifconfig.me).Content.Trim()

# Alternative endpoints:
#   https://api.ipify.org
#   https://icanhazip.com
#   https://checkip.amazonaws.com

# To find the network interface the VPN is using:
Get-NetIPConfiguration | Where-Object { $_.InterfaceDescription -match "VPN|Tunnel|WireGuard|OpenVPN" }
```

### Verify the IP works

```bash
# After applying Terraform, confirm you can reach the VM:
ssh agent@$(terraform output -raw vm_public_ip)

# If it hangs or times out, your egress IP is different from ssh_allowed_ip.
# Check with:
curl -s https://ifconfig.me
# Then update ssh_allowed_ip in terraform.tfvars and re-apply.
```

```bash
# 1. Clone or copy this directory
cd terraform-azure-coding-agent-vm

# 2. Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars -- at minimum set:
#   ssh_allowed_ip = "YOUR_VPN_IP/32"

# 3. Initialize Terraform
terraform init

# 4. Review the plan
terraform plan

# 5. Deploy
terraform apply -auto-approve

# 6. Connect via SSH
ssh agent@$(terraform output -raw vm_public_ip)

# Or use the VS Code output
terraform output vscode_ssh_command
```

## VS Code Remote SSH Setup

Add the SSH host from `terraform output vscode_ssh_command` to your `~/.ssh/config`:

```
Host coding-agent
    HostName <ip-address>
    User agent
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
```

Then in VS Code: **Ctrl+Shift+P** → **Remote-SSH: Connect to Host** → `coding-agent`.

## API Keys

The cloud-init template **does not** set API keys. Set these on first SSH:

```bash
# Agent-specific env vars in ~/.bashrc
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.bashrc
echo 'export OPENROUTER_API_KEY="sk-or-..."' >> ~/.bashrc
source ~/.bashrc

# Hermes config
hermes config set model.default anthropic/claude-sonnet-4
hermes config set model.provider openrouter
```

Or use `~/.hermes/.env` for Hermes-specific keys.

## Docker Sandbox

The coding agents run inside isolated Docker containers, not directly on the host:

```bash
# Interactive shell in sandbox
~/bin/agent-shell my-project

# Run OpenCode inside sandbox
~/bin/run-opencode my-project "Refactor the auth module"

# Run Pi inside sandbox
~/bin/run-pi my-project "Add unit tests for the API"

# Hermes uses Docker backend natively (configured in ~/.hermes/config.yaml)
hermes chat -q "Fix the CI pipeline"
```

The sandbox Dockerfile is at `~/docker/sandbox-coding-agent.Dockerfile`. It:
- Drops all Linux capabilities except essential ones
- Uses `no-new-privileges` security opt
- Mounts only the project directory
- Has no network restrictions (agents need API access)

## Security

- SSH key-only authentication (passwords disabled)
- Root login prohibited
- UFW firewall (SSH only, locked to your IP)
- fail2ban for brute-force protection
- Docker sandboxes with dropped capabilities
- VM has SystemAssigned Managed Identity
- NSG deny-all rule as default

## Cost Estimate

| Resource | SKU | Est. Monthly |
|----------|-----|-------------|
| VM | Standard_B2ms (2 vCPU, 8GB) | ~$46 |
| OS Disk | Premium_LRS 64GB | ~$10 |
| Data Disk | StandardSSD_LRS 32GB (optional) | ~$3 |
| Public IP | Standard Static | ~$3 |
| **Total** | | **~$62** |

Costs reduce ~40% with 1-year reserved instances (~$37 total).

## Variables

See [variables.tf](variables.tf) for all options. Key ones:

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `eastus` | Azure region |
| `vm_size` | `Standard_B2ms` | VM SKU |
| `create_public_ip` | `true` | Set `false` for VPN-only access |
| `ssh_allowed_ip` | `0.0.0.0/0` | Lock to your VPN egress IP |
| `disk_size_gb` | `64` | OS disk size |
| `docker_disk_size_gb` | `32` | Extra disk for Docker data |

## Resources

- https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-terraform
- https://learn.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment
- https://developer.hashicorp.com/terraform/tutorials/provision/cloud-init
- https://opencode.ai/docs/
- https://pi.dev/docs/latest/quickstart
- https://hermes-agent.nousresearch.com/docs/
