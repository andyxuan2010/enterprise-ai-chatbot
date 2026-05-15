import os
from typing import List

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from fastapi import FastAPI, HTTPException
from openai import AzureOpenAI
from pydantic import BaseModel

TOKEN_SCOPE = "https://cognitiveservices.azure.com/.default"


def required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


credential = DefaultAzureCredential()
token_provider = get_bearer_token_provider(credential, TOKEN_SCOPE)

openai_client = AzureOpenAI(
    azure_endpoint=required("AZURE_OPENAI_ENDPOINT"),
    azure_ad_token_provider=token_provider,
    api_version="2024-10-21",
)

search_client = SearchClient(
    endpoint=required("AZURE_SEARCH_ENDPOINT"),
    index_name=required("AZURE_SEARCH_INDEX"),
    credential=credential,
)

CHAT_DEPLOYMENT = required("AZURE_OPENAI_CHAT_DEPLOYMENT")
EMBED_DEPLOYMENT = required("AZURE_OPENAI_EMBED_DEPLOYMENT")

app = FastAPI(title="Enterprise RAG Knowledge Assistant")


class ChatRequest(BaseModel):
    question: str
    user_groups: List[str] = ["default"]


class ChatResponse(BaseModel):
    answer: str
    citations: List[str]


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="Question is required")

    emb = openai_client.embeddings.create(input=req.question, model=EMBED_DEPLOYMENT)
    vector = emb.data[0].embedding

    # Minimal document-level authorization example. Replace security_group with real ACL metadata.
    allowed_groups = [g.replace("'", "''") for g in req.user_groups]
    filter_expr = " or ".join([f"security_group eq '{g}'" for g in allowed_groups]) or "security_group eq 'default'"

    vector_query = VectorizedQuery(vector=vector, k_nearest_neighbors=5, fields="content_vector")
    results = search_client.search(
        search_text=req.question,
        vector_queries=[vector_query],
        select=["content", "title", "source_path"],
        filter=filter_expr,
        top=5,
    )

    docs = []
    citations = []
    for item in results:
        docs.append(f"Source: {item['source_path']}\nTitle: {item['title']}\nContent: {item['content']}")
        citations.append(item["source_path"])

    context = "\n\n---\n\n".join(docs)
    system = (
        "You are an internal enterprise knowledge assistant. Answer only from the provided context. "
        "If the context does not contain the answer, say that the available indexed documents do not contain enough evidence. "
        "Do not invent policies, URLs, commands, or approvals. Cite source_path values when relevant."
    )
    user = f"Question:\n{req.question}\n\nRetrieved context:\n{context}"

    completion = openai_client.chat.completions.create(
        model=CHAT_DEPLOYMENT,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
        temperature=0.1,
        max_tokens=900,
    )
    return ChatResponse(answer=completion.choices[0].message.content or "", citations=sorted(set(citations)))
