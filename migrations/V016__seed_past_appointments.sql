-- =============================================================================
-- V016: Past appointments with diagnostics and prescriptions
-- 5 patients × 3-4 completed appointments each, with diagnostics and prescriptions
--
-- Patients:
--   12  Jorge Ramírez Torres   (M, 1985) — Medicina General   / Dr. Luis García    (UserId=9)
--   14  Carlos Martínez Silva  (M, 1974) — Cardiología        / Dr. Ana López      (UserId=12)
--   15  María García Morales   (F, 1987) — Neurología         / Dr. Patricia Pérez (UserId=16)
--   16  Ana López Flores       (F, 1968) — Endocrinología     / Dr. C. Espinoza    (UserId=60)
--   17  Rosa Martínez Herrera  (F, 1983) — Psiquiatría        / Dr. Julia Olivera  (UserId=95)
--
-- Existing medication IDs used:
--   40=Enalapril 10mg  33=Metformina 850mg  74=Atorvastatina 20mg  41=Atorvastatina 40mg
--   17=Losartán 50mg   15=Omeprazol 20mg    43=Amlodipino 5mg      42=Paracetamol 500mg
--   58=Fluoxetina 20mg 83=Alprazolam 0.5mg  57=Clonazepam 2mg
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New medications (auto-increment — do not override sequence)
--    Referenced by name in PrescriptionDetail via scalar subqueries
-- ---------------------------------------------------------------------------

INSERT INTO "Medication"
    ("PharmaceuticalFormId","AdministrationRouteId","GenericName","CommercialName","Concentration")
VALUES
    (1,1,'Metoprolol',   'Lopressor',  '50 mg'),
    (1,1,'Sumatriptán',  'Imigran',    '50 mg'),
    (1,1,'Levotiroxina', 'Eutirox',    '50 mcg'),
    (1,1,'Zolpidem',     'Stilnox',    '10 mg');

-- ---------------------------------------------------------------------------
-- 2. DoctorAvailability — past slots (all IsBooked = TRUE)
--    IDs start at 91255 (current MAX = 91254); 17 contiguous slots
-- ---------------------------------------------------------------------------

INSERT INTO "DoctorAvailability"
    ("DoctorAvailabilityId","DoctorId","Date","StartTime",
     "IsBooked","CreatedBy","CreatedAt")
    OVERRIDING SYSTEM VALUE VALUES
    -- Dr. Luis García (UserId=9) — Patient 12
    (91255, 9,'2025-08-15','09:00:00',TRUE,1,'2025-08-01 08:00:00-05'),
    (91256, 9,'2025-10-20','09:00:00',TRUE,1,'2025-10-01 08:00:00-05'),
    (91257, 9,'2026-01-12','09:00:00',TRUE,1,'2025-12-15 08:00:00-05'),
    (91258, 9,'2026-04-10','09:00:00',TRUE,1,'2026-03-20 08:00:00-05'),
    -- Dr. Ana López (UserId=12, Cardiología) — Patient 14
    (91259,12,'2025-09-05','10:00:00',TRUE,1,'2025-08-20 08:00:00-05'),
    (91260,12,'2025-12-08','10:00:00',TRUE,1,'2025-11-20 08:00:00-05'),
    (91261,12,'2026-03-14','10:00:00',TRUE,1,'2026-02-25 08:00:00-05'),
    -- Dr. Patricia Pérez (UserId=16, Neurología) — Patient 15
    (91262,16,'2025-07-22','08:00:00',TRUE,1,'2025-07-07 08:00:00-05'),
    (91263,16,'2025-09-30','08:00:00',TRUE,1,'2025-09-10 08:00:00-05'),
    (91264,16,'2026-02-14','08:00:00',TRUE,1,'2026-01-28 08:00:00-05'),
    (91265,16,'2026-05-10','08:00:00',TRUE,1,'2026-04-20 08:00:00-05'),
    -- Dr. Carolina Espinoza (UserId=60, Endocrinología) — Patient 16
    (91266,60,'2025-08-28','11:00:00',TRUE,1,'2025-08-10 08:00:00-05'),
    (91267,60,'2025-11-15','11:00:00',TRUE,1,'2025-10-28 08:00:00-05'),
    (91268,60,'2026-02-20','11:00:00',TRUE,1,'2026-02-05 08:00:00-05'),
    -- Dr. Julia Olivera (UserId=95, Psiquiatría) — Patient 17
    (91269,95,'2025-10-03','14:00:00',TRUE,1,'2025-09-15 08:00:00-05'),
    (91270,95,'2026-01-22','14:00:00',TRUE,1,'2026-01-05 08:00:00-05'),
    (91271,95,'2026-05-08','14:00:00',TRUE,1,'2026-04-20 08:00:00-05');

-- ---------------------------------------------------------------------------
-- 3. Appointments — all Completado (AppointmentStatusId = 3)
--    IDs 29-45 (current MAX = 28); explicit IDs anchor the downstream chain
-- ---------------------------------------------------------------------------

INSERT INTO "Appointment"
    ("AppointmentId",
     "PatientId","DoctorId","DoctorAvailabilityId",
     "ConsultationTypeId","AppointmentStatusId","ScheduledAt",
     "CreatedAt","UpdatedAt","UpdatedBy")
    OVERRIDING SYSTEM VALUE VALUES
    -- Patient 12 / Dr. García (Medicina General)
    (29, 12, 9,91255,2,3,'2025-08-15 09:00:00-05','2025-08-01 10:00:00-05','2025-08-15 10:00:00-05', 9),
    (30, 12, 9,91256,2,3,'2025-10-20 09:00:00-05','2025-10-01 10:00:00-05','2025-10-20 10:00:00-05', 9),
    (31, 12, 9,91257,2,3,'2026-01-12 09:00:00-05','2025-12-15 10:00:00-05','2026-01-12 10:00:00-05', 9),
    (32, 12, 9,91258,2,3,'2026-04-10 09:00:00-05','2026-03-20 10:00:00-05','2026-04-10 10:00:00-05', 9),
    -- Patient 14 / Dr. López (Cardiología)
    (33, 14,12,91259,2,3,'2025-09-05 10:00:00-05','2025-08-20 10:00:00-05','2025-09-05 11:00:00-05',12),
    (34, 14,12,91260,2,3,'2025-12-08 10:00:00-05','2025-11-20 10:00:00-05','2025-12-08 11:00:00-05',12),
    (35, 14,12,91261,2,3,'2026-03-14 10:00:00-05','2026-02-25 10:00:00-05','2026-03-14 11:00:00-05',12),
    -- Patient 15 / Dr. Pérez (Neurología)
    (36, 15,16,91262,2,3,'2025-07-22 08:00:00-05','2025-07-07 10:00:00-05','2025-07-22 09:00:00-05',16),
    (37, 15,16,91263,1,3,'2025-09-30 08:00:00-05','2025-09-10 10:00:00-05','2025-09-30 09:00:00-05',16),
    (38, 15,16,91264,2,3,'2026-02-14 08:00:00-05','2026-01-28 10:00:00-05','2026-02-14 09:00:00-05',16),
    (39, 15,16,91265,1,3,'2026-05-10 08:00:00-05','2026-04-20 10:00:00-05','2026-05-10 09:00:00-05',16),
    -- Patient 16 / Dr. Espinoza (Endocrinología)
    (40, 16,60,91266,2,3,'2025-08-28 11:00:00-05','2025-08-10 10:00:00-05','2025-08-28 12:00:00-05',60),
    (41, 16,60,91267,2,3,'2025-11-15 11:00:00-05','2025-10-28 10:00:00-05','2025-11-15 12:00:00-05',60),
    (42, 16,60,91268,2,3,'2026-02-20 11:00:00-05','2026-02-05 10:00:00-05','2026-02-20 12:00:00-05',60),
    -- Patient 17 / Dr. Olivera (Psiquiatría)
    (43, 17,95,91269,2,3,'2025-10-03 14:00:00-05','2025-09-15 10:00:00-05','2025-10-03 15:00:00-05',95),
    (44, 17,95,91270,1,3,'2026-01-22 14:00:00-05','2026-01-05 10:00:00-05','2026-01-22 15:00:00-05',95),
    (45, 17,95,91271,2,3,'2026-05-08 14:00:00-05','2026-04-20 10:00:00-05','2026-05-08 15:00:00-05',95);

-- ---------------------------------------------------------------------------
-- 4. Diagnostics — one per appointment (AppointmentIds 29-45)
-- ---------------------------------------------------------------------------

INSERT INTO "Diagnostic"
    ("DiagnosticStatusId","AppointmentId",
     "Description","DiagnosedAt","Notes","CreatedBy","CreatedAt")
VALUES
    -- Patient 12: Hipertensión + Diabetes mellitus tipo 2
    (2,29,
     'Hipertensión arterial esencial. PAS 155/PAD 95 mmHg. Inicio de manejo antihipertensivo.',
     '2025-08-15', NULL, 9,'2025-08-15 09:30:00-05'),
    (2,30,
     'Hipertensión arterial con control subóptimo. Glucemia basal 145 mg/dL; diagnóstico de Diabetes mellitus tipo 2. Inicio de terapia combinada.',
     '2025-10-20','Control de PA y glucemia en próxima cita.', 9,'2025-10-20 09:30:00-05'),
    (2,31,
     'Hipertensión arterial y Diabetes mellitus tipo 2. PA 138/88 mmHg, glucemia 112 mg/dL. Cambio de enalapril a losartán por tos seca.',
     '2026-01-12','Reevaluar PA y glucemia en 3 meses.', 9,'2026-01-12 09:30:00-05'),
    (1,32,
     'Hipertensión arterial y Diabetes mellitus tipo 2 con buen control metabólico. HbA1c 6.8%, PA 130/82 mmHg.',
     '2026-04-10','Control satisfactorio. Mantener tratamiento actual.', 9,'2026-04-10 09:30:00-05'),
    -- Patient 14: Cardiopatía isquémica + Dislipidemia + HTA
    (2,33,
     'Cardiopatía isquémica estable. Angina de esfuerzo clase II (CCS). Dislipidemia mixta: LDL 158 mg/dL. Inicio de triple esquema cardiovascular.',
     '2025-09-05','Informar signos de alarma cardiovascular.',12,'2025-09-05 10:30:00-05'),
    (2,34,
     'Cardiopatía isquémica con angina controlada. LDL 112 mg/dL en descenso. Tolerancia adecuada al esquema actual.',
     '2025-12-08','Optimizar dosis de atorvastatina; meta LDL <70 mg/dL.',12,'2025-12-08 10:30:00-05'),
    (1,35,
     'Cardiopatía isquémica estable. LDL 78 mg/dL en objetivo terapéutico. PA 145/90 mmHg; adición de ARB.',
     '2026-03-14','LDL en meta. Controlar PA en próxima visita.',12,'2026-03-14 10:30:00-05'),
    -- Patient 15: Migraña + Trastorno depresivo mayor
    (2,36,
     'Migraña sin aura con episodios frecuentes (>4/mes, duración 12-24 h, EVA 7-8/10). Inicio de tratamiento de rescate.',
     '2025-07-22','Solicitar diario de cefalea para próxima cita.',16,'2025-07-22 08:30:00-05'),
    (2,37,
     'Migraña con respuesta parcial al rescate: episodios reducidos a 2/mes. Trastorno depresivo mayor leve (PHQ-9: 10). Adición de antidepresivo.',
     '2025-09-30','Reevaluar PHQ-9 y tolerancia a fluoxetina en 8 semanas.',16,'2025-09-30 08:30:00-05'),
    (2,38,
     'Migraña en control adecuado (<2 episodios/mes). Episodio depresivo en remisión parcial (PHQ-9: 5).',
     '2026-02-14','Continuar psicoterapia cognitivo-conductual.',16,'2026-02-14 08:30:00-05'),
    (1,39,
     'Migraña crónica en remisión terapéutica (<1 episodio/mes). Trastorno depresivo mayor en tratamiento estable (PHQ-9: 3).',
     '2026-05-10','Excelente respuesta combinada. Mantener 6 meses adicionales.',16,'2026-05-10 08:30:00-05'),
    -- Patient 16: Hipotiroidismo + Diabetes mellitus tipo 2
    (2,40,
     'Hipotiroidismo primario. TSH 12.4 mUI/L, T4L 0.6 ng/dL. Inicio de terapia sustitutiva con levotiroxina.',
     '2025-08-28','Control tiroideo en 6 semanas.',60,'2025-08-28 11:30:00-05'),
    (2,41,
     'Hipotiroidismo en tratamiento. TSH 3.1 mUI/L. Diabetes mellitus tipo 2 con HbA1c 7.9%. Inicio de metformina.',
     '2025-11-15','Ajustar levotiroxina; agregar metformina por DM2.',60,'2025-11-15 11:30:00-05'),
    (1,42,
     'Hipotiroidismo controlado. TSH 2.0 mUI/L. Diabetes mellitus tipo 2 con HbA1c 7.1%. Mantenimiento terapéutico.',
     '2026-02-20','Ambas condiciones en objetivo. Mantener dosis.',60,'2026-02-20 11:30:00-05'),
    -- Patient 17: Trastorno de ansiedad generalizada + Insomnio crónico
    (2,43,
     'Trastorno de ansiedad generalizada (TAG). GAD-7: 14. Insomnio crónico asociado (IGI: 18). Evaluación inicial e inicio de tratamiento.',
     '2025-10-03','Derivar a psicoterapia. Revisar en 4 semanas.',95,'2025-10-03 14:30:00-05'),
    (2,44,
     'TAG con mejoría parcial (GAD-7: 9). Insomnio moderado persistente (IGI: 12). Ajuste de esquema terapéutico.',
     '2026-01-22','Adición de clonazepam nocturno; inicio de reducción de zolpidem.',95,'2026-01-22 14:30:00-05'),
    (1,45,
     'TAG con respuesta satisfactoria (GAD-7: 5). Insomnio en remisión parcial (IGI: 7). Inicio de tapering de alprazolam.',
     '2026-05-08','Reducir alprazolam 0.25 mg cada 2 semanas. Mantener clonazepam nocturno.',95,'2026-05-08 14:30:00-05');

-- ---------------------------------------------------------------------------
-- 5. Prescriptions — all Dispensado (PrescriptionStatusId = 5)
--    DiagnosticId resolved via AppointmentId (scalar subquery)
--    DispensedBy = UserId 1 (Administrador / farmacéutico)
-- ---------------------------------------------------------------------------

INSERT INTO "Prescription"
    ("UserId","PatientId","PrescriptionStatusId","DiagnosticId",
     "Notes","ValidUntil",
     "SignedAt","SignedBy","DispensedAt","DispensedBy",
     "CreatedBy","CreatedAt")
VALUES
    -- Patient 12 / Dr. García
    ( 9,12,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=29),
      'Dieta hiposódica. Control en 2 meses.',
      '2025-09-14','2025-08-15 11:00:00-05', 9,'2025-08-16 12:00:00-05',1, 9,'2025-08-15 10:00:00-05'),
    ( 9,12,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=30),
      'Agregar estatina por dislipidemia. Reforzar adherencia.',
      '2025-11-19','2025-10-20 10:30:00-05', 9,'2025-10-21 12:00:00-05',1, 9,'2025-10-20 09:30:00-05'),
    ( 9,12,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=31),
      'Cambio de enalapril a losartán por tos seca. Mantener metformina.',
      '2026-02-11','2026-01-12 10:30:00-05', 9,'2026-01-13 12:00:00-05',1, 9,'2026-01-12 09:30:00-05'),
    ( 9,12,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=32),
      'Esquema estable. Agregar gastroprotector. Próximo control en 3 meses.',
      '2026-05-10','2026-04-10 10:30:00-05', 9,'2026-04-11 12:00:00-05',1, 9,'2026-04-10 09:30:00-05'),
    -- Patient 14 / Dr. López
    (12,14,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=33),
      'Triple terapia cardiovascular. Informar sobre síntomas de alarma.',
      '2025-10-05','2025-09-05 11:30:00-05',12,'2025-09-06 12:00:00-05',1,12,'2025-09-05 10:30:00-05'),
    (12,14,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=34),
      'Mantener triple esquema. LDL en descenso.',
      '2026-01-07','2025-12-08 11:30:00-05',12,'2025-12-09 12:00:00-05',1,12,'2025-12-08 10:30:00-05'),
    (12,14,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=35),
      'LDL en objetivo. Adición de ARB por HTA residual.',
      '2026-04-13','2026-03-14 11:30:00-05',12,'2026-03-15 12:00:00-05',1,12,'2026-03-14 10:30:00-05'),
    -- Patient 15 / Dr. Pérez
    (16,15,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=36),
      'Sumatriptán al inicio del aura o cefalea. Completar diario de cefalea.',
      '2025-08-21','2025-07-22 09:30:00-05',16,'2025-07-23 12:00:00-05',1,16,'2025-07-22 08:30:00-05'),
    (16,15,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=37),
      'Inicio de fluoxetina; efecto esperado en 2-4 semanas.',
      '2025-10-30','2025-09-30 09:30:00-05',16,'2025-10-01 12:00:00-05',1,16,'2025-09-30 08:30:00-05'),
    (16,15,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=38),
      'Mantener fluoxetina. Rescate con sumatriptán. Reevaluar en 3 meses.',
      '2026-03-16','2026-02-14 09:30:00-05',16,'2026-02-15 12:00:00-05',1,16,'2026-02-14 08:30:00-05'),
    (16,15,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=39),
      'Excelente respuesta. Continuar tratamiento 6 meses adicionales.',
      '2026-06-09','2026-05-10 09:30:00-05',16,'2026-05-11 12:00:00-05',1,16,'2026-05-10 08:30:00-05'),
    -- Patient 16 / Dr. Espinoza
    (60,16,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=40),
      'Levotiroxina en ayunas 30-60 min antes del desayuno. Control en 6 semanas.',
      '2025-09-27','2025-08-28 12:30:00-05',60,'2025-08-29 12:00:00-05',1,60,'2025-08-28 11:30:00-05'),
    (60,16,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=41),
      'Mantener levotiroxina. Inicio de metformina para DM2.',
      '2025-12-15','2025-11-15 12:30:00-05',60,'2025-11-16 12:00:00-05',1,60,'2025-11-15 11:30:00-05'),
    (60,16,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=42),
      'Ambas condiciones controladas. Agregar omeprazol por síntomas dispépticos.',
      '2026-03-22','2026-02-20 12:30:00-05',60,'2026-02-21 12:00:00-05',1,60,'2026-02-20 11:30:00-05'),
    -- Patient 17 / Dr. Olivera
    (95,17,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=43),
      'Alprazolam sólo en episodios de ansiedad aguda. Zolpidem por máximo 4 semanas.',
      '2025-11-02','2025-10-03 15:30:00-05',95,'2025-10-04 12:00:00-05',1,95,'2025-10-03 14:30:00-05'),
    (95,17,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=44),
      'Adición de clonazepam nocturno. Reducir zolpidem progresivamente.',
      '2026-02-21','2026-01-22 15:30:00-05',95,'2026-01-23 12:00:00-05',1,95,'2026-01-22 14:30:00-05'),
    (95,17,5,(SELECT "DiagnosticId" FROM "Diagnostic" WHERE "AppointmentId"=45),
      'Inicio de tapering de alprazolam: reducir 0.25 mg cada 2 semanas.',
      '2026-06-07','2026-05-08 15:30:00-05',95,'2026-05-09 12:00:00-05',1,95,'2026-05-08 14:30:00-05');

-- ---------------------------------------------------------------------------
-- 6. PrescriptionDetails
--    PrescriptionId resolved via AppointmentId (JOIN through Diagnostic)
--    New medication IDs resolved via scalar subquery (unambiguous names)
-- ---------------------------------------------------------------------------

INSERT INTO "PrescriptionDetail"
    ("PrescriptionId","MedicationId","AdministrationRouteId","FrequencyId","Dose","DurationDays","Instructions")
VALUES
    -- Rx for Appt 29 (HTA inicial): Enalapril(40) + Metformina(33)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=29),
     40,1,1,'10 mg',   30,'Tomar en la mañana, con o sin alimentos.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=29),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    -- Rx for Appt 30 (HTA + DM2 + dislipidemia): Enalapril(40) + Metformina(33) + Atorvastatina 20mg(74)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=30),
     40,1,1,'10 mg',   30,'Tomar en la mañana.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=30),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=30),
     74,1,1,'20 mg',   30,'Tomar por la noche.'),
    -- Rx for Appt 31 (ajuste antihipertensivo): Losartán(17) + Metformina(33)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=31),
     17,1,1,'50 mg',   30,'Tomar en la mañana.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=31),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    -- Rx for Appt 32 (mantenimiento + gastroprotección): Losartán(17) + Metformina(33) + Omeprazol(15)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=32),
     17,1,1,'50 mg',   30,'Tomar en la mañana.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=32),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=32),
     15,1,1,'20 mg',   30,'Tomar en ayunas 30 min antes del desayuno.'),
    -- Rx for Appt 33 (triple CV inicio): Metoprolol(subq) + Atorvastatina 20mg(74) + Amlodipino(43)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=33),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Metoprolol'  AND "Concentration"='50 mg'),1,2,'50 mg',30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=33),
     74,1,1,'20 mg',   30,'Tomar por la noche.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=33),
     43,1,1,'5 mg',    30,'Tomar en la mañana.'),
    -- Rx for Appt 34 (triple CV, estatina escalada): Metoprolol(subq) + Atorvastatina 40mg(41) + Amlodipino(43)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=34),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Metoprolol'  AND "Concentration"='50 mg'),1,2,'50 mg',30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=34),
     41,1,1,'40 mg',   30,'Tomar por la noche. Dosis escalada.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=34),
     43,1,1,'5 mg',    30,'Tomar en la mañana.'),
    -- Rx for Appt 35 (triple CV + ARB): Metoprolol(subq) + Atorvastatina 40mg(41) + Losartán(17)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=35),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Metoprolol'  AND "Concentration"='50 mg'),1,2,'50 mg',30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=35),
     41,1,1,'40 mg',   30,'Tomar por la noche.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=35),
     17,1,1,'50 mg',   30,'Tomar en la mañana.'),
    -- Rx for Appt 36 (migraña rescate): Paracetamol(42) + Sumatriptán(subq)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=36),
     42,1,3,'500-1000 mg',7,'Tomar al inicio del episodio; máximo 4 g/día.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=36),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Sumatriptán' AND "Concentration"='50 mg'),1,1,'50 mg',7,'Tomar 1 tableta al inicio del aura o cefalea; repetir a las 2 h si persiste; máximo 2 tabletas/día.'),
    -- Rx for Appt 37 (migraña + depresión): Paracetamol(42) + Sumatriptán(subq) + Fluoxetina(58)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=37),
     42,1,3,'500-1000 mg',7,'Tomar al inicio del episodio; máximo 4 g/día.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=37),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Sumatriptán' AND "Concentration"='50 mg'),1,1,'50 mg',7,'Tomar al inicio del episodio agudo de migraña.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=37),
     58,1,1,'20 mg',   30,'Tomar por la mañana. Efecto esperado en 2-4 semanas.'),
    -- Rx for Appt 38 (mantenimiento migraña + depresión): Sumatriptán(subq) + Fluoxetina(58)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=38),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Sumatriptán' AND "Concentration"='50 mg'),1,1,'50 mg',30,'Rescate ante episodio de migraña; máximo 2 tabletas/día.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=38),
     58,1,1,'20 mg',   30,'Tomar por la mañana. Continuar tratamiento.'),
    -- Rx for Appt 39 (mantenimiento): Sumatriptán(subq) + Fluoxetina(58)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=39),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Sumatriptán' AND "Concentration"='50 mg'),1,1,'50 mg',30,'Rescate ante episodio de migraña.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=39),
     58,1,1,'20 mg',   30,'Mantener 6 meses adicionales.'),
    -- Rx for Appt 40 (hipotiroidismo inicial): Levotiroxina(subq)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=40),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Levotiroxina' AND "Concentration"='50 mcg'),1,1,'50 mcg',30,'Tomar en ayunas 30-60 min antes del desayuno.'),
    -- Rx for Appt 41 (hipotiroidismo + DM2): Levotiroxina(subq) + Metformina(33)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=41),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Levotiroxina' AND "Concentration"='50 mcg'),1,1,'50 mcg',30,'Tomar en ayunas 30-60 min antes del desayuno.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=41),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    -- Rx for Appt 42 (mantenimiento + gastroprotección): Levotiroxina(subq) + Metformina(33) + Omeprazol(15)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=42),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Levotiroxina' AND "Concentration"='50 mcg'),1,1,'50 mcg',30,'Tomar en ayunas 30-60 min antes del desayuno.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=42),
     33,1,2,'850 mg',  30,'Tomar con el desayuno y la cena.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=42),
     15,1,1,'20 mg',   30,'Tomar en ayunas 30 min antes del desayuno.'),
    -- Rx for Appt 43 (TAG + insomnio inicial): Alprazolam(83) + Zolpidem(subq)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=43),
     83,1,2,'0.5 mg',  30,'Tomar una tableta en la mañana y otra por la noche según ansiedad.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=43),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Zolpidem'    AND "Concentration"='10 mg'),1,1,'10 mg',30,'Tomar 30 min antes de acostarse. Usar máximo 4 semanas.'),
    -- Rx for Appt 44 (ajuste TAG): Alprazolam(83) + Clonazepam 2mg(57) + Zolpidem(subq)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=44),
     83,1,2,'0.5 mg',  30,'Reducir a una toma diaria matutina.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=44),
     57,1,1,'1 mg (½ tableta)',30,'Tomar al acostarse para ansiedad nocturna e insomnio.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=44),
     (SELECT "MedicationId" FROM "Medication" WHERE "GenericName"='Zolpidem'    AND "Concentration"='10 mg'),1,1,'5 mg (½ tableta)',30,'Reducir dosis; suspender si clonazepam nocturno es suficiente.'),
    -- Rx for Appt 45 (tapering alprazolam): Alprazolam(83, dosis reducida) + Clonazepam 2mg(57)
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=45),
     83,1,2,'0.25 mg (½ tableta)',30,'Reducir 0.25 mg cada 2 semanas según plan de tapering.'),
    ((SELECT p."PrescriptionId" FROM "Prescription" p JOIN "Diagnostic" d ON p."DiagnosticId"=d."DiagnosticId" WHERE d."AppointmentId"=45),
     57,1,1,'1 mg (½ tableta)',30,'Tomar al acostarse. Mantener durante tapering de alprazolam.');

-- ---------------------------------------------------------------------------
-- Sequence corrections
-- ---------------------------------------------------------------------------

SELECT setval(pg_get_serial_sequence('"DoctorAvailability"', 'DoctorAvailabilityId'), (SELECT MAX("DoctorAvailabilityId") FROM "DoctorAvailability"));
SELECT setval(pg_get_serial_sequence('"Appointment"',        'AppointmentId'),        (SELECT MAX("AppointmentId")        FROM "Appointment"));
