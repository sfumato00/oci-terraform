# OCI Terraform — IaC for Personal Gaming & Learning

## Goal
Scaffold IaC for Oracle Cloud Infrastructure (OCI) for personal gaming and learning.

**Hard requirement:** Everything provisioned by default must stay within OCI Always Free limits.

---

## Design Decisions

- Use the tenancy home region only.
- 4 Arm-based Ampere A1 instances, shape `VM.Standard.A1.Flex`.
- 1 OCPU and 6 GB RAM per instance.
- 50 GB boot volume per instance.
- No extra block volumes by default.
- Ubuntu 24.04 Minimal aarch64 (or closest Always Free-eligible aarch64 image).
- No load balancer by default.
- Public instance IPs with tightly scoped NSG ingress rules.

### Free-tier guardrails
- `instance_count <= 4`
- Total A1 OCPUs `<= 4`
- Total A1 memory `<= 24 GB`
- Total boot/block volume storage `<= 200 GB`
- Default: 4 instances × 50 GB = 200 GB total storage.
- No paid images, extra block volumes, NAT gateways, paid LB sizes, non-home-region resources.
- Cost-control variables disable optional resources unless explicitly enabled.
- Compartment quotas and OCI budget/notification alarms where available.

### OCI configuration
- Read credentials from `~/.oci/config`.
- Configurable profile name, defaulting to `DEFAULT`.
- Required user-provided variables:
  - tenancy OCID
  - compartment OCID
  - region
  - availability domain selection strategy
  - SSH public key
  - allowed source CIDRs
  - allowed TCP ports
  - MUD upstream host and port
  - optional MUD upstream CIDRs for restrictive egress rules

### Compute
- 4 `VM.Standard.A1.Flex` instances.
- 1 OCPU, 6 GB memory per instance.
- Hostnames: `mud-proxy-01` through `mud-proxy-04`.
- Stable private IPs: `10.42.0.11` – `10.42.0.14`.
- Spread across ADs when capacity allows; valid in a single-AD region.
- Outputs: public IPs, private IPs, SSH commands, proxy endpoints.

### Storage
- Boot volumes only in the default design (50 GB each).
- No shared block storage (free 200 GB fully consumed by boot volumes).
- Volume backups disabled by default; if enabled, stay within 5 Always Free backup limit.

### Database
- No managed database in the first scaffold.
- Optional future choices: Always Free Autonomous DB, NoSQL, or MySQL HeatWave.

### Network
- One flat VCN, CIDR `10.42.0.0/16`.
- One regional public subnet, `10.42.1.0/24`.
- Internet Gateway with default route `0.0.0.0/0` for the public subnet.
- Ephemeral public IPv4 per instance by default.
- No NAT Gateway, no Load Balancer by default.

### Network Security Groups
- NSGs for all workload access rules.
- SSH ingress from `allowed_source_cidrs` only.
- MUD/proxy port ingress from `allowed_source_cidrs` only.
- Instance-to-instance traffic inside `10.42.0.0/16`.
- Outbound: DNS, HTTP/S, upstream MUD port (restricted by `mud_upstream_cidrs` if set).
- Subnet security lists kept minimal.

### MUD proxy
- Nginx with stream module for TCP proxying (not HTTP).
- Each instance proxies to the same upstream MUD host and port.
- 4 distinct OCI public source IPs, one per instance.

### cloud-init
- `apt-get update/upgrade`.
- Install: `nginx`, `libnginx-mod-stream`, `tintin++` (variable-controlled), `curl`, `tcpdump`, `netcat-openbsd`, `jq`, `unzip`.
- Render Nginx stream config from Terraform variables.
- Enable and restart Nginx.
- No secrets in cloud-init.

### Observability
- OCI instance metrics.
- Alarms: instance availability, high CPU.
- Optional alarm: high network traffic.
- VCN flow logs: off by default, explicit retention controls when enabled.
- OCI Notifications for alarms when email endpoint configured.

### Terraform state
- Native `oci` backend with OCI Object Storage bucket.
- Always Free bucket in home region with state locking.
- Bootstrap sequence:
  1. `terraform -chdir=bootstrap apply` — creates bucket + IAM policy with local state.
  2. Copy `bootstrap/backend.tf.example` → `backend.tf`, fill in bucket name.
  3. `terraform init -migrate-state`.
  4. Apply main stack with remote state.
- Backend config kept in example file (Terraform backends cannot use input variables).

### Security
- No default to `0.0.0.0/0`; `allowed_source_cidrs` is required.
- SSH keys only; password auth disabled.
- SSH ingress separate from MUD/proxy ingress.
- Least-privilege IAM for state bucket access.
- OCI-managed encryption for Object Storage and boot volumes.
- All resources tagged with project and environment labels.
- No secrets in outputs.

### Non-goals (first scaffold)
- No Kubernetes.
- No managed database by default.
- No load balancer by default.
- No shared block volume in the 4-node layout.
- No paid resource dependencies.
- No guarantee of A1 regional capacity (Terraform fails clearly if unavailable).

---

## Implementation Plan

### Phase 1 — Bootstrap State Backend `[x]`
Create the OCI Object Storage bucket and IAM policy for remote Terraform state, using local state.

**Files:**
- `bootstrap/main.tf` — bucket + IAM policy
- `bootstrap/variables.tf`
- `bootstrap/outputs.tf`
- `bootstrap/backend.tf.example` — example `oci` backend block

**Usage:**
```bash
oci session authenticate --region ap-chuncheon-1 --profile-name tlbb
oci session validate --profile tlbb

# OCI CLI commands that use this session profile need --auth security_token.
oci os ns get --profile tlbb --auth security_token

terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply

# Then wire the main stack to use remote state:
terraform -chdir=bootstrap output backend_snippet
# paste into ../backend.tf, then:
terraform init -migrate-state
terraform plan
```

**Testable outcomes:**
- `terraform validate` passes ✓
- `terraform -chdir=bootstrap apply` succeeds with local state
- Bucket visible in OCI Console
- IAM policy grants state read/write for the Terraform identity

---

### Phase 2 — Core Network `[x]`
VCN, subnet, Internet Gateway, route table, minimal security list.

**Files:**
- `main.tf` — provider + backend
- `variables.tf` — tenancy/compartment/region/profile/tags
- `network.tf` — VCN, subnet, IGW, route table
- `nsg.tf` — NSG skeleton (rules wired in Phase 3)

**Testable outcomes:**
- `terraform validate` passes ✓
- `terraform plan` shows only network resources
- `terraform apply` succeeds; VCN, subnet, IGW visible in OCI Console
- No instances or public IPs provisioned

---

### Phase 3 — NSG Rules `[x]`
Populate NSG with all ingress/egress rules driven by input variables.

**Inputs added:**
- `allowed_source_cidrs` (required, no default)
- `allowed_tcp_ports`
- `mud_upstream_host`, `mud_upstream_port`
- `mud_upstream_cidrs` (optional)

**Rules:**
- SSH ingress from `allowed_source_cidrs`
- MUD port ingress from `allowed_source_cidrs`
- Intra-VCN traffic (`10.42.0.0/16`)
- Egress: DNS (53/UDP+TCP), HTTP/S (80/443), upstream MUD port

**Testable outcomes:**
- `terraform validate` passes ✓
- `terraform plan` shows correct NSG rules
- No `0.0.0.0/0` ingress rules
- Plan rejected if `allowed_source_cidrs` is empty

---

### Phase 4 — Compute Instances `[x]`
4 `VM.Standard.A1.Flex` instances with stable private IPs, Ubuntu 24.04 aarch64.

**Files:**
- `compute.tf` — instances, VNIC configs, 50 GB boot volumes, free-tier lifecycle preconditions
- `data.tf` — AD list + Ubuntu 24.04 Minimal aarch64 image lookup (latest, sorted by TIMECREATED DESC)

**Inputs added:**
- `ssh_public_key` (required, sensitive)
- `instance_count` (default 4, validated 1–4)
- `ocpu_per_instance` (default 1)
- `memory_gb_per_instance` (default 6)
- `boot_volume_gb` (default 50)
- `availability_domain_strategy` (`spread` or `single`, default `spread`)

**Private IPs:** `10.42.1.11`–`10.42.1.14` (within subnet `10.42.1.0/24`).

**Free-tier validations (lifecycle preconditions):** total OCPUs ≤ 4, total memory ≤ 24 GB, total storage ≤ 200 GB.

**Testable outcomes:**
- `terraform validate` passes ✓
- Add `ssh_public_key` to tfvars, then `terraform plan` shows 4 instances, 0 extra block volumes, 0 LBs
- `terraform apply` succeeds; SSH reachable from allowed CIDR

**Usage:**
```bash
# Add to terraform.tfvars (or pass as -var):
# ssh_public_key = "ssh-ed25519 AAAA..."
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

### Phase 5 — cloud-init / Nginx Stream Proxy `[ ]`
Bootstrap each instance with Nginx stream TCP proxy to upstream MUD server.

**Files:**
- `templates/cloud-init.yaml.tpl`

**cloud-init steps:**
1. `apt-get update && upgrade`
2. Install `nginx`, `libnginx-mod-stream`, `tintin++` (variable `install_tintin`, default true), `curl`, `tcpdump`, `netcat-openbsd`, `jq`, `unzip`
3. Write Nginx `stream {}` config pointing to `mud_upstream_host:mud_upstream_port`
4. `systemctl enable --now nginx`

**Testable outcomes:**
- `systemctl status nginx` active on instance
- TCP connect to `<public-ip>:<mud-port>` reaches upstream
- `tintin++` binary present (if enabled)

---

### Phase 6 — Observability `[ ]`
OCI Monitoring alarms and optional email notifications.

**Files:**
- `monitoring.tf`

**Resources:**
- Alarm: instance availability
- Alarm: CPU > 80% sustained
- OCI Notification topic + email subscription (behind `alarm_email`, default empty)
- VCN flow logs (behind `enable_flow_logs`, default false)

**Testable outcomes:**
- `alarm_email = ""` → 0 notification resources in plan
- `alarm_email` set → topic + subscription in plan
- Alarms visible in OCI Monitoring after apply

---

### Phase 7 — Outputs, Tags, and Hardening `[ ]`
Clean outputs, resource tagging, security review pass.

**Files:**
- `outputs.tf` — public IPs, private IPs, SSH commands, proxy endpoints

**Tags on all resources:** `project = "tlbb-mud-proxy"`, `environment = var.environment`

**Testable outcomes:**
- `terraform output` shows all 4 public IPs and SSH commands
- No secrets in outputs
- `terraform validate` passes
- All resources tagged correctly in OCI Console

---

### Phase 8 — Docs and tfvars Example `[ ]`
Usable example vars file and usage documentation.

**Files:**
- `terraform.tfvars.example`
- `PLAN.md` updated with phase status, bootstrap sequence, and test evidence

---

## Progress Log

| Phase | Status | Notes |
|-------|--------|-------|
| 1 — Bootstrap State Backend | Complete | `terraform validate` passes; ready to apply |
| 2 — Core Network | Complete | `terraform validate` passes; ready to apply |
| 3 — NSG Rules | Complete | `terraform validate` passes |
| 4 — Compute Instances | Complete | `terraform validate` passes; add `ssh_public_key` to tfvars before apply |
| 5 — cloud-init / Nginx Proxy | Not started | |
| 6 — Observability | Not started | |
| 7 — Outputs, Tags, Hardening | Not started | |
| 8 — Docs and tfvars Example | Not started | |
