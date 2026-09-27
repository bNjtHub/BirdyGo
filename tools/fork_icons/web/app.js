"use strict";

const copy = {
  fr: {
    workshop: "Atelier SVG", local: "Sur ton ordinateur", import: "Ouvrir un projet",
    project: "Enregistrer le projet", bundle: "Exporter le lot", birds: "Les oiseaux",
    search: "Chercher un oiseau", searchPlaceholder: "Nom français ou scientifique",
    allFamilies: "Tous les gabarits", template: "Gabarit", addSpecies: "Ajouter une espèce",
    draftHint: "Tes réglages restent dans ce navigateur. Enregistre le projet pour les retrouver ailleurs.",
    svg: "Exporter ce SVG", light: "Brume · fond clair", dark: "Encre · fond sombre",
    vector: "Vectoriel, à toutes les tailles", realSizes: "À taille réelle",
    sizeHint: "Vérifie le bec, l’œil et la silhouette.", heard: "Entendu",
    reference: "Planche de référence", openSource: "Consulter la source", adjust: "Ajuster",
    reset: "Réinitialiser", templateHint: "Proposé selon l’espèce, son genre ou sa famille.",
    shape: "Silhouette", colors: "Couleurs du plumage", referenceDetails: "Noms et provenance",
    soundBars: "Afficher les barres sonores",
    plumageStyle: "Rendu du plumage", flatPlumage: "Aplats", softPlumage: "Plumage doux",
    softPlumageHint: "Adoucit seulement les raccords du plumage, avec les couleurs de l’oiseau.",
    legacyHint: "Les 15 dessins d’origine sont conservés. Modifier une forme ou une couleur passe au gabarit paramétrable.",
    scientificName: "Nom scientifique", commonName: "Nom courant",
    newHint: "Un gabarit neutre sera proposé. Documente la source avant de choisir les couleurs.",
    cancel: "Annuler", create: "Créer", noResults: "Aucun oiseau correspondant.",
    needsReview: "À relire", noSource: "Source à documenter. Les couleurs sont une proposition de travail.",
    saved: "Projet enregistré avec les palettes et les réglages de silhouette.",
    restored: "Projet ouvert.", exporting: "Préparation des SVG et de l’index…",
    exported: "Lot exporté. Les fichiers du dépôt restent inchangés.",
    edited: "Brouillon conservé dans ce navigateur.", original: "Dessin d’origine rétabli.",
    storageError: "Le navigateur ne peut pas conserver le brouillon. Enregistre le projet pour garder tes réglages.",
    error: "Impossible de terminer : ", loadError: "Le serveur local ne répond pas. Relance python tools/fork_icons/app.py.",
    invalidProject: "Ce fichier n’est pas un projet BirdyGo SVG valide.",
    head_scale: "Tête", body_scale: "Corps", beak_length: "Longueur du bec",
    tail_length: "Longueur de la queue", wing_scale: "Aile", leg_length: "Longueur des pattes",
    crown: "Calotte", cheek: "Joue", throat: "Gorge", breast: "Poitrine", belly: "Ventre",
    back: "Dos", wing: "Aile", wing_bar: "Barre alaire", tail: "Queue", beak: "Bec", legs: "Pattes", eye: "Œil",
    common_name_fr: "Nom français", common_name_en: "Nom anglais", source_url: "Lien vers la planche",
    source_title: "Ouvrage", source_author: "Auteur", source_license: "Licence / domaine public",
    source_plate: "Planche ou page", plumage: "Plumage représenté",
  },
  en: {
    workshop: "SVG workshop", local: "On your computer", import: "Open project",
    project: "Save project", bundle: "Export bundle", birds: "The birds",
    search: "Find a bird", searchPlaceholder: "Common or scientific name",
    allFamilies: "All templates", template: "Template", addSpecies: "Add species",
    draftHint: "Your adjustments stay in this browser. Save the project to open it elsewhere.",
    svg: "Export this SVG", light: "Mist · light background", dark: "Ink · dark background",
    vector: "Vector artwork, at every size", realSizes: "At actual size",
    sizeHint: "Check the beak, eye and silhouette.", heard: "Heard",
    reference: "Reference plate", openSource: "View source", adjust: "Adjust",
    reset: "Reset", templateHint: "Suggested from the species, genus or family.",
    shape: "Silhouette", colors: "Plumage colors", referenceDetails: "Names and provenance",
    soundBars: "Show sound bars",
    plumageStyle: "Plumage style", flatPlumage: "Flat colors", softPlumage: "Soft plumage",
    softPlumageHint: "Softens only the plumage transitions, using this bird’s colors.",
    legacyHint: "The 15 original drawings are preserved. Changing a shape or color switches to the adjustable template.",
    scientificName: "Scientific name", commonName: "Common name",
    newHint: "A neutral template will be suggested. Document a source before choosing colors.",
    cancel: "Cancel", create: "Create", noResults: "No matching birds.",
    needsReview: "Needs review", noSource: "Source not documented. Colors are a working draft.",
    saved: "Project saved with palettes and silhouette adjustments.", restored: "Project opened.",
    exporting: "Preparing SVGs and the index…", exported: "Bundle exported. Repository files are unchanged.",
    edited: "Draft kept in this browser.", original: "Original drawing restored.",
    storageError: "The browser cannot store this draft. Save the project to keep your adjustments.",
    error: "Could not finish: ", loadError: "The local server is not responding. Run python tools/fork_icons/app.py again.",
    invalidProject: "This is not a valid BirdyGo SVG project.",
    head_scale: "Head", body_scale: "Body", beak_length: "Beak length",
    tail_length: "Tail length", wing_scale: "Wing", leg_length: "Leg length",
    crown: "Crown", cheek: "Cheek", throat: "Throat", breast: "Breast", belly: "Belly",
    back: "Back", wing: "Wing", wing_bar: "Wing bar", tail: "Tail", beak: "Beak", legs: "Legs", eye: "Eye",
    common_name_fr: "French name", common_name_en: "English name", source_url: "Plate URL",
    source_title: "Publication", source_author: "Author", source_license: "License / public domain",
    source_plate: "Plate or page", plumage: "Plumage shown",
  },
};
const $ = id => document.getElementById(id);
const state = { lang: "fr", catalog: null, drafts: {}, current: null, rendered: null,
  imageUrl: null, request: 0, controller: null, timer: null };
const t = key => copy[state.lang][key] || key;
const normalize = value => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
const metadataKeys = ["common_name_fr", "common_name_en", "source_url", "source_title",
  "source_author", "source_license", "source_plate", "plumage"];

function message(text, error = false) {
  $("message").textContent = text;
  $("message").classList.toggle("error", error);
}

async function api(route, body, signal) {
  const options = { signal };
  if (body !== undefined) Object.assign(options, { method: "POST",
    headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  let response;
  try { response = await fetch(route, options); }
  catch (error) { if (error.name === "AbortError") throw error; throw new Error(t("loadError")); }
  if (!response.ok) {
    const result = await response.json().catch(() => ({}));
    throw new Error(result.error || `HTTP ${response.status}`);
  }
  return response;
}

function translate() {
  document.documentElement.lang = state.lang;
  document.title = `BirdyGo · ${t("workshop")}`;
  document.querySelectorAll("[data-i18n]").forEach(el => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll("[data-placeholder]").forEach(el => { el.placeholder = t(el.dataset.placeholder); });
  $("language").value = state.lang;
}

function displayName(row) {
  return row[`common_name_${state.lang}`] || row.scientific_name;
}

function allRows() {
  const rows = new Map(state.catalog.species.map(row => [row.scientific_name, row]));
  for (const draft of Object.values(state.drafts)) {
    const name = draft.scientific_name;
    rows.set(name, { ...(rows.get(name) || { scientific_name: name }),
      ...(draft.metadata || {}), template: draft.template || rows.get(name)?.template });
  }
  return [...rows.values()];
}

function renderList() {
  const query = normalize($("search").value);
  const template = $("family-filter").value;
  const rows = allRows();
  $("species-count").textContent = rows.length;
  const list = $("species-list");
  const scroll = list.scrollTop;
  list.replaceChildren();
  rows.filter(row => (!template || row.template === template) &&
    normalize(`${row.scientific_name} ${row.common_name_fr} ${row.common_name_en}`).includes(query))
    .forEach(row => {
      const wrapper = document.createElement("div"); wrapper.setAttribute("role", "listitem");
      const button = document.createElement("button");
      button.className = "species-choice";
      button.classList.toggle("active", row.scientific_name === state.current?.scientific_name);
      button.classList.toggle("edited", Boolean(state.drafts[row.scientific_name]));
      button.setAttribute("aria-pressed", String(row.scientific_name === state.current?.scientific_name));
      button.textContent = displayName(row);
      const latin = document.createElement("small"); latin.textContent = row.scientific_name;
      button.append(latin); button.addEventListener("click", () => selectSpecies(row.scientific_name));
      wrapper.append(button); list.append(wrapper);
    });
  if (!list.children.length) {
    const empty = document.createElement("p"); empty.className = "empty";
    empty.textContent = t("noResults"); list.append(empty);
  }
  list.scrollTop = scroll;
}

function persist() {
  try { localStorage.setItem("birdygo-svg-project-v1", JSON.stringify({ version: 1,
    drafts: Object.values(state.drafts), lang: state.lang })); }
  catch { message(t("storageError"), true); return false; }
  return true;
}

function changed() {
  state.drafts[state.current.scientific_name] = structuredClone(state.current);
  if (persist()) message(t("edited"));
  clearTimeout(state.timer);
  // Invalidate an in-flight response immediately, not when the debounce fires.
  state.request++;
  state.controller?.abort();
  $("download-svg").disabled = true;
  state.timer = setTimeout(() => renderPreview(false), 110);
  renderList();
}

function buildControls(row) {
  const template = $("template"); template.replaceChildren();
  if (!row.template) template.add(new Option("Mystère / Mystery", ""));
  state.catalog.templates.forEach(item => template.add(new Option(item.label || item.id, item.id)));
  template.value = row.template || "";
  $("sound-bars").checked = state.current.show_sound_bars ?? (row.show_sound_bars !== "false");
  $("sound-bars").disabled = false;
  $("plumage-style").value = state.current.plumage_style ?? (row.plumage_style || "flat");
  $("plumage-style").disabled = false;
  $("morphology").replaceChildren();
  for (const [key, limits] of Object.entries(state.catalog.controls)) {
    const group = document.createElement("div"); group.className = "control";
    const label = document.createElement("label"); label.htmlFor = `shape-${key}`; label.textContent = t(key);
    const output = document.createElement("output"); output.htmlFor = `shape-${key}`;
    const input = document.createElement("input"); input.type = "range"; input.id = `shape-${key}`;
    input.min = limits.min; input.max = limits.max; input.step = 0.01;
    input.value = state.current.adjustments?.[key] ?? limits.default;
    output.textContent = `${Math.round(Number(input.value) * 100)} %`;
    input.addEventListener("input", () => {
      state.current.adjustments ||= {}; state.current.adjustments[key] = Number(input.value);
      output.textContent = `${Math.round(Number(input.value) * 100)} %`; changed();
    });
    label.append(output); group.append(label, input); $("morphology").append(group);
  }
  $("colors").replaceChildren();
  for (const key of state.catalog.zones) {
    const label = document.createElement("label"); label.className = "color-field";
    const input = document.createElement("input"); input.type = "color";
    input.value = row[key] || "#818a94"; input.setAttribute("aria-label", t(key));
    const name = document.createElement("span"); name.textContent = t(key);
    input.addEventListener("input", () => {
      state.current.colors ||= {}; state.current.colors[key] = input.value;
      changed();
    });
    label.append(input, name); $("colors").append(label);
  }
  $("metadata").replaceChildren();
  for (const key of metadataKeys) {
    const label = document.createElement("label"); label.textContent = t(key);
    const input = document.createElement("input"); input.value = row[key] || "";
    input.maxLength = 2000;
    input.addEventListener("change", () => {
      state.current.metadata ||= {}; state.current.metadata[key] = input.value; changed();
    });
    label.append(input); $("metadata").append(label);
  }
}

async function renderPreview(controls) {
  const sequence = ++state.request;
  state.controller?.abort();
  state.controller = new AbortController();
  $("download-svg").disabled = true;
  try {
    const response = await api("/api/preview", state.current, state.controller.signal);
    const result = await response.json();
    if (sequence !== state.request) return;
    state.rendered = result;
    const nextUrl = URL.createObjectURL(new Blob([result.svg], { type: "image/svg+xml" }));
    const previousUrl = state.imageUrl; state.imageUrl = nextUrl;
    document.querySelectorAll(".bird-preview").forEach(img => { img.src = nextUrl; });
    if (previousUrl) URL.revokeObjectURL(previousUrl);
    const row = result.row;
    $("bird-name").textContent = displayName(row);
    $("scientific-name").textContent = row.scientific_name;
    $("current-family").textContent = `BIRDYGO / ${row.family || row.template || "SVG"}`;
    $("source-description").textContent = [row.source_title, row.source_author, row.source_plate,
      row.source_license].filter(Boolean).join(" · ") || t("noSource");
    $("plumage-description").textContent = row.plumage || "";
    $("review-status").textContent = t("needsReview");
    const link = $("source-link");
    const sourceIsWeb = /^https?:\/\//i.test(row.source_url || "");
    link.hidden = !sourceIsWeb;
    if (sourceIsWeb) link.href = row.source_url; else link.removeAttribute("href");
    if (controls) buildControls(row);
    $("download-svg").disabled = false;
  } catch (error) {
    if (error.name !== "AbortError" && sequence === state.request) message(t("error") + error.message, true);
  }
}

async function selectSpecies(name) {
  clearTimeout(state.timer);
  state.current = structuredClone(state.drafts[name] || { scientific_name: name });
  message(""); renderList(); await renderPreview(true);
}

function download(data, filename, type) {
  const blob = data instanceof Blob ? data : new Blob([data], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a"); link.href = url; link.download = filename;
  document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function validateProject(project) {
  if (!project || project.version !== 1 || !Array.isArray(project.drafts) || project.drafts.length > 500)
    throw new Error(t("invalidProject"));
  const names = new Set();
  for (const draft of project.drafts) {
    if (!draft || typeof draft.scientific_name !== "string" || !draft.scientific_name.trim()
        || names.has(draft.scientific_name)) throw new Error(t("invalidProject"));
    names.add(draft.scientific_name);
  }
  return project;
}

async function start() {
  ["download-svg", "export-bundle", "new-species", "save-project", "import-project", "reset"]
    .forEach(id => { $(id).disabled = true; });
  try {
    const stored = localStorage.getItem("birdygo-svg-project-v1");
    if (stored) {
      const project = validateProject(JSON.parse(stored));
      state.drafts = Object.fromEntries(project.drafts.map(draft => [draft.scientific_name, draft]));
      if (copy[project.lang]) state.lang = project.lang;
    }
  } catch { /* A corrupt browser draft never prevents opening the catalog. */ }
  translate();
  try {
    state.catalog = await (await api("/api/catalog")).json();
    state.catalog.templates.forEach(item => $("family-filter").add(new Option(item.label || item.id, item.id)));
    ["export-bundle", "new-species", "save-project", "import-project", "reset"]
      .forEach(id => { $(id).disabled = false; });
    await selectSpecies(state.catalog.species.find(row => row.scientific_name === "Erithacus rubecula")?.scientific_name
      || state.catalog.species[0].scientific_name);
  } catch (error) { message(t("error") + error.message, true); }
}

$("search").addEventListener("input", () => { if (state.catalog) renderList(); });
$("family-filter").addEventListener("change", renderList);
$("language").addEventListener("change", () => {
  state.lang = $("language").value; translate(); persist();
  if (state.catalog) { renderList(); if (state.rendered) { buildControls(state.rendered.row); renderPreview(false); } }
});
$("template").addEventListener("change", () => { state.current.template = $("template").value; changed(); });
$("sound-bars").addEventListener("change", () => {
  state.current.show_sound_bars = $("sound-bars").checked;
  changed();
});
$("plumage-style").addEventListener("change", () => {
  state.current.plumage_style = $("plumage-style").value;
  changed();
});
$("reset").addEventListener("click", () => {
  const name = state.current.scientific_name; delete state.drafts[name]; persist();
  selectSpecies(name).then(() => message(t("original")));
});
$("download-svg").addEventListener("click", () => {
  if (state.rendered) download(state.rendered.svg, state.rendered.filename, "image/svg+xml");
});
$("save-project").addEventListener("click", () => {
  download(JSON.stringify({ version: 1, drafts: Object.values(state.drafts) }, null, 2),
    "birdygo-icons-project.json", "application/json"); message(t("saved"));
});
$("import-project").addEventListener("click", () => $("project-file").click());
$("project-file").addEventListener("change", async event => {
  const file = event.target.files[0]; if (!file) return;
  try {
    if (file.size > 1024 * 1024) throw new Error(t("invalidProject"));
    const project = validateProject(JSON.parse(await file.text()));
    // Validate every imported row before replacing the current project.
    for (const draft of project.drafts) await api("/api/preview", draft);
    state.drafts = Object.fromEntries(project.drafts.map(draft => [draft.scientific_name, draft]));
    persist(); await selectSpecies(project.drafts[0]?.scientific_name || state.catalog.species[0].scientific_name);
    message(t("restored"));
  } catch (error) { message(t("error") + error.message, true); }
  event.target.value = "";
});
$("export-bundle").addEventListener("click", async () => {
  $("export-bundle").disabled = true; message(t("exporting"));
  try {
    const result = await api("/api/export", { drafts: Object.values(state.drafts) });
    download(await result.blob(), "birdygo-species-icons.zip"); message(t("exported"));
  } catch (error) { message(t("error") + error.message, true); }
  finally { $("export-bundle").disabled = false; }
});
$("new-species").addEventListener("click", () => { $("new-dialog").showModal(); $("new-scientific").focus(); });
$("cancel-new").addEventListener("click", () => $("new-dialog").close());
$("new-form").addEventListener("submit", async event => {
  event.preventDefault();
  const name = $("new-scientific").value.trim().replace(/\s+/g, " ");
  const draft = { scientific_name: name,
    metadata: { [`common_name_${state.lang}`]: $("new-common").value.trim() } };
  try {
    await api("/api/preview", draft);
    state.drafts[name] = draft; persist(); $("new-dialog").close(); event.target.reset();
    $("search").value = ""; $("family-filter").value = ""; await selectSpecies(name);
  } catch (error) { message(t("error") + error.message, true); }
});

start();
