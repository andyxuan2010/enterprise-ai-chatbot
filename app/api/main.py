import json
import os
import logging
from functools import lru_cache
from typing import List

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from openai import AzureOpenAI
from pydantic import BaseModel

TOKEN_SCOPE = "https://cognitiveservices.azure.com/.default"
logger = logging.getLogger("enterprise_chatbot")
DEFAULT_HYBRID_SEARCH_TOP = 5
DEFAULT_HYBRID_VECTOR_K = 8
DEFAULT_RERANK_CANDIDATE_TOP = 12
DEFAULT_RERANK_TOP = 5
DEFAULT_RERANK_CONTENT_CHARS = 1200


def required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def optional_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        logger.warning("Invalid integer app setting %s=%r; using %s", name, value, default)
        return default


def optional_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if not value:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


app = FastAPI(title="Enterprise RAG Knowledge Assistant")


@app.get("/", response_class=HTMLResponse)
def index():
    return r"""
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
      padding: 32px 16px;
    }
    main {
      width: min(1280px, 100%);
      margin: 0 auto;
    }
    .shell {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(340px, 420px);
      gap: 18px;
      align-items: start;
    }
    .workspace,
    .source-panel {
      background: #ffffff;
      border: 1px solid #dde4f0;
      border-radius: 8px;
      box-shadow: 0 18px 45px rgba(30, 44, 72, 0.12);
      overflow: hidden;
    }
    .workspace header {
      padding: 28px 32px 20px;
      border-bottom: 1px solid #e6ecf5;
    }
    .source-panel {
      position: sticky;
      top: 24px;
    }
    .source-panel header {
      padding: 20px 22px 16px;
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
    .workspace section {
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
      font-size: 0.94rem;
      overflow-wrap: anywhere;
    }
    .citations-title {
      margin-bottom: 8px;
      color: #536273;
      font-weight: 700;
    }
    .source-list {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .source-button {
      max-width: 100%;
      border: 1px solid #c8d7eb;
      background: #ffffff;
      color: #235eb8;
      padding: 8px 10px;
      font-size: 0.88rem;
      font-weight: 700;
      text-align: left;
    }
    .source-button:hover,
    .source-button.active {
      border-color: #235eb8;
      background: #edf4ff;
    }
    .source-body {
      padding: 18px 22px 22px;
    }
    .source-empty {
      color: #536273;
      line-height: 1.55;
    }
    .source-meta {
      display: grid;
      gap: 8px;
      margin-bottom: 14px;
      color: #536273;
      font-size: 0.9rem;
      overflow-wrap: anywhere;
    }
    .source-meta strong {
      color: #27364a;
    }
    .source-excerpt {
      max-height: 58vh;
      overflow: auto;
      padding: 14px;
      border: 1px solid #dce5f2;
      border-radius: 8px;
      background: #f8fafd;
      color: #182233;
      line-height: 1.55;
      overflow-wrap: anywhere;
    }
    .source-excerpt h1,
    .source-excerpt h2,
    .source-excerpt h3 {
      margin: 0.85em 0 0.35em;
      color: #182233;
      line-height: 1.25;
    }
    .source-excerpt h1 {
      font-size: 1.35rem;
    }
    .source-excerpt h2 {
      font-size: 1.15rem;
    }
    .source-excerpt h3 {
      font-size: 1rem;
    }
    .source-excerpt p,
    .source-excerpt ul,
    .source-excerpt ol,
    .source-excerpt pre {
      margin: 0 0 0.85em;
    }
    .source-excerpt ul,
    .source-excerpt ol {
      padding-left: 1.35em;
    }
    .source-excerpt code {
      border: 1px solid #d8e2ef;
      border-radius: 4px;
      background: #eef4fb;
      padding: 1px 4px;
      font-family: "Cascadia Mono", "SFMono-Regular", Consolas, monospace;
      font-size: 0.92em;
    }
    .source-excerpt pre {
      overflow-x: auto;
      border: 1px solid #d8e2ef;
      border-radius: 8px;
      background: #172033;
      color: #f6f8fb;
      padding: 12px;
    }
    .source-excerpt pre code {
      border: 0;
      background: transparent;
      color: inherit;
      padding: 0;
    }
    .source-excerpt blockquote {
      margin: 0 0 0.85em;
      padding-left: 12px;
      border-left: 4px solid #c8d7eb;
      color: #536273;
    }
    .source-excerpt a {
      color: #235eb8;
      font-weight: 700;
    }
    mark {
      background: #ffe58a;
      color: inherit;
      padding: 0 2px;
      border-radius: 3px;
    }
    @media (max-width: 640px) {
      body {
        padding: 16px 12px;
      }
      .shell {
        grid-template-columns: 1fr;
      }
      .source-panel {
        position: static;
      }
      .workspace header,
      .workspace section {
        padding-left: 20px;
        padding-right: 20px;
      }
    }
  </style>
</head>
<body>
  <main>
    <div class="shell">
      <div class="workspace">
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
      </div>
      <aside class="source-panel" aria-live="polite">
        <header>
          <h2>Source Preview</h2>
          <p>Select a source to inspect the retrieved passage.</p>
        </header>
        <div id="source-preview" class="source-body">
          <div class="source-empty">No source selected.</div>
        </div>
      </aside>
    </div>
  </main>
  <script>
    const form = document.querySelector("#chat-form");
    const question = document.querySelector("#question");
    const submit = document.querySelector("#submit");
    const status = document.querySelector("#status");
    const answer = document.querySelector("#answer");
    const citations = document.querySelector("#citations");
    const sourcePreview = document.querySelector("#source-preview");
    let currentCitations = [];

    function escapeHtml(value) {
      return String(value ?? "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      }[char]));
    }

    function questionTerms() {
      const stopWords = new Set(["about", "after", "again", "against", "also", "and", "are", "can", "does", "for", "from", "how", "into", "only", "should", "that", "the", "then", "this", "what", "when", "where", "which", "with", "would", "your"]);
      return [...new Set(question.value.toLowerCase().match(/[a-z0-9][a-z0-9-]{2,}/g) || [])]
        .filter((term) => !stopWords.has(term))
        .slice(0, 12);
    }

    function highlightHtml(html) {
      for (const term of questionTerms()) {
        const escapedTerm = term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        html = html
          .split(/(<[^>]+>)/g)
          .map((part) => part.startsWith("<") ? part : part.replace(new RegExp(`(${escapedTerm})`, "gi"), "<mark>$1</mark>"))
          .join("");
      }
      return html;
    }

    function renderInlineMarkdown(text) {
      let html = escapeHtml(text);
      html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
      html = html.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (match, label, href) => {
        const safeHref = href.startsWith("http://") || href.startsWith("https://") ? href : "#";
        const title = href.startsWith("http://") || href.startsWith("https://") ? "" : ` title="${escapeHtml(href)}"`;
        return `<a href="${escapeHtml(safeHref)}" target="_blank" rel="noopener noreferrer"${title}>${label}</a>`;
      });
      html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
      html = html.replace(/__([^_]+)__/g, "<strong>$1</strong>");
      html = html.replace(/\*([^*\n]+)\*/g, "<em>$1</em>");
      return highlightHtml(html);
    }

    function renderMarkdown(markdown) {
      const lines = String(markdown || "").replace(/\r\n/g, "\n").split("\n");
      const html = [];
      let paragraph = [];
      let listItems = [];
      let orderedList = false;
      let inCode = false;
      let codeLines = [];

      function flushParagraph() {
        if (paragraph.length) {
          html.push(`<p>${renderInlineMarkdown(paragraph.join(" "))}</p>`);
          paragraph = [];
        }
      }

      function flushList() {
        if (listItems.length) {
          const tag = orderedList ? "ol" : "ul";
          html.push(`<${tag}>${listItems.map((item) => `<li>${renderInlineMarkdown(item)}</li>`).join("")}</${tag}>`);
          listItems = [];
        }
      }

      for (const line of lines) {
        const trimmed = line.trim();

        if (trimmed.startsWith("```")) {
          flushParagraph();
          flushList();
          if (inCode) {
            html.push(`<pre><code>${highlightHtml(escapeHtml(codeLines.join("\n")))}</code></pre>`);
            codeLines = [];
          }
          inCode = !inCode;
          continue;
        }

        if (inCode) {
          codeLines.push(line);
          continue;
        }

        if (!trimmed) {
          flushParagraph();
          flushList();
          continue;
        }

        const heading = trimmed.match(/^(#{1,3})\s+(.+)$/);
        if (heading) {
          flushParagraph();
          flushList();
          const level = heading[1].length;
          html.push(`<h${level}>${renderInlineMarkdown(heading[2])}</h${level}>`);
          continue;
        }

        const unordered = trimmed.match(/^[-*+]\s+(.+)$/);
        const ordered = trimmed.match(/^\d+\.\s+(.+)$/);
        if (unordered || ordered) {
          flushParagraph();
          const nextOrdered = Boolean(ordered);
          if (listItems.length && orderedList !== nextOrdered) {
            flushList();
          }
          orderedList = nextOrdered;
          listItems.push((ordered || unordered)[1]);
          continue;
        }

        const quote = trimmed.match(/^>\s?(.+)$/);
        if (quote) {
          flushParagraph();
          flushList();
          html.push(`<blockquote>${renderInlineMarkdown(quote[1])}</blockquote>`);
          continue;
        }

        paragraph.push(trimmed);
      }

      flushParagraph();
      flushList();
      if (inCode) {
        html.push(`<pre><code>${highlightHtml(escapeHtml(codeLines.join("\n")))}</code></pre>`);
      }

      return html.join("");
    }

    function showSource(index) {
      const citation = currentCitations[index];
      if (!citation) {
        return;
      }

      document.querySelectorAll(".source-button").forEach((button) => {
        button.classList.toggle("active", button.dataset.index === String(index));
      });

      sourcePreview.innerHTML = `
        <div class="source-meta">
          <div><strong>Source:</strong> ${escapeHtml(citation.source_path)}</div>
          <div><strong>Title:</strong> ${escapeHtml(citation.title || citation.source_path)}</div>
          <div><strong>Referenced location:</strong> Retrieved passage ${index + 1}</div>
        </div>
        <div class="source-excerpt">${renderMarkdown(citation.content || "")}</div>
      `;
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      submit.disabled = true;
      status.textContent = "Thinking...";
      answer.hidden = true;
      citations.hidden = true;
      currentCitations = [];
      sourcePreview.innerHTML = '<div class="source-empty">No source selected.</div>';

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

        currentCitations = payload.citations || [];
        if (currentCitations.length) {
          citations.innerHTML = `
            <div class="citations-title">Sources</div>
            <div class="source-list">
              ${currentCitations.map((citation, index) => `
                <button type="button" class="source-button" data-index="${index}">
                  ${escapeHtml(citation.source_path || citation)}
                </button>
              `).join("")}
            </div>
          `;
          citations.hidden = false;
          citations.querySelectorAll(".source-button").forEach((button) => {
            button.addEventListener("click", () => showSource(Number(button.dataset.index)));
          });
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


class Citation(BaseModel):
    source_path: str
    title: str
    content: str


class ChatResponse(BaseModel):
    answer: str
    citations: List[Citation]


def extract_json_object(value: str) -> dict:
    start = value.find("{")
    end = value.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object found in reranker response")
    return json.loads(value[start : end + 1])


def rerank_citations(
    openai_client: AzureOpenAI,
    chat_deployment: str,
    question: str,
    candidates: List[Citation],
    top_n: int,
) -> List[Citation]:
    if not candidates:
        return []

    rerank_content_chars = optional_int("RERANK_CONTENT_CHARS", DEFAULT_RERANK_CONTENT_CHARS)
    payload = [
        {
            "index": index,
            "source_path": citation.source_path,
            "title": citation.title,
            "content": citation.content[:rerank_content_chars],
        }
        for index, citation in enumerate(candidates)
    ]
    system = (
        "You are a retrieval reranker for an enterprise RAG system. "
        "Rank candidate passages by usefulness for answering the question. "
        "Prefer exact matches for product names, error codes, CLI commands, SKU names, acronyms, and policy terms. "
        "Return only JSON with this shape: {\"ranked\":[{\"index\":0,\"score\":100,\"reason\":\"short\"}]}."
    )
    user = f"Question:\n{question}\n\nCandidate passages JSON:\n{json.dumps(payload, ensure_ascii=False)}"

    completion = openai_client.chat.completions.create(
        model=chat_deployment,
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
        temperature=0,
        max_tokens=700,
    )
    content = completion.choices[0].message.content or "{}"
    parsed = extract_json_object(content)

    ranked = []
    seen = set()
    for item in parsed.get("ranked", []):
        try:
            index = int(item.get("index"))
        except (TypeError, ValueError):
            continue
        if index in seen or index < 0 or index >= len(candidates):
            continue
        seen.add(index)
        ranked.append(candidates[index])
        if len(ranked) >= top_n:
            return ranked

    for index, citation in enumerate(candidates):
        if index not in seen:
            ranked.append(citation)
        if len(ranked) >= top_n:
            break

    return ranked


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
    search_key = os.getenv("AZURE_SEARCH_QUERY_KEY")
    credential = AzureKeyCredential(search_key) if search_key else get_credential()

    return SearchClient(
        endpoint=required("AZURE_SEARCH_ENDPOINT"),
        index_name=required("AZURE_SEARCH_INDEX"),
        credential=credential,
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
    return {
        "status": "ok",
        "missing_configuration": missing,
        "retrieval": {
            "mode": "hybrid",
            "search_top": optional_int("HYBRID_SEARCH_TOP", DEFAULT_HYBRID_SEARCH_TOP),
            "vector_k": optional_int("HYBRID_VECTOR_K", DEFAULT_HYBRID_VECTOR_K),
            "semantic_configuration": os.getenv("AZURE_SEARCH_SEMANTIC_CONFIGURATION", ""),
            "rerank_enabled": optional_bool("RERANK_ENABLED", True),
            "rerank_candidate_top": optional_int("RERANK_CANDIDATE_TOP", DEFAULT_RERANK_CANDIDATE_TOP),
            "rerank_top": optional_int("RERANK_TOP", DEFAULT_RERANK_TOP),
        },
    }


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

        hybrid_search_top = optional_int("HYBRID_SEARCH_TOP", DEFAULT_HYBRID_SEARCH_TOP)
        hybrid_vector_k = optional_int("HYBRID_VECTOR_K", DEFAULT_HYBRID_VECTOR_K)
        semantic_configuration = os.getenv("AZURE_SEARCH_SEMANTIC_CONFIGURATION", "").strip()
        rerank_enabled = optional_bool("RERANK_ENABLED", True)
        rerank_candidate_top = optional_int("RERANK_CANDIDATE_TOP", DEFAULT_RERANK_CANDIDATE_TOP)
        rerank_top = optional_int("RERANK_TOP", DEFAULT_RERANK_TOP)
        retrieval_top = max(hybrid_search_top, rerank_candidate_top) if rerank_enabled else hybrid_search_top

        # Hybrid retrieval: keyword/BM25 search_text + vector search. Azure AI Search merges
        # the result sets with reciprocal rank fusion, improving exact-term and semantic recall.
        vector_query = VectorizedQuery(vector=vector, k_nearest_neighbors=hybrid_vector_k, fields="content_vector")
        search_kwargs = {
            "search_text": req.question,
            "vector_queries": [vector_query],
            "select": ["content", "title", "source_path"],
            "filter": filter_expr,
            "top": retrieval_top,
        }
        if semantic_configuration:
            search_kwargs.update({
                "query_type": "semantic",
                "semantic_configuration_name": semantic_configuration,
            })
        results = search_client.search(**search_kwargs)

        candidates = []
        seen_content_ids = set()
        for item in results:
            content_id = f"{item['source_path']}|{item['content']}"
            if content_id in seen_content_ids:
                continue
            seen_content_ids.add(content_id)
            candidates.append(Citation(
                source_path=item["source_path"],
                title=item["title"],
                content=item["content"],
            ))

        if rerank_enabled:
            try:
                citations = rerank_citations(openai_client, chat_deployment, req.question, candidates, rerank_top)
            except Exception as exc:
                logger.warning("Reranking failed; using hybrid retrieval order: %s", exc)
                citations = candidates[:hybrid_search_top]
        else:
            citations = candidates[:hybrid_search_top]

        docs = [
            f"Source: {citation.source_path}\nTitle: {citation.title}\nContent: {citation.content}"
            for citation in citations
        ]
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
        return ChatResponse(answer=completion.choices[0].message.content or "", citations=citations)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Chat request failed")
        raise HTTPException(status_code=500, detail=f"Chat request failed: {exc}") from exc
