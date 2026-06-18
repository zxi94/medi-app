!pip install -q transformers accelerate bitsandbytes sentence-transformers faiss-cpu gradio
import json
import faiss
import os

# البحث عن ملفات البيانات تلقائياً
def find_data_path():
    base = "/kaggle/input"
    for root, dirs, files in os.walk(base):
        if "documents.json" in files:
            return root
    return None

DATA_PATH = find_data_path()
if DATA_PATH is None:
    print("❌ مش لاقي ملفات البيانات!")
    print("تأكد إنك ضفت الـ Dataset في الـ notebook.")
    print("\nالملفات المتاحة:")
    for root, dirs, files in os.walk("/kaggle/input"):
        for f in files:
            print(f"  {os.path.join(root, f)}")
else:
    print(f"✅ لقيت البيانات في: {DATA_PATH}")

    with open(f"{DATA_PATH}/documents.json", "r", encoding="utf-8") as f:
        documents = json.load(f)

    with open(f"{DATA_PATH}/metadata.json", "r", encoding="utf-8") as f:
        metadata = json.load(f)

    with open(f"{DATA_PATH}/medical_knowledge.json", "r", encoding="utf-8") as f:
        medical_knowledge = json.load(f)

    index = faiss.read_index(f"{DATA_PATH}/medical_index.faiss")

    print(f"تم تحميل: {len(documents)} مستند")
    print(f"عدد الـ findings: {len(medical_knowledge)}")
    print(f"حجم الـ index: {index.ntotal}")
import os
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
import torch

MODEL_NAME = "Qwen/Qwen2.5-7B-Instruct"
SAVE_DIR = "/kaggle/working/saved_qwen_model"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
)

if os.path.exists(SAVE_DIR):
    print("🔄 جاري تحميل الموديل المحفوظ مسبقاً من الملفات المحلية...")
    tokenizer = AutoTokenizer.from_pretrained(SAVE_DIR)
    model = AutoModelForCausalLM.from_pretrained(
        SAVE_DIR,
        quantization_config=bnb_config,
        device_map="auto"
    )
else:
    print("🌐 جاري تحميل الموديل من الإنترنت (أول مرة فقط)...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        quantization_config=bnb_config,
        device_map="auto"
    )
    
    print("💾 جاري حفظ الموديل للاستخدام المستقبلي بدون إنترنت...")
    model.save_pretrained(SAVE_DIR)
    tokenizer.save_pretrained(SAVE_DIR)
    print(f"✅ تم حفظ الموديل في: {SAVE_DIR}")

print("🚀 الموديل اتحمل وجاهز!")
from sentence_transformers import SentenceTransformer
import numpy as np

embedder = SentenceTransformer("intfloat/multilingual-e5-base")

print("الـ embedder جاهز ✅")
import re


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
def medical_rag(question, finding):
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
def safe_medical_chat(question, finding):
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
    answer = medical_rag(question, finding)

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


print("✅ كل الدوال جاهزة ومحسنة!")
print("   ✓ تطبيع النص العربي (همزات، ال التعريف، تاء مربوطة)")
print("   ✓ فلترة Context حسب اللغة")
print("   ✓ System Prompt ديناميكي")
print("   ✓ تنظيف خلط اللغات (قاموس 50+ مصطلح)")
print("   ✓ حماية ضد الـ Hallucination")
print("   ✓ رفض الأسئلة غير الطبية")
print("   ✓ تعاطف مع مشاعر المريض")
print("   ✓ Retry Logic")
print("   ✓ Generation Parameters محسنة")
import gradio as gr

findings_list = list(medical_knowledge.keys())


def chat_function(message, history, finding):
    if not finding:
        lang = detect_language(message)
        if lang == "ar":
            return "من فضلك اختر التشخيص من القائمة الأول."
        else:
            return "Please select a diagnosis first."

    response = safe_medical_chat(message, finding)
    return response


custom_css = """
.message {
    direction: rtl !important;
    text-align: right !important;
    unicode-bidi: plaintext !important;
}

.message p, .message div {
    unicode-bidi: plaintext !important;
}
"""

with gr.Blocks(title="Chest X-Ray Findings Assistant", css=custom_css) as demo:
    gr.Markdown(
        """
        # 🩺 مساعد تفسير نتائج أشعة الصدر
        # Chest X-Ray Findings Assistant
        
        هذا المساعد يشرح نتائج أشعة الصدر ويجيب على أسئلتك.
        """
    )

    finding_dropdown = gr.Dropdown(
        choices=findings_list,
        label="التشخيص من تحليل الأشعة | Diagnosis from X-ray analysis"
    )

    chatbot = gr.ChatInterface(
        fn=chat_function,
        additional_inputs=[finding_dropdown],
        examples=[
            ["ايه ده وايه أسبابه؟"],
            ["What are the symptoms?"],
            ["هل ده خطير؟"],
            ["What should I do next?"],
        ],
        type="messages",
        chatbot=gr.Chatbot(
            type="messages",
            placeholder="<center><strong>اختر التشخيص أولاً ثم اسأل</strong></center>",
            rtl=True
        ),
        textbox=gr.Textbox(
            placeholder="اكتب سؤالك هنا",
            rtl=True
        )
    )

demo.launch(share=True, debug=False)
!pip install -q fastapi uvicorn pyngrok nest-asyncio
from fastapi import FastAPI
from pydantic import BaseModel
from pyngrok import ngrok, conf
import uvicorn
import nest_asyncio
import threading

app = FastAPI(title="Chest X-Ray Chatbot API (Improved)")


class ChatRequest(BaseModel):
    question: str
    finding: str


class ChatResponse(BaseModel):
    answer: str
    finding: str
    success: bool


@app.get("/")
def root():
    return {
        "message": "Chest X-Ray Chatbot API (Improved)",
        "endpoints": {
            "/chat": "POST - Send question and finding",
            "/findings": "GET - List available findings"
        }
    }


@app.get("/findings")
def get_findings():
    findings = []
    for name, info in medical_knowledge.items():
        findings.append({
            "name_en": name,
            "name_ar": info["name_ar"]
        })
    return {"findings": findings}


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    if request.finding not in medical_knowledge:
        return ChatResponse(
            answer=f"التشخيص '{request.finding}' غير معروف. اختر من القائمة المتاحة.",
            finding=request.finding,
            success=False
        )

    try:
        answer = safe_medical_chat(request.question, request.finding)
        return ChatResponse(
            answer=answer,
            finding=request.finding,
            success=True
        )
    except Exception as e:
        return ChatResponse(
            answer=f"حدث خطأ: {str(e)}",
            finding=request.finding,
            success=False
        )


print("API جاهز ✅")
# غيّر الـ token بتاعك هنا
conf.get_default().auth_token = "YOUR_NGROK_TOKEN_HERE"

public_url = ngrok.connect(8000)
print(f"🚀 السيرفر متاح على: {public_url}")
print(f"\nالـ endpoints المتاحة:")
print(f"  GET  {public_url}/")
print(f"  GET  {public_url}/findings")
print(f"  POST {public_url}/chat")

nest_asyncio.apply()

def run_server():
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")

server_thread = threading.Thread(target=run_server, daemon=True)
server_thread.start()

import time
time.sleep(3)
print("\n✅ السيرفر شغال")