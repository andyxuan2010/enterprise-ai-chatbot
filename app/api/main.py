import os
import logging
from functools import lru_cache
from typing import List

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from openai import AzureOpenAI
from pydantic import BaseModel

TOKEN_SCOPE = "https://cognitiveservices.azure.com/.default"
logger = logging.getLogger("enterprise_chatbot")


def required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


app = FastAPI(title="Enterprise RAG Knowledge Assistant")


@app.get("/", response_class=HTMLResponse)
def index():
    return """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Enterprise RAG Knowledge Assistant</title>
  <style>
    :root {
      color-scheme: light;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f5f7fb;
      color: #182233;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 32px 16px;
    }
    main {
      width: min(920px, 100%);
      background: #ffffff;
      border: 1px solid #dde4f0;
      border-radius: 8px;
      box-shadow: 0 18px 45px rgba(30, 44, 72, 0.12);
      overflow: hidden;
    }
    header {
      padding: 28px 32px 20px;
      border-bottom: 1px solid #e6ecf5;
    }
    h1 {
      margin: 0 0 8px;
      font-size: clamp(1.55rem, 2vw, 2.1rem);
      line-height: 1.15;
      letter-spacing: 0;
    }
    p {
      margin: 0;
      color: #536273;
      line-height: 1.55;
    }
    section {
      padding: 28px 32px 32px;
    }
    label {
      display: block;
      margin-bottom: 10px;
      font-weight: 700;
      color: #27364a;
    }
    textarea {
      width: 100%;
      min-height: 150px;
      resize: vertical;
      border: 1px solid #cbd6e5;
      border-radius: 8px;
      padding: 14px 16px;
      font: inherit;
      line-height: 1.5;
      color: #182233;
      background: #fbfcfe;
    }
    textarea:focus {
      outline: 3px solid #c9ddff;
      border-color: #3978d8;
      background: #ffffff;
    }
    .actions {
      display: flex;
      align-items: center;
      gap: 14px;
      margin-top: 16px;
      flex-wrap: wrap;
    }
    button {
      border: 0;
      border-radius: 8px;
      background: #235eb8;
      color: white;
      padding: 11px 18px;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }
    button:disabled {
      cursor: wait;
      opacity: 0.68;
    }
    .status {
      min-height: 24px;
      color: #536273;
    }
    .answer {
      margin-top: 24px;
      padding: 18px;
      border: 1px solid #dce5f2;
      border-radius: 8px;
      background: #f8fafd;
      white-space: pre-wrap;
      line-height: 1.55;
    }
    .citations {
      margin-top: 16px;
      color: #536273;
      font-size: 0.94rem;
      overflow-wrap: anywhere;
    }
    @media (max-width: 640px) {
      header,
      section {
        padding-left: 20px;
        padding-right: 20px;
      }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <h1>Enterprise RAG Knowledge Assistant</h1>
      <p>Ask a question against the indexed enterprise knowledge base.</p>
    </header>
    <section>
      <form id="chat-form">
        <label for="question">Question</label>
        <textarea id="question" name="question" placeholder="What would you like to know?" required></textarea>
        <div class="actions">
          <button id="submit" type="submit">Ask</button>
          <span id="status" class="status"></span>
        </div>
      </form>
      <div id="answer" class="answer" hidden></div>
      <div id="citations" class="citations" hidden></div>
    </section>
  </main>
  <script>
    const form = document.querySelector("#chat-form");
    const question = document.querySelector("#question");
    const submit = document.querySelector("#submit");
    const status = document.querySelector("#status");
    const answer = document.querySelector("#answer");
    const citations = document.querySelector("#citations");

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      submit.disabled = true;
      status.textContent = "Thinking...";
      answer.hidden = true;
      citations.hidden = true;

      try {
        const response = await fetch("/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ question: question.value, user_groups: ["default"] })
        });

        const responseText = await response.text();
        let payload = {};
        try {
          payload = responseText ? JSON.parse(responseText) : {};
        } catch {
          payload = { detail: responseText || "The server returned a non-JSON response." };
        }

        if (!response.ok) {
          throw new Error(payload.detail || "The request failed.");
        }

        answer.textContent = payload.answer || "No answer was returned.";
        answer.hidden = false;

        if (payload.citations && payload.citations.length) {
          citations.textContent = "Sources: " + payload.citations.join(", ");
          citations.hidden = false;
        }
        status.textContent = "";
      } catch (error) {
        answer.textContent = error.message;
        answer.hidden = false;
        status.textContent = "Request failed";
      } finally {
        submit.disabled = false;
      }
    });
  </script>
</body>
</html>
"""


class ChatRequest(BaseModel):
    question: str
    user_groups: List[str] = ["default"]


class ChatResponse(BaseModel):
    answer: str
    citations: List[str]


@lru_cache(maxsize=1)
def get_credential() -> DefaultAzureCredential:
    return DefaultAzureCredential()


@lru_cache(maxsize=1)
def get_token_provider():
    return get_bearer_token_provider(get_credential(), TOKEN_SCOPE)


@lru_cache(maxsize=1)
def get_openai_client() -> AzureOpenAI:
    return AzureOpenAI(
        azure_endpoint=required("AZURE_OPENAI_ENDPOINT"),
        azure_ad_token_provider=get_token_provider(),
        api_version="2024-10-21",
    )


@lru_cache(maxsize=1)
def get_search_client() -> SearchClient:
    return SearchClient(
        endpoint=required("AZURE_SEARCH_ENDPOINT"),
        index_name=required("AZURE_SEARCH_INDEX"),
        credential=get_credential(),
    )


@app.get("/healthz")
def healthz():
    missing = [
        name
        for name in [
            "AZURE_OPENAI_ENDPOINT",
            "AZURE_AI_SERVICE_ENDPOINT",
            "AZURE_OPENAI_CHAT_DEPLOYMENT",
            "AZURE_OPENAI_EMBED_DEPLOYMENT",
            "AZURE_SEARCH_ENDPOINT",
            "AZURE_SEARCH_INDEX",
        ]
        if not os.getenv(name)
    ]
    return {"status": "ok", "missing_configuration": missing}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="Question is required")

    try:
        chat_deployment = required("AZURE_OPENAI_CHAT_DEPLOYMENT")
        embed_deployment = required("AZURE_OPENAI_EMBED_DEPLOYMENT")
        openai_client = get_openai_client()
        search_client = get_search_client()

        emb = openai_client.embeddings.create(input=req.question, model=embed_deployment)
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
            model=chat_deployment,
            messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
            temperature=0.1,
            max_tokens=900,
        )
        return ChatResponse(answer=completion.choices[0].message.content or "", citations=sorted(set(citations)))
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Chat request failed")
        raise HTTPException(status_code=500, detail=f"Chat request failed: {exc}") from exc
