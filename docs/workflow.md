# OCI Terraform Workflow

This runbook covers the normal workflow for the OCI Terraform stack: refreshing the OCI security-token session, checking variables, bootstrapping remote state when needed, and planning or applying the root stack.

## 1. Refresh OCI Session

The provider and OCI backend are configured to use the `tlbb` profile with security-token authentication.

```bash
oci session authenticate --region ap-chuncheon-1 --profile-name tlbb
oci session validate --profile tlbb
```

OCI CLI calls with this profile also need `--auth security_token`:

```bash
oci os ns get --profile tlbb --auth security_token
```

## 2. Check `terraform.tfvars`

Before planning, confirm that `terraform.tfvars` contains the required root variables:

- `tenancy_ocid`
- `compartment_ocid`
- `region`
- `oci_config_profile`
- `oci_auth = "SecurityToken"`
- `allowed_source_cidrs`
- `allowed_tcp_ports`
- `mud_upstream_host`
- `mud_upstream_port`
- `ssh_public_key`

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

Run this only when the OCI Object Storage state bucket and IAM policy do not exist yet.

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

## 6. Validate And Plan

Run format, validation, and plan checks from the repository root:

```bash
terraform fmt -check -diff
terraform validate
terraform plan -var-file=terraform.tfvars
```

## 7. Apply

After reviewing the plan, apply the root stack:

```bash
terraform apply -var-file=terraform.tfvars
```

## 8. Focused Checks

Before applying, confirm the plan still satisfies these guardrails:

- NSG ingress does not include `0.0.0.0/0`.
- Total A1 OCPUs are `<= 4`.
- Total A1 memory is `<= 24 GB`.
- Total boot volume storage is `<= 200 GB`.
