# Enterprise AI Document Extraction

Terraform infrastructure for extracting structured data from invoices, claims, contracts, PDFs, resumes, and forms.

## Azure Services

- Landingzone Azure AI Service for Document Intelligence document parsing and extraction.
- Landingzone Azure OpenAI Service with workload-owned deployments for post-processing, normalization, and summarization.
- Azure Functions, provisioned through the shared template `functionapp` module, for event-driven extraction code.
- Azure Logic Apps for workflow orchestration.
- Azure SQL Database, provisioned through the shared template `sqldb` module, for structured extraction results.

## Project Shape

This repo was cleaned from the `enterprise-ai-chatbot` baseline. Chatbot/RAG resources such as App Service deployment packaging, Azure AI Search wiring, embedding deployments, and document-search storage containers have been removed.

The workload does not create new Cognitive Services accounts. It looks up the landingzone Azure AI Service and Azure OpenAI accounts with data sources, then creates the required Azure OpenAI deployment on the landingzone OpenAI account.

Set `sql_ad_admin_object_id` to the real Microsoft Entra object ID for the SQL administrator group before applying an environment.

The current pipeline surface is Terraform-only:

- Azure DevOps: validate, plan, and apply for sandbox/dev.
- GitHub Actions: validate, plan, and optional dev apply.

## Validation

```bash
terraform init -backend=false -reconfigure -input=false
terraform fmt -check -recursive
terraform validate
```
