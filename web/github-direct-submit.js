const OWNER = "BertrandMarconnet";
const REPO = "VideoGame";
const API = "https://api.github.com";
const REPOSITORY = `${OWNER}/${REPO}`;
const WORKFLOW = "generate-game-asset-unified.yml";
const TOKEN_KEY = "blackout.assetGenerator.githubToken";
const API_VERSION = "2022-11-28";

export const tokenCreationUrl =
  "https://github.com/settings/personal-access-tokens/new" +
  "?name=Blackout+Protocol+Asset+Generator" +
  "&description=Upload+des+images+dans+VideoGame+et+suivi+de+la+generation+GitHub+Actions" +
  "&target_name=BertrandMarconnet" +
  "&expires_in=90" +
  "&contents=write" +
  "&actions=read";

function headers(token, extra = {}) {
  return {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": API_VERSION,
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...extra,
  };
}

function permissionHelp(path, operation, acceptedPermissions = "") {
  const actionRequest = path.includes("/actions/");
  if (actionRequest) {
    return [
      `GitHub refuse ${operation || "la lecture de GitHub Actions"}.`,
      "Dans le jeton, sélectionnez Resource owner : BertrandMarconnet, Repository access : Only select repositories → VideoGame, puis Actions : Read-only.",
      acceptedPermissions ? `Permission attendue par GitHub : ${acceptedPermissions}.` : "",
    ].filter(Boolean).join(" ");
  }
  return [
    `GitHub refuse ${operation || "l’écriture dans le dépôt"}.`,
    "Le jeton utilisé n’a pas réellement la permission d’écriture nécessaire, même si le compte possède le dépôt.",
    "Créez ou modifiez un jeton à granularité fine avec Resource owner : BertrandMarconnet, Repository access : Only select repositories → VideoGame, puis Contents : Read and write.",
    "Supprimez ensuite l’ancien jeton mémorisé dans le générateur et reconnectez le nouveau.",
    acceptedPermissions ? `Permission attendue par GitHub : ${acceptedPermissions}.` : "",
  ].filter(Boolean).join(" ");
}

async function api(path, {
  token = "",
  method = "GET",
  body = undefined,
  allowAnonymous = false,
  operation = "",
} = {}) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: headers(allowAnonymous ? "" : token, body === undefined ? {} : { "Content-Type": "application/json" }),
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (response.status === 204) return null;
  const text = await response.text();
  let payload = null;
  try { payload = text ? JSON.parse(text) : null; } catch (_) { payload = text; }

  if (!response.ok) {
    const rawMessage = payload?.message || payload || `${response.status} ${response.statusText}`;
    const acceptedPermissions = response.headers.get("x-accepted-github-permissions") || "";
    const requestId = response.headers.get("x-github-request-id") || "";
    const isPermissionError = response.status === 403 && /resource not accessible|forbidden|permission/i.test(String(rawMessage));
    const message = isPermissionError
      ? permissionHelp(path, operation, acceptedPermissions)
      : `GitHub (${operation || path}) : ${rawMessage}${acceptedPermissions ? ` — permissions attendues : ${acceptedPermissions}` : ""}`;
    const error = new Error(`${message}${requestId ? ` [requête ${requestId}]` : ""}`);
    error.status = response.status;
    error.payload = payload;
    error.path = path;
    error.operation = operation;
    error.acceptedPermissions = acceptedPermissions;
    throw error;
  }
  return payload;
}

export function getStoredToken() {
  return sessionStorage.getItem(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY) || "";
}

export function storeToken(token, remember) {
  sessionStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(TOKEN_KEY);
  if (!token) return;
  (remember ? localStorage : sessionStorage).setItem(TOKEN_KEY, token.trim());
}

export function clearStoredToken() {
  sessionStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(TOKEN_KEY);
}

async function verifyContentsWrite(token) {
  // A tiny unattached blob is a harmless write probe. It verifies the token's
  // actual Contents permission instead of the account owner's repository role.
  return api(`/repos/${REPOSITORY}/git/blobs`, {
    token,
    method: "POST",
    body: {
      content: `blackout-asset-generator-permission-probe:${new Date().toISOString()}`,
      encoding: "utf-8",
    },
    operation: "le test de la permission Contents: Read and write",
  });
}

async function verifyActionsRead(token) {
  try {
    await api(`/repos/${REPOSITORY}/actions/workflows/${WORKFLOW}/runs?per_page=1`, {
      token,
      operation: "le suivi des générations GitHub Actions",
    });
    return true;
  } catch (error) {
    if (error.status !== 403) throw error;
    // VideoGame is public: the workflow can still be followed anonymously.
    await api(`/repos/${REPOSITORY}/actions/workflows/${WORKFLOW}/runs?per_page=1`, {
      allowAnonymous: true,
      operation: "le suivi public des générations GitHub Actions",
    });
    return false;
  }
}

export async function validateGitHubToken(token) {
  const clean = String(token || "").trim();
  if (!clean) throw new Error("Collez d’abord le jeton GitHub.");

  const [user, repository] = await Promise.all([
    api("/user", { token: clean, operation: "l’identification du compte" }),
    api(`/repos/${REPOSITORY}`, { token: clean, operation: "l’accès au dépôt VideoGame" }),
  ]);

  if (String(repository?.full_name || "").toLowerCase() !== REPOSITORY.toLowerCase()) {
    throw new Error("Le jeton ne donne pas accès au dépôt BertrandMarconnet/VideoGame.");
  }
  if (!repository?.permissions?.push && !repository?.permissions?.admin) {
    throw new Error("Le compte lié au jeton ne peut pas écrire dans VideoGame.");
  }

  await verifyContentsWrite(clean);
  const actionsReadable = await verifyActionsRead(clean);

  return {
    login: user.login,
    avatar: user.avatar_url,
    repository: repository.full_name,
    canPush: true,
    contentsWriteVerified: true,
    actionsReadable,
  };
}

function slugify(value) {
  return String(value || "asset")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 54) || "asset";
}

function safeFilename(name, index) {
  const raw = String(name || `file_${index}`);
  const dot = raw.lastIndexOf(".");
  const extension = dot >= 0 ? raw.slice(dot).toLowerCase().replace(/[^.a-z0-9]/g, "") : "";
  const stem = slugify(dot >= 0 ? raw.slice(0, dot) : raw).slice(0, 42) || `file_${index}`;
  return `${String(index).padStart(2, "0")}_${stem}${extension}`;
}

function progressSafe(callback, payload) {
  try { callback?.(payload); } catch (_) { /* UI progress must never stop the upload. */ }
}

async function fileToBase64(file) {
  const buffer = new Uint8Array(await file.arrayBuffer());
  const chunk = 0x8000;
  let binary = "";
  for (let offset = 0; offset < buffer.length; offset += chunk) {
    binary += String.fromCharCode(...buffer.subarray(offset, offset + chunk));
  }
  return btoa(binary);
}

async function createBlob(token, entry) {
  return api(`/repos/${REPOSITORY}/git/blobs`, {
    token,
    method: "POST",
    body: { content: entry.content, encoding: entry.encoding },
    operation: `l’envoi de ${entry.path.split("/").pop()}`,
  });
}

async function createJobCommit(token, jobId, entries, onProgress) {
  progressSafe(onProgress, { stage: "upload", message: "Préparation des fichiers…", progress: 0.08 });
  const blobs = [];
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const blob = await createBlob(token, entry);
    blobs.push({ path: entry.path, mode: "100644", type: "blob", sha: blob.sha });
    progressSafe(onProgress, {
      stage: "upload",
      message: `Envoi ${index + 1}/${entries.length} : ${entry.path.split("/").pop()}`,
      progress: 0.1 + ((index + 1) / entries.length) * 0.55,
    });
  }

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const reference = await api(`/repos/${REPOSITORY}/git/ref/heads/main`, {
      token,
      operation: "la lecture de la branche main",
    });
    const parentSha = reference.object.sha;
    const parent = await api(`/repos/${REPOSITORY}/git/commits/${parentSha}`, {
      token,
      operation: "la lecture du dernier commit",
    });
    const tree = await api(`/repos/${REPOSITORY}/git/trees`, {
      token,
      method: "POST",
      body: { base_tree: parent.tree.sha, tree: blobs },
      operation: "la création du lot d’images et de réglages",
    });
    const commit = await api(`/repos/${REPOSITORY}/git/commits`, {
      token,
      method: "POST",
      body: { message: `Submit asset job ${jobId}`, tree: tree.sha, parents: [parentSha] },
      operation: "la création de la demande de génération",
    });
    try {
      await api(`/repos/${REPOSITORY}/git/refs/heads/main`, {
        token,
        method: "PATCH",
        body: { sha: commit.sha, force: false },
        operation: "la publication de la demande sur main",
      });
      progressSafe(onProgress, { stage: "commit", message: "Demande enregistrée sur GitHub.", progress: 0.72 });
      return commit;
    } catch (error) {
      if (![409, 422].includes(error.status) || attempt === 3) throw error;
      await new Promise((resolve) => setTimeout(resolve, attempt * 1200));
    }
  }
  throw new Error("Impossible de publier la demande après trois tentatives.");
}

async function publicWorkflowApi(path, token, operation) {
  try {
    return await api(path, { token, operation });
  } catch (error) {
    if (error.status !== 403) throw error;
    return api(path, { allowAnonymous: true, operation: `${operation} en accès public` });
  }
}

async function findWorkflowRun(commitSha, token, onProgress) {
  progressSafe(onProgress, { stage: "workflow", message: "Démarrage de la génération GitHub…", progress: 0.76 });
  for (let attempt = 0; attempt < 36; attempt += 1) {
    const query = new URLSearchParams({ event: "push", head_sha: commitSha, per_page: "10" });
    const payload = await publicWorkflowApi(
      `/repos/${REPOSITORY}/actions/workflows/${WORKFLOW}/runs?${query}`,
      token,
      "la recherche du workflow lancé",
    );
    const run = payload?.workflow_runs?.[0];
    if (run) return run;
    await new Promise((resolve) => setTimeout(resolve, 4000));
  }
  return null;
}

export async function watchWorkflowRun(runId, token, onProgress) {
  for (let attempt = 0; attempt < 300; attempt += 1) {
    const run = await publicWorkflowApi(
      `/repos/${REPOSITORY}/actions/runs/${runId}`,
      token,
      "le suivi du workflow",
    );
    const completed = run.status === "completed";
    progressSafe(onProgress, {
      stage: completed ? "completed" : "generation",
      message: completed
        ? (run.conclusion === "success" ? "Modèle généré et intégré." : `Génération terminée : ${run.conclusion}.`)
        : `Génération en cours : ${run.status}`,
      progress: completed ? 1 : Math.min(0.98, 0.8 + attempt * 0.002),
      run,
    });
    if (completed) return run;
    await new Promise((resolve) => setTimeout(resolve, 10000));
  }
  throw new Error("La génération continue sur GitHub, mais le suivi local a expiré.");
}

export async function submitAssetJob({ token, request, imageFiles, audioFiles = [], onProgress = null }) {
  const cleanToken = String(token || "").trim();
  if (!cleanToken) throw new Error("Connexion GitHub requise.");
  if (!Array.isArray(imageFiles) || imageFiles.length === 0) throw new Error("Ajoutez au moins une image.");
  if (imageFiles.length > 6) throw new Error("Six images maximum.");
  if (audioFiles.length > 8) throw new Error("Huit sons maximum.");

  const slug = slugify(request.asset_name || request.slug);
  const jobId = `${slug}-${new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14)}-${crypto.randomUUID().slice(0, 8)}`;
  const root = `asset_jobs/${jobId}`;
  const imagePaths = imageFiles.map((file, index) => `${root}/input/${safeFilename(file.name, index + 1)}`);
  const audioPaths = audioFiles.map((file, index) => `${root}/audio/${safeFilename(file.name, index + 1)}`);
  const normalizedRequest = {
    ...request,
    schema_version: 1,
    slug,
    job_id: jobId,
    reference_images: imagePaths,
    reference_image_errors: [],
    audio_files: audioPaths,
    audio_file_errors: [],
    issue_number: 0,
    issue_url: "",
    submitted_from: "github_pages_asset_generator",
    submitted_at: new Date().toISOString(),
  };

  const entries = [];
  for (let index = 0; index < imageFiles.length; index += 1) {
    if (imageFiles[index].size > 12 * 1024 * 1024) throw new Error(`${imageFiles[index].name} dépasse 12 Mo.`);
    entries.push({ path: imagePaths[index], encoding: "base64", content: await fileToBase64(imageFiles[index]) });
  }
  for (let index = 0; index < audioFiles.length; index += 1) {
    if (audioFiles[index].size > 24 * 1024 * 1024) throw new Error(`${audioFiles[index].name} dépasse 24 Mo.`);
    entries.push({ path: audioPaths[index], encoding: "base64", content: await fileToBase64(audioFiles[index]) });
  }
  entries.push({
    path: `${root}/request.json`,
    encoding: "utf-8",
    content: `${JSON.stringify(normalizedRequest, null, 2)}\n`,
  });

  const commit = await createJobCommit(cleanToken, jobId, entries, onProgress);
  const run = await findWorkflowRun(commit.sha, cleanToken, onProgress);
  const actionsUrl = run?.html_url || `https://github.com/${REPOSITORY}/actions/workflows/${WORKFLOW}`;
  progressSafe(onProgress, {
    stage: "started",
    message: run ? "Génération démarrée sur GitHub." : "Demande publiée ; ouvrez GitHub Actions pour suivre la génération.",
    progress: 0.8,
    run,
  });
  return {
    jobId,
    slug,
    commitSha: commit.sha,
    commitUrl: `https://github.com/${REPOSITORY}/commit/${commit.sha}`,
    actionsUrl,
    run,
    outputUrl: `https://github.com/${REPOSITORY}/tree/main/assets/generated/${slug}`,
  };
}

function configureTokenHelp() {
  const helpLink = document.querySelector("section.card .help a");
  if (helpLink) {
    helpLink.href = tokenCreationUrl;
    helpLink.textContent = "jeton GitHub préconfiguré";
  }
  const help = helpLink?.closest(".help");
  if (help && !document.getElementById("tokenPermissionHelp")) {
    help.insertAdjacentHTML("beforeend", `
      <div id="tokenPermissionHelp" style="margin-top:9px">
        <b>Réglages obligatoires :</b> Resource owner = BertrandMarconnet · Repository access = Only select repositories → VideoGame · Contents = Read and write · Actions = Read-only.
      </div>`);
  }
  const connectButton = document.getElementById("connect");
  if (connectButton && !document.getElementById("forgetToken")) {
    const forgetButton = document.createElement("button");
    forgetButton.id = "forgetToken";
    forgetButton.type = "button";
    forgetButton.textContent = "OUBLIER L’ANCIEN JETON";
    forgetButton.addEventListener("click", () => {
      clearStoredToken();
      const tokenInput = document.getElementById("token");
      if (tokenInput) tokenInput.value = "";
      window.location.reload();
    });
    connectButton.parentElement?.append(forgetButton);
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", configureTokenHelp, { once: true });
} else {
  configureTokenHelp();
}

export const githubRepository = REPOSITORY;
