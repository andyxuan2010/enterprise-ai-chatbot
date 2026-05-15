# Azure Landing Zone

Terraform landing zone repository for provisioning a shared Azure foundation and a small set of opinionated platform workloads.

This repo is a consumer of the shared Terraform modules hosted in the upstream template repository. Its primary job is to compose those modules into a working landing zone, validate the root deployment path, and document the operating patterns used by this stack.

## What This Repo Does

- Provisions a shared root landing zone composition from `main.tf` and `variables.tf`, with environment-specific backend and variable files stored under `environments/<env>/`
- Consumes shared Terraform modules from the upstream Azure DevOps template repo
- Manages the current platform baseline for governance, networking, storage, Key Vault, App Service, Automation/ARI, and Linux runner resources
- Publishes validated snapshots to downstream repos through CI
- Acts as the main documentation entry point for this landing zone implementation

## Current Provisioned Scope

The current checked-in root configuration is wired to provision:

- Management groups and subscription bootstrap
- Shared resource group, Log Analytics workspace, storage account, and Key Vault
- Hub/spoke virtual networks, subnet layout, NSG associations, VNet peering, and private DNS
- App Service Plans, App Services, and optional Entra app registrations for enabled apps
- Automation Account, Azure Resource Inventory runtime/runbook/schedule wiring, and supporting storage containers
- Linux runner/jumpbox resources and App Service deployment RBAC

For the detailed inventory, see [docs/CURRENT_LANDINGZONE_RESOURCES.md](./docs/CURRENT_LANDINGZONE_RESOURCES.md) and [docs/ROOT_LEVEL_MODULES_GUIDE.md](./docs/ROOT_LEVEL_MODULES_GUIDE.md).

## Repo Layout

- [`main.tf`](./main.tf): root landing zone composition
- [`variables.tf`](./variables.tf): root inputs and validation
- [`environments/dev/terraform.tfvars`](./environments/dev/terraform.tfvars): current dev environment values and enabled features
- [`environments/dev/backend.hcl`](./environments/dev/backend.hcl): saved dev remote-backend config for when remote state is re-enabled
- [`environments/sandbox/terraform.tfvars`](./environments/sandbox/terraform.tfvars): current sandbox environment values and enabled features
- [`environments/sandbox/backend.hcl`](./environments/sandbox/backend.hcl): saved sandbox remote-backend config for when remote state is re-enabled
- [`outputs.tf`](./outputs.tf): root outputs
- [`docs/`](./docs/README.md): documentation map of content for this repo
- [`runbooks/`](./runbooks): Automation runbook templates used by the root deployment
- [`scripts/`](./scripts): bootstrap and helper scripts used by the landing zone
- [`.github/workflows/terraform.yml`](./.github/workflows/terraform.yml): GitHub Actions validation and publishing workflow
- [`azure-pipelines.yml`](./azure-pipelines.yml): Azure DevOps pipeline definition

## How To Work In This Repo

### 1. Update root inputs

Most day-to-day changes happen in:

- [`environments/dev/terraform.tfvars`](./environments/dev/terraform.tfvars)
- [`variables.tf`](./variables.tf)
- [`main.tf`](./main.tf)

Use outputs from one module wiring block to feed the next whenever possible instead of hard-coding Azure resource IDs into `terraform.tfvars`.

### 2. Validate locally

Common local checks:

```powershell
terraform fmt -recursive
terraform init -reconfigure
terraform validate
terraform plan -var-file="environments/dev/terraform.tfvars"
```

If you are changing a shared module in the upstream template repo instead of this landing zone composition, do the module-level validation in that module repo as well.

### 3. Let CI validate the root composition

This repo's GitHub Actions workflow validates the landing zone root composition rather than running the full upstream module matrix. The module harness responsibility lives in the template repo; this repo focuses on whether this composed landing zone still plans successfully.

## Deployment And Operations

- Pipeline analysis and CI/CD behavior: [docs/PIPELINES_GUIDE.md](./docs/PIPELINES_GUIDE.md)
- App Service deployment patterns: [docs/APP_SERVICE_DEPLOYMENT_METHODS.md](./docs/APP_SERVICE_DEPLOYMENT_METHODS.md) and [docs/DEPLOYMENT_METHODS.md](./docs/DEPLOYMENT_METHODS.md)
- Automation ARI design and runtime behavior: [docs/AUTOMATION_ARI.md](./docs/AUTOMATION_ARI.md)
- Private endpoint and DNS lookup pattern guidance: [docs/PRIVATE_ENDPOINT_PRIVATE_DNS_LOOKUP_PATTERN.md](./docs/PRIVATE_ENDPOINT_PRIVATE_DNS_LOOKUP_PATTERN.md)
- Shared runner hygiene guidance: [docs/SHARED-RUNNER-HYGIENE-STANDARD.md](./docs/SHARED-RUNNER-HYGIENE-STANDARD.md)

## Docs At A Glance

- [docs/README.md](./docs/README.md): map of content for the full `docs/` folder and the best place to navigate deeper.
- [docs/CURRENT_LANDINGZONE_RESOURCES.md](./docs/CURRENT_LANDINGZONE_RESOURCES.md): fastest inventory of what this repo actually provisions today.
- [docs/ROOT_LEVEL_MODULES_GUIDE.md](./docs/ROOT_LEVEL_MODULES_GUIDE.md): root Terraform wiring order, dependency flow, and which module patterns are active versus template-only.
- [docs/PIPELINES_GUIDE.md](./docs/PIPELINES_GUIDE.md): side-by-side explanation of GitHub Actions versus Azure DevOps, including validation, artifact publishing, and apply behavior.
- [docs/MODULE_USAGE_AND_DEPENDENCIES.md](./docs/MODULE_USAGE_AND_DEPENDENCIES.md): module-by-module dependency map and guidance for composing shared modules correctly.
- [docs/MODULES_INDEX.md](./docs/MODULES_INDEX.md): index of module documentation and validation artifacts from the broader module ecosystem.
- [docs/REPO_MODULES_GUIDE.md](./docs/REPO_MODULES_GUIDE.md): repository standards for validating, documenting, and contributing shared modules.
- [docs/VALIDATION_SUMMARY.md](./docs/VALIDATION_SUMMARY.md): snapshot of module hardening and validation status captured during earlier repo work.
- [docs/APP_SERVICE_DEPLOYMENT_METHODS.md](./docs/APP_SERVICE_DEPLOYMENT_METHODS.md): the three App Service deployment patterns modeled in this landing zone and when to use each.
- [docs/DEPLOYMENT_METHODS.md](./docs/DEPLOYMENT_METHODS.md): broader deployment-method comparison across App Service delivery approaches.
- [docs/APP_SERVICE_PLAN_FUNCTION_APP_NOTES.md](./docs/APP_SERVICE_PLAN_FUNCTION_APP_NOTES.md): key plan and OS-matching constraints for Function Apps that share an App Service Plan.
- [docs/AUTOMATION_ARI.md](./docs/AUTOMATION_ARI.md): how the Automation Account and Azure Resource Inventory workload are wired in this landing zone.
- [docs/PRIVATE_ENDPOINT_PRIVATE_DNS_LOOKUP_PATTERN.md](./docs/PRIVATE_ENDPOINT_PRIVATE_DNS_LOOKUP_PATTERN.md): reference implementation for private endpoint subnet and private DNS lookup patterns across modules.
- [docs/SHARED-RUNNER-HYGIENE-STANDARD.md](./docs/SHARED-RUNNER-HYGIENE-STANDARD.md): reusable hygiene baseline for shared self-hosted runners.
- [docs/GIT-EXTRAHEADER-RUNNER-ISSUE.md](./docs/GIT-EXTRAHEADER-RUNNER-ISSUE.md): troubleshooting note for Azure DevOps runner failures caused by lingering Git `extraheader` configuration.
- [docs/AKS_AUTHENTICATION_KUBELOGIN.md](./docs/AKS_AUTHENTICATION_KUBELOGIN.md): AKS access notes for `kubelogin`, `az aks get-credentials`, and the RBAC required for cluster access.

## Documentation Map

Start with the docs MOC:

- [docs/README.md](./docs/README.md)

Recommended reading order for most contributors:

1. [docs/CURRENT_LANDINGZONE_RESOURCES.md](./docs/CURRENT_LANDINGZONE_RESOURCES.md)
2. [docs/ROOT_LEVEL_MODULES_GUIDE.md](./docs/ROOT_LEVEL_MODULES_GUIDE.md)
3. [docs/PIPELINES_GUIDE.md](./docs/PIPELINES_GUIDE.md)
4. [docs/MODULE_USAGE_AND_DEPENDENCIES.md](./docs/MODULE_USAGE_AND_DEPENDENCIES.md)
5. [docs/REPO_MODULES_GUIDE.md](./docs/REPO_MODULES_GUIDE.md)
6. The topic-specific guides that match the area you are changing

## Related Notes

- This repo no longer needs to validate every upstream module harness in CI, because that belongs in the shared template/module repo.
- Some documents under `docs/` still describe the broader template ecosystem, not just the currently enabled landing zone subset. Use the root-level guide to distinguish what is active here today.
