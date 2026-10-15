-- =============================================================================
-- V018: AuditLog context columns (Phase 2.1)
--   * RecordKey  - public key of the changed row (UUID/composite keys that do not fit RecordId)
--   * ChangedColumns, RequestId - diff summary and request correlation
--   * RecordId becomes nullable (tables without an integer key)
--   * Indexes for per-record, per-user and time-range lookups
-- The API stamps app.user_code / app.ip / app.request_id per transaction
-- (BaseDatabaseService.ExecuteAuditedWriteAsync); triggers arrive in V019.
-- =============================================================================

ALTER TABLE "AuditLog"
    ALTER COLUMN "RecordId" DROP NOT NULL,
    ADD COLUMN "RecordKey"      TEXT,
    ADD COLUMN "ChangedColumns" TEXT[],
    ADD COLUMN "RequestId"      TEXT;

CREATE INDEX idx_audit_log_table_record_key ON "AuditLog" ("TableName", "RecordKey");
CREATE INDEX idx_audit_log_occurred_at      ON "AuditLog" ("OccurredAt");
