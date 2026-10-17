-- =============================================================================
-- S000: demo administrator (UserId 1)
-- SYNTHETIC DEMO DATA ONLY. Never apply to a database with real patients.
-- The later seeds reference UserId 1 as the creator/dispenser. No-op if User 1 already exists
-- (for example the devstack creates its own staff users first). The password hash is the same
-- value the old V014 seed used for every demo account; it only decrypts under the master key
-- that produced it, so log in with a user created through the documented first-user procedure.
-- =============================================================================
DO $$
DECLARE v_person INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM "User" WHERE "UserId" = 1) THEN RETURN; END IF;
    INSERT INTO "Person" ("Names","Surnames","BirthDate","SexCode","Phone","Email")
    VALUES ('Admin','Demo','1990-01-01','c0de0001-0000-4000-8000-000000000001','+51 999 000 001','admin.demo@rxlink.local')
    RETURNING "PersonId" INTO v_person;
    INSERT INTO "User" ("UserId","PersonId","RoleId","Username","Email","PasswordHash","IsActive")
    OVERRIDING SYSTEM VALUE
    VALUES (1, v_person, 1, 'admindemo', 'admin.demo@rxlink.local', 'wJESTpMQRhol5CuXKcCKxZeicN1dEmGYVhFT+zOkYswoMRSXiA==', TRUE);
END $$;
