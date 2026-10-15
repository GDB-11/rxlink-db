-- ---------------------------------------------------------------------------
-- Phase 11.3a — notification outbox.
--
-- Plan §13 (Notifications), §19.4. One row per message to send. The row holds NO
-- message text and NO contact data: only the template type and non-clinical
-- parameters (a date). The text is rendered and the recipient resolved from
-- Person at send time, so a message can never carry a diagnosis or a medication
-- name, and a changed phone/email is honoured.
--
-- "DedupKey" makes the producers idempotent (one reminder per entity + channel).
-- Status: Pending → Sent | Failed (attempts exhausted) | Skipped (no contact data,
-- inactive patient, or the patient's preferences forbid the channel).
-- Not audited by trigger: written only by the system, and it is its own record.
-- ---------------------------------------------------------------------------

CREATE TABLE "NotificationOutbox" (
    "NotificationId"   BIGSERIAL    PRIMARY KEY,
    "NotificationCode" UUID         NOT NULL DEFAULT uuidv7() UNIQUE,
    "NotificationType" VARCHAR(50)  NOT NULL,
    "Channel"          VARCHAR(10)  NOT NULL,
    "PatientId"        INTEGER      NOT NULL REFERENCES "Patient" ("PatientId"),
    "EntityType"       VARCHAR(100) NOT NULL,
    "EntityCode"       UUID         NOT NULL,
    "Parameters"       JSONB        NOT NULL DEFAULT '{}'::jsonb,
    "DedupKey"         TEXT         NOT NULL UNIQUE,
    "Status"           VARCHAR(10)  NOT NULL DEFAULT 'Pending',
    "Attempts"         INTEGER      NOT NULL DEFAULT 0,
    "NextAttemptAt"    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "SentAt"           TIMESTAMPTZ,
    "LastErrorType"    VARCHAR(100),
    "CreatedAt"        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_notification_type    CHECK ("NotificationType" IN ('AppointmentReminder', 'PrescriptionExpiring')),
    CONSTRAINT ck_notification_channel CHECK ("Channel" IN ('Email', 'Sms')),
    CONSTRAINT ck_notification_status  CHECK ("Status" IN ('Pending', 'Sent', 'Failed', 'Skipped')),
    CONSTRAINT ck_notification_sent    CHECK (("Status" = 'Sent') = ("SentAt" IS NOT NULL)),
    CONSTRAINT ck_notification_attempts CHECK ("Attempts" >= 0)
);

CREATE INDEX idx_notification_outbox_due ON "NotificationOutbox" ("NextAttemptAt") WHERE "Status" = 'Pending';
CREATE INDEX idx_notification_outbox_patient ON "NotificationOutbox" ("PatientId", "CreatedAt");
