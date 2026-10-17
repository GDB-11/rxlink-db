-- Baseline schema (squash of the former V001-V041 chain, tag `pre-squash-v041` in git).
-- Catalog master data (sex, document types, specialties, medications, ...) is NOT stored here:
-- it lives in the catalog database and is referenced by *Code columns (no foreign keys).
-- Audit triggers (trg_audit) are attached in V004, after the reference data is loaded.

--
-- Name: activity_event_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activity_event_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'ActivityEvent is append-only (% not allowed)', TG_OP;
END;
$$;

--
-- Name: amendment_request_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.amendment_request_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'PatientAmendmentRequest is append-only (DELETE not allowed)';
    END IF;
    IF OLD."Status" <> 'Pendiente' THEN
        RAISE EXCEPTION 'A decided amendment request cannot be changed';
    END IF;
    IF NEW."PatientId" <> OLD."PatientId"
       OR NEW."TargetArea" <> OLD."TargetArea"
       OR NEW."RequestedChange" <> OLD."RequestedChange"
       OR NEW."RequestedAt" <> OLD."RequestedAt" THEN
        RAISE EXCEPTION 'The patient''s request cannot be rewritten';
    END IF;
    RETURN NEW;
END;
$$;

--
-- Name: audit_log_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_log_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'AuditLog is append-only (% not allowed)', TG_OP;
END;
$$;

--
-- Name: audit_row_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_row_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
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

--
-- Name: break_glass_grant_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.break_glass_grant_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'BreakGlassGrant rows are append-only';
END;
$$;

--
-- Name: patient_consent_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.patient_consent_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'PatientConsent is append-only (DELETE not allowed)';
    END IF;
    IF OLD."RevokedAt" IS NOT NULL THEN
        RAISE EXCEPTION 'A revoked consent cannot be changed';
    END IF;
    IF NEW."RevokedAt" IS NULL
       OR NEW."PatientId" <> OLD."PatientId"
       OR NEW."ConsentType" <> OLD."ConsentType"
       OR NEW."Description" <> OLD."Description"
       OR NEW."GrantedAt" <> OLD."GrantedAt"
       OR NEW."RecordedBy" <> OLD."RecordedBy"
       OR NEW."RecordedAt" <> OLD."RecordedAt" THEN
        RAISE EXCEPTION 'The only allowed change to a consent is its revocation';
    END IF;
    RETURN NEW;
END;
$$;

--
-- Name: patient_disclosure_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.patient_disclosure_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'PatientDisclosure is append-only (% not allowed)', TG_OP;
END;
$$;

--
-- Name: privacy_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.privacy_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION '% is append-only (% not allowed)', TG_TABLE_NAME, TG_OP;
END;
$$;

--
-- Name: stock_movement_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stock_movement_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'StockMovement is append-only (% not allowed)', TG_OP;
END;
$$;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ActivityEvent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ActivityEvent" (
    "ActivityEventId" bigint NOT NULL,
    "EventType" character varying(100) NOT NULL,
    "ActorUserId" integer,
    "EntityType" character varying(100),
    "EntityCode" uuid,
    "Summary" text NOT NULL,
    "Payload" jsonb,
    "OccurredAt" timestamp with time zone DEFAULT now() NOT NULL,
    "IpAddress" inet,
    "RequestId" text
);

--
-- Name: ActivityEvent_ActivityEventId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."ActivityEvent_ActivityEventId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: ActivityEvent_ActivityEventId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."ActivityEvent_ActivityEventId_seq" OWNED BY public."ActivityEvent"."ActivityEventId";

--
-- Name: Appointment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Appointment" (
    "AppointmentId" integer NOT NULL,
    "AppointmentCode" uuid DEFAULT uuidv7() NOT NULL,
    "PatientId" integer NOT NULL,
    "DoctorId" integer NOT NULL,
    "DoctorAvailabilityId" integer NOT NULL,
    "ConsultationTypeId" integer NOT NULL,
    "AppointmentStatusId" integer NOT NULL,
    "ScheduledAt" timestamp with time zone NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedAt" timestamp with time zone,
    "UpdatedBy" integer
);

--
-- Name: AppointmentPayment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."AppointmentPayment" (
    "AppointmentPaymentId" integer NOT NULL,
    "AppointmentId" integer NOT NULL,
    "BaseAmount" numeric(10,2) NOT NULL,
    "CoveragePercentage" numeric(5,2) DEFAULT 0 NOT NULL,
    "CoveredAmount" numeric(10,2) NOT NULL,
    "PatientAmount" numeric(10,2) NOT NULL,
    "RecordedBy" integer,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "InsuranceCode" uuid,
    "InsuranceName" character varying(100),
    CONSTRAINT "AppointmentPayment_InsuranceName_check" CHECK ((("InsuranceCode" IS NULL) OR ("InsuranceName" IS NOT NULL)))
);

--
-- Name: AppointmentPayment_AppointmentPaymentId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."AppointmentPayment_AppointmentPaymentId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: AppointmentPayment_AppointmentPaymentId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."AppointmentPayment_AppointmentPaymentId_seq" OWNED BY public."AppointmentPayment"."AppointmentPaymentId";

--
-- Name: AppointmentStatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."AppointmentStatus" (
    "AppointmentStatusId" integer NOT NULL,
    "AppointmentStatusCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(50) NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL
);

--
-- Name: AppointmentStatus_AppointmentStatusId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."AppointmentStatus_AppointmentStatusId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: AppointmentStatus_AppointmentStatusId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."AppointmentStatus_AppointmentStatusId_seq" OWNED BY public."AppointmentStatus"."AppointmentStatusId";

--
-- Name: Appointment_AppointmentId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Appointment_AppointmentId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Appointment_AppointmentId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Appointment_AppointmentId_seq" OWNED BY public."Appointment"."AppointmentId";

--
-- Name: AuditLog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."AuditLog" (
    "AuditLogId" bigint NOT NULL,
    "TableName" character varying(100) NOT NULL,
    "RecordId" integer,
    "Action" character varying(10) NOT NULL,
    "OldValues" jsonb,
    "NewValues" jsonb,
    "UserId" integer,
    "OccurredAt" timestamp with time zone DEFAULT now() NOT NULL,
    "IpAddress" inet,
    "RecordKey" text,
    "ChangedColumns" text[],
    "RequestId" text,
    CONSTRAINT "AuditLog_Action_check" CHECK ((("Action")::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);

--
-- Name: AuditLog_AuditLogId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."AuditLog_AuditLogId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: AuditLog_AuditLogId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."AuditLog_AuditLogId_seq" OWNED BY public."AuditLog"."AuditLogId";

--
-- Name: BreakGlassGrant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BreakGlassGrant" (
    "BreakGlassGrantId" integer NOT NULL,
    "BreakGlassGrantCode" uuid DEFAULT uuidv7() NOT NULL,
    "UserId" integer NOT NULL,
    "PatientId" integer NOT NULL,
    "Reason" text NOT NULL,
    "GrantedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "IpAddress" inet,
    CONSTRAINT chk_break_glass_expires CHECK (("ExpiresAt" > "GrantedAt")),
    CONSTRAINT chk_break_glass_reason CHECK ((char_length(btrim("Reason")) >= 10))
);

--
-- Name: BreakGlassGrant_BreakGlassGrantId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."BreakGlassGrant_BreakGlassGrantId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: BreakGlassGrant_BreakGlassGrantId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."BreakGlassGrant_BreakGlassGrantId_seq" OWNED BY public."BreakGlassGrant"."BreakGlassGrantId";

--
-- Name: Clinic; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Clinic" (
    "ClinicId" integer NOT NULL,
    "ClinicCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(150) NOT NULL,
    "Address" character varying(250),
    "District" character varying(100),
    "Province" character varying(100),
    "Department" character varying(100),
    "Phone" character varying(30),
    "Email" character varying(150),
    "Website" character varying(250),
    "FacilityRegistrationCode" character varying(50),
    "IsDefault" boolean DEFAULT false NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL,
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer
);

--
-- Name: ClinicStock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ClinicStock" (
    "ClinicId" integer NOT NULL,
    "MedicationCode" uuid NOT NULL,
    "StockQuantity" numeric(12,3) DEFAULT 0 NOT NULL,
    "ReorderLevel" numeric(12,3),
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer,
    CONSTRAINT "ClinicStock_ReorderLevel_check" CHECK (("ReorderLevel" >= (0)::numeric))
);

--
-- Name: Clinic_ClinicId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Clinic_ClinicId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Clinic_ClinicId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Clinic_ClinicId_seq" OWNED BY public."Clinic"."ClinicId";

--
-- Name: ConsultationType; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ConsultationType" (
    "ConsultationTypeId" integer NOT NULL,
    "ConsultationTypeCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(50) NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL
);

--
-- Name: ConsultationType_ConsultationTypeId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."ConsultationType_ConsultationTypeId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: ConsultationType_ConsultationTypeId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."ConsultationType_ConsultationTypeId_seq" OWNED BY public."ConsultationType"."ConsultationTypeId";

--
-- Name: Diagnostic; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Diagnostic" (
    "DiagnosticId" integer NOT NULL,
    "DiagnosticCode" uuid DEFAULT uuidv7() NOT NULL,
    "DiagnosticStatusId" integer NOT NULL,
    "Description" text NOT NULL,
    "DiagnosedAt" date NOT NULL,
    "Notes" text,
    "CreatedBy" integer NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "ModifiedBy" integer,
    "ModifiedAt" timestamp with time zone,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "AppointmentId" integer NOT NULL
);

--
-- Name: DiagnosticStatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."DiagnosticStatus" (
    "DiagnosticStatusId" integer NOT NULL,
    "DiagnosticStatusCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(50) NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL
);

--
-- Name: DiagnosticStatus_DiagnosticStatusId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."DiagnosticStatus_DiagnosticStatusId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: DiagnosticStatus_DiagnosticStatusId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."DiagnosticStatus_DiagnosticStatusId_seq" OWNED BY public."DiagnosticStatus"."DiagnosticStatusId";

--
-- Name: Diagnostic_DiagnosticId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Diagnostic_DiagnosticId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Diagnostic_DiagnosticId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Diagnostic_DiagnosticId_seq" OWNED BY public."Diagnostic"."DiagnosticId";

--
-- Name: DoctorAvailability; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."DoctorAvailability" (
    "DoctorAvailabilityId" integer NOT NULL,
    "DoctorAvailabilityCode" uuid DEFAULT uuidv7() NOT NULL,
    "DoctorId" integer NOT NULL,
    "Date" date NOT NULL,
    "StartTime" time without time zone NOT NULL,
    "IsBooked" boolean DEFAULT false NOT NULL,
    "CreatedBy" integer NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer
);

--
-- Name: DoctorAvailability_DoctorAvailabilityId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."DoctorAvailability_DoctorAvailabilityId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: DoctorAvailability_DoctorAvailabilityId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."DoctorAvailability_DoctorAvailabilityId_seq" OWNED BY public."DoctorAvailability"."DoctorAvailabilityId";

--
-- Name: NavigationItem; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NavigationItem" (
    "NavigationItemId" integer NOT NULL,
    "NavigationItemCode" uuid DEFAULT uuidv7() NOT NULL,
    "NavigationModuleId" integer NOT NULL,
    "Label" character varying(100) NOT NULL,
    "Icon" character varying(50) NOT NULL,
    "Path" character varying(200) NOT NULL,
    "DisplayOrder" integer NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL,
    CONSTRAINT "NavigationItem_DisplayOrder_check" CHECK (("DisplayOrder" > 0))
);

--
-- Name: NavigationItem_NavigationItemId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."NavigationItem_NavigationItemId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: NavigationItem_NavigationItemId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."NavigationItem_NavigationItemId_seq" OWNED BY public."NavigationItem"."NavigationItemId";

--
-- Name: NavigationModule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NavigationModule" (
    "NavigationModuleId" integer NOT NULL,
    "NavigationModuleCode" uuid DEFAULT uuidv7() NOT NULL,
    "Label" character varying(50) NOT NULL,
    "Icon" character varying(50) NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL
);

--
-- Name: NavigationModule_NavigationModuleId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."NavigationModule_NavigationModuleId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: NavigationModule_NavigationModuleId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."NavigationModule_NavigationModuleId_seq" OWNED BY public."NavigationModule"."NavigationModuleId";

--
-- Name: NotificationOutbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NotificationOutbox" (
    "NotificationId" bigint NOT NULL,
    "NotificationCode" uuid DEFAULT uuidv7() NOT NULL,
    "NotificationType" character varying(50) NOT NULL,
    "Channel" character varying(10) NOT NULL,
    "PatientId" integer NOT NULL,
    "EntityType" character varying(100) NOT NULL,
    "EntityCode" uuid NOT NULL,
    "Parameters" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "DedupKey" text NOT NULL,
    "Status" character varying(10) DEFAULT 'Pending'::character varying NOT NULL,
    "Attempts" integer DEFAULT 0 NOT NULL,
    "NextAttemptAt" timestamp with time zone DEFAULT now() NOT NULL,
    "SentAt" timestamp with time zone,
    "LastErrorType" character varying(100),
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_notification_attempts CHECK (("Attempts" >= 0)),
    CONSTRAINT ck_notification_channel CHECK ((("Channel")::text = ANY ((ARRAY['Email'::character varying, 'Sms'::character varying])::text[]))),
    CONSTRAINT ck_notification_sent CHECK (((("Status")::text = 'Sent'::text) = ("SentAt" IS NOT NULL))),
    CONSTRAINT ck_notification_status CHECK ((("Status")::text = ANY ((ARRAY['Pending'::character varying, 'Sent'::character varying, 'Failed'::character varying, 'Skipped'::character varying])::text[]))),
    CONSTRAINT ck_notification_type CHECK ((("NotificationType")::text = ANY ((ARRAY['AppointmentReminder'::character varying, 'PrescriptionExpiring'::character varying])::text[])))
);

--
-- Name: NotificationOutbox_NotificationId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."NotificationOutbox_NotificationId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: NotificationOutbox_NotificationId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."NotificationOutbox_NotificationId_seq" OWNED BY public."NotificationOutbox"."NotificationId";

--
-- Name: PartnerConfig; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PartnerConfig" (
    "PartnerConfigId" integer DEFAULT 1 NOT NULL,
    "PartnerCode" uuid DEFAULT uuidv7() NOT NULL,
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer,
    CONSTRAINT "PartnerConfig_PartnerConfigId_check" CHECK (("PartnerConfigId" = 1))
);

--
-- Name: PartnerInsurance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PartnerInsurance" (
    "InsuranceCode" uuid NOT NULL,
    "IsEnabled" boolean DEFAULT false NOT NULL,
    "CoveragePercentageOverride" numeric(5,2),
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer,
    CONSTRAINT "PartnerInsurance_CoveragePercentageOverride_check" CHECK ((("CoveragePercentageOverride" >= (0)::numeric) AND ("CoveragePercentageOverride" <= (100)::numeric)))
);

--
-- Name: PartnerMedication; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PartnerMedication" (
    "MedicationCode" uuid NOT NULL,
    "IsEnabled" boolean DEFAULT false NOT NULL,
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer
);

--
-- Name: PartnerSpecialty; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PartnerSpecialty" (
    "SpecialtyCode" uuid NOT NULL,
    "IsEnabled" boolean DEFAULT false NOT NULL,
    "PriceInPerson" numeric(10,2) DEFAULT 0 NOT NULL,
    "PriceVirtual" numeric(10,2) DEFAULT 0 NOT NULL,
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "UpdatedBy" integer,
    CONSTRAINT "PartnerSpecialty_PriceInPerson_check" CHECK (("PriceInPerson" >= (0)::numeric)),
    CONSTRAINT "PartnerSpecialty_PriceVirtual_check" CHECK (("PriceVirtual" >= (0)::numeric)),
    CONSTRAINT ck_partner_specialty_enabled_priced CHECK (((NOT "IsEnabled") OR (("PriceInPerson" > (0)::numeric) AND ("PriceVirtual" > (0)::numeric))))
);

--
-- Name: Patient; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Patient" (
    "PatientId" integer NOT NULL,
    "PatientCode" uuid DEFAULT uuidv7() NOT NULL,
    "PersonId" integer NOT NULL,
    "MedicalRecordNumber" character varying(50) NOT NULL,
    "IsActive" boolean DEFAULT true NOT NULL,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "PasswordHash" text
);

--
-- Name: PatientAllergy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientAllergy" (
    "PatientAllergyId" integer NOT NULL,
    "PatientAllergyCode" uuid DEFAULT uuidv7() NOT NULL,
    "PatientId" integer NOT NULL,
    "Notes" text,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "AllergyCode" uuid NOT NULL,
    "SeverityCode" uuid
);

--
-- Name: PatientAllergy_PatientAllergyId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientAllergy_PatientAllergyId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientAllergy_PatientAllergyId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientAllergy_PatientAllergyId_seq" OWNED BY public."PatientAllergy"."PatientAllergyId";

--
-- Name: PatientAmendmentRequest; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientAmendmentRequest" (
    "AmendmentRequestId" bigint NOT NULL,
    "AmendmentRequestCode" uuid DEFAULT uuidv7() NOT NULL,
    "PatientId" integer NOT NULL,
    "TargetArea" character varying(20) NOT NULL,
    "RequestedChange" text NOT NULL,
    "Status" character varying(10) DEFAULT 'Pendiente'::character varying NOT NULL,
    "RequestedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "ReviewedBy" integer,
    "ReviewedAt" timestamp with time zone,
    "DecisionReason" text,
    "AmendmentText" text,
    CONSTRAINT ck_amendment_area CHECK ((("TargetArea")::text = ANY ((ARRAY['Profile'::character varying, 'Allergies'::character varying, 'Diagnostics'::character varying, 'Prescriptions'::character varying, 'Appointments'::character varying, 'Other'::character varying])::text[]))),
    CONSTRAINT ck_amendment_change CHECK (((char_length(btrim("RequestedChange")) >= 10) AND (char_length(btrim("RequestedChange")) <= 2000))),
    CONSTRAINT ck_amendment_review CHECK ((((("Status")::text = 'Pendiente'::text) AND ("ReviewedBy" IS NULL) AND ("ReviewedAt" IS NULL) AND ("DecisionReason" IS NULL) AND ("AmendmentText" IS NULL)) OR ((("Status")::text = 'Aceptada'::text) AND ("ReviewedBy" IS NOT NULL) AND ("ReviewedAt" IS NOT NULL) AND ("DecisionReason" IS NOT NULL) AND ("AmendmentText" IS NOT NULL)) OR ((("Status")::text = 'Denegada'::text) AND ("ReviewedBy" IS NOT NULL) AND ("ReviewedAt" IS NOT NULL) AND ("DecisionReason" IS NOT NULL) AND ("AmendmentText" IS NULL)))),
    CONSTRAINT ck_amendment_status CHECK ((("Status")::text = ANY ((ARRAY['Pendiente'::character varying, 'Aceptada'::character varying, 'Denegada'::character varying])::text[])))
);

--
-- Name: PatientAmendmentRequest_AmendmentRequestId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientAmendmentRequest_AmendmentRequestId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientAmendmentRequest_AmendmentRequestId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientAmendmentRequest_AmendmentRequestId_seq" OWNED BY public."PatientAmendmentRequest"."AmendmentRequestId";

--
-- Name: PatientCommunicationPreference; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientCommunicationPreference" (
    "PatientCommunicationPreferenceId" integer CONSTRAINT "PatientCommunicationPrefere_PatientCommunicationPrefer_not_null" NOT NULL,
    "PatientId" integer NOT NULL,
    "AllowEmail" boolean DEFAULT true NOT NULL,
    "AllowSms" boolean DEFAULT true NOT NULL,
    "AlternativeEmail" character varying(254),
    "AlternativePhone" character varying(20),
    "UpdatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_comm_pref_email CHECK ((("AlternativeEmail" IS NULL) OR ((("AlternativeEmail")::text = btrim(("AlternativeEmail")::text)) AND (("AlternativeEmail")::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text)))),
    CONSTRAINT ck_comm_pref_phone CHECK ((("AlternativePhone" IS NULL) OR (("AlternativePhone")::text ~ '^\+?[0-9 ]{6,19}$'::text)))
);

--
-- Name: PatientCommunicationPreferenc_PatientCommunicationPreferenc_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientCommunicationPreferenc_PatientCommunicationPreferenc_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientCommunicationPreferenc_PatientCommunicationPreferenc_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientCommunicationPreferenc_PatientCommunicationPreferenc_seq" OWNED BY public."PatientCommunicationPreference"."PatientCommunicationPreferenceId";

--
-- Name: PatientConsent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientConsent" (
    "PatientConsentId" bigint NOT NULL,
    "PatientConsentCode" uuid DEFAULT uuidv7() NOT NULL,
    "PatientId" integer NOT NULL,
    "ConsentType" character varying(20) NOT NULL,
    "Description" character varying(500) NOT NULL,
    "GrantedAt" timestamp with time zone NOT NULL,
    "RecordedBy" integer NOT NULL,
    "RecordedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "RevokedAt" timestamp with time zone,
    "RevokedBy" integer,
    "RevokedReason" character varying(500),
    CONSTRAINT ck_consent_description CHECK ((char_length(btrim(("Description")::text)) > 0)),
    CONSTRAINT ck_consent_revocation CHECK (((("RevokedAt" IS NULL) AND ("RevokedBy" IS NULL) AND ("RevokedReason" IS NULL)) OR (("RevokedAt" IS NOT NULL) AND (char_length(btrim(("RevokedReason")::text)) > 0)))),
    CONSTRAINT ck_consent_type CHECK ((("ConsentType")::text = ANY ((ARRAY['Research'::character varying, 'Marketing'::character varying, 'ThirdPartySharing'::character varying, 'Other'::character varying])::text[])))
);

--
-- Name: PatientConsent_PatientConsentId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientConsent_PatientConsentId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientConsent_PatientConsentId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientConsent_PatientConsentId_seq" OWNED BY public."PatientConsent"."PatientConsentId";

--
-- Name: PatientDisclosure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientDisclosure" (
    "DisclosureId" bigint NOT NULL,
    "DisclosureCode" uuid DEFAULT uuidv7() NOT NULL,
    "PatientId" integer NOT NULL,
    "DisclosedAt" timestamp with time zone NOT NULL,
    "RecipientName" character varying(200) NOT NULL,
    "RecipientType" character varying(20) NOT NULL,
    "Purpose" character varying(300) NOT NULL,
    "Description" character varying(500) NOT NULL,
    "RecordedBy" integer NOT NULL,
    "RecordedAt" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_disclosure_recipient_type CHECK ((("RecipientType")::text = ANY ((ARRAY['Authority'::character varying, 'Court'::character varying, 'PublicHealth'::character varying, 'Insurer'::character varying, 'Family'::character varying, 'Researcher'::character varying, 'Other'::character varying])::text[]))),
    CONSTRAINT ck_disclosure_text CHECK (((char_length(btrim(("RecipientName")::text)) > 0) AND (char_length(btrim(("Purpose")::text)) > 0) AND (char_length(btrim(("Description")::text)) > 0)))
);

--
-- Name: PatientDisclosure_DisclosureId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientDisclosure_DisclosureId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientDisclosure_DisclosureId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientDisclosure_DisclosureId_seq" OWNED BY public."PatientDisclosure"."DisclosureId";

--
-- Name: PatientPrivacyNoticeAck; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientPrivacyNoticeAck" (
    "PatientPrivacyNoticeAckId" bigint NOT NULL,
    "PatientId" integer NOT NULL,
    "PrivacyNoticeId" integer NOT NULL,
    "AcknowledgedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "RecordedBy" integer
);

--
-- Name: PatientPrivacyNoticeAck_PatientPrivacyNoticeAckId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientPrivacyNoticeAck_PatientPrivacyNoticeAckId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientPrivacyNoticeAck_PatientPrivacyNoticeAckId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientPrivacyNoticeAck_PatientPrivacyNoticeAckId_seq" OWNED BY public."PatientPrivacyNoticeAck"."PatientPrivacyNoticeAckId";

--
-- Name: PatientRefreshToken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PatientRefreshToken" (
    "PatientRefreshTokenId" integer NOT NULL,
    "PatientId" integer NOT NULL,
    "TokenHash" text,
    "ExpiresAt" timestamp with time zone,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: PatientRefreshToken_PatientRefreshTokenId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PatientRefreshToken_PatientRefreshTokenId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PatientRefreshToken_PatientRefreshTokenId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PatientRefreshToken_PatientRefreshTokenId_seq" OWNED BY public."PatientRefreshToken"."PatientRefreshTokenId";

--
-- Name: Patient_PatientId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Patient_PatientId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Patient_PatientId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Patient_PatientId_seq" OWNED BY public."Patient"."PatientId";

--
-- Name: Person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Person" (
    "PersonId" integer NOT NULL,
    "PersonCode" uuid DEFAULT uuidv7() NOT NULL,
    "Names" character varying(200) NOT NULL,
    "Surnames" character varying(150) NOT NULL,
    "BirthDate" date NOT NULL,
    "Phone" character varying(30) NOT NULL,
    "AlternativePhone" character varying(30),
    "Email" character varying(254) NOT NULL,
    "Address" text,
    "EmergencyContactName" character varying(200),
    "EmergencyContactPhone" character varying(30),
    "SexCode" uuid NOT NULL
);

--
-- Name: PersonDocument; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PersonDocument" (
    "PersonDocumentId" integer NOT NULL,
    "PersonDocumentCode" uuid DEFAULT uuidv7() NOT NULL,
    "PersonId" integer NOT NULL,
    "Number" character varying(50) NOT NULL,
    "IssueDate" date,
    "ExpirationDate" date,
    "DocumentTypeCode" uuid NOT NULL,
    CONSTRAINT chk_person_document_dates CHECK ((("ExpirationDate" IS NULL) OR ("IssueDate" IS NULL) OR ("ExpirationDate" >= "IssueDate")))
);

--
-- Name: PersonDocument_PersonDocumentId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PersonDocument_PersonDocumentId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PersonDocument_PersonDocumentId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PersonDocument_PersonDocumentId_seq" OWNED BY public."PersonDocument"."PersonDocumentId";

--
-- Name: Person_PersonId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Person_PersonId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Person_PersonId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Person_PersonId_seq" OWNED BY public."Person"."PersonId";

--
-- Name: Prescription; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Prescription" (
    "PrescriptionId" integer NOT NULL,
    "PrescriptionCode" uuid DEFAULT uuidv7() NOT NULL,
    "UserId" integer NOT NULL,
    "PatientId" integer NOT NULL,
    "PrescriptionStatusId" integer NOT NULL,
    "Notes" text,
    "ValidUntil" date NOT NULL,
    "SignedAt" timestamp with time zone,
    "SignedBy" integer,
    "DispensedAt" timestamp with time zone,
    "DispensedBy" integer,
    "CreatedBy" integer NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "ModifiedBy" integer,
    "ModifiedAt" timestamp with time zone,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "DiagnosticId" integer NOT NULL,
    CONSTRAINT chk_prescription_dispensed CHECK (((("DispensedAt" IS NULL) AND ("DispensedBy" IS NULL)) OR (("DispensedAt" IS NOT NULL) AND ("DispensedBy" IS NOT NULL)))),
    CONSTRAINT chk_prescription_dispensed_requires_signature CHECK ((("DispensedAt" IS NULL) OR ("SignedAt" IS NOT NULL))),
    CONSTRAINT chk_prescription_signed CHECK (((("SignedAt" IS NULL) AND ("SignedBy" IS NULL)) OR (("SignedAt" IS NOT NULL) AND ("SignedBy" IS NOT NULL)))),
    CONSTRAINT chk_prescription_signed_after_created CHECK ((("SignedAt" IS NULL) OR ("SignedAt" >= "CreatedAt"))),
    CONSTRAINT chk_prescription_valid_until CHECK (("ValidUntil" >= ("CreatedAt")::date))
);

--
-- Name: PrescriptionDetail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PrescriptionDetail" (
    "PrescriptionDetailId" integer NOT NULL,
    "PrescriptionDetailCode" uuid DEFAULT uuidv7() NOT NULL,
    "PrescriptionId" integer NOT NULL,
    "Dose" character varying(100) NOT NULL,
    "DurationDays" integer NOT NULL,
    "Instructions" text,
    "MedicationCode" uuid NOT NULL,
    "AdministrationRouteCode" uuid NOT NULL,
    "FrequencyCode" uuid NOT NULL,
    "MedicationGenericName" character varying(200) NOT NULL,
    "MedicationCommercialName" character varying(200),
    "MedicationConcentration" character varying(50) NOT NULL,
    "PharmaceuticalFormName" character varying(100) NOT NULL,
    "AdministrationRouteName" character varying(100) NOT NULL,
    "FrequencyDescription" character varying(200) NOT NULL,
    "FrequencyIntervalHours" integer NOT NULL,
    CONSTRAINT "PrescriptionDetail_DurationDays_check" CHECK (("DurationDays" > 0)),
    CONSTRAINT "PrescriptionDetail_FrequencyIntervalHours_check" CHECK (("FrequencyIntervalHours" > 0))
);

--
-- Name: PrescriptionDetail_PrescriptionDetailId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PrescriptionDetail_PrescriptionDetailId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PrescriptionDetail_PrescriptionDetailId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PrescriptionDetail_PrescriptionDetailId_seq" OWNED BY public."PrescriptionDetail"."PrescriptionDetailId";

--
-- Name: PrescriptionStatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PrescriptionStatus" (
    "PrescriptionStatusId" integer NOT NULL,
    "PrescriptionStatusCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(50) NOT NULL,
    "Description" text,
    "IsActive" boolean DEFAULT true NOT NULL
);

--
-- Name: PrescriptionStatus_PrescriptionStatusId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PrescriptionStatus_PrescriptionStatusId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PrescriptionStatus_PrescriptionStatusId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PrescriptionStatus_PrescriptionStatusId_seq" OWNED BY public."PrescriptionStatus"."PrescriptionStatusId";

--
-- Name: Prescription_PrescriptionId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Prescription_PrescriptionId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Prescription_PrescriptionId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Prescription_PrescriptionId_seq" OWNED BY public."Prescription"."PrescriptionId";

--
-- Name: PrivacyNotice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PrivacyNotice" (
    "PrivacyNoticeId" integer NOT NULL,
    "PrivacyNoticeCode" uuid DEFAULT uuidv7() NOT NULL,
    "Version" integer NOT NULL,
    "Title" character varying(200) NOT NULL,
    "Body" text NOT NULL,
    "EffectiveFrom" date NOT NULL,
    "PublishedBy" integer NOT NULL,
    "PublishedAt" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_privacy_notice_text CHECK (((char_length(btrim(("Title")::text)) > 0) AND ((char_length(btrim("Body")) >= 20) AND (char_length(btrim("Body")) <= 50000))))
);

--
-- Name: PrivacyNotice_PrivacyNoticeId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."PrivacyNotice_PrivacyNoticeId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: PrivacyNotice_PrivacyNoticeId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."PrivacyNotice_PrivacyNoticeId_seq" OWNED BY public."PrivacyNotice"."PrivacyNoticeId";

--
-- Name: RefreshToken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RefreshToken" (
    "RefreshTokenId" integer NOT NULL,
    "UserId" integer NOT NULL,
    "TokenHash" text NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "IpAddress" inet,
    "UserAgent" text,
    "RevokedAt" timestamp with time zone,
    "RevokedBy" integer,
    "SessionStartedAt" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_refresh_token_revocation CHECK ((("RevokedAt" IS NULL) OR ("RevokedAt" >= "CreatedAt")))
);

--
-- Name: RefreshToken_RefreshTokenId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."RefreshToken_RefreshTokenId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: RefreshToken_RefreshTokenId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."RefreshToken_RefreshTokenId_seq" OWNED BY public."RefreshToken"."RefreshTokenId";

--
-- Name: Role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Role" (
    "RoleId" integer NOT NULL,
    "RoleCode" uuid DEFAULT uuidv7() NOT NULL,
    "Name" character varying(50) NOT NULL,
    "Description" text,
    "IsActive" boolean DEFAULT true NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "CanViewClinicalData" boolean DEFAULT false NOT NULL
);

--
-- Name: RoleNavigationAccess; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RoleNavigationAccess" (
    "RoleNavigationAccessId" integer NOT NULL,
    "RoleId" integer NOT NULL,
    "NavigationModuleId" integer NOT NULL,
    "NavigationItemId" integer,
    "DisplayOrder" integer DEFAULT 0 NOT NULL
);

--
-- Name: RoleNavigationAccess_RoleNavigationAccessId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."RoleNavigationAccess_RoleNavigationAccessId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: RoleNavigationAccess_RoleNavigationAccessId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."RoleNavigationAccess_RoleNavigationAccessId_seq" OWNED BY public."RoleNavigationAccess"."RoleNavigationAccessId";

--
-- Name: Role_RoleId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Role_RoleId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: Role_RoleId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Role_RoleId_seq" OWNED BY public."Role"."RoleId";

--
-- Name: StockMovement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."StockMovement" (
    "StockMovementId" bigint NOT NULL,
    "StockMovementCode" uuid DEFAULT uuidv7() NOT NULL,
    "ClinicId" integer NOT NULL,
    "MedicationCode" uuid NOT NULL,
    "MovementType" character varying(20) NOT NULL,
    "Direction" smallint NOT NULL,
    "Quantity" numeric(12,3) NOT NULL,
    "BatchNumber" character varying(50),
    "ExpiresOn" date,
    "PrescriptionDetailId" integer,
    "Reason" text,
    "UserId" integer,
    "OccurredAt" timestamp with time zone DEFAULT now() NOT NULL,
    "ShortfallQuantity" numeric(12,3),
    CONSTRAINT "StockMovement_Quantity_check" CHECK (("Quantity" > (0)::numeric)),
    CONSTRAINT ck_stock_movement_direction CHECK (("Direction" = ANY (ARRAY[1, '-1'::integer]))),
    CONSTRAINT ck_stock_movement_direction_by_type CHECK ((((("MovementType")::text = ANY ((ARRAY['Entry'::character varying, 'Return'::character varying])::text[])) AND ("Direction" = 1)) OR ((("MovementType")::text = ANY ((ARRAY['Dispense'::character varying, 'Loss'::character varying])::text[])) AND ("Direction" = '-1'::integer)) OR (("MovementType")::text = 'Adjustment'::text))),
    CONSTRAINT ck_stock_movement_dispense_detail CHECK (((("MovementType")::text = 'Dispense'::text) = ("PrescriptionDetailId" IS NOT NULL))),
    CONSTRAINT ck_stock_movement_reason CHECK (((("MovementType")::text <> ALL ((ARRAY['Adjustment'::character varying, 'Loss'::character varying])::text[])) OR (length(btrim(COALESCE("Reason", ''::text))) > 0))),
    CONSTRAINT ck_stock_movement_shortfall CHECK ((("ShortfallQuantity" IS NULL) OR ((("MovementType")::text = 'Dispense'::text) AND ("ShortfallQuantity" > (0)::numeric) AND ("ShortfallQuantity" <= "Quantity") AND (length(btrim(COALESCE("Reason", ''::text))) > 0)))),
    CONSTRAINT ck_stock_movement_type CHECK ((("MovementType")::text = ANY ((ARRAY['Entry'::character varying, 'Dispense'::character varying, 'Adjustment'::character varying, 'Loss'::character varying, 'Return'::character varying])::text[])))
);

--
-- Name: StockMovement_StockMovementId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."StockMovement_StockMovementId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: StockMovement_StockMovementId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."StockMovement_StockMovementId_seq" OWNED BY public."StockMovement"."StockMovementId";

--
-- Name: User; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."User" (
    "UserId" integer NOT NULL,
    "UserCode" uuid DEFAULT uuidv7() NOT NULL,
    "PersonId" integer NOT NULL,
    "RoleId" integer NOT NULL,
    "Username" character varying(100) NOT NULL,
    "Email" character varying(254) NOT NULL,
    "PasswordHash" text NOT NULL,
    "LicenseNumber" character varying(100),
    "IsActive" boolean DEFAULT true NOT NULL,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "LastAccess" timestamp with time zone,
    "DeletedAt" timestamp with time zone,
    "DeletedBy" integer,
    "SpecialtyCode" uuid
);

--
-- Name: UserLockout; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."UserLockout" (
    "UserId" integer NOT NULL,
    "FailedCount" integer DEFAULT 0 NOT NULL,
    "LockedUntil" timestamp with time zone,
    "LastFailedAt" timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: UserMfa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."UserMfa" (
    "UserMfaId" integer NOT NULL,
    "UserId" integer NOT NULL,
    "SecretEncrypted" text NOT NULL,
    "ConfirmedAt" timestamp with time zone,
    "LastUsedStep" bigint,
    "CreatedAt" timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: UserMfa_UserMfaId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."UserMfa_UserMfaId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: UserMfa_UserMfaId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."UserMfa_UserMfaId_seq" OWNED BY public."UserMfa"."UserMfaId";

--
-- Name: User_UserId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."User_UserId_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: User_UserId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."User_UserId_seq" OWNED BY public."User"."UserId";

--
-- Name: ActivityEvent ActivityEventId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ActivityEvent" ALTER COLUMN "ActivityEventId" SET DEFAULT nextval('public."ActivityEvent_ActivityEventId_seq"'::regclass);

--
-- Name: Appointment AppointmentId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment" ALTER COLUMN "AppointmentId" SET DEFAULT nextval('public."Appointment_AppointmentId_seq"'::regclass);

--
-- Name: AppointmentPayment AppointmentPaymentId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentPayment" ALTER COLUMN "AppointmentPaymentId" SET DEFAULT nextval('public."AppointmentPayment_AppointmentPaymentId_seq"'::regclass);

--
-- Name: AppointmentStatus AppointmentStatusId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentStatus" ALTER COLUMN "AppointmentStatusId" SET DEFAULT nextval('public."AppointmentStatus_AppointmentStatusId_seq"'::regclass);

--
-- Name: AuditLog AuditLogId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AuditLog" ALTER COLUMN "AuditLogId" SET DEFAULT nextval('public."AuditLog_AuditLogId_seq"'::regclass);

--
-- Name: BreakGlassGrant BreakGlassGrantId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BreakGlassGrant" ALTER COLUMN "BreakGlassGrantId" SET DEFAULT nextval('public."BreakGlassGrant_BreakGlassGrantId_seq"'::regclass);

--
-- Name: Clinic ClinicId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Clinic" ALTER COLUMN "ClinicId" SET DEFAULT nextval('public."Clinic_ClinicId_seq"'::regclass);

--
-- Name: ConsultationType ConsultationTypeId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConsultationType" ALTER COLUMN "ConsultationTypeId" SET DEFAULT nextval('public."ConsultationType_ConsultationTypeId_seq"'::regclass);

--
-- Name: Diagnostic DiagnosticId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic" ALTER COLUMN "DiagnosticId" SET DEFAULT nextval('public."Diagnostic_DiagnosticId_seq"'::regclass);

--
-- Name: DiagnosticStatus DiagnosticStatusId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DiagnosticStatus" ALTER COLUMN "DiagnosticStatusId" SET DEFAULT nextval('public."DiagnosticStatus_DiagnosticStatusId_seq"'::regclass);

--
-- Name: DoctorAvailability DoctorAvailabilityId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability" ALTER COLUMN "DoctorAvailabilityId" SET DEFAULT nextval('public."DoctorAvailability_DoctorAvailabilityId_seq"'::regclass);

--
-- Name: NavigationItem NavigationItemId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationItem" ALTER COLUMN "NavigationItemId" SET DEFAULT nextval('public."NavigationItem_NavigationItemId_seq"'::regclass);

--
-- Name: NavigationModule NavigationModuleId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationModule" ALTER COLUMN "NavigationModuleId" SET DEFAULT nextval('public."NavigationModule_NavigationModuleId_seq"'::regclass);

--
-- Name: NotificationOutbox NotificationId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NotificationOutbox" ALTER COLUMN "NotificationId" SET DEFAULT nextval('public."NotificationOutbox_NotificationId_seq"'::regclass);

--
-- Name: Patient PatientId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient" ALTER COLUMN "PatientId" SET DEFAULT nextval('public."Patient_PatientId_seq"'::regclass);

--
-- Name: PatientAllergy PatientAllergyId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy" ALTER COLUMN "PatientAllergyId" SET DEFAULT nextval('public."PatientAllergy_PatientAllergyId_seq"'::regclass);

--
-- Name: PatientAmendmentRequest AmendmentRequestId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAmendmentRequest" ALTER COLUMN "AmendmentRequestId" SET DEFAULT nextval('public."PatientAmendmentRequest_AmendmentRequestId_seq"'::regclass);

--
-- Name: PatientCommunicationPreference PatientCommunicationPreferenceId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientCommunicationPreference" ALTER COLUMN "PatientCommunicationPreferenceId" SET DEFAULT nextval('public."PatientCommunicationPreferenc_PatientCommunicationPreferenc_seq"'::regclass);

--
-- Name: PatientConsent PatientConsentId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent" ALTER COLUMN "PatientConsentId" SET DEFAULT nextval('public."PatientConsent_PatientConsentId_seq"'::regclass);

--
-- Name: PatientDisclosure DisclosureId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientDisclosure" ALTER COLUMN "DisclosureId" SET DEFAULT nextval('public."PatientDisclosure_DisclosureId_seq"'::regclass);

--
-- Name: PatientPrivacyNoticeAck PatientPrivacyNoticeAckId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck" ALTER COLUMN "PatientPrivacyNoticeAckId" SET DEFAULT nextval('public."PatientPrivacyNoticeAck_PatientPrivacyNoticeAckId_seq"'::regclass);

--
-- Name: PatientRefreshToken PatientRefreshTokenId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientRefreshToken" ALTER COLUMN "PatientRefreshTokenId" SET DEFAULT nextval('public."PatientRefreshToken_PatientRefreshTokenId_seq"'::regclass);

--
-- Name: Person PersonId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Person" ALTER COLUMN "PersonId" SET DEFAULT nextval('public."Person_PersonId_seq"'::regclass);

--
-- Name: PersonDocument PersonDocumentId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PersonDocument" ALTER COLUMN "PersonDocumentId" SET DEFAULT nextval('public."PersonDocument_PersonDocumentId_seq"'::regclass);

--
-- Name: Prescription PrescriptionId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription" ALTER COLUMN "PrescriptionId" SET DEFAULT nextval('public."Prescription_PrescriptionId_seq"'::regclass);

--
-- Name: PrescriptionDetail PrescriptionDetailId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionDetail" ALTER COLUMN "PrescriptionDetailId" SET DEFAULT nextval('public."PrescriptionDetail_PrescriptionDetailId_seq"'::regclass);

--
-- Name: PrescriptionStatus PrescriptionStatusId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionStatus" ALTER COLUMN "PrescriptionStatusId" SET DEFAULT nextval('public."PrescriptionStatus_PrescriptionStatusId_seq"'::regclass);

--
-- Name: PrivacyNotice PrivacyNoticeId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrivacyNotice" ALTER COLUMN "PrivacyNoticeId" SET DEFAULT nextval('public."PrivacyNotice_PrivacyNoticeId_seq"'::regclass);

--
-- Name: RefreshToken RefreshTokenId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RefreshToken" ALTER COLUMN "RefreshTokenId" SET DEFAULT nextval('public."RefreshToken_RefreshTokenId_seq"'::regclass);

--
-- Name: Role RoleId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Role" ALTER COLUMN "RoleId" SET DEFAULT nextval('public."Role_RoleId_seq"'::regclass);

--
-- Name: RoleNavigationAccess RoleNavigationAccessId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess" ALTER COLUMN "RoleNavigationAccessId" SET DEFAULT nextval('public."RoleNavigationAccess_RoleNavigationAccessId_seq"'::regclass);

--
-- Name: StockMovement StockMovementId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement" ALTER COLUMN "StockMovementId" SET DEFAULT nextval('public."StockMovement_StockMovementId_seq"'::regclass);

--
-- Name: User UserId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User" ALTER COLUMN "UserId" SET DEFAULT nextval('public."User_UserId_seq"'::regclass);

--
-- Name: UserMfa UserMfaId; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserMfa" ALTER COLUMN "UserMfaId" SET DEFAULT nextval('public."UserMfa_UserMfaId_seq"'::regclass);

--
-- Name: ActivityEvent ActivityEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ActivityEvent"
    ADD CONSTRAINT "ActivityEvent_pkey" PRIMARY KEY ("ActivityEventId");

--
-- Name: AppointmentPayment AppointmentPayment_AppointmentId_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentPayment"
    ADD CONSTRAINT "AppointmentPayment_AppointmentId_key" UNIQUE ("AppointmentId");

--
-- Name: AppointmentPayment AppointmentPayment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentPayment"
    ADD CONSTRAINT "AppointmentPayment_pkey" PRIMARY KEY ("AppointmentPaymentId");

--
-- Name: AppointmentStatus AppointmentStatus_AppointmentStatusCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentStatus"
    ADD CONSTRAINT "AppointmentStatus_AppointmentStatusCode_key" UNIQUE ("AppointmentStatusCode");

--
-- Name: AppointmentStatus AppointmentStatus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentStatus"
    ADD CONSTRAINT "AppointmentStatus_pkey" PRIMARY KEY ("AppointmentStatusId");

--
-- Name: Appointment Appointment_AppointmentCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_AppointmentCode_key" UNIQUE ("AppointmentCode");

--
-- Name: Appointment Appointment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_pkey" PRIMARY KEY ("AppointmentId");

--
-- Name: AuditLog AuditLog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AuditLog"
    ADD CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("AuditLogId");

--
-- Name: BreakGlassGrant BreakGlassGrant_BreakGlassGrantCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BreakGlassGrant"
    ADD CONSTRAINT "BreakGlassGrant_BreakGlassGrantCode_key" UNIQUE ("BreakGlassGrantCode");

--
-- Name: BreakGlassGrant BreakGlassGrant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BreakGlassGrant"
    ADD CONSTRAINT "BreakGlassGrant_pkey" PRIMARY KEY ("BreakGlassGrantId");

--
-- Name: ClinicStock ClinicStock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ClinicStock"
    ADD CONSTRAINT "ClinicStock_pkey" PRIMARY KEY ("ClinicId", "MedicationCode");

--
-- Name: Clinic Clinic_ClinicCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Clinic"
    ADD CONSTRAINT "Clinic_ClinicCode_key" UNIQUE ("ClinicCode");

--
-- Name: Clinic Clinic_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Clinic"
    ADD CONSTRAINT "Clinic_pkey" PRIMARY KEY ("ClinicId");

--
-- Name: ConsultationType ConsultationType_ConsultationTypeCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConsultationType"
    ADD CONSTRAINT "ConsultationType_ConsultationTypeCode_key" UNIQUE ("ConsultationTypeCode");

--
-- Name: ConsultationType ConsultationType_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConsultationType"
    ADD CONSTRAINT "ConsultationType_pkey" PRIMARY KEY ("ConsultationTypeId");

--
-- Name: DiagnosticStatus DiagnosticStatus_DiagnosticStatusCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DiagnosticStatus"
    ADD CONSTRAINT "DiagnosticStatus_DiagnosticStatusCode_key" UNIQUE ("DiagnosticStatusCode");

--
-- Name: DiagnosticStatus DiagnosticStatus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DiagnosticStatus"
    ADD CONSTRAINT "DiagnosticStatus_pkey" PRIMARY KEY ("DiagnosticStatusId");

--
-- Name: Diagnostic Diagnostic_DiagnosticCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_DiagnosticCode_key" UNIQUE ("DiagnosticCode");

--
-- Name: Diagnostic Diagnostic_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_pkey" PRIMARY KEY ("DiagnosticId");

--
-- Name: DoctorAvailability DoctorAvailability_DoctorAvailabilityCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT "DoctorAvailability_DoctorAvailabilityCode_key" UNIQUE ("DoctorAvailabilityCode");

--
-- Name: DoctorAvailability DoctorAvailability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT "DoctorAvailability_pkey" PRIMARY KEY ("DoctorAvailabilityId");

--
-- Name: NavigationItem NavigationItem_NavigationItemCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationItem"
    ADD CONSTRAINT "NavigationItem_NavigationItemCode_key" UNIQUE ("NavigationItemCode");

--
-- Name: NavigationItem NavigationItem_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationItem"
    ADD CONSTRAINT "NavigationItem_pkey" PRIMARY KEY ("NavigationItemId");

--
-- Name: NavigationModule NavigationModule_NavigationModuleCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationModule"
    ADD CONSTRAINT "NavigationModule_NavigationModuleCode_key" UNIQUE ("NavigationModuleCode");

--
-- Name: NavigationModule NavigationModule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationModule"
    ADD CONSTRAINT "NavigationModule_pkey" PRIMARY KEY ("NavigationModuleId");

--
-- Name: NotificationOutbox NotificationOutbox_DedupKey_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NotificationOutbox"
    ADD CONSTRAINT "NotificationOutbox_DedupKey_key" UNIQUE ("DedupKey");

--
-- Name: NotificationOutbox NotificationOutbox_NotificationCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NotificationOutbox"
    ADD CONSTRAINT "NotificationOutbox_NotificationCode_key" UNIQUE ("NotificationCode");

--
-- Name: NotificationOutbox NotificationOutbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NotificationOutbox"
    ADD CONSTRAINT "NotificationOutbox_pkey" PRIMARY KEY ("NotificationId");

--
-- Name: PartnerConfig PartnerConfig_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerConfig"
    ADD CONSTRAINT "PartnerConfig_pkey" PRIMARY KEY ("PartnerConfigId");

--
-- Name: PartnerInsurance PartnerInsurance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerInsurance"
    ADD CONSTRAINT "PartnerInsurance_pkey" PRIMARY KEY ("InsuranceCode");

--
-- Name: PartnerMedication PartnerMedication_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerMedication"
    ADD CONSTRAINT "PartnerMedication_pkey" PRIMARY KEY ("MedicationCode");

--
-- Name: PartnerSpecialty PartnerSpecialty_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerSpecialty"
    ADD CONSTRAINT "PartnerSpecialty_pkey" PRIMARY KEY ("SpecialtyCode");

--
-- Name: PatientAllergy PatientAllergy_PatientAllergyCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy"
    ADD CONSTRAINT "PatientAllergy_PatientAllergyCode_key" UNIQUE ("PatientAllergyCode");

--
-- Name: PatientAllergy PatientAllergy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy"
    ADD CONSTRAINT "PatientAllergy_pkey" PRIMARY KEY ("PatientAllergyId");

--
-- Name: PatientAmendmentRequest PatientAmendmentRequest_AmendmentRequestCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAmendmentRequest"
    ADD CONSTRAINT "PatientAmendmentRequest_AmendmentRequestCode_key" UNIQUE ("AmendmentRequestCode");

--
-- Name: PatientAmendmentRequest PatientAmendmentRequest_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAmendmentRequest"
    ADD CONSTRAINT "PatientAmendmentRequest_pkey" PRIMARY KEY ("AmendmentRequestId");

--
-- Name: PatientCommunicationPreference PatientCommunicationPreference_PatientId_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientCommunicationPreference"
    ADD CONSTRAINT "PatientCommunicationPreference_PatientId_key" UNIQUE ("PatientId");

--
-- Name: PatientCommunicationPreference PatientCommunicationPreference_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientCommunicationPreference"
    ADD CONSTRAINT "PatientCommunicationPreference_pkey" PRIMARY KEY ("PatientCommunicationPreferenceId");

--
-- Name: PatientConsent PatientConsent_PatientConsentCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent"
    ADD CONSTRAINT "PatientConsent_PatientConsentCode_key" UNIQUE ("PatientConsentCode");

--
-- Name: PatientConsent PatientConsent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent"
    ADD CONSTRAINT "PatientConsent_pkey" PRIMARY KEY ("PatientConsentId");

--
-- Name: PatientDisclosure PatientDisclosure_DisclosureCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientDisclosure"
    ADD CONSTRAINT "PatientDisclosure_DisclosureCode_key" UNIQUE ("DisclosureCode");

--
-- Name: PatientDisclosure PatientDisclosure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientDisclosure"
    ADD CONSTRAINT "PatientDisclosure_pkey" PRIMARY KEY ("DisclosureId");

--
-- Name: PatientPrivacyNoticeAck PatientPrivacyNoticeAck_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck"
    ADD CONSTRAINT "PatientPrivacyNoticeAck_pkey" PRIMARY KEY ("PatientPrivacyNoticeAckId");

--
-- Name: PatientRefreshToken PatientRefreshToken_PatientId_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientRefreshToken"
    ADD CONSTRAINT "PatientRefreshToken_PatientId_key" UNIQUE ("PatientId");

--
-- Name: PatientRefreshToken PatientRefreshToken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientRefreshToken"
    ADD CONSTRAINT "PatientRefreshToken_pkey" PRIMARY KEY ("PatientRefreshTokenId");

--
-- Name: Patient Patient_MedicalRecordNumber_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient"
    ADD CONSTRAINT "Patient_MedicalRecordNumber_key" UNIQUE ("MedicalRecordNumber");

--
-- Name: Patient Patient_PatientCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient"
    ADD CONSTRAINT "Patient_PatientCode_key" UNIQUE ("PatientCode");

--
-- Name: Patient Patient_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient"
    ADD CONSTRAINT "Patient_pkey" PRIMARY KEY ("PatientId");

--
-- Name: PersonDocument PersonDocument_PersonDocumentCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PersonDocument"
    ADD CONSTRAINT "PersonDocument_PersonDocumentCode_key" UNIQUE ("PersonDocumentCode");

--
-- Name: PersonDocument PersonDocument_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PersonDocument"
    ADD CONSTRAINT "PersonDocument_pkey" PRIMARY KEY ("PersonDocumentId");

--
-- Name: Person Person_PersonCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Person"
    ADD CONSTRAINT "Person_PersonCode_key" UNIQUE ("PersonCode");

--
-- Name: Person Person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Person"
    ADD CONSTRAINT "Person_pkey" PRIMARY KEY ("PersonId");

--
-- Name: PrescriptionDetail PrescriptionDetail_PrescriptionDetailCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionDetail"
    ADD CONSTRAINT "PrescriptionDetail_PrescriptionDetailCode_key" UNIQUE ("PrescriptionDetailCode");

--
-- Name: PrescriptionDetail PrescriptionDetail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionDetail"
    ADD CONSTRAINT "PrescriptionDetail_pkey" PRIMARY KEY ("PrescriptionDetailId");

--
-- Name: PrescriptionStatus PrescriptionStatus_PrescriptionStatusCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionStatus"
    ADD CONSTRAINT "PrescriptionStatus_PrescriptionStatusCode_key" UNIQUE ("PrescriptionStatusCode");

--
-- Name: PrescriptionStatus PrescriptionStatus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionStatus"
    ADD CONSTRAINT "PrescriptionStatus_pkey" PRIMARY KEY ("PrescriptionStatusId");

--
-- Name: Prescription Prescription_PrescriptionCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_PrescriptionCode_key" UNIQUE ("PrescriptionCode");

--
-- Name: Prescription Prescription_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_pkey" PRIMARY KEY ("PrescriptionId");

--
-- Name: PrivacyNotice PrivacyNotice_PrivacyNoticeCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrivacyNotice"
    ADD CONSTRAINT "PrivacyNotice_PrivacyNoticeCode_key" UNIQUE ("PrivacyNoticeCode");

--
-- Name: PrivacyNotice PrivacyNotice_Version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrivacyNotice"
    ADD CONSTRAINT "PrivacyNotice_Version_key" UNIQUE ("Version");

--
-- Name: PrivacyNotice PrivacyNotice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrivacyNotice"
    ADD CONSTRAINT "PrivacyNotice_pkey" PRIMARY KEY ("PrivacyNoticeId");

--
-- Name: RefreshToken RefreshToken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("RefreshTokenId");

--
-- Name: RoleNavigationAccess RoleNavigationAccess_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess"
    ADD CONSTRAINT "RoleNavigationAccess_pkey" PRIMARY KEY ("RoleNavigationAccessId");

--
-- Name: Role Role_RoleCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Role"
    ADD CONSTRAINT "Role_RoleCode_key" UNIQUE ("RoleCode");

--
-- Name: Role Role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Role"
    ADD CONSTRAINT "Role_pkey" PRIMARY KEY ("RoleId");

--
-- Name: StockMovement StockMovement_StockMovementCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement"
    ADD CONSTRAINT "StockMovement_StockMovementCode_key" UNIQUE ("StockMovementCode");

--
-- Name: StockMovement StockMovement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement"
    ADD CONSTRAINT "StockMovement_pkey" PRIMARY KEY ("StockMovementId");

--
-- Name: UserLockout UserLockout_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserLockout"
    ADD CONSTRAINT "UserLockout_pkey" PRIMARY KEY ("UserId");

--
-- Name: UserMfa UserMfa_UserId_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserMfa"
    ADD CONSTRAINT "UserMfa_UserId_key" UNIQUE ("UserId");

--
-- Name: UserMfa UserMfa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserMfa"
    ADD CONSTRAINT "UserMfa_pkey" PRIMARY KEY ("UserMfaId");

--
-- Name: User User_Email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_Email_key" UNIQUE ("Email");

--
-- Name: User User_UserCode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_UserCode_key" UNIQUE ("UserCode");

--
-- Name: User User_Username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_Username_key" UNIQUE ("Username");

--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY ("UserId");

--
-- Name: DoctorAvailability uq_doctor_date_time; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT uq_doctor_date_time UNIQUE ("DoctorId", "Date", "StartTime");

--
-- Name: PatientAllergy uq_patient_allergy; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy"
    ADD CONSTRAINT uq_patient_allergy UNIQUE ("PatientId", "AllergyCode");

--
-- Name: PatientPrivacyNoticeAck uq_privacy_ack; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck"
    ADD CONSTRAINT uq_privacy_ack UNIQUE ("PatientId", "PrivacyNoticeId");

--
-- Name: RoleNavigationAccess uq_role_nav_access; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess"
    ADD CONSTRAINT uq_role_nav_access UNIQUE ("RoleId", "NavigationModuleId", "NavigationItemId");

--
-- Name: idx_activity_event_actor_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_event_actor_time ON public."ActivityEvent" USING btree ("ActorUserId", "OccurredAt");

--
-- Name: idx_activity_event_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_event_entity ON public."ActivityEvent" USING btree ("EntityType", "EntityCode");

--
-- Name: idx_activity_event_time_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_event_time_brin ON public."ActivityEvent" USING brin ("OccurredAt");

--
-- Name: idx_activity_event_type_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_event_type_time ON public."ActivityEvent" USING btree ("EventType", "OccurredAt");

--
-- Name: idx_amendment_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_amendment_patient ON public."PatientAmendmentRequest" USING btree ("PatientId", "RequestedAt" DESC);

--
-- Name: idx_amendment_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_amendment_pending ON public."PatientAmendmentRequest" USING btree ("RequestedAt") WHERE (("Status")::text = 'Pendiente'::text);

--
-- Name: idx_appointment_doctor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_appointment_doctor_id ON public."Appointment" USING btree ("DoctorId");

--
-- Name: idx_appointment_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_appointment_patient_id ON public."Appointment" USING btree ("PatientId");

--
-- Name: idx_appointment_payment_insurance_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_appointment_payment_insurance_code ON public."AppointmentPayment" USING btree ("InsuranceCode");

--
-- Name: idx_audit_log_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_occurred_at ON public."AuditLog" USING btree ("OccurredAt");

--
-- Name: idx_audit_log_occurred_brin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_occurred_brin ON public."AuditLog" USING brin ("OccurredAt");

--
-- Name: idx_audit_log_table_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_table_record ON public."AuditLog" USING btree ("TableName", "RecordId");

--
-- Name: idx_audit_log_table_record_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_table_record_key ON public."AuditLog" USING btree ("TableName", "RecordKey");

--
-- Name: idx_audit_log_unattributed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_unattributed ON public."AuditLog" USING btree ("OccurredAt") WHERE ("UserId" IS NULL);

--
-- Name: idx_audit_log_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_user_time ON public."AuditLog" USING btree ("UserId", "OccurredAt");

--
-- Name: idx_availability_doctor_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_availability_doctor_date ON public."DoctorAvailability" USING btree ("DoctorId", "Date");

--
-- Name: idx_break_glass_granted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_break_glass_granted_at ON public."BreakGlassGrant" USING btree ("GrantedAt");

--
-- Name: idx_break_glass_user_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_break_glass_user_patient ON public."BreakGlassGrant" USING btree ("UserId", "PatientId", "ExpiresAt");

--
-- Name: idx_consent_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consent_patient ON public."PatientConsent" USING btree ("PatientId", "GrantedAt" DESC);

--
-- Name: idx_diagnostic_appointment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_diagnostic_appointment_id ON public."Diagnostic" USING btree ("AppointmentId");

--
-- Name: idx_diagnostic_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_diagnostic_status_id ON public."Diagnostic" USING btree ("DiagnosticStatusId");

--
-- Name: idx_disclosure_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disclosure_patient ON public."PatientDisclosure" USING btree ("PatientId", "DisclosedAt" DESC);

--
-- Name: idx_nav_item_module_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nav_item_module_id ON public."NavigationItem" USING btree ("NavigationModuleId");

--
-- Name: idx_notification_outbox_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_outbox_due ON public."NotificationOutbox" USING btree ("NextAttemptAt") WHERE (("Status")::text = 'Pending'::text);

--
-- Name: idx_notification_outbox_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_outbox_patient ON public."NotificationOutbox" USING btree ("PatientId", "CreatedAt");

--
-- Name: idx_patient_allergy_allergy_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_allergy_allergy_code ON public."PatientAllergy" USING btree ("AllergyCode");

--
-- Name: idx_patient_allergy_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_allergy_patient_id ON public."PatientAllergy" USING btree ("PatientId");

--
-- Name: idx_patient_allergy_severity_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_allergy_severity_code ON public."PatientAllergy" USING btree ("SeverityCode");

--
-- Name: idx_patient_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_is_active ON public."Patient" USING btree ("IsActive") WHERE ("IsActive" = true);

--
-- Name: idx_patient_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_person_id ON public."Patient" USING btree ("PersonId");

--
-- Name: idx_person_document_document_type_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_document_document_type_code ON public."PersonDocument" USING btree ("DocumentTypeCode");

--
-- Name: idx_person_document_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_document_person_id ON public."PersonDocument" USING btree ("PersonId");

--
-- Name: idx_person_last_surnames; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_last_surnames ON public."Person" USING btree ("Surnames");

--
-- Name: idx_person_sex_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_sex_code ON public."Person" USING btree ("SexCode");

--
-- Name: idx_prescription_detail_admin_route_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_detail_admin_route_code ON public."PrescriptionDetail" USING btree ("AdministrationRouteCode");

--
-- Name: idx_prescription_detail_frequency_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_detail_frequency_code ON public."PrescriptionDetail" USING btree ("FrequencyCode");

--
-- Name: idx_prescription_detail_medication_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_detail_medication_code ON public."PrescriptionDetail" USING btree ("MedicationCode");

--
-- Name: idx_prescription_detail_prescription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_detail_prescription_id ON public."PrescriptionDetail" USING btree ("PrescriptionId");

--
-- Name: idx_prescription_diagnostic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_diagnostic_id ON public."Prescription" USING btree ("DiagnosticId");

--
-- Name: idx_prescription_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_patient_id ON public."Prescription" USING btree ("PatientId");

--
-- Name: idx_prescription_patient_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_patient_status ON public."Prescription" USING btree ("PatientId", "PrescriptionStatusId") WHERE ("DeletedAt" IS NULL);

--
-- Name: idx_prescription_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_status_id ON public."Prescription" USING btree ("PrescriptionStatusId");

--
-- Name: idx_prescription_unsigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_unsigned ON public."Prescription" USING btree ("UserId", "CreatedAt") WHERE (("SignedAt" IS NULL) AND ("DeletedAt" IS NULL));

--
-- Name: idx_prescription_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_user_id ON public."Prescription" USING btree ("UserId");

--
-- Name: idx_prescription_valid_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prescription_valid_until ON public."Prescription" USING btree ("ValidUntil");

--
-- Name: idx_privacy_ack_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privacy_ack_patient ON public."PatientPrivacyNoticeAck" USING btree ("PatientId");

--
-- Name: idx_refresh_token_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_token_active ON public."RefreshToken" USING btree ("UserId", "ExpiresAt") WHERE ("RevokedAt" IS NULL);

--
-- Name: idx_refresh_token_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_token_user_id ON public."RefreshToken" USING btree ("UserId");

--
-- Name: idx_role_nav_access_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_nav_access_item_id ON public."RoleNavigationAccess" USING btree ("NavigationItemId");

--
-- Name: idx_role_nav_access_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_nav_access_lookup ON public."RoleNavigationAccess" USING btree ("RoleId", "NavigationModuleId", "DisplayOrder") INCLUDE ("NavigationItemId");

--
-- Name: idx_role_nav_access_module_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_nav_access_module_id ON public."RoleNavigationAccess" USING btree ("NavigationModuleId");

--
-- Name: idx_role_nav_access_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_nav_access_role_id ON public."RoleNavigationAccess" USING btree ("RoleId");

--
-- Name: idx_stock_movement_detail; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_detail ON public."StockMovement" USING btree ("PrescriptionDetailId") WHERE ("PrescriptionDetailId" IS NOT NULL);

--
-- Name: idx_stock_movement_med_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_med_time ON public."StockMovement" USING btree ("ClinicId", "MedicationCode", "OccurredAt" DESC);

--
-- Name: idx_stock_movement_shortfall; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_shortfall ON public."StockMovement" USING btree ("OccurredAt") WHERE ("ShortfallQuantity" IS NOT NULL);

--
-- Name: idx_stock_movement_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_user_time ON public."StockMovement" USING btree ("UserId", "OccurredAt");

--
-- Name: idx_user_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_is_active ON public."User" USING btree ("IsActive") WHERE ("IsActive" = true);

--
-- Name: idx_user_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_person_id ON public."User" USING btree ("PersonId");

--
-- Name: idx_user_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_role_id ON public."User" USING btree ("RoleId");

--
-- Name: idx_user_specialty_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_specialty_code ON public."User" USING btree ("SpecialtyCode");

--
-- Name: uq_clinic_single_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_clinic_single_default ON public."Clinic" USING btree ("IsDefault") WHERE "IsDefault";

--
-- Name: uq_diagnostic_appointment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_diagnostic_appointment ON public."Diagnostic" USING btree ("AppointmentId") WHERE ("DeletedAt" IS NULL);

--
-- Name: uq_prescription_diagnostic; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_prescription_diagnostic ON public."Prescription" USING btree ("DiagnosticId") WHERE ("DeletedAt" IS NULL);

--
-- Name: ActivityEvent trg_activity_event_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_activity_event_immutable BEFORE DELETE OR UPDATE ON public."ActivityEvent" FOR EACH ROW EXECUTE FUNCTION public.activity_event_immutable();

--
-- Name: PatientAmendmentRequest trg_amendment_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_amendment_guard BEFORE DELETE OR UPDATE ON public."PatientAmendmentRequest" FOR EACH ROW EXECUTE FUNCTION public.amendment_request_guard();

--
-- Name: AuditLog trg_audit_log_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_log_immutable BEFORE DELETE OR UPDATE ON public."AuditLog" FOR EACH ROW EXECUTE FUNCTION public.audit_log_immutable();

--
-- Name: BreakGlassGrant trg_break_glass_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_break_glass_immutable BEFORE DELETE OR UPDATE ON public."BreakGlassGrant" FOR EACH ROW EXECUTE FUNCTION public.break_glass_grant_immutable();

--
-- Name: PatientConsent trg_consent_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_consent_guard BEFORE DELETE OR UPDATE ON public."PatientConsent" FOR EACH ROW EXECUTE FUNCTION public.patient_consent_guard();

--
-- Name: PatientDisclosure trg_disclosure_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_disclosure_immutable BEFORE DELETE OR UPDATE ON public."PatientDisclosure" FOR EACH ROW EXECUTE FUNCTION public.patient_disclosure_immutable();

--
-- Name: PatientPrivacyNoticeAck trg_privacy_ack_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_privacy_ack_immutable BEFORE DELETE OR UPDATE ON public."PatientPrivacyNoticeAck" FOR EACH ROW EXECUTE FUNCTION public.privacy_append_only();

--
-- Name: PrivacyNotice trg_privacy_notice_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_privacy_notice_immutable BEFORE DELETE OR UPDATE ON public."PrivacyNotice" FOR EACH ROW EXECUTE FUNCTION public.privacy_append_only();

--
-- Name: StockMovement trg_stock_movement_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stock_movement_immutable BEFORE DELETE OR UPDATE ON public."StockMovement" FOR EACH ROW EXECUTE FUNCTION public.stock_movement_immutable();

--
-- Name: ActivityEvent ActivityEvent_ActorUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ActivityEvent"
    ADD CONSTRAINT "ActivityEvent_ActorUserId_fkey" FOREIGN KEY ("ActorUserId") REFERENCES public."User"("UserId");

--
-- Name: AppointmentPayment AppointmentPayment_AppointmentId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentPayment"
    ADD CONSTRAINT "AppointmentPayment_AppointmentId_fkey" FOREIGN KEY ("AppointmentId") REFERENCES public."Appointment"("AppointmentId");

--
-- Name: AppointmentPayment AppointmentPayment_RecordedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AppointmentPayment"
    ADD CONSTRAINT "AppointmentPayment_RecordedBy_fkey" FOREIGN KEY ("RecordedBy") REFERENCES public."User"("UserId");

--
-- Name: Appointment Appointment_AppointmentStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_AppointmentStatusId_fkey" FOREIGN KEY ("AppointmentStatusId") REFERENCES public."AppointmentStatus"("AppointmentStatusId");

--
-- Name: Appointment Appointment_ConsultationTypeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_ConsultationTypeId_fkey" FOREIGN KEY ("ConsultationTypeId") REFERENCES public."ConsultationType"("ConsultationTypeId");

--
-- Name: Appointment Appointment_DoctorAvailabilityId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_DoctorAvailabilityId_fkey" FOREIGN KEY ("DoctorAvailabilityId") REFERENCES public."DoctorAvailability"("DoctorAvailabilityId");

--
-- Name: Appointment Appointment_DoctorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_DoctorId_fkey" FOREIGN KEY ("DoctorId") REFERENCES public."User"("UserId");

--
-- Name: Appointment Appointment_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: Appointment Appointment_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Appointment"
    ADD CONSTRAINT "Appointment_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: AuditLog AuditLog_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AuditLog"
    ADD CONSTRAINT "AuditLog_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: BreakGlassGrant BreakGlassGrant_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BreakGlassGrant"
    ADD CONSTRAINT "BreakGlassGrant_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: BreakGlassGrant BreakGlassGrant_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BreakGlassGrant"
    ADD CONSTRAINT "BreakGlassGrant_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: ClinicStock ClinicStock_ClinicId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ClinicStock"
    ADD CONSTRAINT "ClinicStock_ClinicId_fkey" FOREIGN KEY ("ClinicId") REFERENCES public."Clinic"("ClinicId");

--
-- Name: ClinicStock ClinicStock_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ClinicStock"
    ADD CONSTRAINT "ClinicStock_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: Clinic Clinic_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Clinic"
    ADD CONSTRAINT "Clinic_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: Diagnostic Diagnostic_AppointmentId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_AppointmentId_fkey" FOREIGN KEY ("AppointmentId") REFERENCES public."Appointment"("AppointmentId");

--
-- Name: Diagnostic Diagnostic_CreatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_CreatedBy_fkey" FOREIGN KEY ("CreatedBy") REFERENCES public."User"("UserId");

--
-- Name: Diagnostic Diagnostic_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: Diagnostic Diagnostic_DiagnosticStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_DiagnosticStatusId_fkey" FOREIGN KEY ("DiagnosticStatusId") REFERENCES public."DiagnosticStatus"("DiagnosticStatusId");

--
-- Name: Diagnostic Diagnostic_ModifiedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Diagnostic"
    ADD CONSTRAINT "Diagnostic_ModifiedBy_fkey" FOREIGN KEY ("ModifiedBy") REFERENCES public."User"("UserId");

--
-- Name: DoctorAvailability DoctorAvailability_CreatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT "DoctorAvailability_CreatedBy_fkey" FOREIGN KEY ("CreatedBy") REFERENCES public."User"("UserId");

--
-- Name: DoctorAvailability DoctorAvailability_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT "DoctorAvailability_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: DoctorAvailability DoctorAvailability_DoctorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DoctorAvailability"
    ADD CONSTRAINT "DoctorAvailability_DoctorId_fkey" FOREIGN KEY ("DoctorId") REFERENCES public."User"("UserId");

--
-- Name: NavigationItem NavigationItem_NavigationModuleId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NavigationItem"
    ADD CONSTRAINT "NavigationItem_NavigationModuleId_fkey" FOREIGN KEY ("NavigationModuleId") REFERENCES public."NavigationModule"("NavigationModuleId");

--
-- Name: NotificationOutbox NotificationOutbox_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NotificationOutbox"
    ADD CONSTRAINT "NotificationOutbox_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PartnerConfig PartnerConfig_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerConfig"
    ADD CONSTRAINT "PartnerConfig_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: PartnerInsurance PartnerInsurance_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerInsurance"
    ADD CONSTRAINT "PartnerInsurance_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: PartnerMedication PartnerMedication_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerMedication"
    ADD CONSTRAINT "PartnerMedication_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: PartnerSpecialty PartnerSpecialty_UpdatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PartnerSpecialty"
    ADD CONSTRAINT "PartnerSpecialty_UpdatedBy_fkey" FOREIGN KEY ("UpdatedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientAllergy PatientAllergy_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy"
    ADD CONSTRAINT "PatientAllergy_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientAllergy PatientAllergy_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAllergy"
    ADD CONSTRAINT "PatientAllergy_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientAmendmentRequest PatientAmendmentRequest_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAmendmentRequest"
    ADD CONSTRAINT "PatientAmendmentRequest_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientAmendmentRequest PatientAmendmentRequest_ReviewedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientAmendmentRequest"
    ADD CONSTRAINT "PatientAmendmentRequest_ReviewedBy_fkey" FOREIGN KEY ("ReviewedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientCommunicationPreference PatientCommunicationPreference_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientCommunicationPreference"
    ADD CONSTRAINT "PatientCommunicationPreference_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientConsent PatientConsent_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent"
    ADD CONSTRAINT "PatientConsent_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientConsent PatientConsent_RecordedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent"
    ADD CONSTRAINT "PatientConsent_RecordedBy_fkey" FOREIGN KEY ("RecordedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientConsent PatientConsent_RevokedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientConsent"
    ADD CONSTRAINT "PatientConsent_RevokedBy_fkey" FOREIGN KEY ("RevokedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientDisclosure PatientDisclosure_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientDisclosure"
    ADD CONSTRAINT "PatientDisclosure_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientDisclosure PatientDisclosure_RecordedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientDisclosure"
    ADD CONSTRAINT "PatientDisclosure_RecordedBy_fkey" FOREIGN KEY ("RecordedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientPrivacyNoticeAck PatientPrivacyNoticeAck_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck"
    ADD CONSTRAINT "PatientPrivacyNoticeAck_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: PatientPrivacyNoticeAck PatientPrivacyNoticeAck_PrivacyNoticeId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck"
    ADD CONSTRAINT "PatientPrivacyNoticeAck_PrivacyNoticeId_fkey" FOREIGN KEY ("PrivacyNoticeId") REFERENCES public."PrivacyNotice"("PrivacyNoticeId");

--
-- Name: PatientPrivacyNoticeAck PatientPrivacyNoticeAck_RecordedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientPrivacyNoticeAck"
    ADD CONSTRAINT "PatientPrivacyNoticeAck_RecordedBy_fkey" FOREIGN KEY ("RecordedBy") REFERENCES public."User"("UserId");

--
-- Name: PatientRefreshToken PatientRefreshToken_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PatientRefreshToken"
    ADD CONSTRAINT "PatientRefreshToken_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: Patient Patient_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient"
    ADD CONSTRAINT "Patient_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: Patient Patient_PersonId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Patient"
    ADD CONSTRAINT "Patient_PersonId_fkey" FOREIGN KEY ("PersonId") REFERENCES public."Person"("PersonId");

--
-- Name: PersonDocument PersonDocument_PersonId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PersonDocument"
    ADD CONSTRAINT "PersonDocument_PersonId_fkey" FOREIGN KEY ("PersonId") REFERENCES public."Person"("PersonId");

--
-- Name: PrescriptionDetail PrescriptionDetail_PrescriptionId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrescriptionDetail"
    ADD CONSTRAINT "PrescriptionDetail_PrescriptionId_fkey" FOREIGN KEY ("PrescriptionId") REFERENCES public."Prescription"("PrescriptionId");

--
-- Name: Prescription Prescription_CreatedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_CreatedBy_fkey" FOREIGN KEY ("CreatedBy") REFERENCES public."User"("UserId");

--
-- Name: Prescription Prescription_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: Prescription Prescription_DiagnosticId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_DiagnosticId_fkey" FOREIGN KEY ("DiagnosticId") REFERENCES public."Diagnostic"("DiagnosticId");

--
-- Name: Prescription Prescription_DispensedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_DispensedBy_fkey" FOREIGN KEY ("DispensedBy") REFERENCES public."User"("UserId");

--
-- Name: Prescription Prescription_ModifiedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_ModifiedBy_fkey" FOREIGN KEY ("ModifiedBy") REFERENCES public."User"("UserId");

--
-- Name: Prescription Prescription_PatientId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_PatientId_fkey" FOREIGN KEY ("PatientId") REFERENCES public."Patient"("PatientId");

--
-- Name: Prescription Prescription_PrescriptionStatusId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_PrescriptionStatusId_fkey" FOREIGN KEY ("PrescriptionStatusId") REFERENCES public."PrescriptionStatus"("PrescriptionStatusId");

--
-- Name: Prescription Prescription_SignedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_SignedBy_fkey" FOREIGN KEY ("SignedBy") REFERENCES public."User"("UserId");

--
-- Name: Prescription Prescription_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Prescription"
    ADD CONSTRAINT "Prescription_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: PrivacyNotice PrivacyNotice_PublishedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PrivacyNotice"
    ADD CONSTRAINT "PrivacyNotice_PublishedBy_fkey" FOREIGN KEY ("PublishedBy") REFERENCES public."User"("UserId");

--
-- Name: RefreshToken RefreshToken_RevokedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_RevokedBy_fkey" FOREIGN KEY ("RevokedBy") REFERENCES public."User"("UserId");

--
-- Name: RefreshToken RefreshToken_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: RoleNavigationAccess RoleNavigationAccess_NavigationItemId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess"
    ADD CONSTRAINT "RoleNavigationAccess_NavigationItemId_fkey" FOREIGN KEY ("NavigationItemId") REFERENCES public."NavigationItem"("NavigationItemId");

--
-- Name: RoleNavigationAccess RoleNavigationAccess_NavigationModuleId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess"
    ADD CONSTRAINT "RoleNavigationAccess_NavigationModuleId_fkey" FOREIGN KEY ("NavigationModuleId") REFERENCES public."NavigationModule"("NavigationModuleId");

--
-- Name: RoleNavigationAccess RoleNavigationAccess_RoleId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RoleNavigationAccess"
    ADD CONSTRAINT "RoleNavigationAccess_RoleId_fkey" FOREIGN KEY ("RoleId") REFERENCES public."Role"("RoleId");

--
-- Name: StockMovement StockMovement_ClinicId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement"
    ADD CONSTRAINT "StockMovement_ClinicId_fkey" FOREIGN KEY ("ClinicId") REFERENCES public."Clinic"("ClinicId");

--
-- Name: StockMovement StockMovement_PrescriptionDetailId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement"
    ADD CONSTRAINT "StockMovement_PrescriptionDetailId_fkey" FOREIGN KEY ("PrescriptionDetailId") REFERENCES public."PrescriptionDetail"("PrescriptionDetailId");

--
-- Name: StockMovement StockMovement_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."StockMovement"
    ADD CONSTRAINT "StockMovement_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: UserLockout UserLockout_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserLockout"
    ADD CONSTRAINT "UserLockout_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: UserMfa UserMfa_UserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserMfa"
    ADD CONSTRAINT "UserMfa_UserId_fkey" FOREIGN KEY ("UserId") REFERENCES public."User"("UserId");

--
-- Name: User User_DeletedBy_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_DeletedBy_fkey" FOREIGN KEY ("DeletedBy") REFERENCES public."User"("UserId");

--
-- Name: User User_PersonId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_PersonId_fkey" FOREIGN KEY ("PersonId") REFERENCES public."Person"("PersonId");

--
-- Name: User User_RoleId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_RoleId_fkey" FOREIGN KEY ("RoleId") REFERENCES public."Role"("RoleId");

--
-- PostgreSQL database dump complete
--
