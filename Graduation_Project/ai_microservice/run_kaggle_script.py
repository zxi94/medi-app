import os
os.system('pip install -q fastapi uvicorn pyngrok nest-asyncio transformers accelerate bitsandbytes sentence-transformers faiss-cpu albumentations scipy pillow torch torchvision timm')

import os
import io
import re
import json
import time
import glob
import base64
import shutil
import threading
import traceback
import urllib.request
from collections import defaultdict
from typing import Optional, List, Dict

import torch
import torch.nn as nn
import numpy as np
import faiss
import gc
import albumentations as A
from albumentations.pytorch import ToTensorV2
from PIL import Image
import timm
from transformers import AutoModel, AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from sentence_transformers import SentenceTransformer
import nest_asyncio
import uvicorn
import requests as http_requests
from pyngrok import ngrok, conf
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    from scipy.ndimage import gaussian_filter
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False

# ─── KAGGLE AUTOMATIC CONFIGURATION ───────────────────────────────────────────
print("=========================================")
print("🔧 INITIALIZING MEDISCAN AI SERVER ON KAGGLE")
print("=========================================")

NGROK_AUTH_TOKEN = "3EgVZPXS2u8Dbk3KMi7PLIfLu4i_568h27mxiHi4NS81qRhtv"

print("🔍 Using explicitly provided Kaggle dataset paths...")
RADDINO_CHECKPOINT = "/kaggle/input/models/refaatelia/ep10/pytorch/default/1/best_model.pth"
CHATBOT_DATA_DIR = "/kaggle/input/datasets/refaatelia/chatbot-data"
GATEKEEPER_CHECKPOINT = "/kaggle/input/models/refaatelia/gatekeeper/pytorch/default/1/gatekeeper_best.pth"

QWEN_MODEL_NAME = "Qwen/Qwen2.5-7B-Instruct"
QWEN_FALLBACK_MODEL = "Qwen/Qwen2.5-3B-Instruct"
EMBEDDING_MODEL_NAME = "intfloat/multilingual-e5-base"
RADDINO_HF_NAME = "microsoft/rad-dino"
IMAGE_SIZE = 518

FASTAPI_PORT = 8081

missing = []
if not RADDINO_CHECKPOINT or not os.path.exists(RADDINO_CHECKPOINT):
    missing.append(f"RAD-DINO checkpoint not found at: {RADDINO_CHECKPOINT}")
if not CHATBOT_DATA_DIR or not os.path.exists(CHATBOT_DATA_DIR):
    missing.append(f"Chatbot data not found at: {CHATBOT_DATA_DIR}")
if not GATEKEEPER_CHECKPOINT or not os.path.exists(GATEKEEPER_CHECKPOINT):
    missing.append(f"Gatekeeper checkpoint not found at: {GATEKEEPER_CHECKPOINT}")

if missing:
    print("\n⚠️  ERROR: Missing dataset files! Please make sure you have uploaded your dataset to Kaggle.")
    for m in missing:
        print(f"   ✗ {m}")
    raise FileNotFoundError("Missing datasets in Kaggle input.")
else:
    print(f"✅ Found RAD-DINO at: {RADDINO_CHECKPOINT}")
    print(f"✅ Found Chatbot Data at: {CHATBOT_DATA_DIR}")
    print(f"✅ Found Gatekeeper at: {GATEKEEPER_CHECKPOINT}")

LOCAL_MODEL_DIR = "/kaggle/working/models"
os.makedirs(LOCAL_MODEL_DIR, exist_ok=True)

local_ckpt = f"{LOCAL_MODEL_DIR}/best_model.pth"
if not os.path.exists(local_ckpt) and os.path.exists(RADDINO_CHECKPOINT):
    print("📋 Copying RAD-DINO checkpoint to local working directory for speed...")
    shutil.copy2(RADDINO_CHECKPOINT, local_ckpt)
    RADDINO_CHECKPOINT = local_ckpt
    print(f"   ✅ Copied to {local_ckpt}")
elif os.path.exists(local_ckpt):
    RADDINO_CHECKPOINT = local_ckpt
    print(f"   ✅ Using cached local checkpoint: {local_ckpt}")

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"🖥️ Device: {DEVICE}")

class GatekeeperModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.backbone = timm.create_model("mobilenetv3_small_100", pretrained=False, num_classes=0, drop_rate=0.3)
        with torch.no_grad():
            dummy = torch.zeros(1, 3, 224, 224)
            in_features = self.backbone(dummy).shape[1]
        self.classifier = nn.Sequential(
            nn.Linear(in_features, 256),
            nn.BatchNorm1d(256),
            nn.SiLU(),
            nn.Dropout(p=0.3),
            nn.Linear(256, 1)
        )
    def forward(self, x):
        features = self.backbone(x)
        logits = self.classifier(features)
        return logits.squeeze(1)

class ModelManager:
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
        self.gatekeeper_model = None

    def load_gatekeeper(self):
        if self.gatekeeper_model is not None: return
        print("🔄 Loading Gatekeeper model...")
        ckpt = torch.load(GATEKEEPER_CHECKPOINT, map_location=DEVICE, weights_only=False)
        model = GatekeeperModel().to(DEVICE)
        model.load_state_dict(ckpt["model_state"])
        model.eval()
        self.gatekeeper_model = model
        print("   ✅ Gatekeeper loaded")

    def load_raddino(self):
        if self.raddino_model is not None: return
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
        state = ckpt.get("ema_state_dict") or ckpt.get("model_state_dict", ckpt)
        model.load_state_dict(state)
        model.eval()

        try:
            if hasattr(model.backbone, "gradient_checkpointing_disable"):
                model.backbone.gradient_checkpointing_disable()
        except Exception:
            pass

        self.raddino_model = model
        print("   ✅ RAD-DINO loaded and ready")

    def load_qwen(self):
        if self.qwen_model is not None: return
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
        )
        print(f"🔄 Loading Qwen LLM: {QWEN_MODEL_NAME} (4-bit)...")
        try:
            self.qwen_tokenizer = AutoTokenizer.from_pretrained(QWEN_MODEL_NAME)
            self.qwen_model = AutoModelForCausalLM.from_pretrained(
                QWEN_MODEL_NAME, quantization_config=bnb_config, device_map="auto"
            )
            print(f"   ✅ {QWEN_MODEL_NAME} loaded (4-bit)")
        except Exception as e:
            print(f"   ⚠️ Failed to load {QWEN_MODEL_NAME}: {e}")
            print(f"   🔄 Falling back to {QWEN_FALLBACK_MODEL}...")
            self.qwen_tokenizer = AutoTokenizer.from_pretrained(QWEN_FALLBACK_MODEL)
            self.qwen_model = AutoModelForCausalLM.from_pretrained(
                QWEN_FALLBACK_MODEL, quantization_config=bnb_config, device_map="auto"
            )
            print(f"   ✅ {QWEN_FALLBACK_MODEL} loaded (4-bit fallback)")

    def load_embeddings_and_faiss(self):
        if self.embedder is not None: return
        print(f"🔄 Loading embeddings: {EMBEDDING_MODEL_NAME}...")
        self.embedder = SentenceTransformer(EMBEDDING_MODEL_NAME)
        
        data_dir = CHATBOT_DATA_DIR
        print(f"🔄 Loading FAISS index + knowledge base from {data_dir}...")
        with open(f"{data_dir}/documents.json", "r", encoding="utf-8") as f:
            self.documents = json.load(f)
        with open(f"{data_dir}/metadata.json", "r", encoding="utf-8") as f:
            self.metadata = json.load(f)
        with open(f"{data_dir}/medical_knowledge.json", "r", encoding="utf-8") as f:
            self.medical_knowledge = json.load(f)
        self.faiss_index = faiss.read_index(f"{data_dir}/medical_index.faiss")

    def load_all(self):
        print("\n" + "=" * 60)
        print("  LOADING ALL MODELS")
        print("=" * 60 + "\n")
        self.load_gatekeeper()
        self.load_raddino()
        self.load_qwen()
        self.load_embeddings_and_faiss()
        gc.collect()
        torch.cuda.empty_cache() if torch.cuda.is_available() else None
        print("\n  ✅ ALL MODELS LOADED SUCCESSFULLY")

models = ModelManager()
models.load_all()

# ─── GATEKEEPER INFERENCE ─────────────────────────────────────────────────────
GK_TRANSFORM = A.Compose([
    A.Resize(224, 224),
    A.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ToTensorV2(),
])

def is_valid_xray(img_array):
    model = models.gatekeeper_model
    tensor = GK_TRANSFORM(image=img_array)["image"]
    tensor = tensor.unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        logit = model(tensor)
        prob = torch.sigmoid(logit).item()
    return prob >= 0.50, prob

# ─── RAD-DINO INFERENCE + GRADCAM ─────────────────────────────────────────────
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
    "Pleural effusion":    [(0.78, 0.25, 0.10, 0.12, 1.0), (0.78, 0.75, 0.10, 0.12, 1.0)],
    "Pleural thickening":  [(0.50, 0.12, 0.20, 0.08, 1.0), (0.50, 0.88, 0.20, 0.08, 1.0)],
    "Pneumothorax":        [(0.30, 0.18, 0.15, 0.10, 1.0), (0.30, 0.82, 0.15, 0.10, 1.0)],
    "Atelectasis":         [(0.55, 0.30, 0.18, 0.15, 1.0), (0.55, 0.70, 0.18, 0.15, 1.0)],
    "Consolidation":       [(0.55, 0.30, 0.20, 0.15, 1.0), (0.55, 0.70, 0.20, 0.15, 1.0)],
    "Lung Opacity":        [(0.50, 0.30, 0.22, 0.16, 1.0), (0.50, 0.70, 0.22, 0.16, 1.0)],
    "Nodule/Mass":         [(0.45, 0.30, 0.22, 0.16, 1.0), (0.45, 0.70, 0.22, 0.16, 1.0)],
    "Pulmonary fibrosis":  [(0.65, 0.25, 0.18, 0.14, 1.0), (0.65, 0.75, 0.18, 0.14, 1.0)],
    "Calcification":       [(0.50, 0.50, 0.30, 0.30, 1.0)],
}

TRANSFORM = A.Compose([
    A.Resize(IMAGE_SIZE, IMAGE_SIZE),
    A.Normalize(mean=NORM_MEAN, std=NORM_STD),
    ToTensorV2(),
])

def crop_borders(image_array, crop_pct=0.05):
    """Crops the outer edges of the image to remove markers and artifacts, then resizes back."""
    H, W = image_array.shape[:2]
    crop_h = int(H * crop_pct)
    crop_w = int(W * crop_pct)
    cropped = image_array[crop_h:H-crop_h, crop_w:W-crop_w]
    return np.array(Image.fromarray(cropped).resize((W, H), Image.BILINEAR))

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

    if cam_np.max() <= 1e-10: cam_np = g_tok.abs().mean(dim=-1)[0].cpu().numpy()
    if cam_np.max() <= 1e-10: cam_np = tokens.abs().mean(dim=-1)[0].cpu().numpy()

    n_patches = cam_np.shape[0]
    grid = int(round(np.sqrt(n_patches)))
    if grid * grid != n_patches: return np.zeros((1, 1), dtype=np.float32)
    return cam_np.reshape(grid, grid)

def postprocess_cam(cam_2d, H, W, class_label, blur_sigma=10.0, gamma=1.0, border_pct=0.08, prior_strength=0.6):
    cam = cam_2d.astype(np.float32)
    cam -= cam.min()
    if cam.max() > 1e-10: cam /= cam.max()
    cam_pil = Image.fromarray((cam * 255).astype(np.uint8))
    cam = np.array(cam_pil.resize((W, H), Image.BICUBIC)) / 255.0
    if border_pct > 0: cam *= hard_border_mask(H, W, border_pct)
    if prior_strength > 0 and class_label in ANATOMY_PRIORS:
        cam *= build_class_prior(class_label, H, W, prior_strength)
    if HAS_SCIPY and blur_sigma > 0:
        cam = gaussian_filter(cam, sigma=blur_sigma * (H / 224.0))
    cam -= cam.min()
    if cam.max() > 1e-10: cam /= cam.max()
    if gamma != 1.0: cam = np.power(cam, gamma)
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
    pil_img = Image.fromarray(img_array)
    buffer = io.BytesIO()
    pil_img.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode("utf-8")

@torch.no_grad()
def run_prediction(image_bytes, img_array=None):
    model = models.raddino_model
    if img_array is None:
        img_array = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
    img_array = crop_borders(img_array, crop_pct=0.05)
    x = TRANSFORM(image=img_array)["image"].unsqueeze(0).to(DEVICE)
    logits = model(x).float()
    logits_flip = model(torch.flip(x, dims=[3])).float()
    logits = (logits + logits_flip) / 2
    probs = torch.sigmoid(logits)[0].cpu().numpy()

    predictions = []
    for i, lb in enumerate(UNIFIED_LABELS):
        if lb in ["Calcification", "Atelectasis"]:
            continue
        is_positive = bool(probs[i] >= THRESHOLDS[i])
        predictions.append({
            "label": lb, "probability": float(probs[i]),
            "threshold": float(THRESHOLDS[i]), "positive": is_positive,
            "severity": SEVERITY.get(lb, "INCIDENTAL"), "info": CLASS_INFO.get(lb, ""),
        })
    predictions.sort(key=lambda p: p["probability"], reverse=True)
    
    positive_findings = [p for p in predictions if p["positive"]]
    heatmaps = {}
    img_resized = np.array(Image.fromarray(img_array).resize((IMAGE_SIZE, IMAGE_SIZE), Image.LANCZOS))
    x_for_cam = TRANSFORM(image=img_resized)["image"].unsqueeze(0).to(DEVICE)

    for finding in positive_findings[:4]: 
        ci = UNIFIED_LABELS.index(finding["label"])
        cam_2d = compute_cam(model, x_for_cam, ci)
        cam = postprocess_cam(cam_2d, IMAGE_SIZE, IMAGE_SIZE, finding["label"])
        overlay = make_heatmap_overlay(img_resized, cam)
        heatmaps[finding["label"]] = numpy_to_base64(overlay)

    if positive_findings:
        top = positive_findings[0]
        labels = [p["label"] for p in positive_findings]
        joined_labels = ", ".join(labels)
        diagnosis_output = {
            "label": joined_labels,
            "confidence": top["probability"],
            "prediction": joined_labels
        }
    else:
        top_idx = int(np.argmax(probs))
        diagnosis_output = {"label": "No significant abnormalities detected", "confidence": float(probs[top_idx]), "prediction": "Normal"}

    return {"predictions": predictions, "diagnosis_output": diagnosis_output, "heatmaps": heatmaps, "heatmap_path": None, "bounding_boxes": []}

# ─── QWEN REPORT GENERATOR ────────────────────────────────────────────────────
def parse_report_sections(report_text, language="en"):
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
        if language == "ar": full_report = f"النتائج:\n{report_text}\n\nالانطباع:\nيُرجى مراجعة النتائج أعلاه.\n\nالتوصيات:\nاستشارة الطبيب المعالج."
        else: full_report = f"Findings:\n{report_text}\n\nImpression:\nPlease review findings above.\n\nRecommendations:\nConsult attending physician."

    return {"findings": findings, "impression": impression, "recommendations": recommendations, "full_report": full_report}

def generate_radiology_report(predictions, language="en"):
    qwen_model = models.qwen_model
    tokenizer = models.qwen_tokenizer
    positive_findings = [p for p in predictions if p.get("positive", False)]

    if not positive_findings:
        if language == "ar":
            return {"findings": "لا توجد نتائج غير طبيعية ملحوظة في صورة الأشعة السينية للصدر.", "impression": "صورة أشعة صدر طبيعية.", "recommendations": "المتابعة السريرية الروتينية حسب الحاجة.", "full_report": "التقرير الإشعاعي\n\nالنتائج:\nلا توجد نتائج غير طبيعية ملحوظة.\n\nالانطباع:\nصورة أشعة صدر طبيعية.\n\nالتوصيات:\nالمتابعة السريرية الروتينية حسب الحاجة."}
        return {"findings": "No notable abnormal findings identified on the chest X-ray.", "impression": "Normal chest X-ray.", "recommendations": "Routine clinical follow-up as needed.", "full_report": "RADIOLOGY REPORT\n\nFindings:\nNo notable abnormal findings identified.\n\nImpression:\nNormal chest X-ray.\n\nRecommendations:\nRoutine clinical follow-up as needed."}

    findings_desc = []
    for f in positive_findings:
        conf_pct = f["probability"] * 100
        findings_desc.append(f"- {f['label']} (confidence: {conf_pct:.1f}%, severity: {f['severity']})")
    findings_text = "\n".join(findings_desc)

    if language == "ar":
        ar_terms = {
            "aortic enlargement": "تضخم الأبهر", "atelectasis": "انخماص الرئة", "calcification": "تكلس",
            "cardiomegaly": "تضخم القلب", "consolidation": "تصلب رئوي", "ild": "مرض الرئة الخلالي",
            "infiltration": "ارتشاح", "lung opacity": "عتامة الرئة", "nodule/mass": "عقدة/كتلة",
            "other lesion": "آفة أخرى", "pleural effusion": "انصباب جنبي", "pleural thickening": "تسمك جنبي",
            "pneumothorax": "استرواح صدري", "pulmonary fibrosis": "تليف رئوي"
        }
        findings_ar_list = []
        for f in positive_findings:
            term = ar_terms.get(f['label'].lower(), f['label'])
            findings_ar_list.append(f"- تم اكتشاف {term} بنسبة ثقة {f['probability']*100:.1f}%.")
        
        findings_text = "\n".join(findings_ar_list)
        report_text = f"النتائج:\n{findings_text}\n\nالانطباع:\nتوجد تشوهات ملحوظة بناءً على النتائج الموضحة أعلاه.\n\nالتوصيات:\nيُرجى مراجعة طبيب مختص وإجراء الفحوصات السريرية اللازمة للمتابعة."
        return parse_report_sections(report_text, language)
    else:
        system_prompt = """You are a board-certified radiologist. Write a structured radiology report based on the provided chest X-ray analysis findings.\n\nStrict rules:\n1. Write in professional medical English only.\n2. Do NOT invent or hallucinate any findings not present in the provided data.\n3. The report MUST contain exactly three sections: Findings, Impression, Recommendations.\n4. Be precise, concise, and professional.\n5. Do NOT mention confidence percentages in the final report.\n6. Respond with the report directly without any preamble or commentary."""
        user_prompt = f"Detected findings from chest X-ray analysis:\n{findings_text}\n\nWrite the report in exactly this format:\n\nFindings:\n[Detailed description of each finding]\n\nImpression:\n[Diagnostic summary]\n\nRecommendations:\n[Suggested next steps]"

        messages = [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}]
        text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = tokenizer(text, return_tensors="pt").to(qwen_model.device)

        with torch.no_grad():
            outputs = qwen_model.generate(**inputs, max_new_tokens=600, temperature=0.1, do_sample=False, num_beams=1, pad_token_id=tokenizer.eos_token_id, use_cache=True, repetition_penalty=1.05)

        report_text = tokenizer.decode(outputs[0][inputs.input_ids.shape[1]:], skip_special_tokens=True).strip()
        return parse_report_sections(report_text, language)


# ─── RAG CHATBOT ──────────────────────────────────────────────────────────────
from collections import defaultdict
import re

chat_sessions = defaultdict(list)
MAX_SESSION_HISTORY = 10

embedder = models.embedder
index = models.faiss_index
documents = models.documents
metadata = models.metadata
medical_knowledge = models.medical_knowledge
tokenizer = models.qwen_tokenizer
model = models.qwen_model


# ══════════════════════════════════════════════════════════════
# تطبيع النص العربي (الأساس لكل المقارنات)
# ══════════════════════════════════════════════════════════════
def normalize_arabic(text):
    """يطبّع النص العربي عشان المقارنات تبقى دقيقة"""
    # إزالة التشكيل
    text = re.sub(r'[\u064B-\u065F\u0670]', '', text)
    # توحيد الهمزات → ا
    text = text.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
    # توحيد التاء المربوطة → ه
    text = text.replace('ة', 'ه')
    # توحيد الألف المقصورة → ي
    text = text.replace('ى', 'ي')
    # إزالة التطويل
    text = text.replace('ـ', '')
    return text


# ══════════════════════════════════════════════════════════════
# قاموس المصطلحات الطبية (عربي ↔ إنجليزي)
# ══════════════════════════════════════════════════════════════
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
    "chest": "صدر",
    "heart": "قلب",
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

# كلمات طبية للتحقق (بدون همزات وبدون ال - التطبيع هيتكفل بالباقي)
MEDICAL_KEYWORDS_AR = [
    "اعراض", "عرض", "علاج", "سبب", "اسباب", "خطر", "خطير", "خطوره",
    "تشخيص", "دواء", "ادويه", "فحص", "تحليل", "طبيب", "دكتور", "مستشفي",
    "مرض", "حاله", "الم", "وجع", "صدر", "قلب", "رئه", "تنفس",
    "اشعه", "عمليه", "جراحه", "كتله", "عقده", "ورم",
    "انصباب", "تليف", "تضخم", "التهاب", "عدوي",
    "عوارض", "اسبابه", "علاجه", "اعراضه", "خطورته",
    "نتيجه", "تقرير", "شفاء", "عمليات", "موت", "وفاه", "وفاة"
]

MEDICAL_KEYWORDS_EN = [
    "symptom", "treatment", "cause", "danger", "risk", "diagnos",
    "medicine", "drug", "test", "doctor", "hospital",
    "disease", "condition", "pain", "chest", "heart", "lung", "breath",
    "x-ray", "xray", "surgery", "nodule", "mass", "effusion", "fibrosis",
    "what is", "how to", "is it", "can it", "should i", "serious",
    "cure", "heal", "recover", "prognos", "die", "death", "fatal", "terminal"
]


# ══════════════════════════════════════════════════════════════
# كشف لغة السؤال
# ══════════════════════════════════════════════════════════════
def detect_language(text):
    """يكشف لغة النص: عربي أو إنجليزي"""
    arabic_chars = sum(1 for c in text if '\u0600' <= c <= '\u06FF')
    total = len(text.strip())
    if total == 0:
        return "ar"
    if arabic_chars > total * 0.3:
        return "ar"
    return "en"


# ══════════════════════════════════════════════════════════════
# البحث مع فلترة حسب اللغة
# ══════════════════════════════════════════════════════════════
def search_with_score(question, finding_filter=None, k=3):
    """البحث في المستندات مع أولوية لنفس لغة السؤال"""
    q_lang = detect_language(question)
    q_embedding = embedder.encode([question], normalize_embeddings=True)
    q_embedding = np.array(q_embedding).astype("float32")

    scores, indices = index.search(q_embedding, len(documents))

    same_lang_results = []
    other_lang_results = []

    for i, idx in enumerate(indices[0]):
        if finding_filter is not None and metadata[idx]["finding"] != finding_filter:
            continue

        result = {
            "text": documents[idx],
            "finding": metadata[idx]["finding"],
            "section": metadata[idx]["section"],
            "language": metadata[idx]["language"],
            "score": float(scores[0][i])
        }

        if metadata[idx]["language"] == q_lang:
            same_lang_results.append(result)
        else:
            other_lang_results.append(result)

    results = same_lang_results[:k]
    if len(results) < k:
        results.extend(other_lang_results[:k - len(results)])

    return results


# ══════════════════════════════════════════════════════════════
# تنظيف خلط اللغات في الإجابة
# ══════════════════════════════════════════════════════════════
def clean_mixed_language(text, target_lang):
    """ينظف خلط اللغات في الإجابة"""

    if target_lang == "ar":
        words = text.split()
        cleaned_words = []
        for word in words:
            stripped = word.strip(".,;:()؟!،؛")
            has_arabic = bool(re.search(r'[\u0600-\u06FF]', word))
            has_latin = bool(re.search(r'[a-zA-Z]', word))

            if has_arabic and has_latin:
                # خلط في نفس الكلمة (مثل "نodule")
                latin_part = re.sub(r'[\u0600-\u06FF\s]', '', stripped).lower()
                if latin_part in MEDICAL_TERMS_EN_TO_AR:
                    word = MEDICAL_TERMS_EN_TO_AR[latin_part]
                else:
                    clean_latin = re.sub(r'[\u0600-\u06FF]', '', word)
                    word = f"({clean_latin})"

            elif not has_arabic and has_latin and len(stripped) > 1:
                lookup = stripped.lower()
                if lookup in MEDICAL_TERMS_EN_TO_AR:
                    prefix = ""
                    suffix = ""
                    lstripped = word.lstrip(".,;:()؟!،؛")
                    rstripped = word.rstrip(".,;:()؟!،؛")
                    if word != lstripped:
                        prefix = word[:len(word) - len(lstripped)]
                    if word != rstripped:
                        suffix = word[len(rstripped):]
                    word = prefix + MEDICAL_TERMS_EN_TO_AR[lookup] + suffix

            cleaned_words.append(word)

        text = " ".join(cleaned_words)

    elif target_lang == "en":
        lines = text.split('\n')
        cleaned_lines = []
        for line in lines:
            words = line.split()
            cleaned = []
            for word in words:
                has_arabic = bool(re.search(r'[\u0600-\u06FF]', word))
                has_latin = bool(re.search(r'[a-zA-Z]', word))
                if has_arabic and has_latin:
                    word = re.sub(r'[\u0600-\u06FF]', '', word)
                elif has_arabic and not has_latin:
                    continue
                cleaned.append(word)
            cleaned_lines.append(" ".join(cleaned))
        text = "\n".join(cleaned_lines)

    text = re.sub(r'  +', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()


def is_answer_clean(answer, target_lang):
    """يتحقق إن الإجابة نظيفة من خلط اللغات"""
    if not answer or len(answer.strip()) < 5:
        return False

    words = answer.split()
    mixed_count = 0
    for word in words:
        has_arabic = bool(re.search(r'[\u0600-\u06FF]', word))
        has_latin = bool(re.search(r'[a-zA-Z]', word))
        if has_arabic and has_latin:
            mixed_count += 1

    if mixed_count > 2:
        return False

    if re.search(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]', answer):
        return False
    if re.search(r'[\u0400-\u04ff]', answer):
        return False

    return True


# ══════════════════════════════════════════════════════════════
# System Prompt ديناميكي حسب اللغة
# ══════════════════════════════════════════════════════════════
def build_system_prompt(question, finding, context):
    """يبني system prompt مناسب للغة السؤال"""
    finding_ar = medical_knowledge[finding]["name_ar"]
    q_lang = detect_language(question)

    if q_lang == "ar":
        return f"""أنت مساعد طبي متخصص في شرح نتائج أشعة الصدر للمرضى. أجب باللغة العربية فقط.

التشخيص الحالي: {finding_ar} ({finding})

القواعد:
1. أجب بالعربية فقط. المصطلحات الطبية اكتبها بالعربي (nodule=عُقدة، mass=كتلة، effusion=انصباب، fibrosis=تليف).
2. استمد إجابتك حصرياً من "المعلومات المتاحة" أدناه.
3. السؤال الحالي يتعلق بتشخيص {finding_ar} ({finding}). أجب عليه بالتفصيل من المعلومات المتاحة.
4. لا تصف أدوية أو جرعات.

المعلومات المتاحة:
{context}"""
    else:
        return f"""You are a medical assistant specialized in explaining chest X-ray findings. Answer in English only.

Current diagnosis: {finding} ({finding_ar})

Rules:
1. Answer in English only.
2. Answer from the information provided below.
3. The current question is about {finding}. Answer it in detail from the available information.
4. Do not prescribe medications or dosages.

Available information:
{context}"""


# ══════════════════════════════════════════════════════════════
# التوليد مع Retry
# ══════════════════════════════════════════════════════════════
def generate_answer(messages, target_lang, max_retries=2):
    """يولد الإجابة مع إعادة المحاولة لو فيها خلط"""
    for attempt in range(max_retries + 1):
        text = tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        inputs = tokenizer(text, return_tensors="pt").to(model.device)

        with torch.no_grad():
            outputs = model.generate(
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

        # ننظف خلط اللغات
        answer = clean_mixed_language(answer, target_lang)

        if is_answer_clean(answer, target_lang):
            return answer

        print(f"  ⚠️ محاولة {attempt + 1}: الإجابة فيها خلط، نحاول تاني...")

    return answer


# ══════════════════════════════════════════════════════════════
# فحص صحة السؤال
# ══════════════════════════════════════════════════════════════
def is_valid_question(text):
    """يتحقق إذا كان السؤال بلغة مدعومة"""
    text = text.strip()

    if len(text) < 3:
        return False, "السؤال قصير جداً. Please ask a complete question."

    if re.search(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]', text):
        return False, "من فضلك اكتب بالعربي أو الإنجليزي فقط."

    if re.search(r'[\u0400-\u04ff]', text):
        return False, "من فضلك اكتب بالعربي أو الإنجليزي فقط."

    return True, ""


# ══════════════════════════════════════════════════════════════
# تصنيف السؤال - النسخة النهائية (مع تطبيع عربي)
# ══════════════════════════════════════════════════════════════
def has_medical_keyword(text):
    """يتحقق إن النص فيه كلمة طبية (مع تطبيع النص العربي)"""
    # تطبيع النص عشان نشيل الفروقات (همزة، ال، تاء مربوطة)
    normalized = normalize_arabic(text)

    for kw in MEDICAL_KEYWORDS_AR:
        normalized_kw = normalize_arabic(kw)
        if normalized_kw in normalized:
            return True

    text_lower = text.lower()
    for kw in MEDICAL_KEYWORDS_EN:
        if kw in text_lower:
            return True

    return False


# ─── العبارات الغامضة ───
VAGUE_PHRASES = [
    # عربي
    "ايه ده", "ما هذا", "اشرحلي", "اشرح لي", "ايه الكلام", "الكلام ده",
    "ايه هي", "ايه هو", "ايه هى", "ما هي", "ما هو",
    "وايه", "ايه اسبابه", "ايه علاجه", "هو ايه", "يعني ايه",
    "فهمني", "وضحلي", "وضح لي", "قولي عنه",
    # إنجليزي
    "explain this", "explain it", "explain", "can you explain",
    "what is this", "what is it", "what does it mean", "what does this mean",
    "tell me about", "tell me more", "describe", "describe it",
    "this thing", "can you help me understand", "i don't understand",
]

def classify_question(text, finding):
    """يصنف السؤال: تحية / مشاعر / غامض / غير طبي / طبي"""
    text_lower = text.strip().lower()
    normalized = normalize_arabic(text_lower)

    # ─── 1. مشاعر وقلق (أولوية عالية للتعاطف) ───
    emotion_words = [
        "خايف", "قلقان", "مرعوب", "زعلان", "مكتئب", "خوف", "قلق",
        "خايفة", "قلقانة", "مرعوبة", "اطمن", "طمني", "يائس",
        "موت", "هموت", "اموت", "هيموتني",
        "afraid", "scared", "worried", "anxious", "depressed", "terrified",
        "die", "death", "kill", "fatal", "terminal"
    ]
    has_emotion = any(
        w in text_lower or normalize_arabic(w) in normalized
        for w in emotion_words
    )

    if has_emotion:
        question_indicators = [
            "ايه", "ما هو", "ما هي", "هل ", "كيف", "ليه", "ازاي",
            "what", "how", "is ", "can ", "why", "does", "?", "؟"
        ]
        has_question_word = any(q in text_lower for q in question_indicators)
        has_medical = has_medical_keyword(text)
        is_vague = any(
            phrase in text_lower or normalize_arabic(phrase) in normalized
            for phrase in VAGUE_PHRASES
        )

        if (has_question_word and has_medical) or (is_vague and has_medical):
            return "medical"
        else:
            return "emotion"

    # ─── 2. لو فيه كلمة طبية → طبي فوراً ───
    if has_medical_keyword(text):
        return "medical"

    # ─── 3. تحيات ───
    greetings = [
        "ازيك", "اخبارك", "كيف الحال", "كيفك",
        "صباح الخير", "مساء الخير", "اهلا", "مرحبا", "السلام عليكم",
        "hello", "hi ", "hey ", "how are you", "good morning", "good evening",
        "good afternoon", "greetings"
    ]
    for phrase in greetings:
        if phrase in text_lower or normalize_arabic(phrase) in normalized:
            return "greeting"

    # ─── 4. أسئلة غامضة عن التشخيص ───
    is_vague = any(
        phrase in text_lower or normalize_arabic(phrase) in normalized
        for phrase in VAGUE_PHRASES
    )
    if is_vague:
        return "vague"

    # ─── 5. غير طبي ───
    return "not_medical"


# ══════════════════════════════════════════════════════════════
# Red Flags (أعراض طوارئ)
# ══════════════════════════════════════════════════════════════
RED_FLAGS_AR = [
    "مش قادر اتنفس", "ضيق تنفس شديد", "ألم شديد في الصدر",
    "وجع شديد في الصدر", "دم في البلغم", "بصق دم", "كحة دم",
    "ازرقاق", "فقدت الوعي", "اختناق"
]

RED_FLAGS_EN = [
    "can't breathe", "cannot breathe", "severe chest pain",
    "coughing blood", "coughing up blood", "blue lips",
    "passed out", "choking", "hemoptysis"
]

EMERGENCY_FINDINGS = ["Pneumothorax"]


def has_red_flag(text):
    """يتحقق من وجود أعراض طوارئ"""
    text_lower = text.lower()
    normalized = normalize_arabic(text_lower)
    for flag in RED_FLAGS_AR + RED_FLAGS_EN:
        if flag in text_lower or normalize_arabic(flag) in normalized:
            return True
    return False


# ══════════════════════════════════════════════════════════════
# الدالة الرئيسية: medical_rag
# ══════════════════════════════════════════════════════════════
def medical_rag(question, finding, session_id=None):
    """الدالة الرئيسية للإجابة على الأسئلة الطبية"""

    # 1. فحص صحة السؤال
    is_valid, error_msg = is_valid_question(question)
    if not is_valid:
        return error_msg

    # 2. كشف اللغة
    q_lang = detect_language(question)
    finding_ar = medical_knowledge[finding]["name_ar"]

    # 3. تصنيف السؤال
    category = classify_question(question, finding)

    # 4. مشاعر أو قلق → تعاطف
    if category == "emotion":
        if q_lang == "ar":
            return (
                "أنا متفهم جداً قلقك وخوفك، وده شعور طبيعي جداً. لكن تذكر إن التشخيص المبكر والمتابعة مع الطبيب هما أول وأهم خطوة للعلاج والشفاء بإذن الله. "
                "لا تتردد في زيارة الطبيب، هو أكتر شخص هيقدر يطمنك ويساعدك. لو عندك أي أسئلة عن طبيعة التشخيص عشان تطمن أكتر، أنا هنا لمساعدتك."
            )
        else:
            return (
                "I completely understand your fear and anxiety, and it's a very natural feeling. However, please remember that early diagnosis and consulting with a doctor are the most important steps towards treatment and recovery. "
                "Do not hesitate to visit your doctor; they are the best person to reassure and help you. If you have any questions about the diagnosis to help you feel more at ease, I am here to help."
            )

    # 5. تحية
    if category == "greeting":
        if q_lang == "ar":
            return (
                f"أهلاً بك! أنا هنا لمساعدتك في فهم تشخيصك ({finding_ar}). "
                f"يمكنك أن تسألني عن الأعراض، الأسباب، العلاج، أو أي شيء آخر متعلق بحالتك."
            )
        else:
            return (
                f"Hello! I'm here to help you understand your diagnosis ({finding}). "
                f"You can ask me about symptoms, causes, treatment, or anything related to your condition."
            )

    # 6. غير طبي → رفض مهذب
    if category == "not_medical":
        if q_lang == "ar":
            return (
                f"السؤال ده خارج نطاق تخصصي. أنا مساعد طبي متخصص في شرح نتائج أشعة الصدر فقط.\n\n"
                f"ممكن تسألني مثلاً:\n"
                f"• ايه هو {finding_ar}؟\n"
                f"• ايه أعراض {finding_ar}؟\n"
                f"• هل {finding_ar} خطير؟\n"
                f"• ايه العلاج المتاح؟"
            )
        else:
            return (
                f"This question is outside my scope. I am a medical assistant specialized in chest X-ray findings only.\n\n"
                f"You can ask me for example:\n"
                f"• What is {finding}?\n"
                f"• What are the symptoms of {finding}?\n"
                f"• Is {finding} serious?\n"
                f"• What treatment is available?"
            )

    # 7. تحديد جملة البحث وسؤال الموديل (معالجة الأسئلة الغامضة أو المركبة)
    q_lower = question.lower()
    q_norm = normalize_arabic(q_lower)
    has_vague = any(p in q_lower or normalize_arabic(p) in q_norm for p in VAGUE_PHRASES)

    if has_vague or category == "vague":
        if q_lang == "ar":
            search_query = f"ما هو {finding_ar}؟ وأسبابه وأعراضه. {question}"
            question_to_llm = f"اشرح ما هو {finding_ar} ({finding}) باختصار ثم أجب على: {question}"
        else:
            search_query = f"What is {finding}? symptoms and causes. {question}"
            question_to_llm = f"Explain what {finding} is briefly, then answer: {question}"
    else:
        # سؤال طبي واضح لا يحتوي على عبارات غامضة
        search_query = question + f" {finding_ar}"
        question_to_llm = question

    # 8. البحث مع فلترة اللغة
    retrieved = search_with_score(search_query, finding_filter=finding, k=3)

    # 9. لو مفيش نتائج خالص
    if not retrieved:
        if q_lang == "ar":
            return f"عذراً، لا توجد معلومات كافية عن {finding_ar} حالياً. من فضلك استشير طبيبك."
        else:
            return f"Sorry, not enough information about {finding}. Please consult your doctor."

    # 10. تجهيز الـ Context
    clean_context = []
    for r in retrieved:
        text = r["text"]
        if "A:" in text:
            text = text.split("A:", 1)[1].strip()
        clean_context.append(text)

    context = "\n\n".join(clean_context)

    # 11. بناء الـ Prompt
    system_msg = build_system_prompt(question_to_llm, finding, context)

    # ─── إضافة تعليمات للتعاطف لو السؤال طبي بس فيه مشاعر ───
    emotion_words = [
        "خايف", "قلقان", "مرعوب", "زعلان", "مكتئب", "خوف", "قلق",
        "خايفة", "قلقانة", "مرعوبة", "اطمن", "طمني", "يائس",
        "موت", "هموت", "اموت", "هيموتني",
        "afraid", "scared", "worried", "anxious", "depressed", "terrified",
        "die", "death", "kill", "fatal", "terminal"
    ]
    has_emotion = any(
        w in q_lower or normalize_arabic(w) in q_norm
        for w in emotion_words
    )
    if has_emotion:
        if q_lang == "ar":
            system_msg += "\n\nملاحظة هامة: المريض خائف أو قلق أو يسأل عن الموت. ابدأ إجابتك بجملة تعاطف وطمأنة بناءً على المعلومات الطبية المتاحة، ثم أجب على سؤاله."
        else:
            system_msg += "\n\nIMPORTANT: The patient is scared, anxious, or asking about death. Start your response with an empathetic and reassuring sentence based on the medical facts, then answer their question."

    messages = [
        {"role": "system", "content": system_msg},
        {"role": "user", "content": question_to_llm}
    ]

    # 12. توليد الإجابة مع retry وتنظيف
    answer = generate_answer(messages, q_lang, max_retries=2)

    return answer


# ══════════════════════════════════════════════════════════════
# الواجهة الرئيسية: safe_medical_chat
# ══════════════════════════════════════════════════════════════
def safe_medical_chat(question, finding, session_id=None):
    """الواجهة الرئيسية للشات"""
    q_lang = detect_language(question)

    # 1. Red flags
    if has_red_flag(question):
        if q_lang == "ar":
            return (
                "⚠️ تحذير: الأعراض اللي وصفتها ممكن تكون خطيرة. "
                "توجه فوراً لأقرب طوارئ أو اتصل بالإسعاف."
            )
        else:
            return (
                "⚠️ Warning: The symptoms you described may be serious. "
                "Please go to the nearest emergency room or call an ambulance immediately."
            )

    # 2. الإجابة
    answer = medical_rag(question, finding, session_id)

    # 3. لو رد ترحيب أو رفض أو تعاطف → نرجعه بدون disclaimer
    skip_markers = [
        "أهلاً بك", "Hello!", "أنا مساعد طبي",
        "I am a medical assistant", "خارج نطاق تخصصي",
        "outside my scope", "مش قادر ألاقي",
        "I couldn't find", "مش قادر أفهم",
        "I couldn't understand", "السؤال قصير",
        "أنا متفهم", "I completely understand",
        "عذراً", "Sorry",
    ]
    if any(marker in answer for marker in skip_markers):
        return answer

    # 4. ملاحظة طوارئ
    emergency_note = ""
    if finding in EMERGENCY_FINDINGS:
        if q_lang == "ar":
            emergency_note = (
                "\n\n⚠️ ملاحظة مهمة: التشخيص ده ممكن يكون حالة طارئة. "
                "لو عندك أعراض شديدة، توجه للطوارئ فوراً."
            )
        else:
            emergency_note = (
                "\n\n⚠️ Important: This diagnosis may be an emergency. "
                "If you have severe symptoms, go to the emergency room immediately."
            )

    # 5. Disclaimer
    if q_lang == "ar":
        disclaimer = "\n\n---\nملاحظة: المعلومات دي للتثقيف فقط وليست بديلاً عن استشارة الطبيب."
    else:
        disclaimer = "\n\n---\nNote: This information is for education only and is not a substitute for medical advice."

    return answer + emergency_note + disclaimer



# ─── FASTAPI APPLICATION ──────────────────────────────────────────────────────
app = FastAPI(title="MediScan AI Service", description="Chest X-Ray AI Backend — RAD-DINO + Qwen + FAISS RAG", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

class PredictRequest(BaseModel): image_path: Optional[str] = None
class PredictionItem(BaseModel): label: str; probability: float; threshold: float; positive: bool; severity: str; info: str
class PredictResponse(BaseModel): predictions: List[PredictionItem]; diagnosis_output: Dict; heatmaps: Dict[str, str]; heatmap_path: Optional[str]; bounding_boxes: List
class ReportRequest(BaseModel): predictions: List[Dict]; language: str = "en"
class ReportResponse(BaseModel): findings: str; impression: str; recommendations: str; full_report: str
class ChatRequest(BaseModel): question: str; finding: str; session_id: Optional[str] = None; language: str = "en"
class ChatResponse(BaseModel): answer: str; finding: str; success: bool

@app.get("/health")
def health_check(): return {"status": "ok", "models_loaded": models._initialized}

@app.get("/findings")
def get_findings(): return {"findings": [{"name_en": name, "name_ar": info["name_ar"]} for name, info in models.medical_knowledge.items()]}

@app.post("/predict")
async def predict(file: UploadFile = File(None), request: PredictRequest = None):
    try:
        image_bytes = None
        if file is not None: image_bytes = await file.read()
        elif request and request.image_path:
            if request.image_path.startswith("http"):
                req = urllib.request.Request(request.image_path)
                with urllib.request.urlopen(req) as resp: image_bytes = resp.read()
            else:
                with open(request.image_path, "rb") as f: image_bytes = f.read()
        if not image_bytes: raise HTTPException(status_code=400, detail="No image provided")
        
        img_array = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"))
        is_valid, prob = is_valid_xray(img_array)
        if not is_valid:
            raise HTTPException(status_code=400, detail=f"Image rejected by Gatekeeper (p={prob:.2%}). Please upload a valid chest X-ray.")

        return run_prediction(image_bytes, img_array)
    except HTTPException: raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.post("/generate_report", response_model=ReportResponse)
async def generate_report_endpoint(request: ReportRequest):
    try: return generate_radiology_report(request.predictions, request.language)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Report generation failed: {str(e)}")

@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    try:
        if request.finding not in models.medical_knowledge:
            return ChatResponse(answer=f"Unknown finding '{request.finding}'. Select from available findings.", finding=request.finding, success=False)
        answer = safe_medical_chat(question=request.question, finding=request.finding, session_id=request.session_id)
        return ChatResponse(answer=answer, finding=request.finding, success=True)
    except Exception as e:
        traceback.print_exc()
        return ChatResponse(answer=f"Error: {str(e)}", finding=request.finding, success=False)

# ─── NGROK & SERVER LAUNCH ────────────────────────────────────────────────────
nest_asyncio.apply()
conf.get_default().auth_token = NGROK_AUTH_TOKEN
try: ngrok.kill()
except Exception: pass

public_url = ngrok.connect(FASTAPI_PORT)
public_url_str = str(public_url)
if "NgrokTunnel" in public_url_str:
    match = re.search(r'"(https?://[^"]+)"', public_url_str)
    if match: public_url_str = match.group(1)

print("\n" + "=" * 60)
print(f"  🚀 PUBLIC URL: {public_url_str}")
print("=" * 60)

def run_server():
    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT, log_level="info")

server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

time.sleep(3)
print(f"\n✅ Server is running. Keep this Kaggle session active to maintain the tunnel.")

# ─── KEEP ALIVE ───────────────────────────────────────────────────────────────
print("🔄 Keep-alive loop started. Press Stop ⏹️ in Kaggle to shut down.")
try:
    while True:
        time.sleep(60)
        try:
            resp = http_requests.get(f"http://localhost:{FASTAPI_PORT}/health", timeout=5)
            if resp.status_code == 200: print(f"  💚 Server healthy at {time.strftime('%H:%M:%S')}")
            else: print(f"  🟡 Health check returned {resp.status_code}")
        except Exception:
            print(f"  🔴 Health check failed at {time.strftime('%H:%M:%S')}")
except KeyboardInterrupt:
    print("\n⏹️ Keep-alive stopped.")
