# MediScan AI — Intelligent Chest X-Ray Diagnosis & Patient Care Platform 🩻🤖

MediScan AI is a full-stack, enterprise-grade medical imaging and secure consultation platform built to streamline the diagnostic workflow for radiologists and patients. The system combines deep-learning computer vision diagnostics with a secure backend architecture and an interactive mobile environment featuring full cross-language (English/Arabic) support and automated WhatsApp OTP verification.

## 🚀 Key Features

- **Automated X-Ray AI Diagnostics:** Direct DICOM/Image upload and analysis processing pipeline for immediate clinical identification.
- **E.164 Seamless Onboarding:** Automated 6-digit Doctor-Patient handshake connection secured via the **Evolution API** delivering high-priority WhatsApp OTP triggers.
- **Dynamic In-App Localization:** Fully integrated English/Arabic interfaces with responsive RTL/LTR structural flipping and LTR forced numerical input fields.
- **Polymorphic Care Chat System:** Secure real-time consultation messaging interface utilizing state-driven conversation persistence across user views.
- **Robust Database Management:** Relational data mapping backed by **PostgreSQL** and managed fluidly through **Prisma ORM**.

## 🛠️ Tech Stack

- **Frontend:** Flutter (Dart), Provider State Management, SharedPreferences.
- **Backend:** Node.js, Express.js, Prisma ORM.
- **Database:** PostgreSQL.
- **Integrations:** Evolution API (WhatsApp Gateway Wrapper).

---

## 📦 Installation & Setup

### 1. Backend Configuration
Navigate to the backend directory, install packages, and initialize your database migrations:

```bash
cd backend
npm install
npx prisma migrate dev 