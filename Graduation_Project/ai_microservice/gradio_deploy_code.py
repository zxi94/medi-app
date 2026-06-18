# === CELL 0 ===
"""
Chest X-Ray Multi-Label Classifier — Gradio Web App (Dark Theme + GradCAM)
===========================================================================
RAD-DINO ViT-B/14 · 11 classes · TTA · Optimized thresholds
Visual explanations: HiResCAM + per-class anatomical priors
+ aggressive corner masking + paper-style overlay
"""
import subprocess, sys
for pkg in ["gradio", "transformers", "albumentations", "pydicom",
            "nest_asyncio", "scipy"]:
    subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=False)

import json, time
from pathlib import Path
import numpy as np
import torch
import torch.nn as nn
from PIL import Image
import gradio as gr
import timm
import albumentations as A
from albumentations.pytorch import ToTensorV2
from transformers import AutoModel
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use("Agg")

try:
    import nest_asyncio
    nest_asyncio.apply()
except Exception:
    pass

try:
    from scipy.ndimage import gaussian_filter
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False

try:
    import pydicom
    HAS_PYDICOM = True
except ImportError:
    HAS_PYDICOM = False


# =============================================================================
# Config
# =============================================================================
WORKING_DIR = Path("/kaggle/working")

MODEL_PATHS = [
    WORKING_DIR / "best_model_ema.pth",
    WORKING_DIR / "best_model.pth",
    Path("/kaggle/input/models/refaatelia/ep10/pytorch/default/1/best_model_ema.pth"),
    Path("/kaggle/input/private-data-source/best_model.pth"),
]
MODEL_PATH = next((p for p in MODEL_PATHS if p.exists()), None)
if MODEL_PATH is None:
    raise FileNotFoundError("No model checkpoint found")

THRESHOLD_PATHS = [
    WORKING_DIR / "optimal_thresholds.json",
    Path("/kaggle/input/private-data-source/optimal_thresholds.json"),
]

DEVICE       = torch.device("cuda" if torch.cuda.is_available() else "cpu")
RADDINO_NAME = "microsoft/rad-dino"
IMAGE_SIZE   = 518
NORM_MEAN    = [0.5307, 0.5307, 0.5307]
NORM_STD     = [0.2583, 0.2583, 0.2583]
USE_TTA      = True

UNIFIED_LABELS = [
    "Aortic enlargement", "Atelectasis", "Calcification", "Cardiomegaly",
    "Consolidation", "Lung Opacity", "Nodule/Mass", "Pleural effusion",
    "Pleural thickening", "Pneumothorax", "Pulmonary fibrosis",
]

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

SEVERITY = {
    "Pneumothorax": "🔴 URGENT", "Aortic enlargement": "🔴 URGENT",
    "Cardiomegaly": "🟠 IMPORTANT", "Pleural effusion": "🟠 IMPORTANT",
    "Consolidation": "🟠 IMPORTANT", "Nodule/Mass": "🟠 IMPORTANT",
    "Atelectasis": "🟡 NOTABLE", "Lung Opacity": "🟡 NOTABLE",
    "Pulmonary fibrosis": "🟡 NOTABLE",
    "Pleural thickening": "🟢 INCIDENTAL", "Calcification": "🟢 INCIDENTAL",
}

# =============================================================================
# Per-class anatomical priors (relative coordinates 0-1 in image space)
# Each entry: list of (cy, cx, sy, sx, weight) Gaussian blobs to combine.
# cy/cx = center, sy/sx = std dev in normalized coords, weight = relative
# These reflect where each finding TYPICALLY appears on a frontal chest X-ray.
# =============================================================================
ANATOMY_PRIORS = {
    "Aortic enlargement":  [(0.32, 0.50, 0.10, 0.12, 1.0)],   # upper mediastinum
    "Cardiomegaly":        [(0.55, 0.50, 0.13, 0.18, 1.0)],   # heart silhouette (center-low)
    "Pleural effusion":    [(0.78, 0.25, 0.10, 0.12, 1.0),    # left base (image right)
                            (0.78, 0.75, 0.10, 0.12, 1.0)],   # right base (image left)
    "Pleural thickening":  [(0.50, 0.12, 0.20, 0.08, 1.0),    # left lateral
                            (0.50, 0.88, 0.20, 0.08, 1.0)],   # right lateral
    "Pneumothorax":        [(0.30, 0.18, 0.15, 0.10, 1.0),    # left apex/lateral
                            (0.30, 0.82, 0.15, 0.10, 1.0)],   # right apex/lateral
    "Atelectasis":         [(0.55, 0.30, 0.18, 0.15, 1.0),    # both lung fields
                            (0.55, 0.70, 0.18, 0.15, 1.0)],
    "Consolidation":       [(0.55, 0.30, 0.20, 0.15, 1.0),
                            (0.55, 0.70, 0.20, 0.15, 1.0)],
    "Lung Opacity":        [(0.50, 0.30, 0.22, 0.16, 1.0),
                            (0.50, 0.70, 0.22, 0.16, 1.0)],
    "Nodule/Mass":         [(0.45, 0.30, 0.22, 0.16, 1.0),
                            (0.45, 0.70, 0.22, 0.16, 1.0)],
    "Pulmonary fibrosis":  [(0.65, 0.25, 0.18, 0.14, 1.0),    # lower lung fields
                            (0.65, 0.75, 0.18, 0.14, 1.0)],
    "Calcification":       [(0.50, 0.50, 0.30, 0.30, 1.0)],   # broad — anywhere
}


# =============================================================================
# Load thresholds
# =============================================================================
HARDCODED_THRESHOLDS = {
    "Aortic enlargement": 0.810, "Atelectasis": 0.855, "Calcification": 0.828,
    "Cardiomegaly": 0.647, "Consolidation": 0.642, "Lung Opacity": 0.665,
    "Nodule/Mass": 0.909, "Pleural effusion": 0.728, "Pleural thickening": 0.715,
    "Pneumothorax": 0.846, "Pulmonary fibrosis": 0.905,
}
THRESHOLDS_DICT = {lb: 0.5 for lb in UNIFIED_LABELS}
threshold_source = "default 0.5"
for path in THRESHOLD_PATHS:
    if path.exists():
        try:
            with open(path) as f:
                thr_data = json.load(f)
            if "thresholds" in thr_data:
                for lb, t in thr_data["thresholds"].items():
                    if lb in THRESHOLDS_DICT:
                        THRESHOLDS_DICT[lb] = float(t)
                threshold_source = str(path)
                print(f"  ✓ Loaded thresholds from: {path}")
                break
        except Exception as e:
            print(f"  ⚠ Failed to load {path}: {e}")
if threshold_source == "default 0.5":
    print(f"  ⚠ Using hardcoded thresholds")
    THRESHOLDS_DICT.update(HARDCODED_THRESHOLDS)
    threshold_source = "hardcoded"
THRESHOLDS = np.array([THRESHOLDS_DICT[lb] for lb in UNIFIED_LABELS], dtype=np.float32)



# =============================================================================
# Gatekeeper Model
# =============================================================================
GATEKEEPER_PATH = '/kaggle/input/models/refaatelia/gatekeeper/pytorch/default/1/gatekeeper_best.pth'

class GatekeeperModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.backbone = timm.create_model('mobilenetv3_small_100', pretrained=False, num_classes=0, drop_rate=0.3)
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

gk_model = None
try:
    if Path(GATEKEEPER_PATH).exists():
        gk_ckpt = torch.load(GATEKEEPER_PATH, map_location=DEVICE, weights_only=False)
        gk_model = GatekeeperModel().to(DEVICE)
        gk_model.load_state_dict(gk_ckpt['model_state'])
        gk_model.eval()
        print('  ✓ Gatekeeper loaded')
except Exception as e:
    print(f'  ⚠ Gatekeeper failed to load: {e}')

GK_TRANSFORM = A.Compose([
    A.Resize(224, 224),
    A.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ToTensorV2(),
])

def is_valid_xray(img_array):
    if gk_model is None: return True, 1.0
    tensor = GK_TRANSFORM(image=img_array)['image'].unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        prob = torch.sigmoid(gk_model(tensor)).item()
    return prob >= 0.50, prob

# =============================================================================
# Translation Dicts
# =============================================================================
AR_LABELS = {
    'Aortic enlargement': 'تضخم الأبهر', 'Atelectasis': 'انخماص رئوي (انكماش)', 
    'Calcification': 'تكلس', 'Cardiomegaly': 'تضخم القلب',
    'Consolidation': 'تصلب رئوي', 'Lung Opacity': 'عتامة في الرئة', 
    'Nodule/Mass': 'عقدة/كتلة', 'Pleural effusion': 'انصباب جنبي',
    'Pleural thickening': 'تسمك جنبي', 'Pneumothorax': 'استرواح صدري', 
    'Pulmonary fibrosis': 'تليف رئوي'
}
AR_SEVERITY = {
    '🔴 URGENT': '🔴 عاجل', '🟠 IMPORTANT': '🟠 هام',
    '🟡 NOTABLE': '🟡 ملحوظ', '🟢 INCIDENTAL': '🟢 عرضي', '⚪': '⚪'
}

# =============================================================================
# Model
# =============================================================================
class RadDinoModel(nn.Module):
    def __init__(self, num_classes, dropout=0.3):
        super().__init__()
        self.backbone = AutoModel.from_pretrained(RADDINO_NAME)
        feat_dim = self.backbone.config.hidden_size
        self.head = nn.Sequential(
            nn.LayerNorm(feat_dim),
            nn.Dropout(dropout),
            nn.Linear(feat_dim, num_classes),
        )
    def forward(self, x):
        out = self.backbone(pixel_values=x)
        return self.head(out.last_hidden_state[:, 0])


print(f"\nLoading: {MODEL_PATH}")
ckpt = torch.load(MODEL_PATH, map_location=DEVICE, weights_only=False)
if isinstance(ckpt, dict) and "model_state_dict" in ckpt:
    state = ckpt.get("ema_state_dict") or ckpt["model_state_dict"]
    MACRO_AUC = ckpt.get("best_auc", 0.9758)
    EPOCH = ckpt.get("epoch", "?")
elif isinstance(ckpt, dict):
    state = ckpt; MACRO_AUC = 0.9758; EPOCH = "?"
else:
    state = ckpt; MACRO_AUC = 0.9758; EPOCH = "?"

model = RadDinoModel(len(UNIFIED_LABELS)).to(DEVICE)
model.load_state_dict(state)
model.eval()

try:
    if hasattr(model.backbone, "gradient_checkpointing_disable"):
        model.backbone.gradient_checkpointing_disable()
except Exception:
    pass

print(f"  ✓ Model loaded (ep{EPOCH}, AUC≈{MACRO_AUC:.4f})")
print(f"  ✓ TTA: {USE_TTA}  |  Device: {DEVICE.type.upper()}")

try:
    n_layers = model.backbone.config.num_hidden_layers
    print(f"  ✓ Backbone has {n_layers} transformer layers")
except Exception:
    n_layers = None

TRANSFORM = A.Compose([
    A.Resize(IMAGE_SIZE, IMAGE_SIZE),
    A.Normalize(mean=NORM_MEAN, std=NORM_STD),
    ToTensorV2(),
])


# =============================================================================
# Helpers — corner crop + chest mask + per-class anatomical prior
# =============================================================================
def crop_borders(img_array, crop_pct=0.05):
    """Crop borders to remove laterality markers / text."""
    if crop_pct <= 0:
        return img_array
    h, w = img_array.shape[:2]
    ch, cw = int(h * crop_pct), int(w * crop_pct)
    if ch == 0 and cw == 0:
        return img_array
    return img_array[ch:h-ch, cw:w-cw]


def build_class_prior(label, H, W, base_strength=1.0, blur_sigma=15.0):
    """
    Build a soft anatomical prior mask for a given finding.
    Returns a [H, W] float array in [0, 1] showing where the finding
    is anatomically expected on a frontal chest X-ray.
    """
    blobs = ANATOMY_PRIORS.get(label,
                                [(0.5, 0.5, 0.25, 0.25, 1.0)])  # default broad center
    y, x = np.ogrid[:H, :W]
    yn = y / H
    xn = x / W
    prior = np.zeros((H, W), dtype=np.float32)
    for (cy, cx, sy, sx, w) in blobs:
        d = ((xn - cx) ** 2) / (2 * sx ** 2) + ((yn - cy) ** 2) / (2 * sy ** 2)
        prior = np.maximum(prior, w * np.exp(-d))
    if prior.max() > 1e-8:
        prior = prior / prior.max()
    # Blend with constant so we don't completely zero outside region
    prior = (1.0 - base_strength) + base_strength * prior
    return prior.astype(np.float32)


def hard_border_mask(H, W, border_pct=0.06):
    """
    Hard rectangular mask that kills the outer border (corners + edges).
    Far more aggressive than the elliptical mask for corner suppression.
    """
    if border_pct <= 0:
        return np.ones((H, W), dtype=np.float32)
    mask = np.ones((H, W), dtype=np.float32)
    bh = int(H * border_pct)
    bw = int(W * border_pct)
    # Build a smooth ramp from the border inward
    ramp_y = np.ones(H, dtype=np.float32)
    ramp_x = np.ones(W, dtype=np.float32)
    for i in range(bh):
        v = (i / max(bh - 1, 1)) ** 1.5  # quadratic ramp for smoothness
        ramp_y[i] = v
        ramp_y[H - 1 - i] = v
    for j in range(bw):
        v = (j / max(bw - 1, 1)) ** 1.5
        ramp_x[j] = v
        ramp_x[W - 1 - j] = v
    mask = ramp_y[:, None] * ramp_x[None, :]
    return mask


# =============================================================================
# ViT GradCAM — uses output_hidden_states (NO HOOKS)
# =============================================================================
def compute_cam(model, x, class_idx, layer_idx=-2,
                method="hirescam", contrastive=True, verbose=False):
    """Per-class CAM via output_hidden_states."""
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

        grads = torch.autograd.grad(
            score, hidden, retain_graph=False, create_graph=False
        )[0]

    act = hidden.detach().float()
    grd = grads.detach().float()

    if verbose:
        print(f"    [layer={layer_idx}] |act|_mean={act.abs().mean():.4f}  "
              f"|grad|_mean={grd.abs().mean():.6f}")

    tokens = act[:, 1:, :]
    g_tok  = grd[:, 1:, :]

    if method == "hirescam":
        cam = (tokens * g_tok).sum(dim=-1)[0]
        cam = torch.relu(cam)
    elif method == "gradcam":
        w = g_tok.mean(dim=1, keepdim=True)
        cam = (w * tokens).sum(dim=-1)[0]
        cam = torch.relu(cam)
    elif method == "gradxinput":
        cam = (tokens * g_tok).abs().sum(dim=-1)[0]
    else:
        raise ValueError(method)

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


def postprocess_cam(cam_2d, H, W, class_label,
                    blur_sigma=10.0, gamma=1.0,
                    border_pct=0.08,
                    prior_strength=0.6):
    """
    Process raw CAM:
      1. Resize to image space
      2. Multiply by HARD rectangular border mask (kills corners aggressively)
      3. Multiply by per-class ANATOMICAL PRIOR (focuses on expected region)
      4. Heavy Gaussian blur for smooth blob look
      5. Renormalize + optional gamma
    """
    cam = cam_2d.astype(np.float32)
    cam = cam - cam.min()
    if cam.max() > 1e-10:
        cam = cam / cam.max()

    # Resize to image space
    cam_pil = Image.fromarray((cam * 255).astype(np.uint8))
    cam = np.array(cam_pil.resize((W, H), Image.BICUBIC)) / 255.0

    # 1. Kill the corners (hard rectangular)
    if border_pct > 0:
        cam = cam * hard_border_mask(H, W, border_pct=border_pct)

    # 2. Apply per-class anatomical prior
    if prior_strength > 0 and class_label in ANATOMY_PRIORS:
        prior = build_class_prior(class_label, H, W, base_strength=prior_strength)
        cam = cam * prior

    # 3. Heavy blur
    if HAS_SCIPY and blur_sigma > 0:
        cam = gaussian_filter(cam, sigma=blur_sigma * (H / 224.0))

    # Renormalize
    cam = cam - cam.min()
    if cam.max() > 1e-10:
        cam = cam / cam.max()

    # Gamma
    if gamma != 1.0:
        cam = np.power(cam, gamma)

    return cam.astype(np.float32)


def make_heatmap_overlay(image_rgb, heatmap, alpha=0.55, colormap="jet"):
    """Classic paper-style overlay — full-frame jet colormap."""
    if heatmap.shape[:2] != image_rgb.shape[:2]:
        h_pil = Image.fromarray((heatmap * 255).astype(np.uint8))
        h_pil = h_pil.resize((image_rgb.shape[1], image_rgb.shape[0]),
                              Image.BILINEAR)
        heatmap = np.array(h_pil) / 255.0
    cmap = plt.get_cmap(colormap)
    heat_rgb = (cmap(heatmap)[:, :, :3] * 255).astype(np.uint8)
    img = image_rgb.astype(np.float32)
    blended = (1 - alpha) * img + alpha * heat_rgb.astype(np.float32)
    return blended.clip(0, 255).astype(np.uint8)


print("\n  GradCAM ready (no hooks — uses output_hidden_states)")


# =============================================================================
# Image loading
# =============================================================================
def read_dicom(path):
    ds = pydicom.dcmread(path)
    img = ds.pixel_array.astype(np.float32)
    slope = getattr(ds, "RescaleSlope", 1)
    intercept = getattr(ds, "RescaleIntercept", 0)
    if slope != 1 or intercept != 0:
        img = img * slope + intercept
    if getattr(ds, "PhotometricInterpretation", "") == "MONOCHROME1":
        img = img.max() - img
    mn, mx = img.min(), img.max()
    img = ((img - mn) / (mx - mn) * 255.0) if mx > mn else np.zeros_like(img)
    img = img.astype(np.uint8)
    if img.ndim == 2: img = np.stack([img] * 3, axis=-1)
    return img


def load_image(image_input):
    if isinstance(image_input, str):
        if image_input.lower().endswith((".dcm", ".dicom")):
            return read_dicom(image_input)
        return np.array(Image.open(image_input).convert("RGB"))
    return np.array(image_input.convert("RGB"))


# =============================================================================
# Inference
# =============================================================================
@torch.no_grad()
def predict(image_input, lang):
    is_ar = lang == 'العربية'
    if image_input is None:
        msg = "### 👋 قم برفع صورة أشعة للبدء." if is_ar else "### 👋 Upload an X-ray to begin."
        return (None, msg, None, None, "")

    t0 = time.time()
    img_array = load_image(image_input)
    
    valid_xray, prob_xray = is_valid_xray(img_array)
    if not valid_xray:
        msg = f"### ❌ خطأ: الصورة المرفوعة لا تبدو كأشعة سينية للصدر (نسبة الثقة {prob_xray:.1%}).\nيُرجى رفع صورة أشعة صحيحة." if is_ar else f"### ❌ Error: The uploaded image does not appear to be a chest X-ray (confidence {prob_xray:.1%}).\nPlease upload a valid chest X-ray."
        return (None, msg, None, None, "")

    x = TRANSFORM(image=img_array)["image"].unsqueeze(0).to(DEVICE)

    logits = model(x).float()
    if USE_TTA:
        logits_f = model(torch.flip(x, dims=[3])).float()
        logits = (logits + logits_f) / 2

    probs = torch.sigmoid(logits)[0].cpu().numpy()
    elapsed_ms = (time.time() - t0) * 1000
    label_dict = {lb: float(probs[i]) for i, lb in enumerate(UNIFIED_LABELS)}

    positives = []
    for i, lb in enumerate(UNIFIED_LABELS):
        if probs[i] >= THRESHOLDS[i]:
            positives.append({
                "label": lb, "prob": float(probs[i]),
                "thr": float(THRESHOLDS[i]),
                "severity": SEVERITY.get(lb, "⚪"),
                "info": CLASS_INFO.get(lb, ""),
            })
    positives.sort(key=lambda x: x["prob"], reverse=True)

    if positives:
        lines = [f"### 🔍 النتائج المكتشفة ({len(positives)})\n"] if is_ar else [f"### 🔍 Detected Findings ({len(positives)})\n"]
        for p in positives:
            margin = (p["prob"] - p["thr"]) * 100
            lbl = AR_LABELS.get(p['label'], p['label']) if is_ar else p['label']
            sev = AR_SEVERITY.get(p['severity'], p['severity']) if is_ar else p['severity']
            info = "" if is_ar else f"<span style='opacity:0.7;font-size:0.9em'>{p['info']}</span>\n"
            lines.append(
                f"**{sev} &nbsp; {lbl}** &nbsp;&nbsp; "
                f"`{p['prob']:.1%}` (thr: `{p['thr']:.1%}`, +{margin:.1f}pp)<br>{info}"
            )
        report_md = "\n".join(lines)
    else:
        top_idx = int(np.argmax(probs))
        if is_ar:
            lbl = AR_LABELS.get(UNIFIED_LABELS[top_idx], UNIFIED_LABELS[top_idx])
            report_md = (
                "### ✅ لا توجد تشوهات ملحوظة\n\n"
                f"أعلى نسبة: **{lbl}** بنسبة `{probs[top_idx]:.1%}` "
                f"(الحد الأدنى: `{THRESHOLDS[top_idx]:.1%}`)<br><br>"
                "<span style='opacity:0.7'>يتطلب الارتباط السريري.</span>"
            )
        else:
            report_md = (
                "### ✅ No abnormalities detected\n\n"
                f"Highest score: **{UNIFIED_LABELS[top_idx]}** at `{probs[top_idx]:.1%}` "
                f"(threshold: `{THRESHOLDS[top_idx]:.1%}`)<br><br>"
                "<span style='opacity:0.7'>Clinical correlation required.</span>"
            )

    table_rows = []
    for i, lb in enumerate(UNIFIED_LABELS):
        flag = "🟢 POSITIVE" if probs[i] >= THRESHOLDS[i] else "⚪ negative"
        if is_ar: flag = "🟢 إيجابي" if probs[i] >= THRESHOLDS[i] else "⚪ سلبي"
        lbl = AR_LABELS.get(lb, lb) if is_ar else lb
        sev_icon = SEVERITY.get(lb, "⚪").split(" ")[0]
        table_rows.append([sev_icon, lbl, f"{probs[i]:.1%}",
                           f"{THRESHOLDS[i]:.1%}", flag])
    table_rows.sort(key=lambda r: float(r[2].rstrip("%")), reverse=True)

    fig = build_probability_chart(probs, THRESHOLDS, UNIFIED_LABELS, is_ar)
    info_md = (f"**Inference time:** `{elapsed_ms:.0f} ms`  |  "
               f"**TTA:** `{'on' if USE_TTA else 'off'}`  |  "
               f"**Device:** `{DEVICE.type.upper()}`")
    return label_dict, report_md, table_rows, fig, info_md


def build_probability_chart(probs, thresholds, labels, is_ar=False):
    plt.style.use("dark_background")
    fig, ax = plt.subplots(figsize=(10, 6), facecolor="#0f0f14")
    ax.set_facecolor("#0f0f14")
    order = np.argsort(probs)[::-1]
    y = np.arange(len(labels))
    sp = probs[order]; st = thresholds[order]; sl = [AR_LABELS.get(labels[i], labels[i]) if is_ar else labels[i] for i in order]
    colors = ["#10b981" if p >= t else "#3b82f6" for p, t in zip(sp, st)]
    ax.barh(y, sp, color=colors, alpha=0.85, edgecolor="white",
            linewidth=0.5, height=0.6)
    for i, t in enumerate(st):
        ax.plot([t, t], [i - 0.35, i + 0.35], color="#f43f5e",
                linewidth=2, alpha=0.9)
    for i, p in enumerate(sp):
        ax.text(p + 0.01, i, f"{p:.1%}", va="center",
                color="white", fontsize=9, fontweight="bold")
    ax.set_yticks(y); ax.set_yticklabels(sl, fontsize=10, color="#e5e7eb")
    ax.set_xlim([0, 1.08])
    ax.set_xlabel("الاحتمالية" if is_ar else "Probability", color="#9ca3af", fontsize=10)
    title = "التوقعات لكل فئة (الخط الأحمر = الحد الأدنى)" if is_ar else "Per-Class Predictions  (red lines = thresholds)"
    ax.set_title(title, color="#e5e7eb", fontsize=11, pad=12)
    ax.invert_yaxis()
    ax.spines["top"].set_visible(False); ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#374151"); ax.spines["bottom"].set_color("#374151")
    ax.tick_params(colors="#9ca3af")
    ax.grid(True, axis="x", alpha=0.15, color="#6b7280")
    plt.tight_layout()
    return fig


def predict_with_gradcam(image_input, top_k, layer_idx, method,
                         blur_sigma, gamma, alpha, contrastive,
                         crop_pct, border_pct, prior_strength):
    if image_input is None:
        return None, "⚠️ Please upload an image first."

    print("\n" + "="*70)
    print(f"GradCAM run: layer={layer_idx} method={method} contrastive={contrastive}")
    print(f"  blur={blur_sigma} γ={gamma} α={alpha} crop={crop_pct} "
          f"border={border_pct} prior={prior_strength}")
    print("="*70)

    top_k = int(top_k)
    img_array = load_image(image_input)

    # Crop borders BEFORE inference to remove markers
    img_array = crop_borders(img_array, crop_pct=float(crop_pct))

    img_for_model = np.array(Image.fromarray(img_array).resize(
        (IMAGE_SIZE, IMAGE_SIZE), Image.LANCZOS))
    x = TRANSFORM(image=img_for_model)["image"].unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        probs = torch.sigmoid(model(x))[0].cpu().numpy()

    top_indices = np.argsort(probs)[::-1][:top_k]

    n_cols = top_k + 1
    fig, axes = plt.subplots(1, n_cols, figsize=(4.2 * n_cols, 4.5),
                              facecolor="#0f0f14")
    if n_cols == 1: axes = [axes]

    axes[0].imshow(img_for_model)
    axes[0].set_title("Original X-Ray", color="#e5e7eb",
                       fontsize=11, fontweight="bold", pad=10)
    axes[0].axis("off")
    axes[0].set_facecolor("#0f0f14")

    for col, ci in enumerate(top_indices):
        label = UNIFIED_LABELS[ci]
        print(f"\n  → {label} (idx={ci}, prob={probs[ci]:.3f})")
        cam_2d = compute_cam(
            model, x, int(ci),
            layer_idx=int(layer_idx),
            method=method,
            contrastive=bool(contrastive),
            verbose=True,
        )
        cam = postprocess_cam(
            cam_2d, IMAGE_SIZE, IMAGE_SIZE,
            class_label=label,
            blur_sigma=float(blur_sigma),
            gamma=float(gamma),
            border_pct=float(border_pct),
            prior_strength=float(prior_strength),
        )

        overlay = make_heatmap_overlay(img_for_model, cam, alpha=float(alpha))
        axes[col + 1].imshow(overlay)
        axes[col + 1].set_facecolor("#0f0f14")
        is_positive = probs[ci] >= THRESHOLDS[ci]
        title_color = "#10b981" if is_positive else "#9ca3af"
        marker = "✓" if is_positive else "•"
        axes[col + 1].set_title(
            f"{marker} {label}\n{probs[ci]:.1%} (thr {THRESHOLDS[ci]:.0%})",
            color=title_color, fontsize=10, fontweight="bold", pad=10)
        axes[col + 1].axis("off")

    plt.suptitle(
        f"{method} · layer={layer_idx} · contrastive={bool(contrastive)} · "
        f"prior={prior_strength:.2f} · border={border_pct:.2f}",
        color="#c7d2fe", fontsize=11, fontweight="bold", y=1.02)
    plt.tight_layout()

    lines = [f"### 🔥 Per-Class Localized Heatmaps\n",
             f"**Method:** `{method}` on `layer_idx={layer_idx}` "
             f"(contrastive={bool(contrastive)})<br>",
             f"**Border crop:** `{crop_pct:.1%}` &nbsp;·&nbsp; "
             f"**Hard border mask:** `{border_pct:.1%}` &nbsp;·&nbsp; "
             f"**Anatomy prior:** `{prior_strength:.2f}`<br>",
             f"**Blur σ:** `{blur_sigma:.1f}` &nbsp;·&nbsp; "
             f"**Gamma:** `{gamma:.1f}` &nbsp;·&nbsp; "
             f"**Alpha:** `{alpha:.2f}`\n\n",
             f"**Top {top_k} predicted classes:**\n"]
    for ci in top_indices:
        is_pos = probs[ci] >= THRESHOLDS[ci]
        marker = "🟢" if is_pos else "⚪"
        lines.append(f"{marker} **{UNIFIED_LABELS[ci]}** — `{probs[ci]:.1%}` "
                     f"(thr: `{THRESHOLDS[ci]:.0%}`)<br>")
    lines.append("\n<span style='opacity:0.7;font-size:0.9em'>"
                 "ℹ️ <b>Anatomy prior</b> (0–1) blends model attention with "
                 "expected anatomical region for each finding "
                 "(heart for cardiomegaly, lung bases for effusion, etc.). "
                 "Set to 0 to see raw model attention; 0.7+ for clean "
                 "clinically-meaningful localization."
                 "</span>")
    return fig, "\n".join(lines)


# =============================================================================
# UI
# =============================================================================
custom_css = """
.gradio-container {
    background: linear-gradient(180deg, #0a0a0f 0%, #0f0f14 100%) !important;
    color: #e5e7eb !important;
    font-family: 'Inter', system-ui, sans-serif !important;
    max-width: 1400px !important; margin: 0 auto !important;
}
.app-header {
    background: linear-gradient(135deg, #1e1b4b 0%, #312e81 50%, #4338ca 100%);
    padding: 28px 32px; border-radius: 16px; margin-bottom: 20px;
    border: 1px solid #3730a3;
    box-shadow: 0 8px 32px rgba(67, 56, 202, 0.25);
}
.app-header h1 { color: #f1f5f9 !important; margin: 0 !important;
    font-size: 28px !important; font-weight: 700 !important; }
.app-header p { color: #c7d2fe !important; margin: 6px 0 0 0 !important;
    font-size: 14px !important; }
.disclaimer {
    background: linear-gradient(135deg, #7c2d12 0%, #991b1b 100%);
    border-left: 4px solid #f87171;
    padding: 14px 18px; border-radius: 8px; margin: 16px 0;
    font-size: 13px; color: #fee2e2;
}
.stats-row { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 12px; }
.stat-badge {
    background: rgba(99, 102, 241, 0.15);
    border: 1px solid rgba(99, 102, 241, 0.3);
    color: #c7d2fe; padding: 6px 14px;
    border-radius: 20px; font-size: 12px; font-weight: 500;
}
table th { background: #1f1f2e !important; color: #c7d2fe !important;
    font-weight: 600 !important; border-bottom: 2px solid #312e81 !important; }
table td { color: #e5e7eb !important; border-bottom: 1px solid #1f1f2e !important; }
.footer { text-align: center; color: #6b7280; font-size: 12px;
    padding: 20px; margin-top: 30px; border-top: 1px solid #1f1f2e; }
"""

theme = gr.themes.Base(
    primary_hue=gr.themes.colors.indigo,
    secondary_hue=gr.themes.colors.violet,
    neutral_hue=gr.themes.colors.slate,
    font=[gr.themes.GoogleFont("Inter"), "system-ui", "sans-serif"],
).set(
    body_background_fill="#0a0a0f",
    body_background_fill_dark="#0a0a0f",
    background_fill_primary="#14141c",
    background_fill_primary_dark="#14141c",
    background_fill_secondary="#1f1f2e",
    background_fill_secondary_dark="#1f1f2e",
    block_background_fill="#14141c",
    block_background_fill_dark="#14141c",
    block_border_color="#1f1f2e",
    block_border_color_dark="#1f1f2e",
    body_text_color="#e5e7eb",
    body_text_color_dark="#e5e7eb",
    button_primary_background_fill="linear-gradient(135deg, #4338ca, #6366f1)",
    button_primary_background_fill_hover="linear-gradient(135deg, #4f46e5, #818cf8)",
    button_primary_text_color="white",
    input_background_fill="#14141c",
    input_border_color="#374151",
)


with gr.Blocks(theme=theme, css=custom_css, title="Chest X-Ray AI") as demo:

    gr.HTML(f"""
    <div class="app-header">
        <h1>🫁 Chest X-Ray Multi-Label Classifier</h1>
        <p>RAD-DINO ViT-B/14 · 11 abnormality classes · Trained on 55K images</p>
        <div class="stats-row">
            <span class="stat-badge">📊 Macro AUC: {MACRO_AUC:.4f}</span>
            <span class="stat-badge">⚡ TTA: {'ON' if USE_TTA else 'OFF'}</span>
            <span class="stat-badge">🎯 Optimized thresholds</span>
            <span class="stat-badge">🔬 {IMAGE_SIZE}×{IMAGE_SIZE}px</span>
            <span class="stat-badge">💻 {DEVICE.type.upper()}</span>
        </div>
    </div>
    """)

    gr.HTML("""
    <div class="disclaimer">
        ⚠️ <b>Research Demo Only — Not for Clinical Use.</b>
        Predictions must not be used to diagnose or treat patients.
        Always consult a board-certified radiologist for medical decisions.
    </div>
    """)

    with gr.Row():
        with gr.Column(scale=1):
            gr.Markdown("### 📤 Upload Chest X-Ray")
            image_input = gr.Image(
                type="pil", label="X-Ray Image", height=420,
                sources=["upload", "clipboard"],
            )
            language_input = gr.Radio(["English", "العربية"], value="English", label="Language / اللغة")
            with gr.Row():
                analyze_btn = gr.Button("🔬 Analyze", variant="primary", size="lg")
                clear_btn = gr.Button("🗑️ Clear", size="lg")
            gr.Markdown(f"""
            #### ℹ️ Model Info
            - **Architecture:** RAD-DINO (Microsoft)
            - **Parameters:** ~86M
            - **Classes:** {len(UNIFIED_LABELS)}
            - **Source:** `{MODEL_PATH.name}`
            """)

        with gr.Column(scale=2):
            with gr.Tabs():
                with gr.Tab("📋 Report"):
                    report_output = gr.Markdown("### 👋 Upload an X-ray to begin.")
                    info_output = gr.Markdown("")

                with gr.Tab("📊 Probability Chart"):
                    chart_output = gr.Plot(label=None, show_label=False)

                with gr.Tab("📈 All Classes"):
                    table_output = gr.Dataframe(
                        headers=["", "Class", "Probability", "Threshold", "Status"],
                        datatype=["str", "str", "str", "str", "str"],
                        interactive=False, wrap=True,
                    )

                with gr.Tab("🎯 Confidence View"):
                    label_output = gr.Label(
                        num_top_classes=len(UNIFIED_LABELS),
                        label="All-class confidence scores",
                    )

                with gr.Tab("🔥 GradCAM"):
                    gr.Markdown(
                        "### 🔥 Visual Explanations — Anatomy-Aware GradCAM\n"
                        "Combines model attention with **per-class anatomical priors** "
                        "(heart for cardiomegaly, lung bases for effusion, lateral "
                        "regions for pleural thickening, etc.) → clean clinical "
                        "localization that doesn't drift to image corners."
                    )
                    with gr.Row():
                        gradcam_topk = gr.Slider(
                            minimum=2, maximum=6, value=4, step=1,
                            label="Top-K classes",
                        )
                        gradcam_layer = gr.Slider(
                            minimum=-12, maximum=-1, value=-2, step=1,
                            label="layer_idx",
                        )
                    with gr.Row():
                        gradcam_method = gr.Dropdown(
                            choices=["hirescam", "gradcam", "gradxinput"],
                            value="hirescam", label="Method",
                        )
                        gradcam_contrastive = gr.Checkbox(
                            value=True,
                            label="Contrastive (class-discriminative)",
                        )
                    with gr.Row():
                        gradcam_crop = gr.Slider(
                            minimum=0.0, maximum=0.12, value=0.05, step=0.01,
                            label="Border crop (pre-inference)",
                        )
                        gradcam_border = gr.Slider(
                            minimum=0.0, maximum=0.20, value=0.08, step=0.01,
                            label="Hard border mask (kills corners)",
                        )
                        gradcam_prior = gr.Slider(
                            minimum=0.0, maximum=1.0, value=0.7, step=0.05,
                            label="Anatomy prior strength ⭐",
                        )
                    with gr.Row():
                        gradcam_blur = gr.Slider(
                            minimum=2.0, maximum=25.0, value=10.0, step=1.0,
                            label="Blur σ",
                        )
                        gradcam_gamma = gr.Slider(
                            minimum=0.5, maximum=2.5, value=1.0, step=0.1,
                            label="Gamma",
                        )
                        gradcam_alpha = gr.Slider(
                            minimum=0.3, maximum=0.85, value=0.55, step=0.05,
                            label="Overlay alpha",
                        )
                    gradcam_btn = gr.Button("🔥 Generate Heatmaps",
                                              variant="primary", size="lg")
                    gradcam_caption = gr.Markdown(
                        "<span style='opacity:0.6'>Click after uploading an X-ray.</span>"
                    )
                    gradcam_plot = gr.Plot(label=None, show_label=False)

    gr.HTML("""
    <div class="footer">
        Built with 🤍 using Gradio + PyTorch · RAD-DINO + custom head<br>
        <span style='opacity:0.6'>Trained on 55,811 images across 4 datasets</span>
    </div>
    """)

    # ── EVENT WIRING ─────────────────────────────────────────────────────
    analyze_btn.click(
        fn=predict, inputs=[image_input, language_input],
        outputs=[label_output, report_output, table_output, chart_output, info_output],
    )

    gradcam_btn.click(
        fn=predict_with_gradcam,
        inputs=[image_input, gradcam_topk, gradcam_layer, gradcam_method,
                gradcam_blur, gradcam_gamma, gradcam_alpha,
                gradcam_contrastive, gradcam_crop, gradcam_border,
                gradcam_prior],
        outputs=[gradcam_plot, gradcam_caption],
    )

    clear_btn.click(
        fn=lambda: (
            None, None, "### 👋 Upload an X-ray to begin.",
            None, None, "",
            None,
            "<span style='opacity:0.6'>Click after uploading an X-ray.</span>"
        ),
        outputs=[image_input, label_output, report_output, table_output,
                 chart_output, info_output, gradcam_plot, gradcam_caption],
    )


# =============================================================================
# Launch
# =============================================================================
if __name__ == "__main__":
    try:
        gr.close_all()
        print("\n✓ Closed previous Gradio instances")
    except Exception as e:
        print(f"\n⚠ {e}")

    demo.queue(max_size=20).launch(
        share=True,           # public link (needed on Kaggle)
        server_name="0.0.0.0",
        server_port=7860,
        show_error=True,
        debug=False,
        inbrowser=False,
        quiet=False,
        max_threads=4,
    )

# === CELL 1 ===


