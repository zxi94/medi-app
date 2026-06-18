"""
Chest X-Ray AI Backend — Google Colab Deployment Notebook
=========================================================
This notebook runs the full AI stack on a Colab T4 GPU:
  1. RAD-DINO (X-ray classification + GradCAM)
  2. Qwen2.5-7B-Instruct (4-bit) — Report Generation + RAG Chatbot
  3. FAISS + multilingual-e5-base — Knowledge Retrieval
  4. FastAPI + ngrok — Public API
  
Deployment:
  1. Open this notebook in Google Colab
  2. Set Runtime → Change runtime type → T4 GPU
  3. Update the configuration cell (ngrok token, Node.js URL, secret)
  4. Run All cells

Architecture:
  Flutter → Node.js → ngrok URL → this Colab FastAPI → AI models
"""

# === CELL 0: Install Dependencies ===
# %% [markdown]
# ## 📦 Install Dependencies

# %%
!pip install -q fastapi uvicorn pyngrok nest-asyncio \
    transformers accelerate bitsandbytes \
    sentence-transformers faiss-cpu \
    albumentations scipy pillow \
    torch torchvision


# === CELL 1: Configuration ===
# %% [markdown]
# ## ⚙️ Configuration
# **IMPORTANT**: Update these values before running.

# %%
import os

# ─── USER CONFIGURATION ───────────────────────────────────────────────────────
# Replace these with your actual values

NGROK_AUTH_TOKEN = "YOUR_NGROK_AUTH_TOKEN_HERE"

# Your Node.js backend URL (where it's publicly accessible)
NODEJS_BACKEND_URL = "http://YOUR_NODEJS_IP:5001"

# Must match AI_SYSTEM_SECRET in your Node.js .env file
AI_SYSTEM_SECRET = "change_me_to_a_strong_secret"

# ─── MODEL PATHS (Google Drive) ───────────────────────────────────────────────
# After mounting, files will be at /content/drive/MyDrive/...
DRIVE_MODEL_DIR = "/content/drive/MyDrive/MediScan_Models"
RADDINO_CHECKPOINT = f"{DRIVE_MODEL_DIR}/best_model_final.pth"
CHATBOT_DATA_DIR = f"{DRIVE_MODEL_DIR}/chatbot_data"

# ─── MODEL CONFIGURATION ──────────────────────────────────────────────────────
QWEN_MODEL_NAME = "Qwen/Qwen2.5-7B-Instruct"
QWEN_FALLBACK_MODEL = "Qwen/Qwen2.5-3B-Instruct"
EMBEDDING_MODEL_NAME = "intfloat/multilingual-e5-base"
RADDINO_HF_NAME = "microsoft/rad-dino"
IMAGE_SIZE = 518

# ─── SERVER ────────────────────────────────────────────────────────────────────
FASTAPI_PORT = 8000

print("✅ Configuration loaded.")
print(f"   Qwen primary:  {QWEN_MODEL_NAME}")
print(f"   Qwen fallback: {QWEN_FALLBACK_MODEL}")
print(f"   Embedding:     {EMBEDDING_MODEL_NAME}")


# === CELL 2: Mount Google Drive ===
# %% [markdown]
# ## 💾 Mount Google Drive & Verify Assets

# %%
from google.colab import drive
drive.mount("/content/drive")

# Verify critical files exist
import os

missing = []
if not os.path.exists(RADDINO_CHECKPOINT):
    missing.append(f"RAD-DINO checkpoint: {RADDINO_CHECKPOINT}")
if not os.path.exists(CHATBOT_DATA_DIR):
    missing.append(f"Chatbot data dir: {CHATBOT_DATA_DIR}")

if missing:
    print("⚠️  Missing files (upload them to Google Drive):")
    for m in missing:
        print(f"   ✗ {m}")
    print(f"\n   Expected structure:")
    print(f"   {DRIVE_MODEL_DIR}/")
    print(f"   ├── best_model_final.pth")
    print(f"   └── chatbot_data/")
    print(f"       ├── documents.json")
    print(f"       ├── metadata.json")
    print(f"       ├── medical_knowledge.json")
    print(f"       └── medical_index.faiss")
else:
    print("✅ All model files found on Google Drive.")

# Optionally copy to local Colab storage for faster I/O
LOCAL_MODEL_DIR = "/content/models"
os.makedirs(LOCAL_MODEL_DIR, exist_ok=True)

import shutil
local_ckpt = f"{LOCAL_MODEL_DIR}/best_model_final.pth"
if not os.path.exists(local_ckpt) and os.path.exists(RADDINO_CHECKPOINT):
    print("📋 Copying RAD-DINO checkpoint to local storage...")
    shutil.copy2(RADDINO_CHECKPOINT, local_ckpt)
    RADDINO_CHECKPOINT = local_ckpt
    print(f"   ✅ Copied to {local_ckpt}")
elif os.path.exists(local_ckpt):
    RADDINO_CHECKPOINT = local_ckpt
    print(f"   ✅ Using cached local checkpoint: {local_ckpt}")


# === CELL 3: Singleton Model Manager ===
# %% [markdown]
# ## 🧠 Singleton Model Manager
# Loads all models once and shares them across services.

# %%
import torch
import torch.nn as nn
import numpy as np
import json
import faiss
import gc

from transformers import AutoModel, AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from sentence_transformers import SentenceTransformer

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"🖥️ Device: {DEVICE}")
if torch.cuda.is_available():
    props = torch.cuda.get_device_properties(0)
    print(f"   GPU: {props.name} ({props.total_mem / 1e9:.1f} GB)")


class ModelManager:
    """Singleton manager for all AI models. Ensures no duplicate loading."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True

        self.raddino_model = None
        self.qwen_model = None
        self.qwen_tokenizer = None
        self.embedder = None
        self.faiss_index = None
        self.documents = None
        self.metadata = None
        self.medical_knowledge = None

    # ── RAD-DINO ──────────────────────────────────────────────────────────
    def load_raddino(self):
        if self.raddino_model is not None:
            print("   ✓ RAD-DINO already loaded")
            return

        print("🔄 Loading RAD-DINO model...")

        class RadDinoModel(nn.Module):
            def __init__(self, num_classes=11, dropout=0.3):
                super().__init__()
                self.backbone = AutoModel.from_pretrained(RADDINO_HF_NAME)
                feat_dim = self.backbone.config.hidden_size
                self.head = nn.Sequential(
                    nn.LayerNorm(feat_dim),
                    nn.Dropout(dropout),
                    nn.Linear(feat_dim, num_classes),
                )
            def forward(self, x):
                out = self.backbone(pixel_values=x)
                return self.head(out.last_hidden_state[:, 0])

        model = RadDinoModel(num_classes=11).to(DEVICE)

        ckpt = torch.load(RADDINO_CHECKPOINT, map_location=DEVICE, weights_only=False)
        if isinstance(ckpt, dict) and "model_state_dict" in ckpt:
            state = ckpt.get("ema_state_dict") or ckpt["model_state_dict"]
        elif isinstance(ckpt, dict):
            state = ckpt
        else:
            state = ckpt

        model.load_state_dict(state)
        model.eval()

        try:
            if hasattr(model.backbone, "gradient_checkpointing_disable"):
                model.backbone.gradient_checkpointing_disable()
        except Exception:
            pass

        self.raddino_model = model
        print("   ✅ RAD-DINO loaded and ready")

    # ── Qwen LLM (4-bit) ─────────────────────────────────────────────────
    def load_qwen(self):
        if self.qwen_model is not None:
            print("   ✓ Qwen already loaded")
            return

        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
        )

        model_name = QWEN_MODEL_NAME
        print(f"🔄 Loading Qwen LLM: {model_name} (4-bit)...")

        try:
            self.qwen_tokenizer = AutoTokenizer.from_pretrained(model_name)
            self.qwen_model = AutoModelForCausalLM.from_pretrained(
                model_name,
                quantization_config=bnb_config,
                device_map="auto",
            )
            print(f"   ✅ {model_name} loaded (4-bit)")
        except Exception as e:
            print(f"   ⚠️ Failed to load {model_name}: {e}")
            print(f"   🔄 Falling back to {QWEN_FALLBACK_MODEL}...")
            model_name = QWEN_FALLBACK_MODEL
            self.qwen_tokenizer = AutoTokenizer.from_pretrained(model_name)
            self.qwen_model = AutoModelForCausalLM.from_pretrained(
                model_name,
                quantization_config=bnb_config,
                device_map="auto",
            )
            print(f"   ✅ {model_name} loaded (4-bit fallback)")

    # ── Embeddings + FAISS ────────────────────────────────────────────────
    def load_embeddings_and_faiss(self):
        if self.embedder is not None:
            print("   ✓ Embeddings + FAISS already loaded")
            return

        print(f"🔄 Loading embeddings: {EMBEDDING_MODEL_NAME}...")
        self.embedder = SentenceTransformer(EMBEDDING_MODEL_NAME)
        print("   ✅ Embedder loaded")

        data_dir = CHATBOT_DATA_DIR
        print(f"🔄 Loading FAISS index + knowledge base from {data_dir}...")

        with open(f"{data_dir}/documents.json", "r", encoding="utf-8") as f:
            self.documents = json.load(f)
        with open(f"{data_dir}/metadata.json", "r", encoding="utf-8") as f:
            self.metadata = json.load(f)
        with open(f"{data_dir}/medical_knowledge.json", "r", encoding="utf-8") as f:
            self.medical_knowledge = json.load(f)

        self.faiss_index = faiss.read_index(f"{data_dir}/medical_index.faiss")

        print(f"   ✅ Loaded {len(self.documents)} documents, "
              f"{len(self.medical_knowledge)} findings, "
              f"FAISS index: {self.faiss_index.ntotal} vectors")

    # ── Load All ──────────────────────────────────────────────────────────
    def load_all(self):
        """Load all models. Call this once during Colab startup."""
        print("\n" + "=" * 60)
        print("  LOADING ALL MODELS")
        print("=" * 60 + "\n")

        self.load_raddino()
        self.load_qwen()
        self.load_embeddings_and_faiss()

        # Memory report
        if torch.cuda.is_available():
            allocated = torch.cuda.memory_allocated() / 1e9
            reserved = torch.cuda.memory_reserved() / 1e9
            print(f"\n📊 GPU Memory: {allocated:.2f} GB allocated, {reserved:.2f} GB reserved")

        gc.collect()
        torch.cuda.empty_cache() if torch.cuda.is_available() else None

        print("\n" + "=" * 60)
        print("  ✅ ALL MODELS LOADED SUCCESSFULLY")
        print("=" * 60)


# Initialize the singleton
models = ModelManager()
models.load_all()


# === CELL 4: RAD-DINO Inference + GradCAM ===
# %% [markdown]
# ## 🔬 RAD-DINO Inference + GradCAM

# %%
import albumentations as A
from albumentations.pytorch import ToTensorV2
from PIL import Image
import io
import base64

try:
    from scipy.ndimage import gaussian_filter
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False

# ── Constants ──────────────────────────────────────────────────────────────
NORM_MEAN = [0.5307, 0.5307, 0.5307]
NORM_STD = [0.2583, 0.2583, 0.2583]

UNIFIED_LABELS = [
    "Aortic enlargement", "Atelectasis", "Calcification", "Cardiomegaly",
    "Consolidation", "Lung Opacity", "Nodule/Mass", "Pleural effusion",
    "Pleural thickening", "Pneumothorax", "Pulmonary fibrosis",
]

HARDCODED_THRESHOLDS = {
    "Aortic enlargement": 0.810, "Atelectasis": 0.855, "Calcification": 0.828,
    "Cardiomegaly": 0.647, "Consolidation": 0.642, "Lung Opacity": 0.665,
    "Nodule/Mass": 0.909, "Pleural effusion": 0.728, "Pleural thickening": 0.715,
    "Pneumothorax": 0.846, "Pulmonary fibrosis": 0.905,
}

THRESHOLDS = np.array([HARDCODED_THRESHOLDS[lb] for lb in UNIFIED_LABELS], dtype=np.float32)

SEVERITY = {
    "Pneumothorax": "URGENT", "Aortic enlargement": "URGENT",
    "Cardiomegaly": "IMPORTANT", "Pleural effusion": "IMPORTANT",
    "Consolidation": "IMPORTANT", "Nodule/Mass": "IMPORTANT",
    "Atelectasis": "NOTABLE", "Lung Opacity": "NOTABLE",
    "Pulmonary fibrosis": "NOTABLE",
    "Pleural thickening": "INCIDENTAL", "Calcification": "INCIDENTAL",
}

CLASS_INFO = {
    "Aortic enlargement": "Widening of the aorta, may indicate aneurysm or aortic dissection.",
    "Atelectasis": "Partial or complete collapse of the lung or a section (lobe) of the lung.",
    "Calcification": "Calcium deposits visible in lung tissue, often from healed infections.",
    "Cardiomegaly": "Enlarged heart, may indicate heart failure or other cardiac conditions.",
    "Consolidation": "Lung tissue filled with fluid instead of air, often from pneumonia.",
    "Lung Opacity": "Areas of increased density in the lungs, non-specific finding.",
    "Nodule/Mass": "Discrete rounded opacity, requires follow-up to rule out malignancy.",
    "Pleural effusion": "Excess fluid between the layers of pleura outside the lungs.",
    "Pleural thickening": "Scarring or thickening of the pleural lining around the lungs.",
    "Pneumothorax": "Collapsed lung due to air in the pleural space — may be emergent.",
    "Pulmonary fibrosis": "Scarring of lung tissue, leads to progressive breathing difficulty.",
}

ANATOMY_PRIORS = {
    "Aortic enlargement":  [(0.32, 0.50, 0.10, 0.12, 1.0)],
    "Cardiomegaly":        [(0.55, 0.50, 0.13, 0.18, 1.0)],
    "Pleural effusion":    [(0.78, 0.25, 0.10, 0.12, 1.0),
                            (0.78, 0.75, 0.10, 0.12, 1.0)],
    "Pleural thickening":  [(0.50, 0.12, 0.20, 0.08, 1.0),
                            (0.50, 0.88, 0.20, 0.08, 1.0)],
    "Pneumothorax":        [(0.30, 0.18, 0.15, 0.10, 1.0),
                            (0.30, 0.82, 0.15, 0.10, 1.0)],
    "Atelectasis":         [(0.55, 0.30, 0.18, 0.15, 1.0),
                            (0.55, 0.70, 0.18, 0.15, 1.0)],
    "Consolidation":       [(0.55, 0.30, 0.20, 0.15, 1.0),
                            (0.55, 0.70, 0.20, 0.15, 1.0)],
    "Lung Opacity":        [(0.50, 0.30, 0.22, 0.16, 1.0),
                            (0.50, 0.70, 0.22, 0.16, 1.0)],
    "Nodule/Mass":         [(0.45, 0.30, 0.22, 0.16, 1.0),
                            (0.45, 0.70, 0.22, 0.16, 1.0)],
    "Pulmonary fibrosis":  [(0.65, 0.25, 0.18, 0.14, 1.0),
                            (0.65, 0.75, 0.18, 0.14, 1.0)],
    "Calcification":       [(0.50, 0.50, 0.30, 0.30, 1.0)],
}

TRANSFORM = A.Compose([
    A.Resize(IMAGE_SIZE, IMAGE_SIZE),
    A.Normalize(mean=NORM_MEAN, std=NORM_STD),
    ToTensorV2(),
])


# ── GradCAM helpers ───────────────────────────────────────────────────────
def build_class_prior(label, H, W, base_strength=1.0):
    blobs = ANATOMY_PRIORS.get(label, [(0.5, 0.5, 0.25, 0.25, 1.0)])
    y, x = np.ogrid[:H, :W]
    yn, xn = y / H, x / W
    prior = np.zeros((H, W), dtype=np.float32)
    for (cy, cx, sy, sx, w) in blobs:
        d = ((xn - cx)**2) / (2*sx**2) + ((yn - cy)**2) / (2*sy**2)
        prior = np.maximum(prior, w * np.exp(-d))
    if prior.max() > 1e-8:
        prior /= prior.max()
    return (1.0 - base_strength) + base_strength * prior


def hard_border_mask(H, W, border_pct=0.06):
    ramp_y = np.ones(H, dtype=np.float32)
    ramp_x = np.ones(W, dtype=np.float32)
    bh, bw = int(H * border_pct), int(W * border_pct)
    for i in range(bh):
        v = (i / max(bh-1, 1))**1.5
        ramp_y[i] = v; ramp_y[H-1-i] = v
    for j in range(bw):
        v = (j / max(bw-1, 1))**1.5
        ramp_x[j] = v; ramp_x[W-1-j] = v
    return ramp_y[:, None] * ramp_x[None, :]


def compute_cam(model, x, class_idx, layer_idx=-2, contrastive=True):
    model.zero_grad(set_to_none=True)
    x = x.clone().detach().to(DEVICE).requires_grad_(False)
    with torch.enable_grad():
        out = model.backbone(pixel_values=x, output_hidden_states=True)
        hidden = out.hidden_states[layer_idx]
        cls_feat = out.last_hidden_state[:, 0]
        logits = model.head(cls_feat)
        if contrastive:
            n_cls = logits.shape[1]
            mask = torch.ones(n_cls, dtype=torch.bool, device=logits.device)
            mask[class_idx] = False
            score = logits[0, class_idx] - logits[0, mask].mean()
        else:
            score = logits[0, class_idx]
        grads = torch.autograd.grad(score, hidden, retain_graph=False, create_graph=False)[0]

    act = hidden.detach().float()
    grd = grads.detach().float()
    tokens = act[:, 1:, :]
    g_tok = grd[:, 1:, :]
    cam = (tokens * g_tok).sum(dim=-1)[0]
    cam = torch.relu(cam)
    cam_np = cam.cpu().numpy()

    if cam_np.max() <= 1e-10:
        cam_np = g_tok.abs().mean(dim=-1)[0].cpu().numpy()
    if cam_np.max() <= 1e-10:
        cam_np = tokens.abs().mean(dim=-1)[0].cpu().numpy()

    n_patches = cam_np.shape[0]
    grid = int(round(np.sqrt(n_patches)))
    if grid * grid != n_patches:
        return np.zeros((1, 1), dtype=np.float32)
    return cam_np.reshape(grid, grid)


def postprocess_cam(cam_2d, H, W, class_label, blur_sigma=10.0, gamma=1.0,
                    border_pct=0.08, prior_strength=0.6):
    cam = cam_2d.astype(np.float32)
    cam -= cam.min()
    if cam.max() > 1e-10:
        cam /= cam.max()
    cam_pil = Image.fromarray((cam * 255).astype(np.uint8))
    cam = np.array(cam_pil.resize((W, H), Image.BICUBIC)) / 255.0
    if border_pct > 0:
        cam *= hard_border_mask(H, W, border_pct)
    if prior_strength > 0 and class_label in ANATOMY_PRIORS:
        cam *= build_class_prior(class_label, H, W, prior_strength)
    if HAS_SCIPY and blur_sigma > 0:
        cam = gaussian_filter(cam, sigma=blur_sigma * (H / 224.0))
    cam -= cam.min()
    if cam.max() > 1e-10:
        cam /= cam.max()
    if gamma != 1.0:
        cam = np.power(cam, gamma)
    return cam.astype(np.float32)


def make_heatmap_overlay(image_rgb, heatmap, alpha=0.55):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    if heatmap.shape[:2] != image_rgb.shape[:2]:
        h_pil = Image.fromarray((heatmap * 255).astype(np.uint8))
        h_pil = h_pil.resize((image_rgb.shape[1], image_rgb.shape[0]), Image.BILINEAR)
        heatmap = np.array(h_pil) / 255.0
    cmap = plt.get_cmap("jet")
    heat_rgb = (cmap(heatmap)[:, :, :3] * 255).astype(np.uint8)
    blended = (1 - alpha) * image_rgb.astype(np.float32) + alpha * heat_rgb.astype(np.float32)
    return blended.clip(0, 255).astype(np.uint8)


def numpy_to_base64(img_array):
    """Convert a numpy image (H,W,3) to a base64-encoded PNG string."""
    pil_img = Image.fromarray(img_array)
    buffer = io.BytesIO()
    pil_img.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("utf-8")


@torch.no_grad()
def run_prediction(image_bytes):
    """Run RAD-DINO prediction on an image. Returns predictions + heatmaps."""
    model = models.raddino_model
    img_array = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
    x = TRANSFORM(image=img_array)["image"].unsqueeze(0).to(DEVICE)

    # TTA: original + horizontal flip
    logits = model(x).float()
    logits_flip = model(torch.flip(x, dims=[3])).float()
    logits = (logits + logits_flip) / 2

    probs = torch.sigmoid(logits)[0].cpu().numpy()

    # Build predictions list
    predictions = []
    for i, lb in enumerate(UNIFIED_LABELS):
        is_positive = bool(probs[i] >= THRESHOLDS[i])
        predictions.append({
            "label": lb,
            "probability": float(probs[i]),
            "threshold": float(THRESHOLDS[i]),
            "positive": is_positive,
            "severity": SEVERITY.get(lb, "INCIDENTAL"),
            "info": CLASS_INFO.get(lb, ""),
        })

    # Sort by probability descending
    predictions.sort(key=lambda p: p["probability"], reverse=True)

    # Generate GradCAM heatmaps for positive findings
    positive_findings = [p for p in predictions if p["positive"]]
    heatmaps = {}

    img_resized = np.array(Image.fromarray(img_array).resize(
        (IMAGE_SIZE, IMAGE_SIZE), Image.LANCZOS))
    x_for_cam = TRANSFORM(image=img_resized)["image"].unsqueeze(0).to(DEVICE)

    for finding in positive_findings[:4]:  # Limit to top 4 for speed
        ci = UNIFIED_LABELS.index(finding["label"])
        cam_2d = compute_cam(model, x_for_cam, ci)
        cam = postprocess_cam(cam_2d, IMAGE_SIZE, IMAGE_SIZE, finding["label"])
        overlay = make_heatmap_overlay(img_resized, cam)
        heatmaps[finding["label"]] = numpy_to_base64(overlay)

    diagnosis_output = {}
    if positive_findings:
        top = positive_findings[0]
        diagnosis_output = {
            "label": top["label"],
            "confidence": top["probability"],
            "prediction": top["label"],
        }
    else:
        top_idx = int(np.argmax(probs))
        diagnosis_output = {
            "label": "No significant abnormalities detected",
            "confidence": float(probs[top_idx]),
            "prediction": "Normal",
        }

    return {
        "predictions": predictions,
        "diagnosis_output": diagnosis_output,
        "heatmaps": heatmaps,
        "heatmap_path": None,
        "bounding_boxes": [],
    }


print("✅ RAD-DINO inference + GradCAM ready")


# === CELL 5: Qwen Report Generator ===
# %% [markdown]
# ## 📝 Qwen-based Report Generator
# Generates structured radiology reports from RAD-DINO predictions.

# %%
import re


def generate_radiology_report(predictions, language="en"):
    """
    Generate a structured radiology report from RAD-DINO predictions.
    Uses the shared Qwen model instance.

    Args:
        predictions: List of dicts with 'label', 'probability', 'positive', 'severity'
        language: 'en' or 'ar'

    Returns:
        Dict with 'findings', 'impression', 'recommendations', 'full_report'
    """
    qwen_model = models.qwen_model
    tokenizer = models.qwen_tokenizer

    positive_findings = [p for p in predictions if p.get("positive", False)]

    # If nothing detected, return a normal report
    if not positive_findings:
        if language == "ar":
            return {
                "findings": "لا توجد نتائج غير طبيعية ملحوظة في صورة الأشعة السينية للصدر.",
                "impression": "صورة أشعة صدر طبيعية.",
                "recommendations": "المتابعة السريرية الروتينية حسب الحاجة.",
                "full_report": "التقرير الإشعاعي\n\nالنتائج:\nلا توجد نتائج غير طبيعية ملحوظة.\n\nالانطباع:\nصورة أشعة صدر طبيعية.\n\nالتوصيات:\nالمتابعة السريرية الروتينية حسب الحاجة."
            }
        return {
            "findings": "No notable abnormal findings identified on the chest X-ray.",
            "impression": "Normal chest X-ray.",
            "recommendations": "Routine clinical follow-up as needed.",
            "full_report": "RADIOLOGY REPORT\n\nFindings:\nNo notable abnormal findings identified.\n\nImpression:\nNormal chest X-ray.\n\nRecommendations:\nRoutine clinical follow-up as needed."
        }

    # Build the findings description for the prompt
    findings_desc = []
    for f in positive_findings:
        conf_pct = f["probability"] * 100
        findings_desc.append(
            f"- {f['label']} (confidence: {conf_pct:.1f}%, severity: {f['severity']})"
        )
    findings_text = "\n".join(findings_desc)

    if language == "ar":
        system_prompt = """أنت طبيب أشعة متخصص. اكتب تقريرًا إشعاعيًا منظمًا بالعربية بناءً على نتائج تحليل الأشعة السينية للصدر المقدمة.

القواعد الصارمة:
1. اكتب بالعربية الفصحى الطبية فقط.
2. لا تخترع أي نتائج غير موجودة في البيانات المقدمة.
3. التقرير يجب أن يحتوي على ثلاثة أقسام فقط: النتائج، الانطباع، التوصيات.
4. كن دقيقًا ومهنيًا.
5. لا تذكر نسب الثقة في التقرير النهائي.
6. أجب بالتقرير مباشرة بدون أي مقدمة أو تعليق."""

        user_prompt = f"""النتائج المكتشفة من تحليل الأشعة:
{findings_text}

اكتب التقرير بالتنسيق التالي بالضبط:

النتائج:
[وصف تفصيلي لكل نتيجة]

الانطباع:
[ملخص التشخيص]

التوصيات:
[الخطوات المقترحة]"""
    else:
        system_prompt = """You are a board-certified radiologist. Write a structured radiology report based on the provided chest X-ray analysis findings.

Strict rules:
1. Write in professional medical English only.
2. Do NOT invent or hallucinate any findings not present in the provided data.
3. The report MUST contain exactly three sections: Findings, Impression, Recommendations.
4. Be precise, concise, and professional.
5. Do NOT mention confidence percentages in the final report.
6. Respond with the report directly without any preamble or commentary."""

        user_prompt = f"""Detected findings from chest X-ray analysis:
{findings_text}

Write the report in exactly this format:

Findings:
[Detailed description of each finding]

Impression:
[Diagnostic summary]

Recommendations:
[Suggested next steps]"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(text, return_tensors="pt").to(qwen_model.device)

    with torch.no_grad():
        outputs = qwen_model.generate(
            **inputs,
            max_new_tokens=600,
            temperature=0.1,
            do_sample=False,
            num_beams=1,
            pad_token_id=tokenizer.eos_token_id,
            use_cache=True,
            repetition_penalty=1.05,
        )

    report_text = tokenizer.decode(
        outputs[0][inputs.input_ids.shape[1]:],
        skip_special_tokens=True
    ).strip()

    # Parse sections from the generated report
    result = parse_report_sections(report_text, language)
    return result


def parse_report_sections(report_text, language="en"):
    """Parse the generated report into structured sections."""
    if language == "ar":
        findings_pattern = r"النتائج:\s*(.*?)(?=الانطباع:|$)"
        impression_pattern = r"الانطباع:\s*(.*?)(?=التوصيات:|$)"
        recommendations_pattern = r"التوصيات:\s*(.*?)$"
    else:
        findings_pattern = r"Findings:\s*(.*?)(?=Impression:|$)"
        impression_pattern = r"Impression:\s*(.*?)(?=Recommendations:|$)"
        recommendations_pattern = r"Recommendations:\s*(.*?)$"

    findings_match = re.search(findings_pattern, report_text, re.DOTALL | re.IGNORECASE)
    impression_match = re.search(impression_pattern, report_text, re.DOTALL | re.IGNORECASE)
    recommendations_match = re.search(recommendations_pattern, report_text, re.DOTALL | re.IGNORECASE)

    findings = findings_match.group(1).strip() if findings_match else report_text
    impression = impression_match.group(1).strip() if impression_match else ""
    recommendations = recommendations_match.group(1).strip() if recommendations_match else ""

    full_report = report_text
    if not findings_match:
        # Couldn't parse, use raw text
        if language == "ar":
            full_report = f"النتائج:\n{report_text}\n\nالانطباع:\nيُرجى مراجعة النتائج أعلاه.\n\nالتوصيات:\nاستشارة الطبيب المعالج."
        else:
            full_report = f"Findings:\n{report_text}\n\nImpression:\nPlease review findings above.\n\nRecommendations:\nConsult attending physician."

    return {
        "findings": findings,
        "impression": impression,
        "recommendations": recommendations,
        "full_report": full_report,
    }


print("✅ Qwen report generator ready")


# === CELL 6: RAG Chatbot ===
# %% [markdown]
# ## 🤖 RAG Medical Chatbot
# Full pipeline: FAISS retrieval → Qwen generation with session memory.

# %%
import re
from collections import defaultdict

# ── Session memory store ─────────────────────────────────────────────────
chat_sessions = defaultdict(list)
MAX_SESSION_HISTORY = 10

# ── Medical terms dictionary (EN ↔ AR) ───────────────────────────────────
MEDICAL_TERMS_EN_TO_AR = {
    "nodule": "عُقدة", "nodules": "عُقد",
    "mass": "كتلة", "masses": "كتل",
    "opacity": "عتامة", "opacities": "عتامات",
    "effusion": "انصباب",
    "pleural": "جنبي", "pleural effusion": "انصباب جنبي",
    "consolidation": "تصلب رئوي",
    "fibrosis": "تليف",
    "pneumothorax": "استرواح صدري",
    "cardiomegaly": "تضخم القلب",
    "aortic": "أبهري",
    "enlargement": "تضخم",
    "thickening": "تسمك",
    "pulmonary": "رئوي",
    "lung": "رئة", "lungs": "رئتين",
    "chest": "صدر", "heart": "قلب",
    "rib": "ضلع", "ribs": "ضلوع",
    "diaphragm": "حجاب حاجز",
    "mediastinum": "المنصف",
    "bronchus": "قصبة هوائية",
    "trachea": "رغامى",
    "aorta": "الأبهر",
    "x-ray": "أشعة سينية",
    "diagnosis": "تشخيص",
    "treatment": "علاج",
    "symptoms": "أعراض", "symptom": "عَرَض",
    "causes": "أسباب", "cause": "سبب",
    "prognosis": "مآل المرض",
    "chronic": "مزمن", "acute": "حاد",
    "benign": "حميد", "malignant": "خبيث",
    "infection": "عدوى", "inflammation": "التهاب",
    "biopsy": "خزعة",
    "ct scan": "أشعة مقطعية", "mri": "رنين مغناطيسي",
    "surgery": "جراحة", "medication": "دواء",
    "doctor": "طبيب", "patient": "مريض",
    "breathlessness": "ضيق تنفس",
    "shortness of breath": "ضيق تنفس",
    "cough": "سعال", "fever": "حمى",
    "pain": "ألم", "swelling": "تورم", "fluid": "سائل",
}

MEDICAL_KEYWORDS_AR = [
    "أعراض", "علاج", "سبب", "أسباب", "خطر", "خطير", "تشخيص",
    "دواء", "أدوية", "فحص", "تحليل", "طبيب", "مستشفى",
    "مرض", "حالة", "ألم", "صدر", "قلب", "رئة", "تنفس",
    "أشعة", "عملية", "جراحة", "كتلة", "عقدة", "ورم",
    "انصباب", "تليف", "تضخم", "التهاب", "عدوى",
]

MEDICAL_KEYWORDS_EN = [
    "symptom", "treatment", "cause", "danger", "risk", "diagnos",
    "medicine", "drug", "test", "doctor", "hospital",
    "disease", "condition", "pain", "chest", "heart", "lung", "breath",
    "x-ray", "surgery", "nodule", "mass", "effusion", "fibrosis",
    "what is", "how to", "is it", "can it", "should i",
]

RED_FLAGS_AR = [
    "مش قادر اتنفس", "ضيق تنفس شديد", "ألم شديد في الصدر",
    "وجع شديد في الصدر", "دم في البلغم", "بصق دم", "كحة دم",
    "ازرقاق", "فقدت الوعي", "اختناق",
]

RED_FLAGS_EN = [
    "can't breathe", "cannot breathe", "severe chest pain",
    "coughing blood", "coughing up blood", "blue lips",
    "passed out", "choking", "hemoptysis",
]

EMERGENCY_FINDINGS = ["Pneumothorax"]


# ── Language detection ────────────────────────────────────────────────────
def detect_language(text):
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    total = len(text.strip())
    if total == 0:
        return "ar"
    return "ar" if arabic_chars > total * 0.3 else "en"


# ── Question classification ──────────────────────────────────────────────
def has_medical_keyword(text):
    text_lower = text.lower()
    for kw in MEDICAL_KEYWORDS_AR:
        if kw in text_lower:
            return True
    for kw in MEDICAL_KEYWORDS_EN:
        if kw in text_lower:
            return True
    return False


def classify_question(text, finding):
    text_lower = text.strip().lower()

    if has_medical_keyword(text):
        return "medical"

    greetings = [
        "ازيك", "اخبارك", "كيف الحال", "كيفك",
        "صباح الخير", "مساء الخير", "اهلا", "مرحبا", "السلام عليكم",
        "hello", "hi ", "hey ", "how are you", "good morning", "good evening",
    ]
    for phrase in greetings:
        if phrase in text_lower:
            return "greeting"

    vague_phrases = [
        "ايه ده", "ما هذا", "اشرحلي", "اشرح لي", "ايه الكلام",
        "explain this", "what is this", "tell me about",
        "ايه هي", "ايه هو", "ما هي", "ما هو",
    ]
    if any(phrase in text_lower for phrase in vague_phrases) and len(text.split()) < 7:
        return "medical"

    emotions = [
        "خايف", "قلقان", "مرعوب", "مش عارف", "زعلان",
        "afraid", "scared", "worried", "anxious", "help me",
    ]
    for phrase in emotions:
        if phrase in text_lower:
            return "emotion"

    return "not_medical"


def has_red_flag(text):
    text_lower = text.lower()
    for flag in RED_FLAGS_AR + RED_FLAGS_EN:
        if flag in text_lower:
            return True
    return False


def is_valid_question(text):
    text = text.strip()
    if len(text) < 3:
        return False, "السؤال قصير جداً. Please ask a complete question."
    if re.search(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]', text):
        return False, "من فضلك اكتب بالعربي أو الإنجليزي فقط."
    return True, ""


# ── FAISS retrieval ───────────────────────────────────────────────────────
def search_with_score(question, finding_filter=None, k=3):
    q_lang = detect_language(question)
    q_embedding = models.embedder.encode([question], normalize_embeddings=True)
    q_embedding = np.array(q_embedding).astype("float32")

    scores, indices = models.faiss_index.search(q_embedding, len(models.documents))

    same_lang = []
    other_lang = []
    for i, idx in enumerate(indices[0]):
        if finding_filter and models.metadata[idx]["finding"] != finding_filter:
            continue
        result = {
            "text": models.documents[idx],
            "finding": models.metadata[idx]["finding"],
            "section": models.metadata[idx]["section"],
            "language": models.metadata[idx]["language"],
            "score": float(scores[0][i]),
        }
        if models.metadata[idx]["language"] == q_lang:
            same_lang.append(result)
        else:
            other_lang.append(result)

    results = same_lang[:k]
    if len(results) < k:
        results.extend(other_lang[:k - len(results)])
    return results


# ── Language cleaning ─────────────────────────────────────────────────────
def clean_mixed_language(text, target_lang):
    if target_lang == "ar":
        words = text.split()
        cleaned = []
        for word in words:
            stripped = word.strip(".,;:()؟!،؛")
            has_arabic = bool(re.search(r'[\u0600-\u06FF]', word))
            has_latin = bool(re.search(r'[a-zA-Z]', word))
            if has_arabic and has_latin:
                latin_part = re.sub(r'[\u0600-\u06FF\s]', '', stripped).lower()
                if latin_part in MEDICAL_TERMS_EN_TO_AR:
                    word = MEDICAL_TERMS_EN_TO_AR[latin_part]
                else:
                    word = f"({re.sub(r'[\u0600-\u06FF]', '', word)})"
            elif not has_arabic and has_latin and len(stripped) > 1:
                lookup = stripped.lower()
                if lookup in MEDICAL_TERMS_EN_TO_AR:
                    word = MEDICAL_TERMS_EN_TO_AR[lookup]
            cleaned.append(word)
        text = " ".join(cleaned)
    elif target_lang == "en":
        lines = text.split('\n')
        cleaned_lines = []
        for line in lines:
            words = line.split()
            cleaned = [w for w in words if not (
                bool(re.search(r'[\u0600-\u06FF]', w)) and
                not bool(re.search(r'[a-zA-Z]', w))
            )]
            cleaned_lines.append(" ".join(cleaned))
        text = "\n".join(cleaned_lines)

    text = re.sub(r'  +', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


# ── System prompt builder ─────────────────────────────────────────────────
def build_system_prompt(question, finding, context, chat_history_text=""):
    medical_knowledge = models.medical_knowledge
    finding_ar = medical_knowledge[finding]["name_ar"]
    q_lang = detect_language(question)

    history_section = ""
    if chat_history_text:
        if q_lang == "ar":
            history_section = f"\n\nسجل المحادثة السابقة:\n{chat_history_text}\n"
        else:
            history_section = f"\n\nPrevious conversation:\n{chat_history_text}\n"

    if q_lang == "ar":
        return f"""أنت مساعد طبي متخصص في شرح نتائج أشعة الصدر للمرضى. أجب باللغة العربية فقط.

التشخيص الحالي: {finding_ar} ({finding})

القواعد الصارمة:
1. أجب بالعربية فقط. لا تستخدم أي كلمة إنجليزية أو بأي لغة أخرى.
2. استمد إجابتك حصرياً من "المعلومات المتاحة" أدناه. لا تخترع أي معلومات من خارجها.
3. إذا كان السؤال يستفسر عن ({finding_ar}) أو ({finding})، أجب عليه بالتفصيل.
4. إذا كان السؤال عن مرض آخر تماماً أو موضوع غير طبي، قل: "السؤال ده خارج نطاق تخصصي."
5. لا تصف أدوية أو جرعات.
{history_section}
المعلومات المتاحة:
{context}"""
    else:
        return f"""You are a medical assistant specialized ONLY in explaining chest X-ray findings. Answer in English only.

Current diagnosis: {finding} ({finding_ar})

Strict rules:
1. Answer in English only.
2. Answer ONLY from the provided information below. Do NOT use general knowledge.
3. If the question asks about {finding}, answer it in detail.
4. If the question is about a different disease or non-medical topic, say: "This question is outside my scope."
5. Do not prescribe medications or dosages.
{history_section}
Available information:
{context}"""


# ── Generation with retry ────────────────────────────────────────────────
def generate_answer(messages, target_lang, max_retries=2):
    qwen_model = models.qwen_model
    tokenizer = models.qwen_tokenizer

    for attempt in range(max_retries + 1):
        text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = tokenizer(text, return_tensors="pt").to(qwen_model.device)

        with torch.no_grad():
            outputs = qwen_model.generate(
                **inputs,
                max_new_tokens=400,
                temperature=0.1 + (attempt * 0.15),
                do_sample=(attempt > 0),
                num_beams=1,
                pad_token_id=tokenizer.eos_token_id,
                use_cache=True,
                repetition_penalty=1.05,
            )

        answer = tokenizer.decode(
            outputs[0][inputs.input_ids.shape[1]:],
            skip_special_tokens=True
        )

        answer = clean_mixed_language(answer, target_lang)

        # Basic quality check
        if answer and len(answer.strip()) >= 5:
            mixed_count = sum(1 for w in answer.split()
                            if bool(re.search(r'[\u0600-\u06FF]', w)) and
                               bool(re.search(r'[a-zA-Z]', w)))
            if mixed_count <= 2:
                return answer

    return answer


# ── Main RAG function ─────────────────────────────────────────────────────
def medical_rag(question, finding, session_id=None):
    """Full RAG pipeline: validate → classify → retrieve → generate."""
    medical_knowledge = models.medical_knowledge

    is_valid, error_msg = is_valid_question(question)
    if not is_valid:
        return error_msg

    q_lang = detect_language(question)
    category = classify_question(question, finding)

    # Emotion response
    if category == "emotion":
        if q_lang == "ar":
            return ("أنا متفهم جداً قلقك وخوفك، وده شعور طبيعي جداً. لكن تذكر إن التشخيص المبكر "
                    "والمتابعة مع الطبيب هما أول وأهم خطوة للعلاج والشفاء بإذن الله. "
                    "لو عندك أي أسئلة عن طبيعة التشخيص، أنا هنا لمساعدتك.")
        return ("I completely understand your fear and anxiety, and it's a very natural feeling. "
                "Please remember that early diagnosis and consulting with a doctor are the most "
                "important steps. If you have questions about the diagnosis, I'm here to help.")

    # Greeting
    if category == "greeting":
        finding_ar = medical_knowledge[finding]["name_ar"]
        if q_lang == "ar":
            return (f"أهلاً بك! أنا هنا لمساعدتك في فهم تشخيصك ({finding_ar}). "
                    f"يمكنك أن تسألني عن الأعراض، الأسباب، العلاج، أو أي شيء متعلق بحالتك.")
        return (f"Hello! I'm here to help you understand your diagnosis ({finding}). "
                f"You can ask me about symptoms, causes, treatment, or anything related.")

    # Not medical
    if category == "not_medical":
        finding_ar = medical_knowledge[finding]["name_ar"]
        if q_lang == "ar":
            return (f"السؤال ده خارج نطاق تخصصي. أنا مساعد طبي متخصص في شرح نتائج أشعة الصدر فقط.\n\n"
                    f"ممكن تسألني مثلاً:\n• ايه هو {finding_ar}؟\n• ايه أعراض {finding_ar}؟\n"
                    f"• هل {finding_ar} خطير؟\n• ايه العلاج المتاح؟")
        return (f"This question is outside my scope. I am a medical assistant specialized in chest X-ray findings only.\n\n"
                f"You can ask me:\n• What is {finding}?\n• What are the symptoms of {finding}?\n"
                f"• Is {finding} serious?\n• What treatment is available?")

    # Handle vague questions
    text_lower = question.lower().strip()
    vague_phrases = ["ايه ده", "ما هذا", "اشرحلي", "explain this", "what is this", "tell me about"]
    is_vague = any(p in text_lower for p in vague_phrases) and len(question.split()) < 7

    if is_vague:
        if q_lang == "ar":
            search_query = f"ما هو {medical_knowledge[finding]['name_ar']} وأعراضه وأسبابه"
            question_to_llm = f"ما هو {medical_knowledge[finding]['name_ar']} ({finding})؟ وما هي أعراضه وأسبابه وعلاجه؟"
        else:
            search_query = f"What is {finding} and what are its symptoms and causes"
            question_to_llm = f"What is {finding}? What are its symptoms, causes, and treatment?"
    else:
        search_query = question
        question_to_llm = question

    # FAISS retrieval
    retrieved = search_with_score(search_query, finding_filter=finding, k=3)

    if not retrieved or retrieved[0]["score"] < 0.78:
        finding_ar = medical_knowledge[finding]["name_ar"]
        if q_lang == "ar":
            return (f"مش قادر ألاقي معلومات تجاوب على سؤالك ده. من فضلك اسأل سؤال محدد عن {finding_ar}.\n\n"
                    f"مثلاً:\n• ايه أعراض {finding_ar}؟\n• ايه أسباب {finding_ar}؟\n• هل {finding_ar} خطير؟")
        return (f"I couldn't find information to answer your question. Please ask about {finding}.\n\n"
                f"For example:\n• What are the symptoms of {finding}?\n• What causes {finding}?\n• Is {finding} serious?")

    # Build context from retrieved chunks
    clean_context = []
    for r in retrieved:
        text = r["text"]
        if "A:" in text:
            text = text.split("A:", 1)[1].strip()
        clean_context.append(text)
    context = "\n\n".join(clean_context)

    # Build conversation history
    chat_history_text = ""
    if session_id and session_id in chat_sessions:
        history = chat_sessions[session_id][-MAX_SESSION_HISTORY:]
        history_lines = []
        for h in history:
            if q_lang == "ar":
                history_lines.append(f"المريض: {h['question']}\nالمساعد: {h['answer']}")
            else:
                history_lines.append(f"Patient: {h['question']}\nAssistant: {h['answer']}")
        chat_history_text = "\n".join(history_lines)

    # Build prompt
    system_msg = build_system_prompt(question_to_llm, finding, context, chat_history_text)
    messages = [
        {"role": "system", "content": system_msg},
        {"role": "user", "content": question_to_llm},
    ]

    # Generate
    answer = generate_answer(messages, q_lang, max_retries=2)
    return answer


def safe_medical_chat(question, finding, session_id=None):
    """Main chat interface with safety guardrails."""
    q_lang = detect_language(question)
    medical_knowledge = models.medical_knowledge

    # Validate finding
    if finding not in medical_knowledge:
        if q_lang == "ar":
            return f"التشخيص '{finding}' غير معروف. اختر من القائمة المتاحة."
        return f"Unknown finding '{finding}'. Please select from available findings."

    # Red flags → emergency
    if has_red_flag(question):
        if q_lang == "ar":
            return ("⚠️ تحذير: الأعراض اللي وصفتها ممكن تكون خطيرة. "
                    "توجه فوراً لأقرب طوارئ أو اتصل بالإسعاف.")
        return ("⚠️ Warning: The symptoms you described may be serious. "
                "Please go to the nearest emergency room or call an ambulance immediately.")

    # Generate answer
    answer = medical_rag(question, finding, session_id)

    # Skip disclaimer for non-content responses
    skip_markers = [
        "أهلاً بك", "Hello!", "خارج نطاق تخصصي",
        "outside my scope", "مش قادر ألاقي",
        "I couldn't find", "السؤال قصير",
    ]
    if any(marker in answer for marker in skip_markers):
        # Store in session even for non-content
        if session_id:
            chat_sessions[session_id].append({"question": question, "answer": answer})
        return answer

    # Emergency note
    emergency_note = ""
    if finding in EMERGENCY_FINDINGS:
        if q_lang == "ar":
            emergency_note = ("\n\n⚠️ ملاحظة مهمة: التشخيص ده ممكن يكون حالة طارئة. "
                              "لو عندك أعراض شديدة، توجه للطوارئ فوراً.")
        else:
            emergency_note = ("\n\n⚠️ Important: This diagnosis may be an emergency. "
                              "If you have severe symptoms, go to the emergency room immediately.")

    # Disclaimer
    if q_lang == "ar":
        disclaimer = "\n\n---\nملاحظة: المعلومات دي للتثقيف فقط وليست بديلاً عن استشارة الطبيب."
    else:
        disclaimer = "\n\n---\nNote: This information is for education only and is not a substitute for medical advice."

    full_answer = answer + emergency_note + disclaimer

    # Store in session memory
    if session_id:
        chat_sessions[session_id].append({"question": question, "answer": full_answer})
        # Trim if too long
        if len(chat_sessions[session_id]) > MAX_SESSION_HISTORY * 2:
            chat_sessions[session_id] = chat_sessions[session_id][-MAX_SESSION_HISTORY:]

    return full_answer


print("✅ RAG chatbot ready")


# === CELL 7: FastAPI Application ===
# %% [markdown]
# ## 🌐 FastAPI Application

# %%
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict
import traceback

app = FastAPI(
    title="MediScan AI Service",
    description="Chest X-Ray AI Backend — RAD-DINO + Qwen + FAISS RAG",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request/Response models ───────────────────────────────────────────────
class PredictRequest(BaseModel):
    image_path: Optional[str] = None

class PredictionItem(BaseModel):
    label: str
    probability: float
    threshold: float
    positive: bool
    severity: str
    info: str

class PredictResponse(BaseModel):
    predictions: List[PredictionItem]
    diagnosis_output: Dict
    heatmaps: Dict[str, str]
    heatmap_path: Optional[str]
    bounding_boxes: List

class ReportRequest(BaseModel):
    predictions: List[Dict]
    language: str = "en"

class ReportResponse(BaseModel):
    findings: str
    impression: str
    recommendations: str
    full_report: str

class ChatRequest(BaseModel):
    question: str
    finding: str
    session_id: Optional[str] = None
    language: str = "en"

class ChatResponse(BaseModel):
    answer: str
    finding: str
    success: bool


# ── Endpoints ─────────────────────────────────────────────────────────────
@app.get("/health")
def health_check():
    return {"status": "ok", "models_loaded": models._initialized}


@app.get("/findings")
def get_findings():
    findings = []
    for name, info in models.medical_knowledge.items():
        findings.append({"name_en": name, "name_ar": info["name_ar"]})
    return {"findings": findings}


@app.post("/predict")
async def predict(file: UploadFile = File(None), request: PredictRequest = None):
    """
    Run RAD-DINO prediction.
    Accepts either:
      - A file upload (multipart form)
      - JSON body with image_path (for Node.js passing a URL or path)
    """
    try:
        image_bytes = None

        if file is not None:
            image_bytes = await file.read()
        elif request and request.image_path:
            # If image_path is a URL, download it
            import urllib.request
            if request.image_path.startswith("http"):
                req = urllib.request.Request(request.image_path)
                with urllib.request.urlopen(req) as resp:
                    image_bytes = resp.read()
            else:
                with open(request.image_path, "rb") as f:
                    image_bytes = f.read()

        if not image_bytes:
            raise HTTPException(status_code=400, detail="No image provided")

        result = run_prediction(image_bytes)
        return result

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.post("/generate_report", response_model=ReportResponse)
async def generate_report_endpoint(request: ReportRequest):
    """Generate a structured radiology report from predictions."""
    try:
        result = generate_radiology_report(request.predictions, request.language)
        return result
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Report generation failed: {str(e)}")


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """RAG chatbot endpoint."""
    try:
        if request.finding not in models.medical_knowledge:
            return ChatResponse(
                answer=f"Unknown finding '{request.finding}'. Select from available findings.",
                finding=request.finding,
                success=False,
            )

        answer = safe_medical_chat(
            question=request.question,
            finding=request.finding,
            session_id=request.session_id,
        )

        return ChatResponse(
            answer=answer,
            finding=request.finding,
            success=True,
        )
    except Exception as e:
        traceback.print_exc()
        return ChatResponse(
            answer=f"Error: {str(e)}",
            finding=request.finding,
            success=False,
        )


print("✅ FastAPI app defined")


# === CELL 8: Start ngrok + Register with Node.js ===
# %% [markdown]
# ## 🚀 Launch Server + ngrok Tunnel

# %%
import nest_asyncio
import uvicorn
import threading
import requests as http_requests
from pyngrok import ngrok, conf

nest_asyncio.apply()

# ── Configure ngrok ───────────────────────────────────────────────────────
conf.get_default().auth_token = NGROK_AUTH_TOKEN

# Kill any existing tunnels
try:
    ngrok.kill()
except Exception:
    pass

# Start ngrok tunnel
public_url = ngrok.connect(FASTAPI_PORT)
public_url_str = str(public_url)

# Clean up the URL (pyngrok sometimes wraps it)
if "NgrokTunnel" in public_url_str:
    import re as re_url
    match = re_url.search(r'"(https?://[^"]+)"', public_url_str)
    if match:
        public_url_str = match.group(1)

print("\n" + "=" * 60)
print(f"  🚀 PUBLIC URL: {public_url_str}")
print("=" * 60)
print(f"\n  Endpoints:")
print(f"    GET  {public_url_str}/health")
print(f"    GET  {public_url_str}/findings")
print(f"    POST {public_url_str}/predict")
print(f"    POST {public_url_str}/generate_report")
print(f"    POST {public_url_str}/chat")

# ── Register with Node.js backend ─────────────────────────────────────────
def register_with_nodejs():
    """Send the ngrok URL to the Node.js backend's webhook."""
    if not NODEJS_BACKEND_URL or "YOUR_NODEJS" in NODEJS_BACKEND_URL:
        print("\n⚠️  NODEJS_BACKEND_URL not configured — skipping auto-registration.")
        print("   You can manually set AI_SERVICE_URL in Node.js .env to:")
        print(f"   {public_url_str}")
        return

    webhook_url = f"{NODEJS_BACKEND_URL}/api/system/update-ai-endpoint"
    payload = {
        "url": public_url_str,
        "token": AI_SYSTEM_SECRET,
    }

    try:
        resp = http_requests.post(webhook_url, json=payload, timeout=10)
        if resp.status_code == 200:
            print(f"\n✅ Successfully registered with Node.js backend at {NODEJS_BACKEND_URL}")
        else:
            print(f"\n⚠️  Node.js registration failed: {resp.status_code} — {resp.text}")
            print(f"   Manually set AI_SERVICE_URL to: {public_url_str}")
    except Exception as e:
        print(f"\n⚠️  Could not reach Node.js backend: {e}")
        print(f"   Manually set AI_SERVICE_URL to: {public_url_str}")


register_with_nodejs()

# ── Start uvicorn in background thread ────────────────────────────────────
def run_server():
    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT, log_level="info")

server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

import time
time.sleep(3)

print(f"\n✅ Server is running on port {FASTAPI_PORT}")
print(f"✅ Public URL: {public_url_str}")
print(f"\n⚠️  Keep this Colab tab open to maintain the server.")
print(f"   If the session disconnects, re-run all cells to restart.")


# === CELL 9: Keep Alive (Optional) ===
# %% [markdown]
# ## 🔄 Keep Alive
# Run this cell to keep the Colab session active.
# Press the Stop button (⏹️) to shut down.

# %%
import time

print("🔄 Keep-alive loop started. Press ⏹️ to stop.")
print(f"   Server URL: {public_url_str}")

try:
    while True:
        time.sleep(60)
        # Periodic health check
        try:
            resp = http_requests.get(f"http://localhost:{FASTAPI_PORT}/health", timeout=5)
            if resp.status_code == 200:
                print(f"  💚 Server healthy at {time.strftime('%H:%M:%S')}")
            else:
                print(f"  🟡 Health check returned {resp.status_code}")
        except Exception:
            print(f"  🔴 Health check failed at {time.strftime('%H:%M:%S')}")
except KeyboardInterrupt:
    print("\n⏹️ Keep-alive stopped.")
