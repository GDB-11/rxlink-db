#!/usr/bin/env bash
# Phase 5.4 orphan check: every non-null "<Catalog>Code" reference column in the partner DB must
# resolve to a row in the catalog DB. Read-only on both sides; exits 1 if any code is orphaned.
# usage: orphan-check.sh <partner-psql-conninfo> <catalog-psql-conninfo>   (PSQL env overrides the psql command)
set -euo pipefail
SRC=${1:?partner conninfo}; DST=${2:?catalog conninfo}
PSQL=${PSQL:-psql}
q() { $PSQL -X -qtA -v ON_ERROR_STOP=1 "$1" -c "$2"; }
rc=0
# partnerTable.column:catalogTable.codeColumn
for spec in Person.SexCode:Sex.SexCode PersonDocument.DocumentTypeCode:DocumentType.DocumentTypeCode \
            User.SpecialtyCode:Specialty.SpecialtyCode PatientAllergy.AllergyCode:Allergy.AllergyCode \
            PatientAllergy.SeverityCode:AllergySeverity.SeverityCode PrescriptionDetail.MedicationCode:Medication.MedicationCode \
            PrescriptionDetail.AdministrationRouteCode:AdministrationRoute.AdministrationRouteCode \
            PrescriptionDetail.FrequencyCode:Frequency.FrequencyCode AppointmentPayment.InsuranceCode:Insurance.InsuranceCode \
            PartnerSpecialty.SpecialtyCode:Specialty.SpecialtyCode PartnerInsurance.InsuranceCode:Insurance.InsuranceCode \
            PartnerMedication.MedicationCode:Medication.MedicationCode ClinicStock.MedicationCode:Medication.MedicationCode; do
  IFS=: read -r pcol ccol <<<"$spec"
  pt=${pcol%%.*}; pc=${pcol#*.}; ct=${ccol%%.*}; cc=${ccol#*.}
  codes=$(q "$SRC" "SELECT string_agg(DISTINCT quote_literal(\"$pc\"::text), ',') FROM \"$pt\" WHERE \"$pc\" IS NOT NULL")
  if [[ -z "$codes" ]]; then echo "OK   $pt.$pc (no codes)"; continue; fi
  orphans=$(q "$DST" "SELECT count(*) FROM unnest(ARRAY[$codes]::uuid[]) AS c(code) WHERE NOT EXISTS (SELECT 1 FROM \"$ct\" WHERE \"$cc\" = c.code)")
  if [[ "$orphans" == 0 ]]; then echo "OK   $pt.$pc"; else echo "ORPHAN $pt.$pc: $orphans code(s) missing in $ct"; rc=1; fi
done
exit $rc
