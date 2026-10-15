-- ---------------------------------------------------------------------------
-- Phase 5.3 (expand) — PartnerSpecialty and PartnerInsurance.
--
-- Partner-local settings over catalog entries, keyed by the catalog code
-- (no FK: the catalog lives in another database). Plan §6.3/§6.4, D5, D23, D26.
--
--   PartnerSpecialty : which specialties this partner offers + its prices
--                      (moved out of Specialty, V017).
--   PartnerInsurance : which insurers this partner accepts + optional coverage
--                      override (NULL = use the catalog default).
--
-- Purely additive: Specialty.PriceInPerson/PriceVirtual/IsActive and
-- Insurance.CoveragePercentage/IsActive stay authoritative until Phase 6/9.
-- Backfill covers EVERY existing row (inactive ones as IsEnabled = FALSE) so
-- no price or override is lost.
-- ---------------------------------------------------------------------------

CREATE TABLE "PartnerSpecialty" (
    "SpecialtyCode" UUID          PRIMARY KEY,
    "IsEnabled"     BOOLEAN       NOT NULL DEFAULT FALSE,
    "PriceInPerson" NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK ("PriceInPerson" >= 0),
    "PriceVirtual"  NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK ("PriceVirtual" >= 0),
    "UpdatedAt"     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    "UpdatedBy"     INTEGER       REFERENCES "User" ("UserId"),
    -- Existing rule (V017): a specialty can only be offered with real prices.
    CONSTRAINT ck_partner_specialty_enabled_priced
        CHECK (NOT "IsEnabled" OR ("PriceInPerson" > 0 AND "PriceVirtual" > 0))
);

CREATE TABLE "PartnerInsurance" (
    "InsuranceCode"              UUID         PRIMARY KEY,
    "IsEnabled"                  BOOLEAN      NOT NULL DEFAULT FALSE,
    "CoveragePercentageOverride" NUMERIC(5,2) CHECK ("CoveragePercentageOverride" BETWEEN 0 AND 100),
    "UpdatedAt"                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "UpdatedBy"                  INTEGER      REFERENCES "User" ("UserId")
);

-- audit_row_change() derives RecordKey from "<Table>Code" or "<Table>Id". These
-- tables are keyed by the catalog code under another name, so fall back to the
-- first "...Code" column of the row. Otherwise identical to V019.
CREATE OR REPLACE FUNCTION audit_row_change() RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_old      JSONB;
    v_new      JSONB;
    v_row      JSONB;
    v_changed  TEXT[];
    v_excluded TEXT[] := COALESCE(TG_ARGV, ARRAY[]::TEXT[]);
    v_user_id  INTEGER;
    v_user_code UUID;
    v_ip       INET;
    v_id_text  TEXT;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_old := to_jsonb(OLD) - v_excluded;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_new := to_jsonb(NEW) - v_excluded;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(array_agg(n.key ORDER BY n.key), ARRAY[]::TEXT[])
          INTO v_changed
          FROM jsonb_each(v_new) n
         WHERE v_old -> n.key IS DISTINCT FROM n.value;

        IF cardinality(v_changed) = 0 THEN
            RETURN NULL;   -- no-op (or only excluded columns changed)
        END IF;
    END IF;

    v_row := CASE WHEN TG_OP = 'DELETE' THEN v_old ELSE v_new END;

    -- Actor: app.user_code is a User.UserCode UUID; unknown/invalid => NULL.
    BEGIN
        v_user_code := NULLIF(current_setting('app.user_code', true), '')::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
        v_user_code := NULL;
    END;
    IF v_user_code IS NOT NULL THEN
        SELECT "UserId" INTO v_user_id FROM "User" WHERE "UserCode" = v_user_code;
    END IF;

    BEGIN
        v_ip := NULLIF(current_setting('app.ip', true), '')::INET;
    EXCEPTION WHEN invalid_text_representation THEN
        v_ip := NULL;
    END;

    v_id_text := v_row ->> (TG_TABLE_NAME || 'Id');

    INSERT INTO "AuditLog" (
        "TableName", "RecordId", "RecordKey", "Action",
        "OldValues", "NewValues", "ChangedColumns",
        "UserId", "IpAddress", "RequestId"
    )
    VALUES (
        TG_TABLE_NAME,
        v_id_text::INTEGER,
        COALESCE(
            v_row ->> (TG_TABLE_NAME || 'Code'),
            v_id_text,
            (SELECT e.value FROM jsonb_each_text(v_row) e
              WHERE e.key LIKE '%Code' ORDER BY e.key LIMIT 1)),
        TG_OP,
        v_old,
        v_new,
        v_changed,
        v_user_id,
        v_ip,
        NULLIF(current_setting('app.request_id', true), '')
    );

    RETURN NULL;
END;
$$;

-- Backfill from the local catalog tables. A specialty is enabled only if it is
-- active AND priced (V017 rule); an active-but-unpriced one stays disabled
-- rather than violating the constraint.
INSERT INTO "PartnerSpecialty" ("SpecialtyCode", "IsEnabled", "PriceInPerson", "PriceVirtual")
SELECT "SpecialtyCode",
       "IsActive" AND "PriceInPerson" > 0 AND "PriceVirtual" > 0,
       "PriceInPerson", "PriceVirtual"
  FROM "Specialty";

INSERT INTO "PartnerInsurance" ("InsuranceCode", "IsEnabled", "CoveragePercentageOverride")
SELECT "InsuranceCode", "IsActive", "CoveragePercentage"
  FROM "Insurance";

-- Attached after the backfill so the schema change doesn't write actor-less
-- AuditLog rows.
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PartnerSpecialty"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON "PartnerInsurance"
    FOR EACH ROW EXECUTE FUNCTION audit_row_change();
