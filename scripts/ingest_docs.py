"""
Minimal ingestion pipeline for an Azure OpenAI + Azure AI Search RAG assistant.

Expected environment variables:
  AZURE_OPENAI_ENDPOINT=https://<openai>.openai.azure.com/
  AZURE_OPENAI_EMBED_DEPLOYMENT=embedding
  AZURE_SEARCH_ENDPOINT=https://<search>.search.windows.net
  AZURE_SEARCH_INDEX=enterprise-docs
  STORAGE_ACCOUNT_NAME=<storage-account>
  STORAGE_CONTAINER_NAME=documents
  DOCS_PATH=./sample_docs

Authentication:
  Uses DefaultAzureCredential by default.
  If the Search service is configured as apiKeyOnly, set AZURE_SEARCH_ADMIN_KEY.
  If local Entra auth cannot access Storage, set AZURE_STORAGE_ACCOUNT_KEY.
  If local Entra auth cannot access Azure OpenAI, set AZURE_OPENAI_API_KEY.
"""

import base64
import hashlib
import os
from pathlib import Path
from typing import Iterable, List, Dict

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
)
from azure.storage.blob import BlobServiceClient
from openai import AzureOpenAI
from pypdf import PdfReader

TOKEN_SCOPE = "https://cognitiveservices.azure.com/.default"
VECTOR_DIMENSIONS = 1536  # text-embedding-3-small default dimension in many deployments. Validate for your deployment.


def required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def read_text(path: Path) -> str:
    if path.suffix.lower() == ".pdf":
        reader = PdfReader(str(path))
        return "\n".join(page.extract_text() or "" for page in reader.pages)
    return path.read_text(encoding="utf-8", errors="ignore")


def chunk_text(text: str, max_chars: int = 3500, overlap: int = 400) -> Iterable[str]:
    text = " ".join(text.split())
    if not text:
        return
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        yield text[start:end]
        if end == len(text):
            break
        start = max(0, end - overlap)


def stable_id(*parts: str) -> str:
    raw = "|".join(parts).encode("utf-8")
    digest = hashlib.sha256(raw).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def create_index_if_missing(index_client: SearchIndexClient, index_name: str) -> None:
    existing = [idx.name for idx in index_client.list_indexes()]
    if index_name in existing:
        return

    fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True, filterable=True),
        SearchableField(name="content", type=SearchFieldDataType.String, analyzer_name="en.lucene"),
        SearchableField(name="title", type=SearchFieldDataType.String, filterable=True, sortable=True),
        SimpleField(name="source_path", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="security_group", type=SearchFieldDataType.String, filterable=True),
        SearchField(
            name="content_vector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=VECTOR_DIMENSIONS,
            vector_search_profile_name="vector-profile",
        ),
    ]
    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="hnsw")],
        profiles=[VectorSearchProfile(name="vector-profile", algorithm_configuration_name="hnsw")],
    )
    index = SearchIndex(name=index_name, fields=fields, vector_search=vector_search)
    index_client.create_index(index)


def main() -> None:
    openai_endpoint = required("AZURE_OPENAI_ENDPOINT")
    embedding_deployment = required("AZURE_OPENAI_EMBED_DEPLOYMENT")
    search_endpoint = required("AZURE_SEARCH_ENDPOINT")
    search_index = required("AZURE_SEARCH_INDEX")
    storage_account = required("STORAGE_ACCOUNT_NAME")
    storage_container = required("STORAGE_CONTAINER_NAME")
    docs_path = Path(os.getenv("DOCS_PATH", "./sample_docs"))

    credential = DefaultAzureCredential()
    search_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
    search_credential = AzureKeyCredential(search_key) if search_key else credential
    storage_key = os.getenv("AZURE_STORAGE_ACCOUNT_KEY")
    storage_credential = storage_key if storage_key else credential
    token_provider = get_bearer_token_provider(credential, TOKEN_SCOPE)
    openai_key = os.getenv("AZURE_OPENAI_API_KEY")

    openai_client_args = {
        "azure_endpoint": openai_endpoint,
        "api_version": "2024-10-21",
    }
    if openai_key:
        openai_client_args["api_key"] = openai_key
    else:
        openai_client_args["azure_ad_token_provider"] = token_provider
    openai_client = AzureOpenAI(**openai_client_args)

    index_client = SearchIndexClient(endpoint=search_endpoint, credential=search_credential)
    create_index_if_missing(index_client, search_index)
    search_client = SearchClient(endpoint=search_endpoint, index_name=search_index, credential=search_credential)

    blob_service = BlobServiceClient(
        account_url=f"https://{storage_account}.blob.core.windows.net",
        credential=storage_credential,
    )
    container = blob_service.get_container_client(storage_container)

    batch: List[Dict] = []
    for path in docs_path.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".txt", ".md", ".pdf"}:
            continue

        blob_name = path.relative_to(docs_path).as_posix()
        with path.open("rb") as fh:
            container.upload_blob(blob_name, fh, overwrite=True)

        text = read_text(path)
        for i, chunk in enumerate(chunk_text(text)):
            emb = openai_client.embeddings.create(input=chunk, model=embedding_deployment)
            batch.append({
                "id": stable_id(blob_name, str(i)),
                "content": chunk,
                "title": path.name,
                "source_path": blob_name,
                "security_group": "default",  # Replace with Entra group or ACL metadata.
                "content_vector": emb.data[0].embedding,
            })

        if len(batch) >= 100:
            search_client.upload_documents(batch)
            batch.clear()

    if batch:
        search_client.upload_documents(batch)

    print(f"Ingestion complete. Index: {search_index}")


if __name__ == "__main__":
    main()
