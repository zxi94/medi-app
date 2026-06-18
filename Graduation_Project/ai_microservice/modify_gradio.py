import sys
from pathlib import Path

path = 'gradio_deploy_code.py'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add timm to imports
content = content.replace('import albumentations as A', 'import timm\nimport albumentations as A')

# 2. Add Gatekeeper Model and Loading
gatekeeper_code = '''
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

'''
content = content.replace('# =============================================================================\n# Model\n# =============================================================================', gatekeeper_code + '# =============================================================================\n# Model\n# =============================================================================')

# 3. Modify predict to take language and gatekeeper
old_predict = '''@torch.no_grad()
def predict(image_input):
    if image_input is None:
        return (None, "### 👋 Upload an X-ray to begin.", None, None, "")

    t0 = time.time()
    img_array = load_image(image_input)'''

new_predict = '''@torch.no_grad()
def predict(image_input, lang):
    is_ar = lang == 'العربية'
    if image_input is None:
        msg = "### 👋 قم برفع صورة أشعة للبدء." if is_ar else "### 👋 Upload an X-ray to begin."
        return (None, msg, None, None, "")

    t0 = time.time()
    img_array = load_image(image_input)
    
    valid_xray, prob_xray = is_valid_xray(img_array)
    if not valid_xray:
        msg = f"### ❌ خطأ: الصورة المرفوعة لا تبدو كأشعة سينية للصدر (نسبة الثقة {prob_xray:.1%}).\\nيُرجى رفع صورة أشعة صحيحة." if is_ar else f"### ❌ Error: The uploaded image does not appear to be a chest X-ray (confidence {prob_xray:.1%}).\\nPlease upload a valid chest X-ray."
        return (None, msg, None, None, "")
'''
content = content.replace(old_predict, new_predict)

# 4. Modify predict string outputs for Arabic
content = content.replace('lines = [f"### 🔍 Detected Findings ({len(positives)})\\n"]', 'lines = [f"### 🔍 النتائج المكتشفة ({len(positives)})\\n"] if is_ar else [f"### 🔍 Detected Findings ({len(positives)})\\n"]')

content = content.replace('''        for p in positives:
            margin = (p["prob"] - p["thr"]) * 100
            lines.append(
                f"**{p['severity']} &nbsp; {p['label']}** &nbsp;&nbsp; "
                f"`{p['prob']:.1%}` (thr: `{p['thr']:.1%}`, +{margin:.1f}pp)<br>"
                f"<span style='opacity:0.7;font-size:0.9em'>{p['info']}</span>\\n"
            )''', '''        for p in positives:
            margin = (p["prob"] - p["thr"]) * 100
            lbl = AR_LABELS.get(p['label'], p['label']) if is_ar else p['label']
            sev = AR_SEVERITY.get(p['severity'], p['severity']) if is_ar else p['severity']
            info = "" if is_ar else f"<span style='opacity:0.7;font-size:0.9em'>{p['info']}</span>\\n"
            lines.append(
                f"**{sev} &nbsp; {lbl}** &nbsp;&nbsp; "
                f"`{p['prob']:.1%}` (thr: `{p['thr']:.1%}`, +{margin:.1f}pp)<br>{info}"
            )''')

content = content.replace('''    else:
        top_idx = int(np.argmax(probs))
        report_md = (
            "### ✅ No abnormalities detected\\n\\n"
            f"Highest score: **{UNIFIED_LABELS[top_idx]}** at `{probs[top_idx]:.1%}` "
            f"(threshold: `{THRESHOLDS[top_idx]:.1%}`)<br><br>"
            "<span style='opacity:0.7'>Clinical correlation required.</span>"
        )''', '''    else:
        top_idx = int(np.argmax(probs))
        if is_ar:
            lbl = AR_LABELS.get(UNIFIED_LABELS[top_idx], UNIFIED_LABELS[top_idx])
            report_md = (
                "### ✅ لا توجد تشوهات ملحوظة\\n\\n"
                f"أعلى نسبة: **{lbl}** بنسبة `{probs[top_idx]:.1%}` "
                f"(الحد الأدنى: `{THRESHOLDS[top_idx]:.1%}`)<br><br>"
                "<span style='opacity:0.7'>يتطلب الارتباط السريري.</span>"
            )
        else:
            report_md = (
                "### ✅ No abnormalities detected\\n\\n"
                f"Highest score: **{UNIFIED_LABELS[top_idx]}** at `{probs[top_idx]:.1%}` "
                f"(threshold: `{THRESHOLDS[top_idx]:.1%}`)<br><br>"
                "<span style='opacity:0.7'>Clinical correlation required.</span>"
            )''')

content = content.replace('''    for i, lb in enumerate(UNIFIED_LABELS):
        flag = "🟢 POSITIVE" if probs[i] >= THRESHOLDS[i] else "⚪ negative"
        sev_icon = SEVERITY.get(lb, "⚪").split(" ")[0]
        table_rows.append([sev_icon, lb, f"{probs[i]:.1%}",
                           f"{THRESHOLDS[i]:.1%}", flag])''', '''    for i, lb in enumerate(UNIFIED_LABELS):
        flag = "🟢 POSITIVE" if probs[i] >= THRESHOLDS[i] else "⚪ negative"
        if is_ar: flag = "🟢 إيجابي" if probs[i] >= THRESHOLDS[i] else "⚪ سلبي"
        lbl = AR_LABELS.get(lb, lb) if is_ar else lb
        sev_icon = SEVERITY.get(lb, "⚪").split(" ")[0]
        table_rows.append([sev_icon, lbl, f"{probs[i]:.1%}",
                           f"{THRESHOLDS[i]:.1%}", flag])''')

content = content.replace('''def build_probability_chart(probs, thresholds, labels):''', '''def build_probability_chart(probs, thresholds, labels, is_ar=False):''')
content = content.replace('''    fig = build_probability_chart(probs, THRESHOLDS, UNIFIED_LABELS)''', '''    fig = build_probability_chart(probs, THRESHOLDS, UNIFIED_LABELS, is_ar)''')

content = content.replace('''    ax.set_xlabel("Probability", color="#9ca3af", fontsize=10)
    ax.set_title("Per-Class Predictions  (red lines = thresholds)",
                 color="#e5e7eb", fontsize=11, pad=12)''', '''    ax.set_xlabel("الاحتمالية" if is_ar else "Probability", color="#9ca3af", fontsize=10)
    title = "التوقعات لكل فئة (الخط الأحمر = الحد الأدنى)" if is_ar else "Per-Class Predictions  (red lines = thresholds)"
    ax.set_title(title, color="#e5e7eb", fontsize=11, pad=12)''')
content = content.replace('''sl = [labels[i] for i in order]''', '''sl = [AR_LABELS.get(labels[i], labels[i]) if is_ar else labels[i] for i in order]''')


# 5. UI layout changes
content = content.replace('''            image_input = gr.Image(
                type="pil", label="X-Ray Image", height=420,
                sources=["upload", "clipboard"],
            )''', '''            image_input = gr.Image(
                type="pil", label="X-Ray Image", height=420,
                sources=["upload", "clipboard"],
            )
            language_input = gr.Radio(["English", "العربية"], value="English", label="Language / اللغة")''')

content = content.replace('''    analyze_btn.click(
        fn=predict, inputs=image_input,
        outputs=[label_output, report_output, table_output, chart_output, info_output],
    )''', '''    analyze_btn.click(
        fn=predict, inputs=[image_input, language_input],
        outputs=[label_output, report_output, table_output, chart_output, info_output],
    )''')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
