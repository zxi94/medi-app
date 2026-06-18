require("dotenv").config();

// Validate required environment variables immediately after env injection
require("./config/envValidation")();


process.on('unhandledRejection', (reason, promise) => {
  console.error('⚠️ Unhandled Rejection at:', promise, 'reason:', reason);
});
process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught Exception caught:', error);
});

const fs = require("fs");
const path = require("path");
const app = require("./app");
const { sequelize } = require("./models");

const port = Number(process.env.PORT || 5000);
const uploadDir = path.resolve(process.cwd(), process.env.UPLOAD_DIR || "uploads");
fs.mkdirSync(uploadDir, { recursive: true });
// eslint-disable-next-line no-console
console.log(`[DB] Using DB user: ${process.env.DB_USER}`);

const requiredEvoVars = ['EVO_API_URL', 'EVO_API_KEY', 'EVO_INSTANCE_NAME'];
for (const v of requiredEvoVars) {
  if (!process.env[v]) {
    throw new Error(`Startup Error: Missing required Evolution API environment variable ${v}`);
  }
}

async function ensureDatabaseSchema() {
  await sequelize.query(`
    BEGIN;

    -- 1. Users table
    CREATE TABLE IF NOT EXISTS "Users" (
      "id" SERIAL PRIMARY KEY,
      "email" VARCHAR(255) NOT NULL UNIQUE,
      "password" VARCHAR(255) NOT NULL,
      "phone" VARCHAR(40),
      "role" VARCHAR(255) NOT NULL DEFAULT 'PATIENT',
      "is_verified" BOOLEAN NOT NULL DEFAULT false,
      "verification_status" VARCHAR(30) NOT NULL DEFAULT 'pending',
      "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
      "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

    ALTER TABLE "Users" ALTER COLUMN "role" DROP DEFAULT;
    ALTER TABLE "Users" ALTER COLUMN "role" TYPE VARCHAR(20) USING UPPER("role"::text);
    ALTER TABLE "Users" ALTER COLUMN "role" SET DEFAULT 'PATIENT';
    ALTER TABLE "Users" DROP CONSTRAINT IF EXISTS users_role_check;
    UPDATE "Users" SET "role" = UPPER("role");

    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_role_check') THEN
        ALTER TABLE "Users" ADD CONSTRAINT users_role_check CHECK (role IN ('PATIENT', 'DOCTOR', 'ADMIN'));
      END IF;
    END $$;

    -- 2. Add user_id column if not exists
    ALTER TABLE IF EXISTS "Patients" ADD COLUMN IF NOT EXISTS "user_id" INTEGER;
    ALTER TABLE IF EXISTS "Doctors" ADD COLUMN IF NOT EXISTS "user_id" INTEGER;

    -- 3. Populate Users
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Patients' AND column_name = 'email'
      ) THEN
        INSERT INTO "Users" ("email", "password", "phone", "role", "is_verified", "verification_status")
        SELECT "email", "password", "phone", 'PATIENT', "is_verified", "verification_status"
        FROM "Patients"
        ON CONFLICT ("email") DO NOTHING;

        UPDATE "Patients" p
        SET "user_id" = u.id
        FROM "Users" u
        WHERE p.email = u.email AND p.user_id IS NULL;
      END IF;

      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'Doctors' AND column_name = 'email'
      ) THEN
        INSERT INTO "Users" ("email", "password", "phone", "role", "is_verified", "verification_status")
        SELECT "email", "password", "phone", 'DOCTOR', "is_verified", "verification_status"
        FROM "Doctors"
        ON CONFLICT ("email") DO NOTHING;

        UPDATE "Doctors" d
        SET "user_id" = u.id
        FROM "Users" u
        WHERE d.email = u.email AND d.user_id IS NULL;
      END IF;
    END $$;

    -- 5. Drop referencing constraints
    ALTER TABLE IF EXISTS "Chat_Threads" DROP CONSTRAINT IF EXISTS "Chat_Threads_patient_id_fkey";
    ALTER TABLE IF EXISTS "Diagnosis_Reports" DROP CONSTRAINT IF EXISTS "Diagnosis_Reports_patient_id_fkey";
    ALTER TABLE IF EXISTS "Xray_Images" DROP CONSTRAINT IF EXISTS "Xray_Images_patient_id_fkey";

    ALTER TABLE IF EXISTS "Chat_Threads" DROP CONSTRAINT IF EXISTS "Chat_Threads_doctor_id_fkey";
    ALTER TABLE IF EXISTS "Diagnosis_Reports" DROP CONSTRAINT IF EXISTS "Diagnosis_Reports_doctor_id_fkey";
    ALTER TABLE IF EXISTS "Xray_Images" DROP CONSTRAINT IF EXISTS "Xray_Images_doctor_id_fkey";

    -- 6. Modify Patients primary key
    DO $$
    BEGIN
      IF to_regclass('"Patients"') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Patients' AND column_name = 'id') THEN
          IF NOT EXISTS (SELECT 1 FROM "Patients" WHERE "user_id" IS NULL) THEN
            ALTER TABLE "Patients" DROP CONSTRAINT IF EXISTS "Patients_pkey" CASCADE;
            ALTER TABLE "Patients" DROP CONSTRAINT IF EXISTS "patients_pkey" CASCADE;
            ALTER TABLE "Patients" DROP COLUMN IF EXISTS "id";
            ALTER TABLE "Patients" ALTER COLUMN "user_id" SET NOT NULL;
            ALTER TABLE "Patients" ADD CONSTRAINT "Patients_pkey" PRIMARY KEY ("user_id");
          END IF;
        END IF;
      END IF;
    END $$;

    -- 7. Modify Doctors primary key
    DO $$
    BEGIN
      IF to_regclass('"Doctors"') IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Doctors' AND column_name = 'id') THEN
          IF NOT EXISTS (SELECT 1 FROM "Doctors" WHERE "user_id" IS NULL) THEN
            ALTER TABLE "Doctors" DROP CONSTRAINT IF EXISTS "Doctors_pkey" CASCADE;
            ALTER TABLE "Doctors" DROP CONSTRAINT IF EXISTS "doctors_pkey" CASCADE;
            ALTER TABLE "Doctors" DROP COLUMN IF EXISTS "id";
            ALTER TABLE "Doctors" ALTER COLUMN "user_id" SET NOT NULL;
            ALTER TABLE "Doctors" ADD CONSTRAINT "Doctors_pkey" PRIMARY KEY ("user_id");
          END IF;
        END IF;
      END IF;
    END $$;

    -- 8. Add user_id foreign keys to Users
    ALTER TABLE IF EXISTS "Patients" DROP CONSTRAINT IF EXISTS "patients_user_id_users_id_fk";
    ALTER TABLE IF EXISTS "Patients" ADD CONSTRAINT "patients_user_id_users_id_fk" FOREIGN KEY (user_id) REFERENCES "Users"(id) ON UPDATE CASCADE ON DELETE CASCADE;

    ALTER TABLE IF EXISTS "Doctors" DROP CONSTRAINT IF EXISTS "doctors_user_id_users_id_fk";
    ALTER TABLE IF EXISTS "Doctors" ADD CONSTRAINT "doctors_user_id_users_id_fk" FOREIGN KEY (user_id) REFERENCES "Users"(id) ON UPDATE CASCADE ON DELETE CASCADE;

    -- 9. Recreate referencing constraints
    ALTER TABLE IF EXISTS "Chat_Threads" ADD CONSTRAINT "Chat_Threads_patient_id_fkey" FOREIGN KEY (patient_id) REFERENCES "Patients"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
    ALTER TABLE IF EXISTS "Diagnosis_Reports" ADD CONSTRAINT "Diagnosis_Reports_patient_id_fkey" FOREIGN KEY (patient_id) REFERENCES "Patients"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
    ALTER TABLE IF EXISTS "Xray_Images" ADD CONSTRAINT "Xray_Images_patient_id_fkey" FOREIGN KEY (patient_id) REFERENCES "Patients"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;

    ALTER TABLE IF EXISTS "Chat_Threads" ADD CONSTRAINT "Chat_Threads_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES "Doctors"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
    ALTER TABLE IF EXISTS "Diagnosis_Reports" ADD CONSTRAINT "Diagnosis_Reports_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES "Doctors"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
    ALTER TABLE IF EXISTS "Xray_Images" ADD CONSTRAINT "Xray_Images_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES "Doctors"(user_id) ON UPDATE CASCADE ON DELETE CASCADE;

    -- 10. Drop duplicate columns
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "email";
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "password";
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "role";
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "phone";
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "is_verified";
    ALTER TABLE IF EXISTS "Patients" DROP COLUMN IF EXISTS "verification_status";

    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "email";
    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "password";
    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "role";
    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "phone";
    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "is_verified";
    ALTER TABLE IF EXISTS "Doctors" DROP COLUMN IF EXISTS "verification_status";

    -- 11. Add approval_status to Doctors
    ALTER TABLE IF EXISTS "Doctors" ADD COLUMN IF NOT EXISTS "approval_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING';
    DO $$
    BEGIN
      IF to_regclass('"Doctors"') IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'doctors_approval_status_check') THEN
        ALTER TABLE "Doctors" ADD CONSTRAINT doctors_approval_status_check CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED'));
      END IF;
    END $$;

    -- 12. Contacts table
    CREATE TABLE IF NOT EXISTS "Contacts" (
      "id" SERIAL PRIMARY KEY,
      "doctor_id" INTEGER NOT NULL REFERENCES "Doctors"("user_id") ON UPDATE CASCADE ON DELETE CASCADE,
      "patient_id" INTEGER NOT NULL REFERENCES "Patients"("user_id") ON UPDATE CASCADE ON DELETE CASCADE,
      "status" VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION',
      "otp_code" VARCHAR(10),
      "otp_expires_at" TIMESTAMP WITH TIME ZONE,
      "otp_used" BOOLEAN DEFAULT false,
      "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
      "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
      UNIQUE ("doctor_id", "patient_id")
    );
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contacts_status_check') THEN
        ALTER TABLE "Contacts" ADD CONSTRAINT contacts_status_check CHECK (status IN ('PENDING_VERIFICATION', 'ACTIVE'));
      END IF;
    END $$;

    -- Ensure OTP columns exist if table was already created
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Contacts' AND column_name = 'otp_code') THEN
        ALTER TABLE "Contacts" ADD COLUMN "otp_code" VARCHAR(10);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Contacts' AND column_name = 'otp_expires_at') THEN
        ALTER TABLE "Contacts" ADD COLUMN "otp_expires_at" TIMESTAMP WITH TIME ZONE;
      END IF;
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Contacts' AND column_name = 'otp_used') THEN
        ALTER TABLE "Contacts" ADD COLUMN "otp_used" BOOLEAN DEFAULT false;
      END IF;
    END $$;

    -- Add language to Users
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Users' AND column_name = 'language') THEN
        ALTER TABLE "Users" ADD COLUMN "language" VARCHAR(10) DEFAULT 'en';
      END IF;
    END $$;

    -- Add ai_report to Result_Images
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'Result_Images' AND column_name = 'ai_report') THEN
        ALTER TABLE "Result_Images" ADD COLUMN "ai_report" JSONB;
      END IF;
    END $$;

    -- 13. PendingInvitations table (OTPs sent to phones not yet registered)
    CREATE TABLE IF NOT EXISTS "PendingInvitations" (
      "id" SERIAL PRIMARY KEY,
      "phone" VARCHAR(40) NOT NULL,
      "doctor_id" INTEGER NOT NULL REFERENCES "Doctors"("user_id") ON UPDATE CASCADE ON DELETE CASCADE,
      "otp_code" VARCHAR(10) NOT NULL,
      "otp_expires_at" TIMESTAMP WITH TIME ZONE NOT NULL,
      "used" BOOLEAN NOT NULL DEFAULT false,
      "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS pending_invitations_phone_idx ON "PendingInvitations" ("phone");

    COMMIT;
  `);

  // eslint-disable-next-line no-console
  console.log("[DB] Relational database logic and administrative structure successfully verified/migrated.");
  console.log("[DB] AFTER QUERY COMPLETED");
}

process.on('unhandledRejection', (reason, promise) => {
  console.error('⚠️ Unhandled Rejection at:', promise, 'reason:', reason);
});
process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught Exception caught:', error);
});

async function start() {
  try {
    await sequelize.authenticate();
    const [[databaseInfo]] = await sequelize.query(
      "SELECT current_database() AS database, current_schema() AS schema, current_user AS user"
    );
    // eslint-disable-next-line no-console
    console.log(
      `[DB] Connected to ${databaseInfo.user}@${databaseInfo.database}, schema ${databaseInfo.schema}`
    );
    await ensureDatabaseSchema();
    await sequelize.sync();
    
    // Run bootstrapping for admin account
    const bootstrap = require("./config/bootstrap");
    await bootstrap();

    const server = app.listen(port, () => {
      // eslint-disable-next-line no-console
      console.log(`Backend running on :${port}`);
    });

    server.on('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        console.error(`❌ Port ${port} is already in use.`);
      } else {
        console.error('❌ Server error:', error);
      }
      process.exit(1);
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("❌ [Database] Connection failed during bootstrap:", error.name, error.message);
    console.error("STACK TRACE:", error.stack);
    // Allow fallback or log clearly instead of an untracked crash
  }
}

start();
