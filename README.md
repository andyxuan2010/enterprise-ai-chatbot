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

## RAG Runtime

The web app is a document-grounded RAG assistant. It does not search the public internet at runtime; it searches content that has been ingested into Azure AI Search.

Current runtime flow:

1. The user posts a question to `/chat`.
2. The app rewrites vague or follow-up questions into a standalone retrieval question and generates expanded retrieval queries.
3. The app embeds each retrieval query with the configured Azure OpenAI embedding deployment.
4. The app runs hybrid retrieval against Azure AI Search:
   - keyword/full-text search with `search_text`
   - vector search with `VectorizedQuery`
5. Azure AI Search merges keyword and vector results with reciprocal rank fusion.
6. The app applies access and optional metadata filters.
7. The app deduplicates candidates returned by the expanded queries.
8. The app optionally reranks the broader hybrid candidate set with the configured Azure OpenAI chat deployment.
9. The app assigns evidence IDs to reranked chunks and asks the chat deployment for a structured grounded answer.
10. The app verifies that returned citations reference real retrieved evidence IDs.
11. If citations are missing or retrieval evidence is weak, the app returns a conservative refusal instead of an unsupported answer.
12. The browser renders clickable source previews with markdown formatting, metadata, and highlighted matching terms.

Runtime tuning settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| `HYBRID_SEARCH_TOP` | `5` | Number of hybrid results used when reranking is disabled, and fallback count if reranking fails |
| `HYBRID_VECTOR_K` | `8` | Number of vector neighbors requested before Azure AI Search fuses results |
| `AZURE_SEARCH_SEMANTIC_CONFIGURATION` | empty | Optional Azure AI Search semantic configuration name |
| `QUERY_REWRITE_ENABLED` | `true` | Enables standalone question rewriting and multi-query expansion |
| `QUERY_EXPANSION_COUNT` | `3` | Maximum number of alternate retrieval queries generated before search |
| `QUERY_REWRITE_HISTORY_MESSAGES` | `6` | Number of recent chat messages used to rewrite follow-up questions |
| `RERANK_ENABLED` | `true` | Enables the second-stage LLM reranker |
| `RERANK_CANDIDATE_TOP` | `12` | Number of hybrid candidates retrieved before reranking |
| `RERANK_TOP` | `5` | Number of reranked chunks sent to answer generation |
| `RERANK_CONTENT_CHARS` | `1200` | Maximum characters per candidate sent to the reranker |
| `MIN_GROUNDED_CITATIONS` | `1` | Minimum verified evidence citations required before returning an answer |

Reranking improves precision but adds one extra chat completion call per question. Set `RERANK_ENABLED=false` for lower latency and lower demo cost.

Answer generation uses a grounded JSON contract. The model must return `answer`, `citations`, `grounded`, and `refusal_reason`. The app only accepts citations that match retrieved evidence IDs, and returns a conservative refusal when the answer is not grounded.

The `/chat` endpoint accepts optional metadata filters:

```json
{
  "question": "How do I configure vector search?",
  "user_groups": ["default"],
  "chat_history": [
    {
      "role": "user",
      "content": "Tell me about Azure AI Search."
    },
    {
      "role": "assistant",
      "content": "Azure AI Search supports keyword, vector, hybrid, and semantic search."
    }
  ],
  "filters": {
    "source_path": "retrieval-augmented-generation-overview.md",
    "document_title": "Retrieval augmented generation",
    "section_heading": "Indexing strategy",
    "product_service": "search",
    "document_date": "2025-09-01",
    "document_version": "2025-09-01",
    "url": "https://learn.microsoft.com/...",
    "access_group": "default"
  }
}
```

`chat_history` is optional. It helps the app rewrite follow-up questions like "how do I configure that?" into standalone retrieval queries. All filter fields are optional. If omitted, the app only applies the existing access filter from `user_groups`.

## Document Ingestion

The ingestion script is [scripts/ingest_docs.py](./scripts/ingest_docs.py). It recursively reads `.md`, `.txt`, and `.pdf` files from `DOCS_PATH`, uploads source files to Blob Storage, chunks and embeds the text, and writes searchable records into the configured Azure AI Search index.

Required environment variables:

```powershell
$env:AZURE_OPENAI_ENDPOINT="https://<openai>.openai.azure.com/"
$env:AZURE_OPENAI_EMBED_DEPLOYMENT="embedding"
$env:AZURE_SEARCH_ENDPOINT="https://<search>.search.windows.net"
$env:AZURE_SEARCH_INDEX="enterprise-docs"
$env:STORAGE_ACCOUNT_NAME="<storage-account>"
$env:STORAGE_CONTAINER_NAME="documents"
$env:DOCS_PATH="path\to\docs"
```

For the current sandbox Search service, key auth is required for ingestion:

```powershell
$env:AZURE_SEARCH_ADMIN_KEY=(az search admin-key show --service-name srch-platform-cc-sbx --resource-group rg-platform-sbx --query primaryKey -o tsv)
$env:AZURE_STORAGE_ACCOUNT_KEY=(az storage account keys list --account-name stplatformccsbx --resource-group rg-platform-sbx --query '[0].value' -o tsv)
$env:AZURE_OPENAI_API_KEY=(az cognitiveservices account keys list --name oai-platform-cc-sbx --resource-group rg-platform-sbx --query key1 -o tsv)
python scripts\ingest_docs.py
```

Markdown line structure is preserved during ingestion so source previews can render headings, lists, links, blockquotes, and code blocks. If content was ingested before markdown-preserving chunks were introduced, recreate or clear the index and reingest for the cleanest preview rendering.

Each chunk includes metadata for filtering and source inspection:

| Field | Source |
| --- | --- |
| `source_path` | Relative file path under `DOCS_PATH` |
| `document_title` | `title` metadata, first H1, or file name |
| `section_heading` | Nearest heading inside the chunk |
| `product_service` | `INGEST_PRODUCT_SERVICE`, `ms.service`, `service`, or folder name |
| `document_date` | `ms.date` or `date` metadata |
| `document_version` | `ms.version` or `version` metadata |
| `url` | `url`, `canonical_url`, `ms.authoring-url`, or `DOCS_BASE_URL` + path |
| `access_group` | `INGEST_ACCESS_GROUP`, default `default` |

Metadata fields are part of the Search index schema. If the index was created before metadata support was added, recreate or migrate the index before using metadata filters.

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
- Detailed current architecture, runtime flow, retrieval design, risks, and recommended improvements are documented in [docs/current-deployment-architecture.md](./docs/current-deployment-architecture.md).
