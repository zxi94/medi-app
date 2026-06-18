# =============================================================================
#  GATEKEEPER — Chest X-Ray vs. Non-Medical Image Binary Classifier
#  Designed for Kaggle Notebooks  |  PyTorch + timm + Albumentations
# =============================================================================
#
#  DATASET SETUP (run these Kaggle dataset slugs in your notebook's "Add Data"):
#   • Chest X-Rays: "nih-chest-xrays" (NIH) — or any chest-xray kaggle dataset
#     e.g. https://www.kaggle.com/datasets/nih-chest-xrays/data
#   • COCO 2017 (non-medical):
#     https://www.kaggle.com/datasets/awsaf49/coco-2017-dataset
#
#  EXPECTED INPUT PATHS (adjust INPUT_DIRS below if yours differ):
#   /kaggle/input/nih-chest-xrays/images/images_*/  (Class 1 — X-ray)
#   /kaggle/input/coco-2017-dataset/coco2017/train2017/  (Class 0 — non-medical)
#
#  OUTPUT:
#   /kaggle/working/gatekeeper_best.pth  ← best checkpoint (val loss)
#   /kaggle/working/gatekeeper_final.pth ← final epoch checkpoint
# =============================================================================

# ── 0. Install / imports ─────────────────────────────────────────────────────
# Uncomment if not pre-installed in your Kaggle env:
# !pip install -q timm albumentations --upgrade

import os
import glob
import random
import time
import copy
import numpy as np
import pandas as pd
from pathlib import Path
from PIL import Image

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler

import timm
import albumentations as A
from albumentations.pytorch import ToTensorV2

from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    accuracy_score, roc_auc_score, f1_score,
    precision_score, recall_score, confusion_matrix
)

import warnings
warnings.filterwarnings("ignore")

# ── 1. Configuration ──────────────────────────────────────────────────────────

class CFG:
    # ---- Paths ---------------------------------------------------------------
    XRAY_GLOB      = "/kaggle/input/datasets/organizations/nih-chest-xrays/data/images_*/images/*.png"
    COCO_GLOB      = "/kaggle/input/datasets/awsaf49/coco-2017-dataset/coco2017/*2017/*.jpg"

    CHECKPOINT_DIR = Path("/kaggle/working")
    BEST_CKPT      = CHECKPOINT_DIR / "gatekeeper_best.pth"
    FINAL_CKPT     = CHECKPOINT_DIR / "gatekeeper_final.pth"

    # ---- Data ----------------------------------------------------------------
    # Subsample to keep training fast — raise for better performance
    MAX_XRAY_SAMPLES = 10_000   # Class 1
    MAX_COCO_SAMPLES = 10_000   # Class 0

    VAL_SPLIT        = 0.15
    TEST_SPLIT       = 0.05
    RANDOM_SEED      = 42

    # ---- Model ---------------------------------------------------------------
    MODEL_NAME    = "mobilenetv3_small_100"   # ~2.5M params, fast & accurate
    PRETRAINED    = True
    NUM_CLASSES   = 1      # Binary — BCEWithLogitsLoss
    DROP_RATE     = 0.3    # Classifier head dropout

    # ---- Training ------------------------------------------------------------
    EPOCHS        = 5
    BATCH_SIZE    = 64
    NUM_WORKERS   = 2
    IMG_SIZE      = 224
    LR            = 3e-4
    WEIGHT_DECAY  = 1e-4

    # LR scheduler: cosine annealing with warm restarts
    T_0           = 5
    T_MULT        = 1
    ETA_MIN       = 1e-6

    # Early stopping
    PATIENCE      = 5

    # ---- Inference threshold -------------------------------------------------
    # Probability above this → valid X-ray (Class 1)
    INFERENCE_THRESHOLD = 0.50

    DEVICE = "cuda" if torch.cuda.is_available() else "cpu"


def seed_everything(seed: int = CFG.RANDOM_SEED):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)

seed_everything()
print(f"[CFG] Device : {CFG.DEVICE}")
print(f"[CFG] Model  : {CFG.MODEL_NAME}")


# ── 2. Build Image Manifest ───────────────────────────────────────────────────

def build_manifest() -> pd.DataFrame:
    """Collect file paths + labels, subsample, and return a DataFrame."""
    print("\n[Data] Scanning X-ray images …")
    xray_files = glob.glob(CFG.XRAY_GLOB, recursive=True)
    print(f"       Found {len(xray_files):,} X-ray images")

    print("[Data] Scanning COCO images …")
    coco_files = glob.glob(CFG.COCO_GLOB)
    print(f"       Found {len(coco_files):,} COCO images")

    if not xray_files:
        raise FileNotFoundError(
            f"No X-ray images found at: {CFG.XRAY_GLOB}\n"
            "Check your Kaggle dataset slug and path."
        )
    if not coco_files:
        raise FileNotFoundError(
            f"No COCO images found at: {CFG.COCO_GLOB}\n"
            "Check your Kaggle dataset slug and path."
        )

    # Subsample
    random.shuffle(xray_files)
    random.shuffle(coco_files)
    xray_files = xray_files[: CFG.MAX_XRAY_SAMPLES]
    coco_files = coco_files[: CFG.MAX_COCO_SAMPLES]

    rows = (
        [{"path": p, "label": 1} for p in xray_files] +
        [{"path": p, "label": 0} for p in coco_files]
    )
    df = pd.DataFrame(rows).sample(frac=1, random_state=CFG.RANDOM_SEED).reset_index(drop=True)

    # Stratified train / val / test split
    train_val_df, test_df = train_test_split(
        df, test_size=CFG.TEST_SPLIT,
        stratify=df["label"], random_state=CFG.RANDOM_SEED
    )
    val_frac = CFG.VAL_SPLIT / (1 - CFG.TEST_SPLIT)
    train_df, val_df = train_test_split(
        train_val_df, test_size=val_frac,
        stratify=train_val_df["label"], random_state=CFG.RANDOM_SEED
    )

    print(f"\n[Data] Split summary:")
    print(f"       Train : {len(train_df):,}  (xray={train_df.label.sum():,})")
    print(f"       Val   : {len(val_df):,}  (xray={val_df.label.sum():,})")
    print(f"       Test  : {len(test_df):,}  (xray={test_df.label.sum():,})")
    return train_df, val_df, test_df


# ── 3. Albumentations Transforms ─────────────────────────────────────────────

def get_transforms(split: str) -> A.Compose:
    """
    Train: heavy augmentation to handle domain shift between DICOM-sourced
           X-rays and natural COCO photos.
    Val/Test: deterministic centre-crop pipeline.
    """
    mean = [0.485, 0.456, 0.406]   # ImageNet stats — timm pretrained models
    std  = [0.229, 0.224, 0.225]

    if split == "train":
        return A.Compose([
            A.Resize(CFG.IMG_SIZE + 32, CFG.IMG_SIZE + 32),
            A.RandomCrop(CFG.IMG_SIZE, CFG.IMG_SIZE),
            A.HorizontalFlip(p=0.5),
            A.ShiftScaleRotate(shift_limit=0.05, scale_limit=0.1,
                               rotate_limit=15, p=0.5),
            A.OneOf([
                A.RandomBrightnessContrast(brightness_limit=0.2,
                                           contrast_limit=0.2, p=1.0),
                A.CLAHE(clip_limit=4.0, p=1.0),           # helps X-ray contrast
            ], p=0.6),
            A.GaussNoise(var_limit=(10.0, 50.0), p=0.3),
            A.GaussianBlur(blur_limit=(3, 5), p=0.2),
            A.CoarseDropout(                              # simulates occlusion
                max_holes=8, max_height=24, max_width=24,
                fill_value=0, p=0.3
            ),
            A.Normalize(mean=mean, std=std),
            ToTensorV2(),
        ])
    else:
        return A.Compose([
            A.Resize(CFG.IMG_SIZE, CFG.IMG_SIZE),
            A.Normalize(mean=mean, std=std),
            ToTensorV2(),
        ])


# ── 4. Custom Dataset ─────────────────────────────────────────────────────────

class GatekeeperDataset(Dataset):
    """
    Binary image dataset.
    • Handles both grayscale (X-rays) and RGB (COCO) images transparently.
    • Converts everything to 3-channel RGB so timm models work out-of-the-box.
    """

    def __init__(self, df: pd.DataFrame, transform: A.Compose):
        self.paths     = df["path"].tolist()
        self.labels    = df["label"].tolist()
        self.transform = transform

    def __len__(self) -> int:
        return len(self.paths)

    def __getitem__(self, idx: int):
        path  = self.paths[idx]
        label = self.labels[idx]

        try:
            img = Image.open(path).convert("RGB")   # grayscale → 3-ch
            img = np.array(img, dtype=np.uint8)
        except Exception as e:
            # Corrupted file: return a black image so training doesn't crash
            print(f"[WARNING] Could not open {path}: {e}")
            img = np.zeros((CFG.IMG_SIZE, CFG.IMG_SIZE, 3), dtype=np.uint8)

        if self.transform:
            augmented = self.transform(image=img)
            img = augmented["image"]   # torch.Tensor [C, H, W], float32

        return img, torch.tensor(label, dtype=torch.float32)


def build_dataloaders(train_df, val_df, test_df):
    """Builds DataLoaders with class-balanced WeightedRandomSampler for train."""
    train_ds = GatekeeperDataset(train_df, get_transforms("train"))
    val_ds   = GatekeeperDataset(val_df,   get_transforms("val"))
    test_ds  = GatekeeperDataset(test_df,  get_transforms("test"))

    # ── Weighted sampler to handle mild class imbalance ──────────────────────
    class_counts  = train_df["label"].value_counts().sort_index().values   # [n_neg, n_pos]
    sample_weights = np.where(
        train_df["label"].values == 1,
        1.0 / class_counts[1],
        1.0 / class_counts[0]
    )
    sampler = WeightedRandomSampler(
        weights=torch.DoubleTensor(sample_weights),
        num_samples=len(train_ds),
        replacement=True
    )

    train_loader = DataLoader(
        train_ds, batch_size=CFG.BATCH_SIZE,
        sampler=sampler,
        num_workers=CFG.NUM_WORKERS, pin_memory=True
    )
    val_loader = DataLoader(
        val_ds, batch_size=CFG.BATCH_SIZE * 2,
        shuffle=False,
        num_workers=CFG.NUM_WORKERS, pin_memory=True
    )
    test_loader = DataLoader(
        test_ds, batch_size=CFG.BATCH_SIZE * 2,
        shuffle=False,
        num_workers=CFG.NUM_WORKERS, pin_memory=True
    )
    return train_loader, val_loader, test_loader


# ── 5. Model ──────────────────────────────────────────────────────────────────

class GatekeeperModel(nn.Module):
    """
    MobileNetV3-Small backbone (timm) with a custom binary classifier head.
    The head adds an extra hidden layer + dropout before the final sigmoid
    output — gives the model more capacity to separate the two domains.
    """

    def __init__(self):
        super().__init__()
        self.backbone = timm.create_model(
            CFG.MODEL_NAME,
            pretrained=CFG.PRETRAINED,
            num_classes=0,          # Remove timm's default head
            drop_rate=CFG.DROP_RATE
        )
        # Detect the true feature size via a dummy forward pass.
        # timm's num_features property can mismatch the actual tensor shape
        # depending on library version and model variant.
        with torch.no_grad():
            dummy = torch.zeros(1, 3, CFG.IMG_SIZE, CFG.IMG_SIZE)
            in_features = self.backbone(dummy).shape[1]
        print(f"  [Model] Backbone output features: {in_features}")

        self.classifier = nn.Sequential(
            nn.Linear(in_features, 256),
            nn.BatchNorm1d(256),
            nn.SiLU(),
            nn.Dropout(p=CFG.DROP_RATE),
            nn.Linear(256, CFG.NUM_CLASSES)    # raw logit — no sigmoid here
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        features = self.backbone(x)      # [B, in_features]
        logits   = self.classifier(features)  # [B, 1]
        return logits.squeeze(1)         # [B]


def build_model() -> GatekeeperModel:
    model = GatekeeperModel().to(CFG.DEVICE)
    total_params = sum(p.numel() for p in model.parameters())
    print(f"\n[Model] {CFG.MODEL_NAME}  |  Params: {total_params/1e6:.2f}M")
    return model


# ── 6. Training Utilities ─────────────────────────────────────────────────────

class AverageMeter:
    """Tracks a running mean for loss / metric logging."""
    def __init__(self):
        self.reset()

    def reset(self):
        self.val = self.avg = self.sum = self.count = 0.0

    def update(self, val, n=1):
        self.val    = val
        self.sum   += val * n
        self.count += n
        self.avg    = self.sum / self.count


class EarlyStopping:
    """Stops training when validation loss doesn't improve for `patience` epochs."""

    def __init__(self, patience=CFG.PATIENCE, mode="min", delta=1e-4):
        self.patience   = patience
        self.mode       = mode
        self.delta      = delta
        self.counter    = 0
        self.best_score = None
        self.early_stop = False

    def __call__(self, score: float) -> bool:
        if self.best_score is None:
            self.best_score = score
            return False

        improved = (
            score < self.best_score - self.delta if self.mode == "min"
            else score > self.best_score + self.delta
        )
        if improved:
            self.best_score = score
            self.counter    = 0
        else:
            self.counter += 1
            print(f"  [EarlyStopping] No improvement for {self.counter}/{self.patience} epochs")
            if self.counter >= self.patience:
                self.early_stop = True
        return self.early_stop


# ── 7. Training & Validation Loops ───────────────────────────────────────────

def train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: optim.Optimizer,
    scaler: torch.cuda.amp.GradScaler,
    epoch: int
) -> dict:
    model.train()
    loss_meter = AverageMeter()
    all_preds, all_labels = [], []
    t0 = time.time()

    for step, (images, labels) in enumerate(loader):
        images = images.to(CFG.DEVICE, non_blocking=True)
        labels = labels.to(CFG.DEVICE, non_blocking=True)

        optimizer.zero_grad()

        # Mixed-precision forward
        with torch.cuda.amp.autocast(enabled=(CFG.DEVICE == "cuda")):
            logits = model(images)
            loss   = criterion(logits, labels)

        scaler.scale(loss).backward()
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        scaler.step(optimizer)
        scaler.update()

        loss_meter.update(loss.item(), n=images.size(0))

        probs = torch.sigmoid(logits).detach().cpu().numpy()
        all_preds.extend(probs)
        all_labels.extend(labels.cpu().numpy())

        if (step + 1) % 50 == 0:
            print(f"   Epoch {epoch+1} | step {step+1}/{len(loader)} "
                  f"| loss {loss_meter.avg:.4f}")

    elapsed = time.time() - t0
    preds_bin = (np.array(all_preds) >= CFG.INFERENCE_THRESHOLD).astype(int)
    return {
        "loss"     : loss_meter.avg,
        "accuracy" : accuracy_score(all_labels, preds_bin),
        "auc"      : roc_auc_score(all_labels, all_preds),
        "elapsed"  : elapsed,
    }


@torch.no_grad()
def validate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
) -> dict:
    model.eval()
    loss_meter = AverageMeter()
    all_preds, all_labels = [], []

    for images, labels in loader:
        images = images.to(CFG.DEVICE, non_blocking=True)
        labels = labels.to(CFG.DEVICE, non_blocking=True)

        with torch.cuda.amp.autocast(enabled=(CFG.DEVICE == "cuda")):
            logits = model(images)
            loss   = criterion(logits, labels)

        loss_meter.update(loss.item(), n=images.size(0))
        probs = torch.sigmoid(logits).cpu().numpy()
        all_preds.extend(probs)
        all_labels.extend(labels.cpu().numpy())

    preds_bin = (np.array(all_preds) >= CFG.INFERENCE_THRESHOLD).astype(int)
    return {
        "loss"      : loss_meter.avg,
        "accuracy"  : accuracy_score(all_labels, preds_bin),
        "auc"       : roc_auc_score(all_labels, all_preds),
        "f1"        : f1_score(all_labels, preds_bin),
        "precision" : precision_score(all_labels, preds_bin),
        "recall"    : recall_score(all_labels, preds_bin),
        "preds"     : all_preds,
        "labels"    : all_labels,
    }


# ── 8. Full Training Pipeline ─────────────────────────────────────────────────

def train():
    CFG.CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)

    # ── Build data ────────────────────────────────────────────────────────────
    train_df, val_df, test_df = build_manifest()
    train_loader, val_loader, test_loader = build_dataloaders(
        train_df, val_df, test_df
    )

    # ── Model, loss, optimizer ────────────────────────────────────────────────
    model = build_model()

    # Pos-weight handles residual class imbalance after WeightedRandomSampler
    pos_weight = torch.tensor(
        [train_df["label"].value_counts()[0] / train_df["label"].value_counts()[1]],
        dtype=torch.float32
    ).to(CFG.DEVICE)
    criterion = nn.BCEWithLogitsLoss(pos_weight=pos_weight)

    optimizer = optim.AdamW(
        model.parameters(), lr=CFG.LR, weight_decay=CFG.WEIGHT_DECAY
    )
    scheduler = optim.lr_scheduler.CosineAnnealingWarmRestarts(
        optimizer, T_0=CFG.T_0, T_mult=CFG.T_MULT, eta_min=CFG.ETA_MIN
    )
    scaler        = torch.cuda.amp.GradScaler(enabled=(CFG.DEVICE == "cuda"))
    early_stopper = EarlyStopping(patience=CFG.PATIENCE, mode="min")

    best_val_loss = float("inf")
    best_weights  = None
    history       = []

    print("\n" + "="*65)
    print("  Starting Gatekeeper Training")
    print("="*65)

    for epoch in range(CFG.EPOCHS):
        print(f"\n── Epoch {epoch+1}/{CFG.EPOCHS} "
              f"(lr={scheduler.get_last_lr()[0]:.2e}) ──")

        train_metrics = train_one_epoch(
            model, train_loader, criterion, optimizer, scaler, epoch
        )
        val_metrics   = validate(model, val_loader, criterion)
        scheduler.step()

        print(f"  TRAIN  loss={train_metrics['loss']:.4f}  "
              f"acc={train_metrics['accuracy']:.4f}  "
              f"auc={train_metrics['auc']:.4f}  "
              f"({train_metrics['elapsed']:.1f}s)")
        print(f"  VAL    loss={val_metrics['loss']:.4f}  "
              f"acc={val_metrics['accuracy']:.4f}  "
              f"auc={val_metrics['auc']:.4f}  "
              f"f1={val_metrics['f1']:.4f}  "
              f"prec={val_metrics['precision']:.4f}  "
              f"rec={val_metrics['recall']:.4f}")

        history.append({
            "epoch"      : epoch + 1,
            "train_loss" : train_metrics["loss"],
            "val_loss"   : val_metrics["loss"],
            "val_auc"    : val_metrics["auc"],
            "val_f1"     : val_metrics["f1"],
        })

        # Save best checkpoint
        if val_metrics["loss"] < best_val_loss:
            best_val_loss = val_metrics["loss"]
            best_weights  = copy.deepcopy(model.state_dict())
            torch.save(
                {
                    "epoch"       : epoch + 1,
                    "model_state" : best_weights,
                    "val_loss"    : best_val_loss,
                    "val_auc"     : val_metrics["auc"],
                    "cfg"         : {
                        "model_name" : CFG.MODEL_NAME,
                        "img_size"   : CFG.IMG_SIZE,
                        "threshold"  : CFG.INFERENCE_THRESHOLD,
                    },
                },
                CFG.BEST_CKPT,
            )
            print(f"  ✓ Saved best checkpoint  (val_loss={best_val_loss:.4f})")

        if early_stopper(val_metrics["loss"]):
            print(f"\n  ⚑ Early stopping triggered at epoch {epoch+1}")
            break

    # Save final checkpoint
    torch.save(
        {"epoch": epoch + 1, "model_state": model.state_dict()},
        CFG.FINAL_CKPT,
    )
    print(f"\n  ✓ Saved final checkpoint → {CFG.FINAL_CKPT}")

    # ── Test set evaluation ───────────────────────────────────────────────────
    print("\n" + "="*65)
    print("  Test Set Evaluation  (best checkpoint)")
    print("="*65)
    model.load_state_dict(best_weights)
    test_metrics = validate(model, test_loader, criterion)
    preds_bin    = (np.array(test_metrics["preds"]) >= CFG.INFERENCE_THRESHOLD).astype(int)
    cm           = confusion_matrix(test_metrics["labels"], preds_bin)
    tn, fp, fn, tp = cm.ravel()

    print(f"  Loss      : {test_metrics['loss']:.4f}")
    print(f"  Accuracy  : {test_metrics['accuracy']:.4f}")
    print(f"  AUC-ROC   : {test_metrics['auc']:.4f}")
    print(f"  F1        : {test_metrics['f1']:.4f}")
    print(f"  Precision : {test_metrics['precision']:.4f}")
    print(f"  Recall    : {test_metrics['recall']:.4f}")
    print(f"\n  Confusion Matrix:")
    print(f"               Pred Non-Medical  Pred X-Ray")
    print(f"  True Non-Med        {tn:>6}         {fp:>6}   (FP = bad)")
    print(f"  True X-Ray          {fn:>6}         {tp:>6}   (FN = bad)")
    print(f"\n  False-Positive Rate (medical blocked): {fp/(fp+tn):.4f}")
    print(f"  False-Negative Rate (junk let through): {fn/(fn+tp):.4f}")

    pd.DataFrame(history).to_csv(
        CFG.CHECKPOINT_DIR / "training_history.csv", index=False
    )
    print(f"\n  ✓ Training history saved → {CFG.CHECKPOINT_DIR/'training_history.csv'}")
    return model


# ── 9. Inference Function — Gradio-Ready ─────────────────────────────────────

def load_gatekeeper(
    checkpoint_path: str = str(CFG.BEST_CKPT),
    device: str = CFG.DEVICE
) -> GatekeeperModel:
    """
    Load a trained Gatekeeper model from a checkpoint file.

    Usage:
        gatekeeper = load_gatekeeper()
    """
    ckpt  = torch.load(checkpoint_path, map_location=device)
    model = GatekeeperModel().to(device)
    model.load_state_dict(ckpt["model_state"])
    model.eval()
    print(f"[Gatekeeper] Loaded from {checkpoint_path}  "
          f"(val_loss={ckpt.get('val_loss', 'N/A'):.4f})")
    return model


# ── The function you plug directly into your Gradio app ──────────────────────

_INFER_TRANSFORM = get_transforms("val")   # deterministic, no augmentation
_GATEKEEPER_MODEL: GatekeeperModel | None = None


def is_valid_xray(
    img,                               # PIL.Image.Image OR np.ndarray
    model: GatekeeperModel | None = None,
    threshold: float = CFG.INFERENCE_THRESHOLD,
    device: str = CFG.DEVICE,
) -> tuple[bool, float]:
    """
    Gatekeeper inference function — drop straight into a Gradio app.

    Parameters
    ----------
    img       : PIL Image or NumPy array (H×W×3, uint8)
    model     : GatekeeperModel instance.  If None, loads from default ckpt.
    threshold : Probability cutoff for Class 1 (X-ray).  Default 0.50.
    device    : "cuda" or "cpu"

    Returns
    -------
    (is_xray: bool, probability: float)
        is_xray     — True if the image is classified as a chest X-ray
        probability — Model confidence [0, 1] that the image is an X-ray

    Gradio integration example
    --------------------------
    import gradio as gr
    from gatekeeper_xray_classifier import is_valid_xray, load_gatekeeper

    gk_model = load_gatekeeper()   # call once at app startup

    def run_medical_ai(image):
        valid, prob = is_valid_xray(image, model=gk_model)
        if not valid:
            return f"❌ Rejected (p={prob:.2%}). Please upload a chest X-ray."
        return your_medical_model(image)   # proceed to downstream model

    gr.Interface(fn=run_medical_ai, inputs="image", outputs="text").launch()
    """
    global _GATEKEEPER_MODEL

    # Lazy-load model singleton if none passed
    if model is None:
        if _GATEKEEPER_MODEL is None:
            _GATEKEEPER_MODEL = load_gatekeeper(device=device)
        model = _GATEKEEPER_MODEL

    # Normalise input to numpy uint8 RGB
    if isinstance(img, Image.Image):
        img_np = np.array(img.convert("RGB"), dtype=np.uint8)
    elif isinstance(img, np.ndarray):
        if img.ndim == 2:                         # grayscale
            img_np = np.stack([img] * 3, axis=-1)
        elif img.shape[-1] == 4:                  # RGBA
            img_np = img[..., :3]
        else:
            img_np = img
        img_np = img_np.astype(np.uint8)
    else:
        raise TypeError(f"Unsupported image type: {type(img)}")

    # Apply validation transforms
    tensor = _INFER_TRANSFORM(image=img_np)["image"]          # [C, H, W]
    tensor = tensor.unsqueeze(0).to(device)                    # [1, C, H, W]

    with torch.no_grad():
        logit       = model(tensor)
        probability = torch.sigmoid(logit).item()

    is_xray = probability >= threshold
    return is_xray, probability


# ── 10. Entry Point ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    # ---- Full training run ---------------------------------------------------
    trained_model = train()

    # ---- Quick smoke-test of the inference function ─────────────────────────
    print("\n[Smoke Test] is_valid_xray() …")
    dummy_img = np.random.randint(0, 255, (256, 256, 3), dtype=np.uint8)
    result, prob = is_valid_xray(dummy_img, model=trained_model)
    print(f"  Dummy image → is_xray={result}, p={prob:.4f}  ✓")