# Enterprise AI Chatbot

Terraform root for the `enterprise-ai-chatbot` Azure deployment.

This repo is not a full landing zone. It is a workload repo that reuses shared platform resources from the sibling `landingzone` repo and provisions only the app-specific Azure pieces needed for this chatbot.

## What This Repo Provisions

- An application resource group
- A Linux App Service Plan
- A Linux Python App Service
- A Microsoft Entra app registration for the App Service

## What This Repo Reuses From `landingzone`

These resources are looked up with Terraform data sources instead of being created here:

- Shared resource group
- Storage account
- Key Vault
- Log Analytics workspace
- Azure OpenAI account
- Azure AI Service account
- Azure AI Search service

If a required shared resource does not exist, `terraform plan` will fail on the lookup. Azure AI Search is intentionally optional and can be disabled per environment with `landingzone_azure_ai_search_enabled`.

## App Layout

The deployed Python app lives under [app/api](./app/api).

Repo-root wrappers are used so Azure App Service can boot the app from the repo package:

- [requirements.txt](./requirements.txt): forwards to `app/api/requirements.txt`
- [startup.sh](./startup.sh): changes into `app/api` and runs the app startup there

The App Service startup command is configured in [main.tf](./main.tf) as:

```bash
bash /home/site/wwwroot/startup.sh
```

## Terraform Layout

- [main.tf](./main.tf): root resource composition
- [data.tf](./data.tf): shared `landingzone` lookups
- [variables.tf](./variables.tf): root inputs
- [outputs.tf](./outputs.tf): root outputs
- [providers.tf](./providers.tf): provider configuration
- [versions.tf](./versions.tf): Terraform and provider version constraints
- [environments/dev](./environments/dev): dev backend and tfvars
- [environments/sandbox](./environments/sandbox): sandbox backend and tfvars
- [environments/prod](./environments/prod): prod backend and tfvars

## Important Inputs

Common inputs you will likely touch:

- `workload`
- `environment`
- `resource_group_name`
- `app_service_plan_name`
- `app_service_name`
- `app_registration_display_name`
- `app_service_python_version`
- `app_service_enable_auth`
- `azure_openai_chat_deployment`
- `azure_openai_embed_deployment`
- `azure_search_index`

Shared-resource lookup inputs:

- `landingzone_resource_group_name`
- `landingzone_storage_account_name`
- `landingzone_key_vault_name`
- `landingzone_log_analytics_name`
- `landingzone_openai_name`
- `landingzone_azure_ai_service_name`
- `landingzone_azure_ai_search_name`
- `landingzone_azure_ai_search_enabled`

## Tags

This repo follows the `landingzone` tag pattern for App Service Plan and App Service resources.

- Governance tags come from `rg_tags`
- `Workload` is added from `var.workload`
- extra optional tags can still be supplied through `tags`

Case-conflicting keys like lowercase `workload` and `environment` are filtered out so they do not collide with the canonical `landingzone` tag format.

## Local Validation

Typical local workflow:

```powershell
terraform fmt -recursive
terraform init -backend-config="environments/dev/backend.hcl" -reconfigure
terraform validate
terraform plan -var-file="environments/dev/terraform.tfvars"
```

For isolated syntax validation without remote backend auth:

```powershell
terraform init -backend=false
terraform validate
```

## Pipelines

### GitHub Actions

GitHub Actions is defined in [`.github/workflows/terraform.yml`](./.github/workflows/terraform.yml).

Current behavior:

- validates and plans for `dev`
- supports manual `workflow_dispatch` apply for `dev`
- can publish to a stage repo
- can mirror to an Azure DevOps repo

Important GitHub secrets used by the workflow include:

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_ADO_PAT2`
- `INFRACOST_API_KEY`
- `STAGE_REPO_URL`
- `STAGE_REPO_TOKEN`
- `ADO_REPO_URL`
- `ADO_REPO_PAT`

### Azure DevOps

Azure DevOps is defined in [azure-pipelines.yml](./azure-pipelines.yml).

Current behavior:

- validates the repo on `main`, `dev`, `sandbox`, and `sbx`
- runs sandbox plan/apply for `main`, `sandbox`, and `sbx`
- runs dev plan/apply for `main` and `dev`

The pipeline expects the shared template repo and the existing Azure service connections configured in the YAML.

## Outputs

Useful outputs from this root:

- App Service name and URL
- App Service Plan ID
- App Service managed identity principal ID
- App registration application ID
- Resolved Azure OpenAI endpoint
- Resolved Azure AI Service endpoint
- Resolved Azure AI Search endpoint
- Resolved shared landingzone resource IDs

## Notes

- This repo depends on shared Terraform modules from the Azure DevOps `template` repo.
- This repo depends on shared platform resources that already exist in the sibling `landingzone`.
- `sandbox` uses `app_env = sbx` when calling the shared App Service modules because that is the accepted environment code in the upstream module.
- The `prod` tfvars file still contains placeholder values for several shared landingzone resource names and should be completed before a real prod deployment.
