-- =============================================================================
-- V021: AuditLog partial index for the "writes with no actor" signal (Phase 2.4)
-- (per-user history is already covered by idx_audit_log_user_time from V001)
-- =============================================================================

CREATE INDEX idx_audit_log_unattributed ON "AuditLog" ("OccurredAt") WHERE "UserId" IS NULL;
