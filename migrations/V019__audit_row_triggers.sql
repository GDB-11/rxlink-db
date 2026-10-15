-- =============================================================================
-- V019: Row-level audit triggers (Phase 2.2)
--
-- audit_row_change() writes one AuditLog row per INSERT/UPDATE/DELETE on the
-- audited tables. The actor comes from the transaction-local settings the API
-- stamps via BaseDatabaseService (app.user_code / app.ip / app.request_id).
-- Writes without that context are logged with "UserId" = NULL, which is the
-- signal for a write path that missed the audited-write helper (Phase 2.4).
--
-- Trigger arguments (TG_ARGV) = columns to exclude from OldValues/NewValues
-- (secrets and high-churn columns). An UPDATE that changes only excluded
-- columns, or nothing at all, is skipped as noise.
--
-- Deliberately NOT audited: RefreshToken, PatientRefreshToken (high churn,
-- hashes only), AuditLog itself, and static lookup tables the API never writes.
-- =============================================================================

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
        COALESCE(v_row ->> (TG_TABLE_NAME || 'Code'), v_id_text),
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

-- AuditLog is append-only for the application: nobody but the table owner (migrations)
-- and the SECURITY DEFINER trigger function can modify it.
REVOKE UPDATE, DELETE, TRUNCATE ON "AuditLog" FROM PUBLIC;
-- No dedicated application role exists yet (Phase 1.2), so a role could still hold an explicit
-- grant. Enforce append-only at the row level too. A retention purge must disable this trigger.
CREATE OR REPLACE FUNCTION audit_log_immutable() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'AuditLog is append-only (% not allowed)', TG_OP;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_log_immutable ON "AuditLog";
CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON "AuditLog"
    FOR EACH ROW EXECUTE FUNCTION audit_log_immutable();

-- Attach to every table the API writes to.
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN
        SELECT * FROM (VALUES
            ('Person',             ''),
            ('PersonDocument',     ''),
            ('User',               'PasswordHash,LastAccess'),
            ('Role',               ''),
            ('RoleNavigationAccess', ''),
            ('Patient',            'PasswordHash'),
            ('PatientAllergy',     ''),
            ('Diagnostic',         ''),
            ('Prescription',       ''),
            ('PrescriptionDetail', ''),
            ('Appointment',        ''),
            ('AppointmentPayment', ''),
            ('DoctorAvailability', ''),
            ('Medication',         ''),
            ('Allergy',            ''),
            ('Specialty',          ''),
            ('Insurance',          '')
        ) AS v(tbl, excluded)
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit ON %I', t.tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I '
            'FOR EACH ROW EXECUTE FUNCTION audit_row_change(%s)',
            t.tbl,
            COALESCE(
                (SELECT string_agg(quote_literal(c), ',') FROM unnest(string_to_array(NULLIF(t.excluded, ''), ',')) AS c),
                ''));
    END LOOP;
END $$;
