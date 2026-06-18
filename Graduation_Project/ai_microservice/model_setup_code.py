# === CELL 0 ===
"""
Multi-Dataset Chest X-ray Classifier — Production Pipeline v2
==============================================================
ALL UPGRADES + CLINICAL METRICS + CURVES
  1. TTA (horizontal flip)
  2. Self-distillation round 2
  3. RAD-DINO backbone (ViT-B/14 @ 518px)
  4. Tuned ASL loss + per-class pos_weight
  5. No mixup, no label smoothing
  6. CANDID-PTX optional
  + Clinical metrics: F1, Precision, Recall, Miss Rate, Sens@95Spec, Spec@95Sens
  + ROC/PR curves, confusion matrices
"""

import subprocess, sys
for pkg in ["iterative-stratification", "pydicom", "python-gdcm", "transformers"]:
    subprocess.run([sys.executable, "-m", "pip", "install", pkg, "-q"], check=False)

import os, gc, random, warnings, time, json, copy
from pathlib import Path
from typing import Dict, List, Optional
from multiprocessing import Pool
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib.pyplot as plt
warnings.filterwarnings("ignore")

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torch.amp import GradScaler, autocast

import timm
from timm.utils import ModelEmaV2
import albumentations as A
from albumentations.pytorch import ToTensorV2

from sklearn.metrics import (roc_auc_score, average_precision_score,
                              f1_score, precision_score, recall_score,
                              roc_curve, precision_recall_curve, confusion_matrix)
from iterstrat.ml_stratifiers import MultilabelStratifiedShuffleSplit

try:
    import pydicom
    HAS_PYDICOM = True
    print(f"✓ pydicom {pydicom.__version__}")
except ImportError:
    HAS_PYDICOM = False

try:
    from transformers import AutoModel
    HAS_TRANSFORMERS = True
except ImportError:
    HAS_TRANSFORMERS = False

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
USE_AMP = DEVICE.type == "cuda"
AMP_DEVICE = "cuda" if USE_AMP else "cpu"
N_GPUS = torch.cuda.device_count() if torch.cuda.is_available() else 0
USE_DP = False

print(f"Python  : {sys.version.split()[0]}")
print(f"PyTorch : {torch.__version__}")
print(f"timm    : {timm.__version__}")
print(f"CUDA    : {torch.cuda.is_available()}")
print(f"GPUs    : {N_GPUS}")
if torch.cuda.is_available():
    for i in range(N_GPUS):
        p = torch.cuda.get_device_properties(i)
        print(f"  [{i}] {p.name} ({p.total_memory/1e9:.1f} GB)")


# =============================================================================
# Configuration
# =============================================================================
class CFG:
    UNIFIED_LABELS = [
        "Aortic enlargement", "Atelectasis", "Calcification", "Cardiomegaly",
        "Consolidation", "Lung Opacity", "Nodule/Mass", "Pleural effusion",
        "Pleural thickening", "Pneumothorax", "Pulmonary fibrosis",
    ]
    NUM_CLASSES = 11

    VINDR_CANDIDATES = [
        Path("/kaggle/input/datasets/awsaf49/vinbigdata-1024-image-dataset"),
        Path("/kaggle/input/competitions/vinbigdata-chest-xray-abnormalities-detection"),
    ]
    SIIM_CANDIDATES = [
        Path("/kaggle/input/datasets/vbookshelf/pneumothorax-chest-xray-images-and-masks"),
        Path("/kaggle/input/datasets/jesperdramsch/siim-acr-pneumothorax-segmentation-data"),
    ]
    RSNA_CANDIDATES = [
        Path("/kaggle/input/datasets/iamtapendu/rsna-pneumonia-processed-dataset"),
    ]
    CHESTXDET_CANDIDATES = [
        Path("/kaggle/input/datasets/ztamnaja/chestxdet10dataset"),
        Path("/kaggle/input/datasets/mathurinache/chestxdetdataset"),
    ]
    CANDID_CANDIDATES = [Path("/kaggle/input/datasets/candid-ptx")]

    VINDR_CLASS_IDS = {
        0:"Aortic enlargement", 1:"Atelectasis", 2:"Calcification", 3:"Cardiomegaly",
        4:"Consolidation", 5:"ILD", 6:"Infiltration", 7:"Lung Opacity",
        8:"Nodule/Mass", 9:"Other lesion", 10:"Pleural effusion",
        11:"Pleural thickening", 12:"Pneumothorax", 13:"Pulmonary fibrosis",
        14:"No finding",
    }
    VINDR_MERGE = {"ILD": "Pulmonary fibrosis", "Infiltration": "Lung Opacity"}
    VINDR_DROP = ["Other lesion"]
    MIN_RAD_AGREEMENT = 2

    CHESTXDET_MAP = {
        "Atelectasis":"Atelectasis", "Calcification":"Calcification",
        "Consolidation":"Consolidation", "Effusion":"Pleural effusion",
        "Emphysema":None, "Fibrosis":"Pulmonary fibrosis", "Fracture":None,
        "Mass":"Nodule/Mass", "Nodule":"Nodule/Mass", "Pneumothorax":"Pneumothorax",
        "Diffuse Nodule":"Nodule/Mass",
    }

    # ── BACKBONE: RAD-DINO ───────────────────────────────────────────────
    BACKBONE_TYPE  = "raddino"          # "raddino" or "convnext"
    CONVNEXT_NAME  = "convnext_base.fb_in22k_ft_in1k_384"
    RADDINO_NAME   = "microsoft/rad-dino"
    PRETRAINED     = True
    DROP_RATE      = 0.3
    DROP_PATH_RATE = 0.2

    # ConvNeXt: 512  |  RAD-DINO ViT-B/14: 518 (must be %14==0)
    IMAGE_SIZE = 518

    BATCH_SIZE      = 4
    GRAD_ACCUM      = 8         # effective 32
    NUM_EPOCHS      = 15
    LR              = 2e-5
    MIN_LR          = 1e-7
    WARMUP_EPOCHS   = 2
    WEIGHT_DECAY    = 0.05
    BETAS           = (0.9, 0.999)
    LABEL_SMOOTHING = 0.0
    GRAD_CLIP       = 1.0

    USE_MIXUP    = False
    MIXUP_ALPHA  = 0.2
    USE_CUTMIX   = True
    CUTMIX_ALPHA = 1.0
    AUGMENT_PROB = 0.5

    USE_EMA   = True
    EMA_DECAY = 0.999          # tightened from 0.9998 for short runs

    USE_TTA_VAL    = False
    USE_TTA_FINAL  = True
    TTA_FLIP       = True

    VAL_SPLIT = 0.15
    SEED      = 42

    SAMPLER_WEIGHTS = {"vindr":2.0, "siim":1.0, "rsna":0.7, "chestxdet":2.5}

    ASL_GAMMA_NEG = 6
    ASL_GAMMA_POS = 0
    ASL_CLIP      = 0.1
    POS_WEIGHT_CAP = 10.0

    PATIENCE   = 6
    MIN_DELTA  = 1e-4

    NUM_WORKERS = 8
    PIN_MEMORY  = True
    LOG_EVERY   = 50

    RESUME_PATH         = "/kaggle/input/models/refaatelia/ep10/pytorch/default/1/checkpoint_round1_epoch_10.pth"
    CHECKPOINT_DIR      = Path("/kaggle/working")
    CHECKPOINT_SAVE_DIR = Path("/kaggle/working")
    SAVE_PATH           = Path("/kaggle/working/best_model.pth")
    EMA_SAVE_PATH       = Path("/kaggle/working/best_model_ema.pth")
    DISTILL_SAVE_PATH   = Path("/kaggle/working/best_model_distilled.pth")
    CHECKPOINT_EVERY    = 1
    KEEP_LAST_N_CKPTS   = 3

    USE_CACHE     = True
    CACHE_DIR     = Path("/tmp/img_cache")
    CACHE_FORMAT  = "jpg"
    CACHE_QUALITY = 92
    CACHE_RESIZE  = 640
    CACHE_WORKERS = 8

    DO_SELF_DISTILL    = False
    DISTILL_POS_THRESH = 0.97
    DISTILL_NEG_THRESH = 0.03
    DISTILL_EPOCHS     = 5
    DISTILL_LR         = 5e-6
    DISTILL_REVERT_DROP = 0.01

    USE_CANDID_PTX = False


def seed_everything(seed=42):
    random.seed(seed); os.environ['PYTHONHASHSEED'] = str(seed)
    np.random.seed(seed); torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = False
    torch.backends.cudnn.benchmark = True


def unwrap(m):
    return m.module if isinstance(m, nn.DataParallel) else m


seed_everything(CFG.SEED)
CFG.CHECKPOINT_SAVE_DIR.mkdir(parents=True, exist_ok=True)
if CFG.USE_CACHE: CFG.CACHE_DIR.mkdir(parents=True, exist_ok=True)

if CFG.BACKBONE_TYPE == "raddino" and CFG.IMAGE_SIZE % 14 != 0:
    raise ValueError(f"RAD-DINO requires IMAGE_SIZE % 14 == 0, got {CFG.IMAGE_SIZE}")

L2I = {l: i for i, l in enumerate(CFG.UNIFIED_LABELS)}
N_CLS = CFG.NUM_CLASSES


# =============================================================================
# DICOM utilities
# =============================================================================
def read_dicom_as_array(dicom_path: str) -> np.ndarray:
    ds = pydicom.dcmread(dicom_path)
    img = ds.pixel_array.astype(np.float32)
    slope = getattr(ds, 'RescaleSlope', 1)
    intercept = getattr(ds, 'RescaleIntercept', 0)
    if slope != 1 or intercept != 0:
        img = img * slope + intercept
    if getattr(ds, 'PhotometricInterpretation', '') == "MONOCHROME1":
        img = img.max() - img
    if hasattr(ds, 'WindowCenter') and hasattr(ds, 'WindowWidth'):
        wc, ww = ds.WindowCenter, ds.WindowWidth
        if isinstance(wc, pydicom.multival.MultiValue): wc = float(wc[0])
        if isinstance(ww, pydicom.multival.MultiValue): ww = float(ww[0])
        wc, ww = float(wc), float(ww)
        img = np.clip(img, wc - ww/2, wc + ww/2)
    mn, mx = img.min(), img.max()
    img = ((img - mn) / (mx - mn) * 255.0) if mx > mn else np.zeros_like(img)
    img = img.astype(np.uint8)
    if img.ndim == 2: img = np.stack([img]*3, axis=-1)
    return img


def _convert_single(args):
    img_id, src_path, cache_dir, fmt, quality, resize = args
    out_path = str(Path(cache_dir) / f"{img_id}.{fmt}")
    if os.path.exists(out_path):
        return img_id, out_path, "cached"
    try:
        if src_path.lower().endswith((".dcm",".dicom")):
            img_array = read_dicom_as_array(src_path)
        else:
            img_array = np.array(Image.open(src_path).convert("RGB"))
        pil_img = Image.fromarray(img_array)
        if resize and max(pil_img.size) > resize:
            pil_img.thumbnail((resize, resize), Image.LANCZOS)
        if fmt == "jpg": pil_img.save(out_path, "JPEG", quality=quality)
        else: pil_img.save(out_path)
        return img_id, out_path, "converted"
    except Exception as e:
        return img_id, src_path, f"failed: {e}"


def convert_cached_parallel(path_map: Dict[str, str], tag: str = "") -> Dict[str, str]:
    if not path_map: return {}
    cached = sum(1 for img_id in path_map
                 if (CFG.CACHE_DIR / f"{img_id}.{CFG.CACHE_FORMAT}").exists())
    todo = len(path_map) - cached
    print(f"  [{tag}] {cached:,} cached, {todo:,} to convert (workers={CFG.CACHE_WORKERS})")
    if todo == 0:
        return {img_id: str(CFG.CACHE_DIR / f"{img_id}.{CFG.CACHE_FORMAT}")
                for img_id in path_map}
    args = [(img_id, src, str(CFG.CACHE_DIR), CFG.CACHE_FORMAT,
             CFG.CACHE_QUALITY, CFG.CACHE_RESIZE)
            for img_id, src in path_map.items()]
    t0 = time.time()
    new_map = {}; n_done = converted = was_cached = failed = 0
    with Pool(processes=min(CFG.CACHE_WORKERS, len(args))) as pool:
        for img_id, out_path, status in pool.imap_unordered(_convert_single, args, chunksize=20):
            new_map[img_id] = out_path
            if status == "cached":   was_cached += 1
            elif status == "converted": converted += 1
            else: failed += 1
            n_done += 1
            if n_done % 1000 == 0 or n_done == len(args):
                rate = n_done / max(time.time()-t0, 0.01)
                eta = (len(args) - n_done) / max(rate, 0.01)
                print(f"    [{tag}] {n_done:,}/{len(args):,} ({rate:.1f}/s, ETA {eta/60:.1f}m)")
    print(f"  [{tag}] ✓ {converted} new, {was_cached} cached, {failed} failed "
          f"({(time.time()-t0)/60:.1f}m)")
    return new_map


# =============================================================================
# Path helpers
# =============================================================================
def find_first_existing(candidates: List[Path]) -> Optional[Path]:
    for p in candidates:
        if p.exists(): return p
    return None


def find_file_recursive(root: Path, name: str, max_depth=4) -> Optional[Path]:
    if not root.exists(): return None
    if (root / name).exists(): return root / name
    for d in range(1, max_depth+1):
        hits = list(root.glob("/".join(["*"]*d) + "/" + name))
        if hits: return hits[0]
    return None


# =============================================================================
# Dataset loaders
# =============================================================================
def load_vindr() -> List[dict]:
    root = find_first_existing(CFG.VINDR_CANDIDATES)
    if root is None: print("  [VinDr] not found"); return []
    print(f"  [VinDr] root: {root}")
    ann_csv = find_file_recursive(root, "train.csv", 4)
    if ann_csv is None: return []
    print(f"  [VinDr] CSV: {ann_csv}")
    csv_base = ann_csv.parent
    df = pd.read_csv(ann_csv); id_col = "image_id"
    if "class_name" not in df.columns:
        df["class_name"] = df["class_id"].map(CFG.VINDR_CLASS_IDS)
    if "rad_id" in df.columns and CFG.MIN_RAD_AGREEMENT > 1:
        before = len(df)
        agree = (df.groupby([id_col, "class_name"])
                   .agg(rc=("rad_id","nunique")).reset_index())
        agree = agree[agree["rc"] >= CFG.MIN_RAD_AGREEMENT][[id_col,"class_name"]]
        nf = df[df["class_name"].str.lower().str.strip() == "no finding"]
        df = pd.concat([df.merge(agree, on=[id_col,"class_name"], how="inner"), nf]).drop_duplicates()
        print(f"  [VinDr] rad-agreement ≥{CFG.MIN_RAD_AGREEMENT}: {before:,} → {len(df):,}")
    df["class_name"] = df["class_name"].replace(CFG.VINDR_MERGE)
    df = df[~df["class_name"].isin(CFG.VINDR_DROP)]
    unique_ids = df[id_col].unique().tolist()
    print(f"  [VinDr] unique images: {len(unique_ids):,}")
    df["_cls"] = df["class_name"].str.strip()
    abn = df[df["_cls"].isin(CFG.UNIFIED_LABELS)].copy()
    pivot = abn.pivot_table(index=id_col, columns="_cls", aggfunc="size", fill_value=0)
    pivot = (pivot > 0).astype(np.float32)
    label_df = pivot.reindex(unique_ids, fill_value=0.0)
    for lb in CFG.UNIFIED_LABELS:
        if lb not in label_df.columns: label_df[lb] = 0.0
    img_dirs = []
    for base in [csv_base, root]:
        for d in ["train","train_images","images","train_png","png","."]:
            p = base / d
            if p.exists() and p.is_dir() and p not in img_dirs:
                img_dirs.append(p)
    path_map = {}
    for d in img_dirs:
        for ext in [".png",".jpg",".jpeg",".dicom",".dcm"]:
            tp = d / f"{unique_ids[0]}{ext}"
            if tp.exists():
                for img_id in unique_ids:
                    p = d / f"{img_id}{ext}"
                    if p.exists(): path_map[img_id] = str(p)
                break
        if path_map: break
    if not path_map:
        id_set = set(unique_ids)
        for d in img_dirs:
            for f in d.rglob("*"):
                if not f.is_file(): continue
                if f.suffix.lower() not in (".png",".jpg",".jpeg",".dicom",".dcm"): continue
                if f.stem in id_set: path_map[f.stem] = str(f)
            if len(path_map) >= len(id_set): break
    print(f"  [VinDr] found {len(path_map):,}/{len(unique_ids):,}")
    if not path_map: return []
    if CFG.USE_CACHE:
        path_map = convert_cached_parallel(path_map, tag="VinDr")
    full_mask = np.ones(N_CLS, dtype=np.float32)
    records = []
    for img_id in unique_ids:
        if img_id not in path_map: continue
        labels = np.zeros(N_CLS, dtype=np.float32)
        if img_id in label_df.index:
            row = label_df.loc[img_id]
            for lb in CFG.UNIFIED_LABELS:
                if lb in row.index and float(row[lb]) > 0.5:
                    labels[L2I[lb]] = 1.0
        records.append({"image_path": path_map[img_id], "labels": labels,
                        "mask": full_mask.copy(), "dataset_id": "vindr",
                        "image_id": img_id})
    print(f"  [VinDr] ✓ {len(records):,} records")
    return records


def load_siim() -> List[dict]:
    root = find_first_existing(CFG.SIIM_CANDIDATES)
    if root is None: print("  [SIIM] not found"); return []
    print(f"  [SIIM] root: {root}")
    is_vbookshelf = "vbookshelf" in str(root) or any(
        (root / sub).exists() for sub in ["siim-acr-pneumothorax", "png_images"])
    if not is_vbookshelf: return []
    base = root
    if (root / "siim-acr-pneumothorax").exists():
        base = root / "siim-acr-pneumothorax"
    png_dir = None
    for cand in ["png_images","stage_1_images","images","train_png","train"]:
        p = base / cand
        if p.exists() and p.is_dir(): png_dir = p; break
    if png_dir is None: return []
    csv_path = None
    for name in ["stage_1_train_images.csv","train-rle.csv","train_rle.csv","train.csv"]:
        p = find_file_recursive(base, name, 4)
        if p: csv_path = p; break
    if csv_path is None: return []
    print(f"  [SIIM] PNG: {png_dir} | CSV: {csv_path}")
    df = pd.read_csv(csv_path)
    df.columns = [c.strip() for c in df.columns]
    id_col = next((c for c in df.columns
                  if c.lower() in ("new_filename","image_id","imageid","filename","file","image")),
                  df.columns[0])
    label_col = None
    for c in df.columns:
        if any(k in c.lower() for k in ["has_pneumo","pneumo","target","label","class"]):
            label_col = c; break
    rle_col = next((c for c in df.columns
                   if "encoded" in c.lower() or "rle" in c.lower() or "pixels" in c.lower()), None)
    if label_col:
        df["has_ptx"] = df[label_col].astype(float).clip(0, 1)
    elif rle_col:
        df["has_ptx"] = df[rle_col].astype(str).apply(
            lambda s: 0.0 if s.strip() in ("-1","","nan","NaN","None") else 1.0)
    else:
        df["has_ptx"] = 1.0
    df = df.groupby(id_col)["has_ptx"].max().reset_index()
    src_map = {}
    for f in png_dir.rglob("*"):
        if f.is_file() and f.suffix.lower() in (".png",".jpg",".jpeg"):
            src_map[f.stem] = str(f)
    if CFG.USE_CACHE and src_map:
        src_map = convert_cached_parallel(src_map, tag="SIIM")
    records = []
    mask = np.zeros(N_CLS, dtype=np.float32); mask[L2I["Pneumothorax"]] = 1.0
    for _, row in df.iterrows():
        key = str(row[id_col]); stem = Path(key).stem
        path = src_map.get(stem) or src_map.get(key)
        if not path: continue
        labels = np.zeros(N_CLS, dtype=np.float32)
        labels[L2I["Pneumothorax"]] = float(row["has_ptx"])
        records.append({"image_path": path, "labels": labels, "mask": mask.copy(),
                        "dataset_id": "siim", "image_id": stem})
    pos = sum(1 for r in records if r["labels"][L2I["Pneumothorax"]] > 0.5)
    print(f"  [SIIM] ✓ {len(records):,} records ({pos:,} pneumo+)")
    return records


def load_rsna() -> List[dict]:
    root = find_first_existing(CFG.RSNA_CANDIDATES)
    if root is None: print("  [RSNA] not found"); return []
    print(f"  [RSNA] root: {root}")
    csv_path = None
    for name in ["stage_2_train_labels.csv","stage_1_train_labels.csv",
                 "train_labels.csv","labels.csv","train.csv","rsna_labels.csv",
                 "stage2_train_metadata.csv"]:
        p = find_file_recursive(root, name, 4)
        if p: csv_path = p; break
    if csv_path is None:
        for p in root.rglob("*.csv"):
            try:
                cols = pd.read_csv(p, nrows=0).columns.str.lower()
                if any("target" in c or "label" in c for c in cols):
                    csv_path = p; break
            except Exception: continue
    if csv_path is None: return []
    print(f"  [RSNA] CSV: {csv_path}")
    df = pd.read_csv(csv_path)
    df.columns = [c.strip() for c in df.columns]
    id_col = next((c for c in df.columns
                  if c.lower() in ("patientid","patient_id","image_id","imageid","image","filename","id")),
                  df.columns[0])
    label_col = next((c for c in df.columns if c.lower() in ("target","label","class","pneumonia")), None)
    if label_col is None: return []
    df = df.groupby(id_col)[label_col].max().reset_index()
    df.rename(columns={label_col: "Target"}, inplace=True)
    image_ids = df[id_col].astype(str).tolist()
    print(f"  [RSNA] {len(image_ids):,} unique IDs")
    img_dirs = []
    for n in ["stage_2_train_images","stage_1_train_images","train_images",
              "images","train","png","jpg"]:
        for p in root.rglob(n):
            if p.is_dir(): img_dirs.append(p)
    if not img_dirs:
        for d in root.rglob("*"):
            if d.is_dir():
                try:
                    n_imgs = sum(1 for _ in list(d.iterdir())[:100]
                                 if _.suffix.lower() in (".png",".jpg",".dcm",".dicom"))
                    if n_imgs > 20: img_dirs.append(d)
                except Exception: continue
    img_paths = {}; id_set = set(image_ids)
    for d in img_dirs:
        for f in d.rglob("*"):
            if not f.is_file(): continue
            if f.suffix.lower() not in (".png",".jpg",".jpeg",".dcm",".dicom"): continue
            if f.stem in id_set: img_paths[f.stem] = str(f)
        if len(img_paths) >= len(id_set): break
    print(f"  [RSNA] found {len(img_paths):,}/{len(image_ids):,}")
    if not img_paths: return []
    if CFG.USE_CACHE:
        img_paths = convert_cached_parallel(img_paths, tag="RSNA")
    mask = np.zeros(N_CLS, dtype=np.float32); mask[L2I["Lung Opacity"]] = 1.0
    df_idx = df.set_index(id_col); records = []
    for img_id, path in img_paths.items():
        if img_id not in df_idx.index: continue
        labels = np.zeros(N_CLS, dtype=np.float32)
        labels[L2I["Lung Opacity"]] = float(df_idx.loc[img_id, "Target"])
        records.append({"image_path": path, "labels": labels, "mask": mask.copy(),
                        "dataset_id": "rsna", "image_id": img_id})
    pos = sum(1 for r in records if r["labels"][L2I["Lung Opacity"]] > 0.5)
    print(f"  [RSNA] ✓ {len(records):,} records ({pos:,} opacity+)")
    return records


def load_chestxdet() -> List[dict]:
    root = find_first_existing(CFG.CHESTXDET_CANDIDATES)
    if root is None: print("  [ChestX-Det] not found"); return []
    print(f"  [ChestX-Det] root: {root}")
    json_paths = sorted(root.rglob("*.json"))
    priority = [p for p in json_paths
                if any(k in p.name.lower() for k in ("train", "test", "chestx", "annot"))]
    json_paths = priority if priority else json_paths
    print(f"  [ChestX-Det] JSON files: {len(json_paths)}")
    if not json_paths: return []
    parsed = []
    for jp in json_paths:
        try:
            with open(jp) as f: data = json.load(f)
            if isinstance(data, dict): data = list(data.values())
            if not isinstance(data, list): continue
            for entry in data:
                if not isinstance(entry, dict): continue
                fname = (entry.get("file_name") or entry.get("image")
                         or entry.get("filename") or entry.get("image_name"))
                syms  = (entry.get("syms") or entry.get("labels")
                         or entry.get("findings") or entry.get("symptoms") or [])
                if fname:
                    parsed.append({"file_name": fname, "syms": syms})
        except Exception as e:
            print(f"  [ChestX-Det] parse fail {jp.name}: {e}")
    if not parsed: return []
    fname_to_path = {}
    for f in root.rglob("*"):
        if f.is_file() and f.suffix.lower() in (".png", ".jpg", ".jpeg"):
            fname_to_path[f.name] = str(f); fname_to_path[f.stem] = str(f)
    src_cache = {}
    for r in parsed:
        path = (fname_to_path.get(r["file_name"])
                or fname_to_path.get(Path(r["file_name"]).stem)
                or fname_to_path.get(Path(r["file_name"]).name))
        if path: src_cache[Path(r["file_name"]).stem] = path
    if CFG.USE_CACHE and src_cache:
        src_cache = convert_cached_parallel(src_cache, tag="ChestX-Det")
    known_targets = {v for v in CFG.CHESTXDET_MAP.values() if v}
    mask = np.zeros(N_CLS, dtype=np.float32)
    for tgt in known_targets: mask[L2I[tgt]] = 1.0
    records, missing, seen, unmapped = [], 0, set(), set()
    for r in parsed:
        stem = Path(r["file_name"]).stem
        path = src_cache.get(stem)
        if not path: missing += 1; continue
        if stem in seen: continue
        seen.add(stem)
        labels = np.zeros(N_CLS, dtype=np.float32)
        for src in r["syms"]:
            tgt = CFG.CHESTXDET_MAP.get(src)
            if tgt: labels[L2I[tgt]] = 1.0
            else:   unmapped.add(src)
        records.append({"image_path": path, "labels": labels, "mask": mask.copy(),
                        "dataset_id": "chestxdet", "image_id": stem})
    if unmapped: print(f"  [ChestX-Det] unmapped: {sorted(unmapped)}")
    n_pos_any = sum(1 for r in records if r["labels"].max() > 0.5)
    print(f"  [ChestX-Det] ✓ {len(records):,} records ({n_pos_any:,} ≥1 pos)")
    return records


def load_candid_ptx() -> List[dict]:
    if not CFG.USE_CANDID_PTX: return []
    root = find_first_existing(CFG.CANDID_CANDIDATES)
    if root is None: print("  [CANDID-PTX] not found"); return []
    print(f"  [CANDID-PTX] root: {root}")
    csv_path = None
    for name in ["Pneumothorax_reports.csv","labels.csv","train.csv"]:
        p = find_file_recursive(root, name, 4)
        if p: csv_path = p; break
    if csv_path is None:
        for p in root.rglob("*.csv"): csv_path = p; break
    if csv_path is None: return []
    df = pd.read_csv(csv_path)
    df.columns = [c.strip() for c in df.columns]
    id_col = next((c for c in df.columns
                   if c.lower() in ("sopinstanceuid", "image_id", "filename", "id")),
                  df.columns[0])
    ptx_col = next((c for c in df.columns if "pneumo" in c.lower()), None)
    if ptx_col is None: return []
    df["has_ptx"] = df[ptx_col].astype(str).str.lower().isin(
        ["1","true","yes","positive","y"]).astype(float)
    df = df.groupby(id_col)["has_ptx"].max().reset_index()
    src_map = {}
    for f in root.rglob("*"):
        if f.is_file() and f.suffix.lower() in (".dcm",".dicom",".png",".jpg"):
            src_map[f.stem] = str(f)
    if CFG.USE_CACHE and src_map:
        src_map = convert_cached_parallel(src_map, tag="CANDID")
    mask = np.zeros(N_CLS, dtype=np.float32); mask[L2I["Pneumothorax"]] = 1.0
    records = []; df_idx = df.set_index(id_col)
    for img_id, path in src_map.items():
        if img_id not in df_idx.index: continue
        labels = np.zeros(N_CLS, dtype=np.float32)
        labels[L2I["Pneumothorax"]] = float(df_idx.loc[img_id, "has_ptx"])
        records.append({"image_path": path, "labels": labels, "mask": mask.copy(),
                        "dataset_id": "candid_ptx", "image_id": img_id})
    pos = sum(1 for r in records if r["labels"][L2I["Pneumothorax"]] > 0.5)
    print(f"  [CANDID-PTX] ✓ {len(records):,} records ({pos:,} pneumo+)")
    return records


def load_all_datasets() -> List[dict]:
    print("\n" + "="*70); print("LOADING DATASETS"); print("="*70)
    all_records = []
    all_records += load_vindr()
    all_records += load_siim()
    all_records += load_rsna()
    all_records += load_chestxdet()
    all_records += load_candid_ptx()
    if not all_records: raise RuntimeError("No dataset records loaded!")
    print("\n" + "="*70); print("MERGED DATASET SUMMARY"); print("="*70)
    by_ds = {}
    for r in all_records: by_ds.setdefault(r["dataset_id"], []).append(r)
    for ds_id, recs in by_ds.items():
        print(f"  {ds_id:12s}: {len(recs):6,} images")
    print(f"  {'TOTAL':12s}: {len(all_records):6,} images")
    print(f"\n  Positive counts per class (mask=1):")
    print(f"  {'Class':25s} {'Pos':>8s} {'Known':>8s}")
    for i, lb in enumerate(CFG.UNIFIED_LABELS):
        n_pos = sum(1 for r in all_records if r["mask"][i] > 0.5 and r["labels"][i] > 0.5)
        n_known = sum(1 for r in all_records if r["mask"][i] > 0.5)
        print(f"  {lb:25s} {n_pos:8,} {n_known:8,}")
    if CFG.USE_CACHE and CFG.CACHE_DIR.exists():
        try:
            total_mb = sum(f.stat().st_size for f in CFG.CACHE_DIR.iterdir() if f.is_file()) / 1e6
            print(f"\n  /tmp cache size: {total_mb:.0f} MB")
        except Exception: pass
    return all_records


# =============================================================================
# Dataset & augmentations
# =============================================================================
DATASET_ID_TO_INT = {"vindr":0, "siim":1, "rsna":2, "chestxdet":3, "candid_ptx":4}
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD  = [0.229, 0.224, 0.225]
RADDINO_MEAN  = [0.5307, 0.5307, 0.5307]
RADDINO_STD   = [0.2583, 0.2583, 0.2583]


def get_norm_stats():
    if CFG.BACKBONE_TYPE == "raddino":
        return RADDINO_MEAN, RADDINO_STD
    return IMAGENET_MEAN, IMAGENET_STD


class MergedCXRDataset(Dataset):
    def __init__(self, records: List[dict], transform=None):
        self.records = records; self.transform = transform
    def __len__(self): return len(self.records)
    def __getitem__(self, i):
        r = self.records[i]; path = r["image_path"]
        try:
            if path.lower().endswith((".dcm",".dicom")) and HAS_PYDICOM:
                img = read_dicom_as_array(path)
            else:
                img = np.array(Image.open(path).convert("RGB"))
        except Exception:
            img = np.zeros((CFG.IMAGE_SIZE, CFG.IMAGE_SIZE, 3), dtype=np.uint8)
        if self.transform:
            img = self.transform(image=img)["image"]
        return (img,
                torch.from_numpy(r["labels"]).float(),
                torch.from_numpy(r["mask"]).float(),
                DATASET_ID_TO_INT[r["dataset_id"]])


def get_transforms(train=True):
    mean, std = get_norm_stats()
    if train:
        return A.Compose([
            A.Resize(CFG.IMAGE_SIZE, CFG.IMAGE_SIZE),
            A.ShiftScaleRotate(shift_limit=0.08, scale_limit=0.15,
                               rotate_limit=10, border_mode=0, p=0.7),
            A.OneOf([A.CLAHE(clip_limit=3.0, p=1.0),
                     A.RandomGamma(gamma_limit=(80,120), p=1.0)], p=0.4),
            A.OneOf([A.RandomBrightnessContrast(brightness_limit=0.2, contrast_limit=0.2, p=1.0),
                     A.HueSaturationValue(hue_shift_limit=8, sat_shift_limit=15, val_shift_limit=15, p=1.0)], p=0.5),
            A.OneOf([A.GaussNoise(var_limit=(10,50), p=1.0),
                     A.GaussianBlur(blur_limit=(3,5), p=1.0)], p=0.3),
            A.CoarseDropout(max_holes=8, max_height=32, max_width=32,
                            min_holes=2, fill_value=0, p=0.3),
            A.Normalize(mean=mean, std=std),
            ToTensorV2(),
        ])
    return A.Compose([
        A.Resize(CFG.IMAGE_SIZE, CFG.IMAGE_SIZE),
        A.Normalize(mean=mean, std=std),
        ToTensorV2(),
    ])


# =============================================================================
# Models
# =============================================================================
class ChestXrayModel(nn.Module):
    def __init__(self, name, nc, pretrained=True, dr=0.3, dpr=0.2):
        super().__init__()
        self.backbone = timm.create_model(
            name, pretrained=pretrained, num_classes=0,
            drop_rate=dr, drop_path_rate=dpr)
        with torch.no_grad():
            fd = self.backbone(torch.randn(1,3,CFG.IMAGE_SIZE,CFG.IMAGE_SIZE)).shape[1]
        self.head = nn.Sequential(nn.Dropout(dr), nn.Linear(fd, nc))
    def forward(self, x):
        f = self.backbone(x)
        if f.dim() == 4: f = f.mean(dim=[2,3])
        return self.head(f)


class RadDinoModel(nn.Module):
    def __init__(self, num_classes, dropout=0.3, gradient_checkpointing=True):
        super().__init__()
        if not HAS_TRANSFORMERS:
            raise RuntimeError("transformers not installed")
        print(f"  Loading {CFG.RADDINO_NAME} ...")
        self.backbone = AutoModel.from_pretrained(CFG.RADDINO_NAME)
        if gradient_checkpointing:
            try:
                self.backbone.gradient_checkpointing_enable()
                print(f"  ✓ Gradient checkpointing enabled")
            except Exception as e:
                print(f"  ⚠ Gradient checkpointing failed: {e}")
        feat_dim = self.backbone.config.hidden_size
        self.head = nn.Sequential(
            nn.LayerNorm(feat_dim),
            nn.Dropout(dropout),
            nn.Linear(feat_dim, num_classes),
        )
        print(f"  RAD-DINO feat_dim={feat_dim}, num_classes={num_classes}")
    def freeze_backbone(self):
        for p in self.backbone.parameters(): p.requires_grad = False
    def unfreeze_backbone(self):
        for p in self.backbone.parameters(): p.requires_grad = True
    def forward(self, x):
        out = self.backbone(pixel_values=x)
        cls = out.last_hidden_state[:, 0]
        return self.head(cls)


def build_model():
    if CFG.BACKBONE_TYPE == "raddino":
        print(f"  Building RAD-DINO model")
        return RadDinoModel(CFG.NUM_CLASSES, dropout=CFG.DROP_RATE)
    print(f"  Building {CFG.CONVNEXT_NAME}")
    return ChestXrayModel(CFG.CONVNEXT_NAME, CFG.NUM_CLASSES,
                          CFG.PRETRAINED, CFG.DROP_RATE, CFG.DROP_PATH_RATE)


# =============================================================================
# Loss
# =============================================================================
class MaskedAsymmetricLoss(nn.Module):
    def __init__(self, gamma_neg=6, gamma_pos=0, clip=0.1, pos_weight=None):
        super().__init__()
        self.gamma_neg, self.gamma_pos, self.clip = gamma_neg, gamma_pos, clip
        if pos_weight is not None:
            self.register_buffer("pos_weight", pos_weight)
        else:
            self.pos_weight = None

    def forward(self, x, y, mask):
        xs_pos = torch.sigmoid(x); xs_neg = 1 - xs_pos
        if self.clip > 0: xs_neg = (xs_neg + self.clip).clamp(max=1)
        los_pos = y * torch.log(xs_pos.clamp(min=1e-8))
        los_neg = (1 - y) * torch.log(xs_neg.clamp(min=1e-8))
        if self.pos_weight is not None:
            los_pos = los_pos * self.pos_weight.view(1, -1)
        loss = los_pos + los_neg
        pt = xs_pos * y + xs_neg * (1 - y)
        gamma = self.gamma_pos * y + self.gamma_neg * (1 - y)
        loss = loss * torch.pow(1 - pt, gamma)
        loss = loss * mask
        return -loss.sum() / mask.sum().clamp(min=1.0)


def compute_pos_weights(records, cap=10.0):
    n_pos = np.zeros(N_CLS); n_neg = np.zeros(N_CLS)
    for r in records:
        for c in range(N_CLS):
            if r["mask"][c] > 0.5:
                if r["labels"][c] > 0.5: n_pos[c] += 1
                else: n_neg[c] += 1
    weights = np.sqrt(n_neg / n_pos.clip(min=1))
    weights = np.clip(weights, 1.0, cap)
    print(f"\n  Per-class pos_weights:")
    for c, lb in enumerate(CFG.UNIFIED_LABELS):
        print(f"    {lb:25s} pos={int(n_pos[c]):>5d} neg={int(n_neg[c]):>6d} "
              f"w={weights[c]:.2f}")
    return torch.tensor(weights, dtype=torch.float32)


# =============================================================================
# Mixup / Cutmix / scheduler
# =============================================================================
def mixup_data(x, y, m, alpha=0.2):
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    idx = torch.randperm(x.size(0)).to(x.device)
    return lam*x + (1-lam)*x[idx], y, y[idx], m, m[idx], lam
def cutmix_data(x, y, m, alpha=1.0):
    lam = np.random.beta(alpha, alpha) if alpha > 0 else 1.0
    B,_,H,W = x.size(); idx = torch.randperm(B).to(x.device)
    cr = np.sqrt(1-lam); cw, ch = int(W*cr), int(H*cr)
    cx, cy = np.random.randint(W), np.random.randint(H)
    x1, y1 = np.clip(cx-cw//2,0,W), np.clip(cy-ch//2,0,H)
    x2, y2 = np.clip(cx+cw//2,0,W), np.clip(cy+ch//2,0,H)
    x_mix = x.clone()
    x_mix[:,:,y1:y2,x1:x2] = x[idx,:,y1:y2,x1:x2]
    lam_adj = 1 - (x2-x1)*(y2-y1)/(W*H)
    return x_mix, y, y[idx], m, m[idx], lam_adj


def cosine_sched(opt, warmup, total, min_ratio=1e-3):
    def fn(s):
        if s < warmup: return s / max(1, warmup)
        p = (s - warmup) / max(1, total - warmup)
        return min_ratio + (1 - min_ratio) * 0.5 * (1 + np.cos(np.pi * p))
    return torch.optim.lr_scheduler.LambdaLR(opt, fn)


# =============================================================================
# TTA
# =============================================================================
@torch.no_grad()
def tta_forward(model, x, use_flip=True):
    """Returns sigmoid probabilities (averaged over flips if enabled)."""
    with autocast(AMP_DEVICE, enabled=USE_AMP):
        probs = torch.sigmoid(model(x))
        if use_flip:
            probs_flip = torch.sigmoid(model(torch.flip(x, dims=[3])))
            probs = (probs + probs_flip) / 2
    return probs


# =============================================================================
# CLINICAL METRICS
# =============================================================================
def compute_metrics(preds, targets, masks):
    """
    Computes ranking + threshold-based + clinical metrics per class.
    Returns:
      Macro: auc, map, f1_05, precision_05, recall_05, miss_rate_05,
             sens_at_95spec, spec_at_95sens
      Per-class arrays for everything above + n_pos, n_neg
    """
    n_classes = targets.shape[1]
    aucs, aps = [], []
    sens_at_95spec, spec_at_95sens = [], []
    f1s_05, precs_05, recs_05 = [], [], []
    miss_rates_05 = []
    pos_counts, neg_counts = [], []
    
    for i in range(n_classes):
        sel = masks[:, i] > 0.5
        if sel.sum() < 2:
            for arr in [aucs, aps, sens_at_95spec, spec_at_95sens,
                        f1s_05, precs_05, recs_05, miss_rates_05]:
                arr.append(np.nan)
            pos_counts.append(0); neg_counts.append(0)
            continue
        
        y_true = targets[sel, i]
        y_score = preds[sel, i]
        n_pos = int(y_true.sum())
        n_neg = int(len(y_true) - n_pos)
        pos_counts.append(n_pos)
        neg_counts.append(n_neg)
        
        if len(np.unique(y_true)) < 2 or n_pos == 0:
            for arr in [aucs, aps, sens_at_95spec, spec_at_95sens,
                        f1s_05, precs_05, recs_05, miss_rates_05]:
                arr.append(np.nan)
            continue
        
        aucs.append(roc_auc_score(y_true, y_score))
        aps.append(average_precision_score(y_true, y_score))
        
        y_pred_05 = (y_score >= 0.5).astype(int)
        f1s_05.append(f1_score(y_true, y_pred_05, zero_division=0))
        precs_05.append(precision_score(y_true, y_pred_05, zero_division=0))
        rec05 = recall_score(y_true, y_pred_05, zero_division=0)
        recs_05.append(rec05)
        miss_rates_05.append(1.0 - rec05)
        
        fpr, tpr, _ = roc_curve(y_true, y_score)
        valid_fpr = fpr <= 0.05
        sens_at_95spec.append(float(tpr[valid_fpr].max()) if valid_fpr.any() else 0.0)
        valid_tpr = tpr >= 0.95
        spec_at_95sens.append(float((1 - fpr[valid_tpr]).max()) if valid_tpr.any() else 0.0)
    
    def safe_mean(arr):
        valid = [x for x in arr if not (isinstance(x, float) and np.isnan(x))]
        return float(np.mean(valid)) if valid else 0.0
    
    return {
        "auc": safe_mean(aucs),
        "map": safe_mean(aps),
        "f1_05": safe_mean(f1s_05),
        "precision_05": safe_mean(precs_05),
        "recall_05": safe_mean(recs_05),
        "miss_rate_05": safe_mean(miss_rates_05),
        "sens_at_95spec": safe_mean(sens_at_95spec),
        "spec_at_95sens": safe_mean(spec_at_95sens),
        "auc_per_class": aucs,
        "ap_per_class": aps,
        "f1_05_per_class": f1s_05,
        "precision_05_per_class": precs_05,
        "recall_05_per_class": recs_05,
        "miss_rate_05_per_class": miss_rates_05,
        "sens_at_95spec_per_class": sens_at_95spec,
        "spec_at_95sens_per_class": spec_at_95sens,
        "n_pos_per_class": pos_counts,
        "n_neg_per_class": neg_counts,
    }


def print_clinical_metrics_report(metrics, labels, thresholds=None,
                                   threshold_metrics=None, save_path=None):
    print("\n" + "="*100)
    print("CLINICAL METRICS REPORT")
    print("="*100)
    
    print(f"\n  Macro averages:")
    print(f"    AUC                    : {metrics['auc']:.4f}    (ranking quality)")
    print(f"    mAP                    : {metrics['map']:.4f}    (precision–recall area)")
    print(f"    F1 @ thr=0.5           : {metrics['f1_05']:.4f}")
    print(f"    Precision @ thr=0.5    : {metrics['precision_05']:.4f}")
    print(f"    Recall @ thr=0.5       : {metrics['recall_05']:.4f}    (sensitivity)")
    print(f"    Miss rate @ thr=0.5    : {metrics['miss_rate_05']:.4f}    (% positives missed)")
    print(f"    Sens @ 95% Specificity : {metrics['sens_at_95spec']:.4f}    ⭐ screening")
    print(f"    Spec @ 95% Sensitivity : {metrics['spec_at_95sens']:.4f}    ⭐ safety")
    
    print(f"\n  Per-class breakdown (at threshold = 0.5):")
    print(f"  {'Class':22s} {'AUC':>6s} {'AP':>6s} {'F1':>6s} "
          f"{'Prec':>6s} {'Rec':>6s} {'Miss%':>6s} "
          f"{'S@95Sp':>7s} {'Sp@95S':>7s} {'N+':>6s} {'N-':>7s}")
    print(f"  {'─'*22} {'─'*6} {'─'*6} {'─'*6} {'─'*6} {'─'*6} {'─'*6} "
          f"{'─'*7} {'─'*7} {'─'*6} {'─'*7}")
    
    for i, lb in enumerate(labels):
        def fmt(x, w=6, dp=4):
            if isinstance(x, float) and np.isnan(x):
                return f"{'N/A':>{w}s}"
            if isinstance(x, int):
                return f"{x:>{w}d}"
            return f"{x:>{w}.{dp}f}"
        
        auc = metrics['auc_per_class'][i]
        ap  = metrics['ap_per_class'][i]
        f1  = metrics['f1_05_per_class'][i]
        p   = metrics['precision_05_per_class'][i]
        r   = metrics['recall_05_per_class'][i]
        miss = metrics['miss_rate_05_per_class'][i]
        s95 = metrics['sens_at_95spec_per_class'][i]
        sp95 = metrics['spec_at_95sens_per_class'][i]
        npos = metrics['n_pos_per_class'][i]
        nneg = metrics['n_neg_per_class'][i]
        miss_str = "N/A   " if (isinstance(miss, float) and np.isnan(miss)) \
                   else f"{miss*100:5.1f}%"
        print(f"  {lb:22s} {fmt(auc)} {fmt(ap)} {fmt(f1)} "
              f"{fmt(p)} {fmt(r)} {miss_str:>6s} "
              f"{fmt(s95, 7)} {fmt(sp95, 7)} {fmt(npos, 6, 0)} {fmt(nneg, 7, 0)}")
    
    if threshold_metrics is not None and thresholds is not None:
        print(f"\n  Per-class breakdown (at OPTIMIZED threshold):")
        print(f"  {'Class':22s} {'Thr':>6s} {'F1':>6s} {'Prec':>6s} "
              f"{'Rec':>6s} {'Miss%':>6s}  vs F1@0.5")
        print(f"  {'─'*22} {'─'*6} {'─'*6} {'─'*6} {'─'*6} {'─'*6}  {'─'*8}")
        for i, lb in enumerate(labels):
            t = thresholds.get(lb, 0.5)
            tm = threshold_metrics.get(lb, {})
            f1_opt = tm.get('f1', 0)
            p_opt = tm.get('precision', 0)
            r_opt = tm.get('recall', 0)
            miss_opt = 1.0 - r_opt if r_opt > 0 else 1.0
            f1_def = metrics['f1_05_per_class'][i]
            f1_def = 0.0 if (isinstance(f1_def, float) and np.isnan(f1_def)) else f1_def
            delta = f1_opt - f1_def
            arrow = "↑" if delta > 0.005 else ("↓" if delta < -0.005 else "=")
            print(f"  {lb:22s} {t:6.3f} {f1_opt:6.4f} {p_opt:6.4f} "
                  f"{r_opt:6.4f} {miss_opt*100:5.1f}%  {delta:+.4f} {arrow}")
    
    print(f"\n  Use-case readiness (by AUC):")
    auc_thr = [(0.92, "Kaggle competition"),
               (0.95, "Portfolio / demo"),
               (0.96, "Research publication"),
               (0.98, "Clinical decision support"),
               (0.99, "FDA-cleared device")]
    for thr, name in auc_thr:
        ok = "✅" if metrics['auc'] >= thr else "❌"
        print(f"    {ok} {name:30s} (AUC ≥ {thr})")
    
    print(f"\n  Sensitivity@95%Spec readiness (clinical):")
    sens_thr = [(0.50, "Awareness only"),
                (0.70, "Triage helper"),
                (0.85, "Second reader"),
                (0.95, "Primary screener")]
    for thr, name in sens_thr:
        ok = "✅" if metrics['sens_at_95spec'] >= thr else "❌"
        print(f"    {ok} {name:30s} (Sens@95Spec ≥ {thr})")
    
    if save_path:
        save_path = Path(save_path)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        rows = []
        for i, lb in enumerate(labels):
            row = {
                "label": lb,
                "AUC":           metrics['auc_per_class'][i],
                "AP":            metrics['ap_per_class'][i],
                "F1@0.5":        metrics['f1_05_per_class'][i],
                "Precision@0.5": metrics['precision_05_per_class'][i],
                "Recall@0.5":    metrics['recall_05_per_class'][i],
                "MissRate@0.5":  metrics['miss_rate_05_per_class'][i],
                "Sens@95%Spec":  metrics['sens_at_95spec_per_class'][i],
                "Spec@95%Sens":  metrics['spec_at_95sens_per_class'][i],
                "N_positive":    metrics['n_pos_per_class'][i],
                "N_negative":    metrics['n_neg_per_class'][i],
            }
            if threshold_metrics is not None and thresholds is not None:
                tm = threshold_metrics.get(lb, {})
                row["OptimalThreshold"] = thresholds.get(lb, 0.5)
                row["F1@opt"] = tm.get('f1', 0)
                row["Precision@opt"] = tm.get('precision', 0)
                row["Recall@opt"] = tm.get('recall', 0)
                r_opt = tm.get('recall', 0)
                row["MissRate@opt"] = 1.0 - r_opt if r_opt > 0 else 1.0
            rows.append(row)
        pd.DataFrame(rows).to_csv(save_path, index=False)
        print(f"\n  💾 Full metrics CSV → {save_path.name}")


def plot_roc_pr_curves(preds, targets, masks, labels, save_path=None):
    """Plot ROC and PR curves for all classes side by side."""
    fig, axes = plt.subplots(1, 2, figsize=(16, 7))
    colors = plt.cm.tab20(np.linspace(0, 1, len(labels)))
    
    for i, lb in enumerate(labels):
        sel = masks[:, i] > 0.5
        if sel.sum() < 2: continue
        y_true = targets[sel, i]; y_score = preds[sel, i]
        if len(np.unique(y_true)) < 2: continue
        fpr, tpr, _ = roc_curve(y_true, y_score)
        auc = roc_auc_score(y_true, y_score)
        axes[0].plot(fpr, tpr, color=colors[i], lw=1.5,
                    label=f"{lb} (AUC={auc:.3f})")
    axes[0].plot([0, 1], [0, 1], 'k--', alpha=0.3, lw=1)
    axes[0].axvline(x=0.05, color='red', linestyle=':', alpha=0.5,
                    label='5% FPR (95% Spec)')
    axes[0].set_xlabel("False Positive Rate (1 - Specificity)")
    axes[0].set_ylabel("True Positive Rate (Sensitivity / Recall)")
    axes[0].set_title("ROC Curves")
    axes[0].legend(fontsize=7, loc='lower right')
    axes[0].grid(True, alpha=0.3)
    axes[0].set_xlim([0, 1]); axes[0].set_ylim([0, 1.02])
    
    for i, lb in enumerate(labels):
        sel = masks[:, i] > 0.5
        if sel.sum() < 2: continue
        y_true = targets[sel, i]; y_score = preds[sel, i]
        if len(np.unique(y_true)) < 2: continue
        prec, rec, _ = precision_recall_curve(y_true, y_score)
        ap = average_precision_score(y_true, y_score)
        axes[1].plot(rec, prec, color=colors[i], lw=1.5,
                    label=f"{lb} (AP={ap:.3f})")
    axes[1].set_xlabel("Recall (Sensitivity)")
    axes[1].set_ylabel("Precision")
    axes[1].set_title("Precision–Recall Curves")
    axes[1].legend(fontsize=7, loc='lower left')
    axes[1].grid(True, alpha=0.3)
    axes[1].set_xlim([0, 1]); axes[1].set_ylim([0, 1.02])
    
    plt.tight_layout()
    if save_path:
        save_path = Path(save_path)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


def plot_confusion_matrices(preds, targets, masks, labels,
                             thresholds=None, save_path=None):
    """One confusion matrix per class, using optimal threshold if provided."""
    n = len(labels); cols = 4; rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(4*cols, 3.5*rows))
    axes = axes.flatten() if rows > 1 else axes
    
    for i, lb in enumerate(labels):
        ax = axes[i]
        sel = masks[:, i] > 0.5
        if sel.sum() < 2:
            ax.set_title(f"{lb}\n(N/A)", fontsize=10); ax.axis('off'); continue
        y_true = targets[sel, i].astype(int)
        y_score = preds[sel, i]
        thr = thresholds.get(lb, 0.5) if thresholds else 0.5
        y_pred = (y_score >= thr).astype(int)
        cm = confusion_matrix(y_true, y_pred, labels=[0, 1])
        if cm.shape != (2, 2):
            cm_full = np.zeros((2, 2), dtype=int)
            cm_full[:cm.shape[0], :cm.shape[1]] = cm
            cm = cm_full
        cm_pct = cm / cm.sum(axis=1, keepdims=True).clip(min=1) * 100
        ax.imshow(cm_pct, cmap='Blues', vmin=0, vmax=100)
        for r in range(2):
            for c in range(2):
                txt = f"{cm[r,c]}\n({cm_pct[r,c]:.1f}%)"
                color = 'white' if cm_pct[r, c] > 50 else 'black'
                ax.text(c, r, txt, ha='center', va='center',
                        color=color, fontsize=9)
        ax.set_xticks([0, 1]); ax.set_yticks([0, 1])
        ax.set_xticklabels(['Pred-', 'Pred+'], fontsize=9)
        ax.set_yticklabels(['True-', 'True+'], fontsize=9)
        miss = 100 - (cm[1,1] / max(cm[1].sum(), 1) * 100)
        ax.set_title(f"{lb}\nthr={thr:.2f}, miss={miss:.1f}%", fontsize=9)
    for j in range(n, len(axes)):
        axes[j].axis('off')
    plt.suptitle("Confusion Matrices (per class)", fontsize=14, fontweight='bold', y=1.0)
    plt.tight_layout()
    if save_path:
        save_path = Path(save_path)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


# =============================================================================
# Train / val
# =============================================================================
def train_epoch(model, loader, crit, opt, sched, scaler, ema, accum=1):
    model.train(); running = 0.0; opt.zero_grad()
    t0 = time.time(); n = len(loader)
    for i, (imgs, lbls, masks, _) in enumerate(loader):
        imgs  = imgs.to(DEVICE, non_blocking=True)
        lbls  = lbls.to(DEVICE, non_blocking=True)
        masks = masks.to(DEVICE, non_blocking=True)
        do_aug = np.random.rand() < CFG.AUGMENT_PROB
        if do_aug and CFG.USE_MIXUP and np.random.rand() < 0.5:
            imgs, la, lb_, ma, mb, lam = mixup_data(imgs, lbls, masks, CFG.MIXUP_ALPHA)
        elif do_aug and CFG.USE_CUTMIX:
            imgs, la, lb_, ma, mb, lam = cutmix_data(imgs, lbls, masks, CFG.CUTMIX_ALPHA)
        else:
            la, lb_, ma, mb, lam = lbls, lbls, masks, masks, 1.0
        with autocast(AMP_DEVICE, enabled=USE_AMP):
            out = model(imgs)
            if CFG.LABEL_SMOOTHING > 0:
                lb_ = lb_*(1-CFG.LABEL_SMOOTHING) + CFG.LABEL_SMOOTHING/2
            loss = (lam*crit(out, la, ma) + (1-lam)*crit(out, lb_, mb)) / accum
        scaler.scale(loss).backward()
        if (i+1) % accum == 0:
            scaler.unscale_(opt)
            torch.nn.utils.clip_grad_norm_(model.parameters(), CFG.GRAD_CLIP)
            scaler.step(opt); scaler.update(); opt.zero_grad(); sched.step()
            if ema is not None: ema.update(unwrap(model))
        running += loss.item() * accum
        if (i+1) % CFG.LOG_EVERY == 0:
            ela = time.time() - t0
            spd = (i+1) / max(ela, 0.01)
            eta = (n - i - 1) / max(spd, 0.01)
            print(f"  [{i+1:4d}/{n}] loss={running/(i+1):.4f} "
                  f"lr={sched.get_last_lr()[0]:.6f} {spd:.1f}b/s ETA={eta/60:.1f}m")
    if n % accum != 0:
        scaler.unscale_(opt)
        torch.nn.utils.clip_grad_norm_(model.parameters(), CFG.GRAD_CLIP)
        scaler.step(opt); scaler.update(); opt.zero_grad(); sched.step()
        if ema is not None: ema.update(unwrap(model))
    return running / n


@torch.no_grad()
def validate(model, loader, crit, use_tta=False):
    model.eval(); losses = 0.0
    all_p, all_y, all_m = [], [], []
    for imgs, lbls, masks, _ in loader:
        imgs  = imgs.to(DEVICE, non_blocking=True)
        lbls  = lbls.to(DEVICE, non_blocking=True)
        masks = masks.to(DEVICE, non_blocking=True)
        with autocast(AMP_DEVICE, enabled=USE_AMP):
            logits = model(imgs)
            losses += crit(logits, lbls, masks).item()
        if use_tta:
            probs = tta_forward(model, imgs, use_flip=CFG.TTA_FLIP)
        else:
            probs = torch.sigmoid(logits)
        all_p.append(probs.cpu().numpy())
        all_y.append(lbls.cpu().numpy())
        all_m.append(masks.cpu().numpy())
    m = compute_metrics(np.concatenate(all_p), np.concatenate(all_y), np.concatenate(all_m))
    m["loss"] = losses / len(loader)
    return m


@torch.no_grad()
def collect_predictions(model, loader, use_tta=True):
    model.eval()
    all_p, all_y, all_m = [], [], []
    for imgs, lbls, masks, _ in loader:
        imgs = imgs.to(DEVICE, non_blocking=True)
        if use_tta:
            probs = tta_forward(model, imgs, use_flip=CFG.TTA_FLIP)
        else:
            with autocast(AMP_DEVICE, enabled=USE_AMP):
                probs = torch.sigmoid(model(imgs))
        all_p.append(probs.cpu().numpy())
        all_y.append(lbls.cpu().numpy())
        all_m.append(masks.cpu().numpy())
    return np.concatenate(all_p), np.concatenate(all_y), np.concatenate(all_m)


# =============================================================================
# Self-distillation
# =============================================================================
@torch.no_grad()
def generate_pseudo_labels(model, records, batch_size=16,
                           pos_thresh=0.97, neg_thresh=0.03, use_tta=True):
    print(f"\n  Generating pseudo-labels (pos≥{pos_thresh}, neg≤{neg_thresh}, TTA={use_tta})")
    model.eval()
    ds = MergedCXRDataset(records, get_transforms(train=False))
    loader = DataLoader(ds, batch_size=batch_size, shuffle=False,
                        num_workers=CFG.NUM_WORKERS, pin_memory=True,
                        persistent_workers=False)
    all_probs = []
    t0 = time.time(); n = len(loader)
    for bi, (imgs, _, _, _) in enumerate(loader):
        imgs = imgs.to(DEVICE, non_blocking=True)
        if use_tta:
            probs = tta_forward(model, imgs, use_flip=CFG.TTA_FLIP)
        else:
            with autocast(AMP_DEVICE, enabled=USE_AMP):
                probs = torch.sigmoid(model(imgs))
        all_probs.append(probs.cpu().numpy())
        if (bi+1) % 50 == 0:
            spd = (bi+1) / max(time.time()-t0, 0.01)
            eta = (n - bi - 1) / max(spd, 0.01)
            print(f"    [{bi+1:4d}/{n}] {spd:.1f}b/s ETA={eta/60:.1f}m")
    all_probs = np.concatenate(all_probs)

    n_added_pos = np.zeros(N_CLS, dtype=int)
    n_added_neg = np.zeros(N_CLS, dtype=int)
    n_kept_orig = np.zeros(N_CLS, dtype=int)
    new_records = []
    for i, r in enumerate(records):
        new_labels = r["labels"].copy()
        new_mask   = r["mask"].copy()
        for c in range(N_CLS):
            if r["mask"][c] > 0.5:
                n_kept_orig[c] += 1; continue
            p = all_probs[i, c]
            if p >= pos_thresh:
                new_labels[c] = 1.0; new_mask[c] = 1.0; n_added_pos[c] += 1
            elif p <= neg_thresh:
                new_labels[c] = 0.0; new_mask[c] = 1.0; n_added_neg[c] += 1
        new_r = dict(r); new_r["labels"] = new_labels; new_r["mask"] = new_mask
        new_records.append(new_r)
    print(f"\n  {'Class':25s} {'Orig':>7s} {'+Pos':>7s} {'+Neg':>7s} {'Total':>7s}")
    print(f"  {'─'*25} {'─'*7} {'─'*7} {'─'*7} {'─'*7}")
    for c, lb in enumerate(CFG.UNIFIED_LABELS):
        total = n_kept_orig[c] + n_added_pos[c] + n_added_neg[c]
        print(f"  {lb:25s} {n_kept_orig[c]:7d} {n_added_pos[c]:7d} "
              f"{n_added_neg[c]:7d} {total:7d}")
    return new_records


# =============================================================================
# Early stopping + checkpoints
# =============================================================================
class EarlyStopping:
    def __init__(self, patience=6, min_delta=1e-4, best=None, counter=0):
        self.patience = patience; self.min_delta = min_delta
        self.best = best; self.counter = counter; self.stop = False
    def __call__(self, score):
        if self.best is None:
            self.best = score; return True
        if score > self.best + self.min_delta:
            d = score - self.best
            print(f"  ✓ Improved +{d:.5f} ({self.best:.4f}→{score:.4f})")
            self.best = score; self.counter = 0
            return True
        self.counter += 1
        print(f"  ✗ No improvement {self.counter}/{self.patience} (best={self.best:.4f})")
        if self.counter >= self.patience: self.stop = True
        return False


def save_checkpoint(epoch, model, ema, opt, sched, scaler, history,
                    best_auc, es_counter, path, light=False):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    model_name = CFG.RADDINO_NAME if CFG.BACKBONE_TYPE == "raddino" else CFG.CONVNEXT_NAME
    payload = {
        "epoch": epoch,
        "model_state_dict": unwrap(model).state_dict(),
        "ema_state_dict":   ema.module.state_dict() if ema is not None else None,
        "history": history, "best_auc": best_auc,
        "early_stop_counter": es_counter,
        "config": {
            "backbone_type": CFG.BACKBONE_TYPE,
            "model_name": model_name,
            "image_size": CFG.IMAGE_SIZE,
            "num_classes": CFG.NUM_CLASSES,
            "labels": CFG.UNIFIED_LABELS,
        },
    }
    if not light:
        payload["optimizer_state_dict"] = opt.state_dict()
        payload["scheduler_state_dict"] = sched.state_dict()
        payload["scaler_state_dict"]    = scaler.state_dict()
    torch.save(payload, path)
    sz = path.stat().st_size / 1e6
    tag = "[light]" if light else "[full]"
    print(f"  💾 {tag} → {path.name} (ep{epoch}, {sz:.0f} MB)")


def cleanup_old_checkpoints(save_dir: Path, keep_n: int = 3):
    ckpts = sorted(save_dir.glob("checkpoint_*.pth"))
    if len(ckpts) <= keep_n: return
    for f in ckpts[:-keep_n]:
        try: f.unlink(); print(f"  🗑  removed: {f.name}")
        except Exception: pass


def auto_find_checkpoint(checkpoint_dir: Path) -> Optional[Path]:
    dirs = [checkpoint_dir]
    if CFG.CHECKPOINT_SAVE_DIR != checkpoint_dir:
        dirs.append(CFG.CHECKPOINT_SAVE_DIR)
    for d in dirs:
        if not d.exists(): continue
        ec = sorted(d.glob("checkpoint_*epoch_*.pth"))
        if ec: print(f"  Found: {ec[-1]}"); return ec[-1]
        bm = d / "best_model.pth"
        if bm.exists(): print(f"  Found: {bm}"); return bm
        any_ckpt = sorted(d.glob("*.pth"))
        if any_ckpt: print(f"  Found: {any_ckpt[-1]}"); return any_ckpt[-1]
    return None


def load_checkpoint(path, model, ema, opt, sched, scaler):
    print(f"\n  Loading: {path}")
    ckpt = torch.load(path, map_location=DEVICE, weights_only=False)
    is_full = isinstance(ckpt, dict) and "epoch" in ckpt
    empty_history = {"train_loss":[],"val_loss":[],"val_auc":[],"val_map":[],
                     "auc_per_class":[],"ap_per_class":[],
                     "ema_val_auc":[],"ema_val_map":[],"lr":[]}
    if not is_full:
        print(f"  ⚠ weights-only checkpoint")
        sd = ckpt if not isinstance(ckpt, dict) else ckpt.get("model_state_dict", ckpt)
        try:
            unwrap(model).load_state_dict(sd, strict=False)
            print(f"  partial load (strict=False)")
        except Exception as e:
            print(f"  ⚠ partial load failed: {e}")
        return 1, empty_history, 0.0, 0
    saved_cfg = ckpt.get("config", {})
    saved_cls = saved_cfg.get("num_classes")
    saved_backbone = saved_cfg.get("backbone_type", "convnext")
    if saved_backbone != CFG.BACKBONE_TYPE:
        print(f"  ⚠ backbone mismatch: saved={saved_backbone}, current={CFG.BACKBONE_TYPE}")
        print(f"  → ignoring checkpoint, fresh training")
        return 1, empty_history, 0.0, 0
    if saved_cls is not None and saved_cls != CFG.NUM_CLASSES:
        print(f"  ⚠ class mismatch: {saved_cls}→{CFG.NUM_CLASSES}, loading backbone only")
        sd = ckpt["model_state_dict"]
        backbone_sd = {k: v for k, v in sd.items() if k.startswith("backbone.")}
        unwrap(model).load_state_dict(backbone_sd, strict=False)
        return 1, empty_history, 0.0, 0
    try:
        unwrap(model).load_state_dict(ckpt["model_state_dict"])
    except Exception as e:
        print(f"  ⚠ strict load failed: {e}, trying non-strict")
        unwrap(model).load_state_dict(ckpt["model_state_dict"], strict=False)
    if ema is not None and ckpt.get("ema_state_dict") is not None:
        try: ema.module.load_state_dict(ckpt["ema_state_dict"]); print("  EMA loaded")
        except Exception as e: print(f"  EMA skipped: {e}")
    if "optimizer_state_dict" in ckpt:
        try:
            if len(ckpt["optimizer_state_dict"]["param_groups"]) == len(opt.param_groups):
                opt.load_state_dict(ckpt["optimizer_state_dict"])
            else: print("  Optimizer skipped (group mismatch)")
        except Exception as e: print(f"  Optimizer skipped: {e}")
    if "scheduler_state_dict" in ckpt:
        try: sched.load_state_dict(ckpt["scheduler_state_dict"])
        except Exception as e: print(f"  Scheduler skipped: {e}")
    if "scaler_state_dict" in ckpt:
        try: scaler.load_state_dict(ckpt["scaler_state_dict"])
        except Exception as e: print(f"  Scaler skipped: {e}")
    history = ckpt.get("history", empty_history)
    for k in empty_history:
        if k not in history: history[k] = []
    start = ckpt["epoch"] + 1
    best = ckpt.get("best_auc", 0.0)
    cnt = ckpt.get("early_stop_counter", 0)
    print(f"  Resume: ep {start} | Best AUC: {best:.4f} | ES: {cnt}/{CFG.PATIENCE}")
    return start, history, best, cnt


# =============================================================================
# Threshold optimization
# =============================================================================
def optimize_thresholds(preds, targets, masks, labels, search_steps=200):
    thresholds = np.linspace(0.05, 0.95, search_steps)
    res = {"labels": labels, "thresholds": {}, "metrics_at_threshold": {},
           "default_0.5_metrics": {}}
    print(f"\n  Optimizing thresholds (F1, {search_steps} steps)")
    print(f"  {'Label':25s} {'Thr':>6s} {'F1':>7s} {'P':>7s} {'R':>7s} {'F1@.5':>7s} {'Δ':>7s}")
    print(f"  {'─'*25} {'─'*6} {'─'*7} {'─'*7} {'─'*7} {'─'*7} {'─'*7}")
    for i, lb in enumerate(labels):
        sel = masks[:, i] > 0.5
        if sel.sum() < 5:
            res["thresholds"][lb] = 0.5
            res["metrics_at_threshold"][lb] = {"f1":0,"precision":0,"recall":0,"n_positive":0}
            res["default_0.5_metrics"][lb] = {"f1":0,"precision":0,"recall":0}
            print(f"  {lb:25s} {'N/A':>6s}"); continue
        y = targets[sel, i].astype(int); p = preds[sel, i]
        if y.sum() == 0:
            res["thresholds"][lb] = 0.5
            res["metrics_at_threshold"][lb] = {"f1":0,"precision":0,"recall":0,"n_positive":0}
            res["default_0.5_metrics"][lb] = {"f1":0,"precision":0,"recall":0}
            print(f"  {lb:25s} {'N/A':>6s}  (no pos)"); continue
        best_f1, best_t, best_p, best_r = 0, 0.5, 0, 0
        for t in thresholds:
            yp = (p >= t).astype(int)
            f1 = f1_score(y, yp, zero_division=0)
            if f1 > best_f1:
                best_f1, best_t = f1, t
                best_p = precision_score(y, yp, zero_division=0)
                best_r = recall_score(y, yp, zero_division=0)
        yp_def = (p >= 0.5).astype(int)
        f1_def = f1_score(y, yp_def, zero_division=0)
        p_def  = precision_score(y, yp_def, zero_division=0)
        r_def  = recall_score(y, yp_def, zero_division=0)
        delta = best_f1 - f1_def
        arrow = "↑" if delta > 0.005 else ("↓" if delta < -0.005 else "=")
        res["thresholds"][lb] = round(float(best_t), 4)
        res["metrics_at_threshold"][lb] = {
            "f1": round(float(best_f1),4), "precision": round(float(best_p),4),
            "recall": round(float(best_r),4), "n_positive": int(y.sum())}
        res["default_0.5_metrics"][lb] = {
            "f1": round(float(f1_def),4), "precision": round(float(p_def),4),
            "recall": round(float(r_def),4)}
        print(f"  {lb:25s} {best_t:6.3f} {best_f1:7.4f} {best_p:7.4f} {best_r:7.4f} "
              f"{f1_def:7.4f} {delta:+7.4f} {arrow}")
    opt_f1s = [v["f1"] for v in res["metrics_at_threshold"].values() if v["f1"] > 0]
    def_f1s = [v["f1"] for v in res["default_0.5_metrics"].values() if v["f1"] > 0]
    res["macro_f1_optimized"] = round(float(np.mean(opt_f1s)),4) if opt_f1s else 0
    res["macro_f1_default"]   = round(float(np.mean(def_f1s)),4) if def_f1s else 0
    print(f"\n  Macro F1: opt={res['macro_f1_optimized']:.4f}  "
          f"def={res['macro_f1_default']:.4f}  "
          f"Δ={res['macro_f1_optimized']-res['macro_f1_default']:+.4f}")
    return res


def save_thresholds(results, save_dir: Path):
    save_dir.mkdir(parents=True, exist_ok=True)
    with open(save_dir/"optimal_thresholds.json","w") as f:
        json.dump(results, f, indent=2)
    rows = []
    for lb in results["labels"]:
        opt = results["metrics_at_threshold"].get(lb, {})
        dfl = results["default_0.5_metrics"].get(lb, {})
        rows.append({"label": lb,
                     "optimal_threshold": results["thresholds"].get(lb, 0.5),
                     "f1_optimized": opt.get("f1",0),
                     "precision_optimized": opt.get("precision",0),
                     "recall_optimized": opt.get("recall",0),
                     "f1_at_0.5": dfl.get("f1",0),
                     "n_positive": opt.get("n_positive",0)})
    pd.DataFrame(rows).to_csv(save_dir/"optimal_thresholds.csv", index=False)
    with open(save_dir/"thresholds_quick.txt","w") as f:
        f.write(f"# Macro F1 opt={results['macro_f1_optimized']:.4f}  "
                f"def={results['macro_f1_default']:.4f}\n")
        for lb in results["labels"]:
            f.write(f"{lb}: {results['thresholds'].get(lb,0.5):.4f}\n")
    print(f"  💾 thresholds saved (json/csv/txt)")


def plot_threshold_analysis(results, save_path=None):
    labels = results["labels"]
    opt_t = [results["thresholds"].get(lb, 0.5) for lb in labels]
    f1_opt = [results["metrics_at_threshold"].get(lb,{}).get("f1",0) for lb in labels]
    f1_def = [results["default_0.5_metrics"].get(lb,{}).get("f1",0) for lb in labels]
    fig, axes = plt.subplots(1, 2, figsize=(16, 6))
    y_pos = np.arange(len(labels))
    colors = ['#2ecc71' if t<0.5 else '#e74c3c' if t>0.5 else '#3498db' for t in opt_t]
    axes[0].barh(y_pos, opt_t, color=colors, alpha=0.8, height=0.6)
    axes[0].axvline(x=0.5, color='black', linestyle='--', alpha=0.5, label='0.5')
    axes[0].set_yticks(y_pos); axes[0].set_yticklabels(labels, fontsize=9)
    axes[0].set_xlabel("Optimal Threshold"); axes[0].set_title("Per-Class Thresholds")
    axes[0].legend(); axes[0].set_xlim(0,1); axes[0].grid(True, alpha=0.3, axis='x')
    w = 0.35
    axes[1].barh(y_pos - w/2, f1_def, w, label='F1@0.5', color='#e74c3c', alpha=0.7)
    axes[1].barh(y_pos + w/2, f1_opt, w, label='F1@opt', color='#2ecc71', alpha=0.7)
    axes[1].set_yticks(y_pos); axes[1].set_yticklabels(labels, fontsize=9)
    axes[1].set_xlabel("F1"); axes[1].set_title("F1: Default vs Optimized")
    axes[1].legend(); axes[1].grid(True, alpha=0.3, axis='x')
    plt.tight_layout()
    if save_path:
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


# =============================================================================
# GradCAM
# =============================================================================
class GradCAM:
    def __init__(self, model):
        self.model = model
        unwrap(self.model).eval()
        self.activations = None; self.gradients = None
        self._hooks = []; self._register()

    def _find_target_layer(self):
        target = None
        m = unwrap(self.model)
        if CFG.BACKBONE_TYPE == "raddino":
            try:
                for name, mod in m.backbone.named_modules():
                    if "encoder.layer" in name and name.endswith("layernorm_after"):
                        target = mod
            except Exception: pass
            return target
        for name, mod in m.backbone.named_modules():
            if isinstance(mod, nn.Conv2d): target = mod
        for name, mod in m.backbone.named_modules():
            if "norm_pre" in name or ("head" in name and "norm" in name):
                target = mod; break
        return target

    def _register(self):
        target = self._find_target_layer()
        if target is None: return
        def fwd(_m, _i, o): self.activations = o.detach()
        def bwd(_m, _gi, go): self.gradients = go[0].detach()
        self._hooks.append(target.register_forward_hook(fwd))
        self._hooks.append(target.register_full_backward_hook(bwd))

    def generate(self, x, class_idx):
        H, W = x.shape[2], x.shape[3]
        m = unwrap(self.model); m.zero_grad()
        x = x.to(DEVICE).requires_grad_(True)
        out = m(x)
        out[0, class_idx].backward()
        if self.activations is None or self.gradients is None:
            return np.zeros((H, W))
        if self.activations.dim() == 4:
            w = self.gradients.mean(dim=[2,3], keepdim=True)
            cam = (w * self.activations).sum(dim=1, keepdim=True)
            cam = F.relu(cam)[0, 0].cpu().numpy()
        elif self.activations.dim() == 3:
            tokens = self.activations[:, 1:, :]
            grads  = self.gradients[:, 1:, :]
            cam = (tokens * grads).sum(-1)[0]
            n_patches = cam.shape[0]
            grid = int(np.sqrt(n_patches))
            if grid * grid != n_patches:
                return np.zeros((H, W))
            cam = cam.reshape(grid, grid).cpu().numpy()
            cam = np.maximum(cam, 0)
        else:
            return np.zeros((H, W))
        if cam.max() > 0: cam = cam / cam.max()
        cam_pil = Image.fromarray((cam*255).astype(np.uint8))
        return np.array(cam_pil.resize((W, H), Image.BILINEAR)) / 255.0

    def cleanup(self):
        for h in self._hooks: h.remove()
        self._hooks.clear()


def create_heatmap_overlay(image, heatmap, alpha=0.4):
    if heatmap.shape[:2] != image.shape[:2]:
        heatmap = np.array(Image.fromarray((heatmap*255).astype(np.uint8))
                           .resize((image.shape[1], image.shape[0]), Image.BILINEAR)) / 255.0
    hc = (plt.cm.jet(heatmap)[:,:,:3] * 255).astype(np.uint8)
    return ((1-alpha)*image.astype(np.float32) + alpha*hc.astype(np.float32)).clip(0,255).astype(np.uint8)


def visualize_gradcam_grid(model, val_records, n_samples=8, top_k=3, save_path=None):
    print(f"\n  GradCAM for {n_samples} samples (top {top_k} classes)")
    gradcam = GradCAM(model)
    unwrap(model).eval()
    pos_recs = [r for r in val_records if r["labels"].max() > 0]
    if len(pos_recs) < n_samples: pos_recs = val_records
    sel = random.sample(pos_recs, min(n_samples, len(pos_recs)))
    fig, axes = plt.subplots(n_samples, top_k+1, figsize=(4*(top_k+1), 4*n_samples))
    if n_samples == 1: axes = axes[np.newaxis, :]
    tx = get_transforms(False)
    m_raw = unwrap(model)
    for row, r in enumerate(sel):
        path = r["image_path"]
        try:
            if path.lower().endswith((".dcm",".dicom")) and HAS_PYDICOM:
                orig = read_dicom_as_array(path)
            else:
                orig = np.array(Image.open(path).convert("RGB"))
            orig = np.array(Image.fromarray(orig).resize((CFG.IMAGE_SIZE, CFG.IMAGE_SIZE), Image.LANCZOS))
        except Exception:
            orig = np.zeros((CFG.IMAGE_SIZE, CFG.IMAGE_SIZE, 3), dtype=np.uint8)
        x = tx(image=orig)["image"].unsqueeze(0)
        with torch.no_grad():
            with autocast(AMP_DEVICE, enabled=USE_AMP):
                probs = torch.sigmoid(m_raw(x.to(DEVICE))).cpu().numpy()[0]
        top = np.argsort(probs)[::-1][:top_k]
        true_labels = r["labels"]
        true_str = ", ".join([CFG.UNIFIED_LABELS[i] for i in range(N_CLS) if true_labels[i] > 0.5])
        if not true_str: true_str = "No finding"
        axes[row,0].imshow(orig)
        axes[row,0].set_title(f"GT: {true_str}", fontsize=8, color='green')
        axes[row,0].axis('off')
        for col, ci in enumerate(top):
            heat = gradcam.generate(x, ci)
            ov = create_heatmap_overlay(orig, heat, alpha=0.45)
            axes[row, col+1].imshow(ov)
            is_true = true_labels[ci] > 0.5
            color = 'green' if is_true else 'red'
            mk = "✓" if is_true else "✗"
            axes[row, col+1].set_title(f"{CFG.UNIFIED_LABELS[ci]}\np={probs[ci]:.3f} {mk}",
                                       fontsize=8, color=color)
            axes[row, col+1].axis('off')
    plt.suptitle("GradCAM — Top Predicted Classes", fontsize=14, fontweight='bold', y=1.01)
    plt.tight_layout()
    if save_path:
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()
    gradcam.cleanup()


# =============================================================================
# Training-history plots
# =============================================================================
def plot_training_curves(history, save_path=None):
    n = len(history["train_loss"])
    if n == 0: return
    er = range(1, n+1)
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    axes[0].plot(er, history["train_loss"], 'b-o', ms=4, label="Train")
    axes[0].plot(er, history["val_loss"], 'r-o', ms=4, label="Val")
    axes[0].set_title("Loss"); axes[0].legend(); axes[0].grid(True, alpha=0.3)
    axes[0].set_xlabel("Epoch"); axes[0].set_ylabel("Loss")
    axes[1].plot(er, history["val_auc"], 'g-o', ms=4, label="Val AUC")
    if history.get("ema_val_auc"):
        axes[1].plot(er, history["ema_val_auc"], 'm-o', ms=4, label="EMA AUC")
    bi = int(np.argmax(history["val_auc"])); bv = history["val_auc"][bi]
    axes[1].plot(bi+1, bv, 'r*', ms=15, label=f"Best={bv:.4f}@ep{bi+1}")
    axes[1].axhline(y=0.90, color='orange', linestyle=':', alpha=0.6, label="0.90")
    axes[1].set_title("Macro AUC"); axes[1].legend(); axes[1].grid(True, alpha=0.3)
    axes[1].set_xlabel("Epoch"); axes[1].set_ylabel("AUC")
    axes[2].plot(er, history["val_map"], 'm-o', ms=4, label="Val mAP")
    if history.get("ema_val_map"):
        axes[2].plot(er, history["ema_val_map"], 'c-o', ms=4, label="EMA mAP")
    axes[2].set_title("Macro mAP"); axes[2].legend(); axes[2].grid(True, alpha=0.3)
    axes[2].set_xlabel("Epoch"); axes[2].set_ylabel("mAP")
    plt.tight_layout()
    if save_path:
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


def plot_per_class_auc(history, labels, save_path=None):
    if not history.get("auc_per_class"): return
    n = len(history["auc_per_class"])
    er = range(1, n+1)
    fig, ax = plt.subplots(figsize=(12, 6))
    colors = plt.cm.tab20(np.linspace(0, 1, len(labels)))
    for i, lb in enumerate(labels):
        s = []
        for e in range(n):
            v = history["auc_per_class"][e][i] if i < len(history["auc_per_class"][e]) else np.nan
            s.append(v if not (isinstance(v, float) and np.isnan(v)) else None)
        ax.plot(er, s, '-o', ms=3, color=colors[i], label=lb)
    ax.axhline(y=0.90, color='red', linestyle=':', alpha=0.5)
    ax.set_xlabel("Epoch"); ax.set_ylabel("AUC")
    ax.set_title("Per-Class Validation AUC")
    ax.legend(bbox_to_anchor=(1.05,1), loc='upper left', fontsize=8)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    if save_path:
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


def plot_lr_schedule(history, save_path=None):
    if not history.get("lr"): return
    n = len(history["lr"])
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(range(1, n+1), history["lr"], 'b-o', ms=3)
    ax.set_xlabel("Epoch"); ax.set_ylabel("LR"); ax.set_yscale('log')
    ax.set_title("LR Schedule"); ax.grid(True, alpha=0.3)
    plt.tight_layout()
    if save_path:
        save_path.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"  📊 {save_path.name}")
    plt.show()


def make_balanced_sampler(records):
    weights = [CFG.SAMPLER_WEIGHTS.get(r["dataset_id"], 1.0) for r in records]
    return WeightedRandomSampler(weights, num_samples=len(records), replacement=True)


# =============================================================================
# Training-loop helper
# =============================================================================
def run_training_loop(model, ema, opt, sched, scaler, crit, tl, vl,
                       num_epochs, start_epoch, history, best_auc, es_counter,
                       save_path, tag="ROUND-1"):
    es = EarlyStopping(patience=CFG.PATIENCE, min_delta=CFG.MIN_DELTA,
                       best=(best_auc if best_auc > 0 else None),
                       counter=es_counter)
    print(f"\n  Training {tag}: epochs {start_epoch}→{num_epochs}")
    for epoch in range(start_epoch, num_epochs + 1):
        t0 = time.time()
        print(f"\n{'='*70}\n[{tag}] Epoch {epoch}/{num_epochs}\n{'='*70}")
        train_loss = train_epoch(model, tl, crit, opt, sched, scaler, ema, CFG.GRAD_ACCUM)
        vm = validate(model, vl, crit, use_tta=CFG.USE_TTA_VAL)
        ema_vm = validate(ema.module, vl, crit, use_tta=CFG.USE_TTA_VAL) if ema is not None else None
        dt = time.time() - t0
        print(f"\n  ┌─ Train loss : {train_loss:.4f}")
        print(f"  ├─ Val   loss : {vm['loss']:.4f}")
        print(f"  ├─ Val   AUC  : {vm['auc']:.4f}")
        print(f"  ├─ Val   mAP  : {vm['map']:.4f}")
        print(f"  ├─ Val F1@0.5 : {vm['f1_05']:.4f}  Miss={vm['miss_rate_05']:.4f}")
        print(f"  ├─ Sens@95Sp  : {vm['sens_at_95spec']:.4f}")
        if ema_vm:
            print(f"  ├─ EMA   AUC  : {ema_vm['auc']:.4f}")
            print(f"  ├─ EMA   mAP  : {ema_vm['map']:.4f}")
            print(f"  ├─ EMA Sens@95Sp: {ema_vm['sens_at_95spec']:.4f}")
        print(f"  └─ Time       : {dt:.0f}s ({dt/60:.1f}m)")

        print(f"\n  Per-class:")
        for i, lb in enumerate(CFG.UNIFIED_LABELS):
            a = vm['auc_per_class'][i]; ap = vm['ap_per_class'][i]
            a_str  = f"{a:.4f}"  if not (isinstance(a, float) and np.isnan(a))   else "  -  "
            ap_str = f"{ap:.4f}" if not (isinstance(ap, float) and np.isnan(ap)) else "  -  "
            print(f"    {lb:25s}  AUC={a_str}  AP={ap_str}")

        history["train_loss"].append(train_loss)
        history["val_loss"].append(vm["loss"])
        history["val_auc"].append(vm["auc"])
        history["val_map"].append(vm["map"])
        history["auc_per_class"].append(vm["auc_per_class"])
        history["ap_per_class"].append(vm["ap_per_class"])
        history["lr"].append(opt.param_groups[-1]["lr"])
        if ema_vm:
            history["ema_val_auc"].append(ema_vm["auc"])
            history["ema_val_map"].append(ema_vm["map"])

        track = ema_vm["auc"] if ema_vm else vm["auc"]
        improved = es(track)
        if improved:
            best_auc = track
            save_checkpoint(epoch, model, ema, opt, sched, scaler,
                            history, best_auc, es.counter, save_path, light=False)
        if CFG.CHECKPOINT_EVERY > 0 and epoch % CFG.CHECKPOINT_EVERY == 0:
            ck_path = CFG.CHECKPOINT_SAVE_DIR / f"checkpoint_{tag.lower()}_epoch_{epoch:02d}.pth"
            save_checkpoint(epoch, model, ema, opt, sched, scaler,
                            history, best_auc, es.counter, ck_path, light=True)
            cleanup_old_checkpoints(CFG.CHECKPOINT_SAVE_DIR, CFG.KEEP_LAST_N_CKPTS)
        if es.stop:
            print(f"\n⚠ Early stop at epoch {epoch} (best={es.best:.4f})")
            break
        gc.collect()
        if torch.cuda.is_available(): torch.cuda.empty_cache()
    return history, best_auc


# =============================================================================
# MAIN
# =============================================================================
def main():
    if torch.cuda.is_available():
        torch.cuda.empty_cache(); gc.collect()
        for i in range(N_GPUS):
            free = torch.cuda.mem_get_info(i)[0] / 1e9
            total = torch.cuda.get_device_properties(i).total_memory / 1e9
            print(f"GPU {i}: {free:.1f}/{total:.1f} GB free")

    t_total = time.time()
    backbone_name = CFG.RADDINO_NAME if CFG.BACKBONE_TYPE == "raddino" else CFG.CONVNEXT_NAME
    print("\n" + "="*70)
    print("MULTI-DATASET CHEST X-RAY CLASSIFIER v2 — clinical metrics")
    print(f"  Backbone   : {CFG.BACKBONE_TYPE} ({backbone_name})")
    print(f"  Image size : {CFG.IMAGE_SIZE}")
    print(f"  Batch      : {CFG.BATCH_SIZE} × accum {CFG.GRAD_ACCUM} = effective {CFG.BATCH_SIZE*CFG.GRAD_ACCUM}")
    print(f"  Epochs     : {CFG.NUM_EPOCHS}  (+ {CFG.DISTILL_EPOCHS} self-distill)")
    print(f"  Loss       : ASL γ-={CFG.ASL_GAMMA_NEG} γ+={CFG.ASL_GAMMA_POS} clip={CFG.ASL_CLIP} +pos_weight")
    print(f"  Mixup      : {CFG.USE_MIXUP}  Cutmix: {CFG.USE_CUTMIX}  LS: {CFG.LABEL_SMOOTHING}")
    print(f"  TTA (val)  : {CFG.USE_TTA_VAL}   TTA (final): {CFG.USE_TTA_FINAL}")
    print(f"  Self-distill: {CFG.DO_SELF_DISTILL} (pos≥{CFG.DISTILL_POS_THRESH}, neg≤{CFG.DISTILL_NEG_THRESH})")
    print(f"  CANDID-PTX : {CFG.USE_CANDID_PTX}")
    print("="*70)

    all_records = load_all_datasets()

    # ── Split ─────────────────────────────────────────────────────────────
    print("\n" + "="*70); print("TRAIN / VAL SPLIT (VinDr-only val)"); print("="*70)
    vindr_records = [r for r in all_records if r["dataset_id"] == "vindr"]
    other_records = [r for r in all_records if r["dataset_id"] != "vindr"]
    if not vindr_records: raise RuntimeError("No VinDr records!")
    vindr_labels = np.stack([r["labels"] for r in vindr_records])
    msss = MultilabelStratifiedShuffleSplit(n_splits=1, test_size=CFG.VAL_SPLIT,
                                            random_state=CFG.SEED)
    tri, vai = next(msss.split(np.zeros(len(vindr_records)), vindr_labels))
    vindr_train = [vindr_records[i] for i in tri]
    val_records = [vindr_records[i] for i in vai]
    train_records = vindr_train + other_records
    print(f"  Train: {len(train_records):,} (VinDr={len(vindr_train):,}, "
          f"others={len(other_records):,})")
    print(f"  Val (VinDr): {len(val_records):,}")

    # ── Loaders ───────────────────────────────────────────────────────────
    tds = MergedCXRDataset(train_records, get_transforms(True))
    vds = MergedCXRDataset(val_records, get_transforms(False))
    sampler = make_balanced_sampler(train_records)
    pw = CFG.NUM_WORKERS > 0
    tl = DataLoader(tds, batch_size=CFG.BATCH_SIZE, sampler=sampler,
                    num_workers=CFG.NUM_WORKERS, pin_memory=CFG.PIN_MEMORY,
                    persistent_workers=pw, drop_last=True,
                    prefetch_factor=6 if pw else None)
    vl = DataLoader(vds, batch_size=CFG.BATCH_SIZE*2, shuffle=False,
                    num_workers=CFG.NUM_WORKERS, pin_memory=CFG.PIN_MEMORY,
                    persistent_workers=pw)
    print(f"  Train batches: {len(tl)} | Val batches: {len(vl)}")

    steps_per_epoch = len(tl) // CFG.GRAD_ACCUM
    total_steps  = steps_per_epoch * CFG.NUM_EPOCHS
    warmup_steps = steps_per_epoch * CFG.WARMUP_EPOCHS

    # ── Pos weights ───────────────────────────────────────────────────────
    print("\n" + "="*70); print("LOSS — POS_WEIGHT COMPUTATION"); print("="*70)
    pos_weights = compute_pos_weights(train_records, cap=CFG.POS_WEIGHT_CAP).to(DEVICE)

    # ── Model ─────────────────────────────────────────────────────────────
    print("\n" + "="*70); print("MODEL"); print("="*70)
    model = build_model().to(DEVICE)
    print(f"  Params: {sum(p.numel() for p in model.parameters()):,}")
    print(f"  Trainable: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")
    with torch.no_grad():
        dummy = torch.randn(2, 3, CFG.IMAGE_SIZE, CFG.IMAGE_SIZE).to(DEVICE)
        out = model(dummy)
        print(f"  Forward sanity: input {dummy.shape} → output {out.shape}")
        assert out.shape == (2, CFG.NUM_CLASSES)
    del dummy, out

    ema = ModelEmaV2(model, decay=CFG.EMA_DECAY) if CFG.USE_EMA else None
    if ema is not None: print(f"  EMA enabled (decay={CFG.EMA_DECAY})")

    crit = MaskedAsymmetricLoss(
        gamma_neg=CFG.ASL_GAMMA_NEG, gamma_pos=CFG.ASL_GAMMA_POS,
        clip=CFG.ASL_CLIP, pos_weight=pos_weights
    ).to(DEVICE)
    opt = optim.AdamW(model.parameters(), lr=CFG.LR,
                      weight_decay=CFG.WEIGHT_DECAY, betas=CFG.BETAS)
    sched = cosine_sched(opt, warmup_steps, total_steps, CFG.MIN_LR / CFG.LR)
    scaler = GradScaler(AMP_DEVICE, enabled=USE_AMP)
    print(f"  AdamW lr={CFG.LR}, wd={CFG.WEIGHT_DECAY}")
    print(f"  Cosine warmup={warmup_steps}, total={total_steps}")

    # ── Resume ────────────────────────────────────────────────────────────
    print("\n" + "="*70); print("CHECKPOINT"); print("="*70)
    history = {"train_loss":[],"val_loss":[],"val_auc":[],"val_map":[],
               "auc_per_class":[],"ap_per_class":[],
               "ema_val_auc":[],"ema_val_map":[],"lr":[]}
    start_epoch, best_auc, es_counter = 1, 0.0, 0
    if CFG.RESUME_PATH == "auto":
        path = auto_find_checkpoint(CFG.CHECKPOINT_DIR)
    elif CFG.RESUME_PATH:
        path = Path(CFG.RESUME_PATH)
    else:
        path = None
    if path is not None and path.exists():
        start_epoch, history, best_auc, es_counter = load_checkpoint(
            path, model, ema, opt, sched, scaler)
    else:
        print("  No checkpoint — fresh training")

    # ── ROUND 1 ───────────────────────────────────────────────────────────
    print("\n" + "="*70); print("ROUND 1: MAIN TRAINING"); print("="*70)
    history, best_auc = run_training_loop(
        model, ema, opt, sched, scaler, crit, tl, vl,
        num_epochs=CFG.NUM_EPOCHS, start_epoch=start_epoch,
        history=history, best_auc=best_auc, es_counter=es_counter,
        save_path=CFG.SAVE_PATH, tag="ROUND1"
    )

    # ── Load best EMA weights ─────────────────────────────────────────────
    print("\n" + "="*70); print("LOAD BEST WEIGHTS"); print("="*70)
    if CFG.SAVE_PATH.exists():
        ckpt = torch.load(CFG.SAVE_PATH, map_location=DEVICE, weights_only=False)
        if ckpt.get("ema_state_dict") is not None:
            unwrap(model).load_state_dict(ckpt["ema_state_dict"])
            print(f"  ✓ Loaded EMA (ep{ckpt['epoch']}, AUC={ckpt['best_auc']:.4f})")
            torch.save({
                "model_state_dict": ckpt["ema_state_dict"],
                "epoch": ckpt["epoch"], "best_auc": ckpt["best_auc"],
                "config": ckpt["config"],
            }, CFG.EMA_SAVE_PATH)
            print(f"  💾 EMA-only weights → {CFG.EMA_SAVE_PATH.name}")
        else:
            unwrap(model).load_state_dict(ckpt["model_state_dict"])
            print(f"  ✓ Loaded raw (ep{ckpt['epoch']}, AUC={ckpt['best_auc']:.4f})")

    fm_r1 = validate(model, vl, crit, use_tta=CFG.USE_TTA_FINAL)
    print(f"\n  [Round 1] AUC={fm_r1['auc']:.4f}  mAP={fm_r1['map']:.4f}  "
          f"Sens@95Sp={fm_r1['sens_at_95spec']:.4f} (TTA={CFG.USE_TTA_FINAL})")
    auc_per_class_r1 = list(fm_r1["auc_per_class"])

    # ── ROUND 2: SELF-DISTILLATION ────────────────────────────────────────
    fm_r2 = None
    train_records_round2 = train_records
    if CFG.DO_SELF_DISTILL:
        print("\n" + "="*70); print("ROUND 2: SELF-DISTILLATION"); print("="*70)
        train_records_distilled = generate_pseudo_labels(
            model, train_records,
            batch_size=CFG.BATCH_SIZE * 2,
            pos_thresh=CFG.DISTILL_POS_THRESH,
            neg_thresh=CFG.DISTILL_NEG_THRESH,
            use_tta=CFG.USE_TTA_FINAL,
        )

        round1_state = {k: v.detach().cpu().clone()
                        for k, v in unwrap(model).state_dict().items()}
        round1_ema_state = None
        if ema is not None:
            round1_ema_state = {k: v.detach().cpu().clone()
                                for k, v in ema.module.state_dict().items()}

        print("\n  Recomputing pos_weights with distilled labels:")
        pos_weights_r2 = compute_pos_weights(train_records_distilled,
                                             cap=CFG.POS_WEIGHT_CAP).to(DEVICE)
        crit_r2 = MaskedAsymmetricLoss(
            gamma_neg=CFG.ASL_GAMMA_NEG, gamma_pos=CFG.ASL_GAMMA_POS,
            clip=CFG.ASL_CLIP, pos_weight=pos_weights_r2
        ).to(DEVICE)

        tds_r2 = MergedCXRDataset(train_records_distilled, get_transforms(True))
        sampler_r2 = make_balanced_sampler(train_records_distilled)
        tl_r2 = DataLoader(tds_r2, batch_size=CFG.BATCH_SIZE, sampler=sampler_r2,
                           num_workers=CFG.NUM_WORKERS, pin_memory=CFG.PIN_MEMORY,
                           persistent_workers=pw, drop_last=True,
                           prefetch_factor=6 if pw else None)
        print(f"  Round-2 train batches: {len(tl_r2)}")

        opt_r2 = optim.AdamW(model.parameters(), lr=CFG.DISTILL_LR,
                             weight_decay=CFG.WEIGHT_DECAY, betas=CFG.BETAS)
        steps_r2 = (len(tl_r2) // CFG.GRAD_ACCUM) * CFG.DISTILL_EPOCHS
        warmup_r2 = (len(tl_r2) // CFG.GRAD_ACCUM) * 1
        sched_r2 = cosine_sched(opt_r2, warmup_r2, steps_r2, CFG.MIN_LR / CFG.DISTILL_LR)
        scaler_r2 = GradScaler(AMP_DEVICE, enabled=USE_AMP)

        if ema is not None:
            ema = ModelEmaV2(model, decay=CFG.EMA_DECAY)

        history_r2 = {"train_loss":[],"val_loss":[],"val_auc":[],"val_map":[],
                      "auc_per_class":[],"ap_per_class":[],
                      "ema_val_auc":[],"ema_val_map":[],"lr":[]}

        history_r2, best_auc_r2 = run_training_loop(
            model, ema, opt_r2, sched_r2, scaler_r2, crit_r2, tl_r2, vl,
            num_epochs=CFG.DISTILL_EPOCHS, start_epoch=1,
            history=history_r2, best_auc=0.0, es_counter=0,
            save_path=CFG.DISTILL_SAVE_PATH, tag="ROUND2"
        )
        for k in history_r2:
            if k in history: history[k].extend(history_r2[k])

        if CFG.DISTILL_SAVE_PATH.exists():
            ckpt2 = torch.load(CFG.DISTILL_SAVE_PATH, map_location=DEVICE, weights_only=False)
            if ckpt2.get("ema_state_dict") is not None:
                unwrap(model).load_state_dict(ckpt2["ema_state_dict"])
                print(f"\n  ✓ Loaded Round-2 EMA (ep{ckpt2['epoch']}, AUC={ckpt2['best_auc']:.4f})")
            else:
                unwrap(model).load_state_dict(ckpt2["model_state_dict"])

        fm_r2 = validate(model, vl, crit, use_tta=CFG.USE_TTA_FINAL)
        print(f"\n  [Round 2] AUC={fm_r2['auc']:.4f}  mAP={fm_r2['map']:.4f}  "
              f"Sens@95Sp={fm_r2['sens_at_95spec']:.4f}")

        # Per-class revert check
        print("\n  Per-class delta (R2 − R1):")
        print(f"  {'Label':25s} {'R1 AUC':>8s} {'R2 AUC':>8s} {'Δ':>8s}")
        for i, lb in enumerate(CFG.UNIFIED_LABELS):
            a1 = auc_per_class_r1[i]
            a2 = fm_r2["auc_per_class"][i]
            if isinstance(a1, float) and np.isnan(a1): continue
            if isinstance(a2, float) and np.isnan(a2): continue
            delta = a2 - a1
            flag = ""
            if delta < -CFG.DISTILL_REVERT_DROP: flag = "  ⚠ DROP"
            elif delta > 0.005: flag = "  ↑"
            print(f"  {lb:25s} {a1:8.4f} {a2:8.4f} {delta:+8.4f}{flag}")

        if fm_r2["auc"] < fm_r1["auc"] - 0.002:
            print(f"\n  ⚠ Round 2 macro AUC dropped → REVERTING to Round 1")
            unwrap(model).load_state_dict({k: v.to(DEVICE) for k, v in round1_state.items()})
            if ema is not None and round1_ema_state is not None:
                ema.module.load_state_dict({k: v.to(DEVICE) for k, v in round1_ema_state.items()})
            train_records_round2 = train_records
            fm_final = fm_r1
        else:
            print(f"\n  ✓ Keeping Round 2 model")
            train_records_round2 = train_records_distilled
            fm_final = fm_r2
            torch.save({
                "model_state_dict": unwrap(model).state_dict(),
                "epoch": "round2_final",
                "best_auc": fm_r2["auc"],
                "config": {
                    "backbone_type": CFG.BACKBONE_TYPE,
                    "model_name": backbone_name,
                    "image_size": CFG.IMAGE_SIZE,
                    "num_classes": CFG.NUM_CLASSES,
                    "labels": CFG.UNIFIED_LABELS,
                },
            }, Path("/kaggle/working/best_model_final.pth"))
            print(f"  💾 Final inference weights → best_model_final.pth")
    else:
        fm_final = fm_r1

    # ── FINAL EVAL ────────────────────────────────────────────────────────
    print("\n" + "="*70); print("FINAL EVALUATION"); print("="*70)
    print(f"\n  Final Macro AUC : {fm_final['auc']:.4f}")
    print(f"  Final mAP       : {fm_final['map']:.4f}")
    print(f"  Final Sens@95Sp : {fm_final['sens_at_95spec']:.4f}")

    # ── THRESHOLD OPTIMIZATION ────────────────────────────────────────────
    print("\n" + "="*70); print("THRESHOLD OPTIMIZATION"); print("="*70)
    val_preds, val_targets, val_masks = collect_predictions(
        model, vl, use_tta=CFG.USE_TTA_FINAL)
    thr_results = optimize_thresholds(val_preds, val_targets, val_masks,
                                      CFG.UNIFIED_LABELS, search_steps=200)
    save_thresholds(thr_results, CFG.CHECKPOINT_SAVE_DIR)
    plot_threshold_analysis(thr_results,
                            CFG.CHECKPOINT_SAVE_DIR / "threshold_analysis.png")

    # ── CLINICAL METRICS REPORT ───────────────────────────────────────────
    print("\n" + "="*70); print("CLINICAL METRICS"); print("="*70)
    full_metrics = compute_metrics(val_preds, val_targets, val_masks)
    print_clinical_metrics_report(
        full_metrics, CFG.UNIFIED_LABELS,
        thresholds=thr_results['thresholds'],
        threshold_metrics=thr_results['metrics_at_threshold'],
        save_path=CFG.CHECKPOINT_SAVE_DIR / "full_metrics_report.csv"
    )

    # ── ROC + PR CURVES ───────────────────────────────────────────────────
    print("\n" + "="*70); print("ROC + PR CURVES"); print("="*70)
    plot_roc_pr_curves(val_preds, val_targets, val_masks, CFG.UNIFIED_LABELS,
                       save_path=CFG.CHECKPOINT_SAVE_DIR / "roc_pr_curves.png")

    # ── CONFUSION MATRICES ────────────────────────────────────────────────
    print("\n" + "="*70); print("CONFUSION MATRICES"); print("="*70)
    plot_confusion_matrices(val_preds, val_targets, val_masks, CFG.UNIFIED_LABELS,
                            thresholds=thr_results['thresholds'],
                            save_path=CFG.CHECKPOINT_SAVE_DIR / "confusion_matrices.png")

    # ── GRADCAM ───────────────────────────────────────────────────────────
    print("\n" + "="*70); print("GRADCAM"); print("="*70)
    try:
        visualize_gradcam_grid(model, val_records, n_samples=8, top_k=3,
                               save_path=CFG.CHECKPOINT_SAVE_DIR / "gradcam_grid.png")
    except Exception as e:
        print(f"  ⚠ GradCAM failed: {e}")

    # ── TRAINING-HISTORY PLOTS ────────────────────────────────────────────
    print("\n" + "="*70); print("TRAINING PLOTS"); print("="*70)
    plot_training_curves(history, CFG.CHECKPOINT_SAVE_DIR / "training_curves.png")
    plot_per_class_auc(history, CFG.UNIFIED_LABELS,
                       CFG.CHECKPOINT_SAVE_DIR / "per_class_auc.png")
    plot_lr_schedule(history, CFG.CHECKPOINT_SAVE_DIR / "lr_schedule.png")

    # ── SUMMARY ───────────────────────────────────────────────────────────
    elapsed = time.time() - t_total
    print(f"\n  Total: {elapsed/60:.1f}m ({elapsed/3600:.2f}h)")
    print(f"\n  Round 1: AUC={fm_r1['auc']:.4f}  mAP={fm_r1['map']:.4f}  "
          f"Sens@95Sp={fm_r1['sens_at_95spec']:.4f}")
    if fm_r2 is not None:
        print(f"  Round 2: AUC={fm_r2['auc']:.4f}  mAP={fm_r2['map']:.4f}  "
              f"Sens@95Sp={fm_r2['sens_at_95spec']:.4f}")
    print(f"  FINAL  : AUC={fm_final['auc']:.4f}  mAP={fm_final['map']:.4f}  "
          f"Sens@95Sp={fm_final['sens_at_95spec']:.4f}")

    print(f"\n  📁 Output files:")
    total_mb = 0
    for f in sorted(CFG.CHECKPOINT_SAVE_DIR.iterdir()):
        if f.is_file():
            mb = f.stat().st_size / 1e6
            total_mb += mb
            icon = '📦' if f.suffix == '.pth' else '📄'
            print(f"    {icon} {f.name:42s} {mb:8.1f} MB")
    print(f"\n  Total output: {total_mb:.0f} MB")

    return model, history, fm_final, thr_results, full_metrics


# =============================================================================
# Entry
# =============================================================================
if __name__ == "__main__":
    model, history, final_metrics, thr_results, full_metrics = main()
    print(f"\n✓ Done.")
    print(f"  AUC          = {final_metrics['auc']:.4f}")
    print(f"  mAP          = {final_metrics['map']:.4f}")
    print(f"  Macro F1 opt = {thr_results['macro_f1_optimized']:.4f}")
    print(f"  Sens@95%Spec = {final_metrics['sens_at_95spec']:.4f}")
    print(f"  Spec@95%Sens = {final_metrics['spec_at_95sens']:.4f}")
    print(f"  Miss rate    = {final_metrics['miss_rate_05']:.4f} (at thr=0.5)")

# === CELL 1 ===


