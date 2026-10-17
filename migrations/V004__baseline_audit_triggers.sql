-- Row-level audit triggers (audit_row_change() is created in V001). Attached last so the
-- reference data of V002/V003 does not produce unattributed AuditLog rows.

--
-- Name: Appointment trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Appointment" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: AppointmentPayment trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."AppointmentPayment" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: BreakGlassGrant trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."BreakGlassGrant" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Clinic trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Clinic" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: ClinicStock trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."ClinicStock" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Diagnostic trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Diagnostic" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: DoctorAvailability trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."DoctorAvailability" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PartnerConfig trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PartnerConfig" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PartnerInsurance trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PartnerInsurance" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PartnerMedication trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PartnerMedication" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PartnerSpecialty trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PartnerSpecialty" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Patient trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Patient" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('PasswordHash');

--
-- Name: PatientAllergy trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientAllergy" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PatientAmendmentRequest trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientAmendmentRequest" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PatientCommunicationPreference trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientCommunicationPreference" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('AlternativeEmail', 'AlternativePhone');

--
-- Name: PatientConsent trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientConsent" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PatientDisclosure trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientDisclosure" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PatientPrivacyNoticeAck trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PatientPrivacyNoticeAck" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Person trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Person" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PersonDocument trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PersonDocument" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Prescription trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Prescription" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PrescriptionDetail trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PrescriptionDetail" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: PrivacyNotice trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."PrivacyNotice" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: Role trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."Role" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: RoleNavigationAccess trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."RoleNavigationAccess" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();

--
-- Name: User trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."User" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('PasswordHash', 'LastAccess');

--
-- Name: UserMfa trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public."UserMfa" FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('SecretEncrypted', 'LastUsedStep');
