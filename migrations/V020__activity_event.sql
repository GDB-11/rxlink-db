-- =============================================================================
-- V020: ActivityEvent - business events layer (Phase 2.3)
-- Readable "who did what" records emitted by the API inside the same transaction
-- as the business change they describe (or, for auth events, right after it).
-- Append-only. Complements the row-level AuditLog (V019).
-- =============================================================================

CREATE TABLE "ActivityEvent" (
    "ActivityEventId" BIGSERIAL    PRIMARY KEY,
    "EventType"       VARCHAR(100) NOT NULL,              -- e.g. 'Prescription.Signed'
    "ActorUserId"     INTEGER               REFERENCES "User" ("UserId"),  -- NULL: anonymous/system/patient
    "EntityType"      VARCHAR(100),
    "EntityCode"      UUID,
    "Summary"         TEXT         NOT NULL,              -- human readable, no clinical content
    "Payload"         JSONB,
    "OccurredAt"      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    "IpAddress"       INET,
    "RequestId"       TEXT
);

CREATE INDEX idx_activity_event_type_time  ON "ActivityEvent" ("EventType", "OccurredAt");
CREATE INDEX idx_activity_event_actor_time ON "ActivityEvent" ("ActorUserId", "OccurredAt");
CREATE INDEX idx_activity_event_entity     ON "ActivityEvent" ("EntityType", "EntityCode");
CREATE INDEX idx_activity_event_time_brin  ON "ActivityEvent" USING BRIN ("OccurredAt");

REVOKE UPDATE, DELETE, TRUNCATE ON "ActivityEvent" FROM PUBLIC;

CREATE OR REPLACE FUNCTION activity_event_immutable() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'ActivityEvent is append-only (% not allowed)', TG_OP;
END;
$$;

CREATE TRIGGER trg_activity_event_immutable
    BEFORE UPDATE OR DELETE ON "ActivityEvent"
    FOR EACH ROW EXECUTE FUNCTION activity_event_immutable();
