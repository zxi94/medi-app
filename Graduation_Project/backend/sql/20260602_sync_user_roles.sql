BEGIN;

CREATE TABLE IF NOT EXISTS "Users" (
  "id" SERIAL PRIMARY KEY,
  "email" VARCHAR(255) NOT NULL UNIQUE,
  "password" VARCHAR(255) NOT NULL,
  "phone" VARCHAR(40),
  "role" VARCHAR(20) NOT NULL DEFAULT 'PATIENT',
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
ALTER TABLE "Users"
  ADD CONSTRAINT users_role_check CHECK ("role" IN ('PATIENT', 'DOCTOR', 'ADMIN'));

ALTER TABLE IF EXISTS "Doctors"
  ADD COLUMN IF NOT EXISTS "approval_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING';

ALTER TABLE IF EXISTS "Doctors" DROP CONSTRAINT IF EXISTS doctors_approval_status_check;
ALTER TABLE IF EXISTS "Doctors"
  ADD CONSTRAINT doctors_approval_status_check
  CHECK ("approval_status" IN ('PENDING', 'APPROVED', 'REJECTED'));

ALTER TABLE IF EXISTS "Patients" ADD COLUMN IF NOT EXISTS "user_id" INTEGER;
ALTER TABLE IF EXISTS "Doctors" ADD COLUMN IF NOT EXISTS "user_id" INTEGER;

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
    SET "user_id" = u."id"
    FROM "Users" u
    WHERE p."email" = u."email" AND p."user_id" IS NULL;
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
    SET "user_id" = u."id"
    FROM "Users" u
    WHERE d."email" = u."email" AND d."user_id" IS NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('"Patients"') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM "Patients" WHERE "user_id" IS NULL)
       AND EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'Patients' AND column_name = 'id'
       ) THEN
      ALTER TABLE "Patients" DROP CONSTRAINT IF EXISTS "Patients_pkey";
      ALTER TABLE "Patients" DROP CONSTRAINT IF EXISTS "patients_pkey";
      ALTER TABLE "Patients" DROP COLUMN "id";
      ALTER TABLE "Patients" ALTER COLUMN "user_id" SET NOT NULL;
      ALTER TABLE "Patients" ADD CONSTRAINT "Patients_pkey" PRIMARY KEY ("user_id");
    END IF;
  END IF;

  IF to_regclass('"Doctors"') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM "Doctors" WHERE "user_id" IS NULL)
       AND EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_name = 'Doctors' AND column_name = 'id'
       ) THEN
      ALTER TABLE "Doctors" DROP CONSTRAINT IF EXISTS "Doctors_pkey";
      ALTER TABLE "Doctors" DROP CONSTRAINT IF EXISTS "doctors_pkey";
      ALTER TABLE "Doctors" DROP COLUMN "id";
      ALTER TABLE "Doctors" ALTER COLUMN "user_id" SET NOT NULL;
      ALTER TABLE "Doctors" ADD CONSTRAINT "Doctors_pkey" PRIMARY KEY ("user_id");
    END IF;
  END IF;
END $$;

ALTER TABLE IF EXISTS "Patients" DROP CONSTRAINT IF EXISTS patients_user_id_users_id_fk;
ALTER TABLE IF EXISTS "Patients"
  ADD CONSTRAINT patients_user_id_users_id_fk
  FOREIGN KEY ("user_id") REFERENCES "Users"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE IF EXISTS "Doctors" DROP CONSTRAINT IF EXISTS doctors_user_id_users_id_fk;
ALTER TABLE IF EXISTS "Doctors"
  ADD CONSTRAINT doctors_user_id_users_id_fk
  FOREIGN KEY ("user_id") REFERENCES "Users"("id")
  ON UPDATE CASCADE ON DELETE CASCADE;

COMMIT;
