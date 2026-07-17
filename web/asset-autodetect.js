const MODEL_ID = "Xenova/clip-vit-base-patch32";
const TRANSFORMERS_URL = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.1/+esm";

export const CATEGORY_PROFILES = {
  robot_biped: {
    label: "Robot bipède",
    candidate: "a full body biped humanoid robot",
    dimensions: { width: 0.82, height: 2.25, depth: 0.58 },
    material: "metal_armored",
    geometry: "articulated_biped",
    rig: "rigid_biped",
    collision: "capsule",
    destruction: "detachable",
    animations: ["idle", "walk", "run", "attack", "crawl", "shutdown"],
    parts: ["head", "sensor", "torso", "left_arm", "right_arm", "left_leg", "right_leg"],
    sounds: ["servo", "step", "impact", "electric"],
    damage: "Une jambe détruite réduit la vitesse ; deux jambes détruites déclenchent crawl ; le capteur réduit la détection ; le torse provoque shutdown.",
    integration: "replace_procedural",
  },
  robot_quadruped: {
    label: "Robot quadrupède",
    candidate: "a low wide quadruped robot or mechanical animal",
    dimensions: { width: 1.45, height: 0.72, depth: 1.75 },
    material: "metal_armored",
    geometry: "articulated_quadruped",
    rig: "rigid_quadruped",
    collision: "capsule",
    destruction: "detachable",
    animations: ["idle", "walk", "run", "attack", "shutdown"],
    parts: ["body", "sensor", "left_front_leg", "right_front_leg", "left_rear_leg", "right_rear_leg"],
    sounds: ["servo", "step", "impact", "electric"],
    damage: "Chaque patte détruite ralentit le robot ; plusieurs pattes détruites dégradent fortement la locomotion ; le capteur réduit la détection.",
    integration: "replace_procedural",
  },
  character_humanoid: {
    label: "Personnage humanoïde",
    candidate: "a full body human character or technician",
    dimensions: { width: 0.68, height: 1.8, depth: 0.4 },
    material: "technical_fabric",
    geometry: "articulated_biped",
    rig: "humanoid",
    collision: "capsule",
    destruction: "localized",
    animations: ["idle", "walk", "run", "interact", "fall"],
    parts: ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"],
    sounds: ["step", "impact", "ambience"],
    damage: "Tête, torse et membres reçoivent des dégâts localisés ; une jambe blessée réduit la vitesse.",
    integration: "bridge_module",
  },
  fps_viewmodel: {
    label: "Vue FPS — main et objet",
    candidate: "a first person view hand holding a flashlight tool or weapon",
    dimensions: { width: 0.34, height: 0.3, depth: 0.62 },
    material: "metal_light",
    geometry: "held_tool",
    rig: "fps_hand",
    collision: "none",
    destruction: "localized",
    animations: ["idle", "use", "bash", "inspect"],
    parts: ["forearm", "hand", "tool_body", "battery", "lens", "control"],
    sounds: ["servo", "impact", "electric"],
    damage: "La lentille détruite désactive la lumière ; la batterie détruite coupe l'alimentation ; le corps de l'outil peut se détacher.",
    integration: "fps_viewmodel",
  },
  articulated_machine: {
    label: "Machine articulée",
    candidate: "an industrial articulated robot arm or factory machine",
    dimensions: { width: 1.8, height: 2.4, depth: 1.4 },
    material: "metal_armored",
    geometry: "articulated_machine",
    rig: "articulated_machine",
    collision: "local_boxes",
    destruction: "detachable",
    animations: ["idle", "work", "alarm", "shutdown"],
    parts: ["base", "column", "upper_arm", "lower_arm", "wrist", "tool", "sensor"],
    sounds: ["hydraulic", "servo", "alarm", "impact"],
    damage: "Les bras, le poignet, l'outil et le capteur sont indépendants ; la base détruite arrête la machine.",
    integration: "bridge_module",
  },
  prop: {
    label: "Objet ou accessoire",
    candidate: "a standalone game prop object or handheld tool",
    dimensions: { width: 0.6, height: 0.6, depth: 0.6 },
    material: "metal_light",
    geometry: "modular_detachable",
    rig: "rigid_segmented",
    collision: "local_boxes",
    destruction: "localized",
    animations: ["idle", "use", "break"],
    parts: ["body", "handle", "front_module", "rear_module"],
    sounds: ["impact", "electric"],
    damage: "Les parties listées peuvent casser ou se détacher sans supprimer tout l'objet.",
    integration: "bridge_module",
  },
  wall: {
    label: "Mur ou cloison",
    candidate: "a wall panel brick wall drywall or modular building wall",
    dimensions: { width: 3.0, height: 2.5, depth: 0.18 },
    material: "drywall",
    geometry: "cellular_wall",
    rig: "none",
    collision: "segmented_cells",
    destruction: "segmented_wall",
    animations: ["break"],
    parts: ["cell_01", "cell_02", "cell_03", "cell_04", "frame"],
    sounds: ["impact"],
    damage: "Chaque cellule peut ouvrir un trou local ; le comportement dépend du matériau choisi.",
    integration: "bridge_module",
  },
  door: {
    label: "Porte ou sas",
    candidate: "an industrial door security door or airlock",
    dimensions: { width: 1.25, height: 2.3, depth: 0.22 },
    material: "metal_armored",
    geometry: "hinged_door",
    rig: "hinge",
    collision: "local_boxes",
    destruction: "localized",
    animations: ["open", "close", "lock", "unlock"],
    parts: ["frame", "door_panel", "hinge", "lock", "reader", "status_light"],
    sounds: ["hydraulic", "servo", "impact"],
    damage: "Le verrou peut être neutralisé séparément ; le panneau peut être endommagé selon son matériau.",
    integration: "bridge_module",
  },
  environment: {
    label: "Module d'environnement",
    candidate: "an industrial room corridor bunker environment module",
    dimensions: { width: 4.0, height: 3.0, depth: 4.0 },
    material: "concrete",
    geometry: "environment_module",
    rig: "none",
    collision: "local_boxes",
    destruction: "material_advanced",
    animations: ["idle", "alarm"],
    parts: ["floor", "ceiling", "left_wall", "right_wall", "service_panel"],
    sounds: ["ambience", "alarm", "electric"],
    damage: "Les éléments porteurs restent intacts ; les panneaux légers et accessoires peuvent être détruits localement.",
    integration: "bridge_module",
  },
  gui_panel: {
    label: "Console, écran ou interface 3D",
    candidate: "a control console computer terminal screen or user interface panel",
    dimensions: { width: 1.2, height: 1.0, depth: 0.45 },
    material: "technical_plastic",
    geometry: "technical_panel",
    rig: "none",
    collision: "box",
    destruction: "localized",
    animations: ["idle", "boot", "alarm", "shutdown"],
    parts: ["housing", "screen", "keyboard", "buttons", "status_light"],
    sounds: ["electric", "alarm", "servo"],
    damage: "L'écran, les commandes et le boîtier sont indépendants ; un écran détruit désactive l'affichage.",
    integration: "bridge_module",
  },
};

const LABEL_TO_CATEGORY = Object.fromEntries(
  Object.entries(CATEGORY_PROFILES).map(([key, value]) => [value.candidate, key]),
);

let classifierPromise = null;

function progressSafe(callback, payload) {
  try { callback?.(payload); } catch (_) { /* UI callbacks must never abort detection. */ }
}

async function loadClassifier(onProgress) {
  if (!classifierPromise) {
    classifierPromise = (async () => {
      progressSafe(onProgress, { stage: "model", message: "Chargement du moteur visuel local…", progress: 0.05 });
      const { pipeline, env } = await import(TRANSFORMERS_URL);
      env.allowLocalModels = false;
      env.useBrowserCache = true;
      const classifier = await pipeline("zero-shot-image-classification", MODEL_ID, {
        progress_callback: (event) => {
          const ratio = Number.isFinite(event?.progress) ? event.progress / 100 : 0.2;
          progressSafe(onProgress, {
            stage: "model",
            message: event?.file ? `Chargement IA : ${event.file}` : "Chargement du moteur visuel local…",
            progress: Math.max(0.05, Math.min(0.75, ratio * 0.75)),
          });
        },
      });
      return classifier;
    })();
  }
  return classifierPromise;
}

function slugText(value) {
  return String(value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function filenameScores(files) {
  const scores = Object.fromEntries(Object.keys(CATEGORY_PROFILES).map((key) => [key, 0]));
  const text = slugText(files.map((file) => file.name).join(" "));
  const rules = {
    robot_biped: ["specter", "biped", "humanoid_robot", "android", "endoskeleton"],
    robot_quadruped: ["crawler", "quadruped", "spider_robot", "drone_legged"],
    character_humanoid: ["character", "person", "technician", "human", "operator"],
    fps_viewmodel: ["fps", "first_person", "hand", "flashlight", "weapon", "viewmodel"],
    articulated_machine: ["machine", "robot_arm", "industrial_arm", "manipulator"],
    prop: ["prop", "object", "tool", "crate", "battery", "lamp"],
    wall: ["wall", "brick", "drywall", "placo", "cloison"],
    door: ["door", "gate", "airlock", "sas", "porte"],
    environment: ["environment", "room", "corridor", "hall", "bunker", "factory"],
    gui_panel: ["console", "screen", "terminal", "panel", "monitor", "gui"],
  };
  for (const [category, words] of Object.entries(rules)) {
    for (const word of words) if (text.includes(word)) scores[category] += 0.18;
  }
  return scores;
}

function inferReferenceMode(files) {
  const names = slugText(files.map((file) => file.name).join(" "));
  const orthographicHits = ["front", "face", "right", "side", "profil", "back", "rear", "arriere", "three_quarter", "3_4"].filter((word) => names.includes(word)).length;
  if (files.length >= 4 && orthographicHits >= 3) return "orthographic_four";
  if (files.length >= 3) return "multi_view";
  return files.length === 1 ? "single_view" : "multi_view";
}

async function classifyOne(classifier, file) {
  const url = URL.createObjectURL(file);
  try {
    return await classifier(url, Object.keys(LABEL_TO_CATEGORY), {
      hypothesis_template: "This is an image of {}.",
    });
  } finally {
    URL.revokeObjectURL(url);
  }
}

function normalizeScores(scores) {
  const values = Object.values(scores);
  const sum = values.reduce((total, value) => total + Math.max(0, value), 0) || 1;
  return Object.fromEntries(Object.entries(scores).map(([key, value]) => [key, Math.max(0, value) / sum]));
}

export async function detectAsset(files, onProgress = null) {
  if (!Array.isArray(files) || files.length === 0) throw new Error("Aucune image à analyser.");
  const usable = files.slice(0, 4);
  const heuristic = filenameScores(files);
  const scores = Object.fromEntries(Object.keys(CATEGORY_PROFILES).map((key) => [key, heuristic[key] || 0]));
  let engine = "heuristics";
  let modelError = "";

  try {
    const classifier = await loadClassifier(onProgress);
    engine = MODEL_ID;
    for (let index = 0; index < usable.length; index += 1) {
      progressSafe(onProgress, {
        stage: "analysis",
        message: `Analyse visuelle ${index + 1}/${usable.length}…`,
        progress: 0.76 + (index / usable.length) * 0.2,
      });
      const predictions = await classifyOne(classifier, usable[index]);
      for (const prediction of predictions) {
        const category = LABEL_TO_CATEGORY[prediction.label];
        if (category) scores[category] += Number(prediction.score || 0) / usable.length;
      }
    }
  } catch (error) {
    modelError = String(error?.message || error);
    progressSafe(onProgress, { stage: "fallback", message: "IA locale indisponible : utilisation de l'analyse rapide.", progress: 0.9 });
  }

  const normalized = normalizeScores(scores);
  const ranking = Object.entries(normalized)
    .sort((a, b) => b[1] - a[1])
    .map(([category, score]) => ({ category, label: CATEGORY_PROFILES[category].label, score }));
  const best = ranking[0];
  progressSafe(onProgress, { stage: "done", message: "Analyse terminée.", progress: 1 });
  return {
    category: best.category,
    confidence: best.score,
    ranking,
    referenceMode: inferReferenceMode(files),
    engine,
    modelError,
    profile: structuredClone(CATEGORY_PROFILES[best.category]),
  };
}

export function profileFor(category) {
  const profile = CATEGORY_PROFILES[category];
  if (!profile) throw new Error(`Catégorie inconnue : ${category}`);
  return structuredClone(profile);
}

export function inferGeneratorProfile(category, assetName) {
  const name = slugText(assetName);
  if (category === "robot_biped") return name.includes("specter") ? "specter_biped" : "generic_biped";
  if (category === "robot_quadruped") return name.includes("crawler") ? "crawler7" : "generic_quadruped";
  return {
    character_humanoid: "generic_character",
    fps_viewmodel: "fps_viewmodel",
    articulated_machine: "articulated_machine",
    prop: "generic_prop",
    wall: "segmented_wall",
    door: "industrial_door",
    environment: "environment_module",
    gui_panel: "gui_panel",
  }[category];
}
