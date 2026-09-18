(() => {
  "use strict";
  const button = document.getElementById("themeButton"), saved = localStorage.getItem("docs-theme");
  if (saved === "dark" || (!saved && window.matchMedia?.("(prefers-color-scheme: dark)").matches)) document.documentElement.dataset.theme = "dark";
  button?.addEventListener("click", () => { const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark"; document.documentElement.dataset.theme = next; localStorage.setItem("docs-theme", next); });
  const form = document.querySelector("[data-search-form]"), input = document.querySelector("#site-search"), cards = [...document.querySelectorAll("[data-search-card]")], categories = [...document.querySelectorAll("[data-category]")], empty = document.querySelector("[data-search-empty]");
  if (!form || !input || !cards.length) return;
  input.value = new URLSearchParams(location.search).get("q") || "";
  const filter = () => { const query = input.value.trim().toLowerCase(); let visible = 0; cards.forEach(card => { const match = !query || card.textContent.toLowerCase().includes(query); card.hidden = !match; if (match) visible++; }); categories.forEach(category => { const links = [...category.querySelectorAll("[data-search-card]")]; category.hidden = Boolean(query) && links.every(link => link.hidden); }); if (empty) empty.hidden = visible !== 0; };
  input.addEventListener("input", filter); form.addEventListener("submit", event => event.preventDefault()); filter();
})();
