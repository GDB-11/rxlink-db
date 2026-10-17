-- Baseline reference data the application needs to function (not demo data).

-- Role
INSERT INTO public."Role" ("RoleId", "RoleCode", "Name", "Description", "IsActive", "CreatedAt", "DeletedAt", "DeletedBy", "CanViewClinicalData") VALUES
	(1, '01a141df-5c5c-71ed-873d-fdd5aa25f9cd', 'Administrador', 'Control de usuarios, configuración y accesos', true, '2026-10-15 23:22:00.084762+00', NULL, NULL, false),
	(2, '01a141df-5c5c-739a-9d94-32f967ab2c53', 'Doctor', 'Puede crear y gestionar recetas', true, '2026-10-15 23:22:00.084762+00', NULL, NULL, true),
	(3, '01a141df-5c5c-73ac-b27a-84c33aa9d1a2', 'Enfermero', 'Acceso a asistencia clínica', true, '2026-10-15 23:22:00.084762+00', NULL, NULL, true);
SELECT pg_catalog.setval('public."Role_RoleId_seq"', 3, true);

-- PrescriptionStatus
INSERT INTO public."PrescriptionStatus" ("PrescriptionStatusId", "PrescriptionStatusCode", "Name", "Description", "IsActive") VALUES
	(1, '01a141df-5c5d-7574-9995-00ad2fdfac06', 'Borrador', 'Receta creada pero aún no firmada; no es clínicamente válida', true),
	(2, '01a141df-5c5d-76df-9efc-692b8b928bc3', 'Activo', 'Receta firmada y válida, pendiente de dispensación', true),
	(3, '01a141df-5c5d-76ef-95a7-cdc057c4c071', 'Suspendido', 'Suspendido temporalmente por el médico prescriptor', true),
	(4, '01a141df-5c5d-76f8-9c6c-64fa51c78616', 'Finalizado', 'Finalización del tratamiento', true),
	(5, '01a141df-5c5d-7700-bad6-a8464d5dcbf2', 'Dispensado', 'Se le han entregado los medicamentos al paciente', true),
	(6, '01a141df-5c5d-7708-9e32-092526374352', 'Caducado', 'La receta caducó sin que se dispensara el medicamento', true),
	(7, '01a141df-5c5d-770f-b35b-358d3a16e539', 'Cancelado', 'Receta totalmente cancelada por el doctor; no es clínicamente válida', true);
SELECT pg_catalog.setval('public."PrescriptionStatus_PrescriptionStatusId_seq"', 7, true);

-- ConsultationType
INSERT INTO public."ConsultationType" ("ConsultationTypeId", "ConsultationTypeCode", "Name", "IsActive") VALUES
	(1, '01a141df-5ef4-7b50-8f2c-d4967be2b112', 'Virtual', true),
	(2, '01a141df-5ef4-7cde-809b-70a9b165e5c1', 'Presencial', true);
SELECT pg_catalog.setval('public."ConsultationType_ConsultationTypeId_seq"', 2, true);

-- AppointmentStatus
INSERT INTO public."AppointmentStatus" ("AppointmentStatusId", "AppointmentStatusCode", "Name", "IsActive") VALUES
	(1, '01a141df-5ef8-7139-8f83-b902fe096f21', 'PendientePago', true),
	(2, '01a141df-5ef8-729e-b755-51034cba021f', 'Confirmado', true),
	(3, '01a141df-5ef8-72af-ac7f-26fb619b2f6c', 'Completado', true),
	(4, '01a141df-5ef8-72b8-b57b-0a8756414109', 'Cancelado', true),
	(5, '01a141df-5ef8-72c0-bb11-119134cdb8a1', 'NoAsistio', true);
SELECT pg_catalog.setval('public."AppointmentStatus_AppointmentStatusId_seq"', 5, true);

-- DiagnosticStatus
INSERT INTO public."DiagnosticStatus" ("DiagnosticStatusId", "DiagnosticStatusCode", "Name", "IsActive") VALUES
	(1, '01a141df-5e7e-70e0-a038-f81eff42e320', 'Activo', true),
	(2, '01a141df-5e7e-726a-9169-40c9c3d2b532', 'Inactivo', true);
SELECT pg_catalog.setval('public."DiagnosticStatus_DiagnosticStatusId_seq"', 2, true);

-- Default clinic and single-row partner configuration (PartnerCode is generated here)
INSERT INTO "Clinic" ("Name", "IsDefault") VALUES ('Sede Principal', TRUE);
INSERT INTO "PartnerConfig" ("PartnerConfigId") VALUES (1);
