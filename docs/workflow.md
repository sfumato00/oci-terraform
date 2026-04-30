# OCI Terraform Workflow

This runbook covers the normal OCI Terraform workflow and the teardown path to
use when state is stale or partially corrupted.

## 1. Refresh OCI Session

The provider and OCI backend use the `tlbb` profile with security-token
authentication.

```bash
oci session authenticate --region ap-chuncheon-1 --profile-name tlbb
oci session validate --profile tlbb
```

OCI CLI calls with this profile also need `--auth security_token`:

```bash
oci os ns get --profile tlbb --auth security_token
```

## 2. Check `terraform.tfvars`

Before planning, confirm that `terraform.tfvars` contains the required root
variables:

- `tenancy_ocid`
- `compartment_ocid`
- `region`
- `oci_config_profile`
- `oci_auth = "SecurityToken"`
- `allowed_source_cidrs`
- `nginx_reverse_proxies`
- `ssh_public_key`

Each `nginx_reverse_proxies` entry must include:

- `listen_port`
- `upstream_host`
- `upstream_ip`
- `upstream_port`

The stack currently uses these Always Free compute defaults:

- `instance_count = 4`
- `ocpu_per_instance = 1`
- `memory_gb_per_instance = 6`
- `boot_volume_gb = 50`
- `availability_domain_strategy = "spread"`

If the workstation public IP changed, get the current IP:

```bash
curl -fsS https://ifconfig.me/ip
```

Then update `allowed_source_cidrs` in `terraform.tfvars`:

```hcl
allowed_source_cidrs = ["<ip>/32"]
```

## 3. Bootstrap Remote State

Run this only when the OCI Object Storage state bucket and IAM policy do not
exist yet.

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt -check -diff
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
```

After bootstrap, print the backend snippet:

```bash
terraform -chdir=bootstrap output backend_snippet
```

## 4. Confirm Backend Configuration

Confirm `backend.tf` contains the bootstrap output values.

Current expected backend values:

- `auth = "SecurityToken"`
- `config_file_profile = "tlbb"`
- `region = "ap-chuncheon-1"`
- `namespace = "axg4yq5nfjj2"`
- `bucket = "tlbb-terraform-state"`
- `key = "terraform.tfstate"`

## 5. Initialize Root Stack

Initialize the root stack or migrate local state to the OCI backend:

```bash
terraform init -migrate-state
```

If backend config did not change, this is enough:

```bash
terraform init
```

## 6. Validate And Plan

Run format, validation, and plan checks from the repository root:

```bash
terraform fmt -check -diff
terraform validate
terraform plan -var-file=terraform.tfvars
```

Before applying, confirm these guardrails:

- NSG ingress does not include unrestricted SSH or proxy access.
- Total A1 OCPUs are `<= 4`.
- Total A1 memory is `<= 24 GB`.
- Total boot volume storage is `<= 200 GB`.

## 7. Apply

After reviewing the plan, apply the root stack:

```bash
terraform apply -var-file=terraform.tfvars
```

## 8. Shortcut

```bash
terraform init -migrate-state
terraform fmt -check -diff
terraform validate
terraform plan -var-file=terraform.tfvars -out tfplan.bin
terraform apply "tfplan.bin"
```

## 8. Graceful Destroy

Use a saved destroy plan so the apply matches the reviewed plan exactly.

```bash
mkdir -p state-backups
terraform state pull > "state-backups/root-$(date +%Y%m%d-%H%M%S).tfstate.json"

terraform init
terraform fmt -check -diff
terraform validate
terraform plan -destroy -var-file=terraform.tfvars -out=destroy.tfplan
terraform apply -input=false destroy.tfplan
rm -f destroy.tfplan
```

Verify the root stack is empty:

```bash
terraform state list
terraform plan -destroy -var-file=terraform.tfvars -detailed-exitcode
```

Expected result:

- `terraform state list` prints no managed resources.
- The destroy plan exits `0` and reports `No changes. No objects need to be destroyed.`

This only destroys the root stack resources. It does not destroy the bootstrap
state bucket or IAM policy.

## 9. State Repair During Destroy

If `terraform plan -destroy` shows the same OCI ID under more than one Terraform
address, repair state before applying. Do not delete the real OCI object twice.

Inspect the suspicious addresses:

```bash
terraform state show '<address-1>'
terraform state show '<address-2>'
```

If both addresses point to the same `id`, keep the address that matches the
current configuration and remove only the stale duplicate address from state:

```bash
terraform state rm '<stale-duplicate-address>'
```

Then save another backup and re-run the destroy plan:

```bash
terraform state pull > "state-backups/root-$(date +%Y%m%d-%H%M%S)-after-state-rm.tfstate.json"
terraform plan -destroy -var-file=terraform.tfvars -out=destroy.tfplan
terraform apply -input=false destroy.tfplan
```

For the duplicate NSG rule corruption seen in this stack, the stale addresses
were old `mud_ingress` port `22` entries. The real SSH rules remained managed by
`ssh_ingress`.
