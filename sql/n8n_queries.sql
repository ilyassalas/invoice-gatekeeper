-- =====================================================================
-- The 3 queries the Process workflow runs (Postgres node → Execute Query)
-- Query Parameters: always written as an expression that returns an ARRAY,
-- e.g. {{ [ $json.a, $json.b ] }} — a plain comma-separated list breaks
-- as soon as a value contains a comma.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) "Lookup": everything the checks need, in ONE round trip.
--    Always returns exactly one row, even when nothing is found.
-- Query Parameters:
--   {{ [ $json.supplier_vat, $json.po_number, $json.mode, $json.invoice_number ] }}
-- ---------------------------------------------------------------------
SELECT
  (SELECT row_to_json(s) FROM ap.suppliers s WHERE s.vat_number = $1)                    AS supplier,
  (SELECT row_to_json(p) FROM ap.purchase_orders p WHERE p.po_number = $2)               AS po,
  (SELECT coalesce(json_agg(l), '[]'::json) FROM ap.po_lines l WHERE l.po_number = $2)   AS po_lines,
  (SELECT count(*)::int FROM ap.invoices i
    WHERE i.mode = $3 AND i.supplier_vat = $1 AND i.invoice_number = $4
      AND i.status <> 'duplicate')                                                       AS existing_count;


-- ---------------------------------------------------------------------
-- 2) "Save invoice": the whole invoice goes in as ONE JSON parameter,
--    and Postgres maps each key to the column with the same name.
--    It returns everything the next steps need (ledger, approval email),
--    with dates cast to text so they don't shift with time zones.
-- Query Parameters:
--   {{ [ JSON.stringify($json) ] }}
-- ---------------------------------------------------------------------
INSERT INTO ap.invoices (mode, source, source_ref, file_name, supplier_id, supplier_name, supplier_vat,
                         invoice_number, invoice_date, due_date, currency, po_number,
                         total_ht, total_vat, total_ttc, lines, issues, status, decided_by, decided_at)
SELECT r.mode, r.source, r.source_ref, r.file_name, r.supplier_id, r.supplier_name, r.supplier_vat,
       r.invoice_number, r.invoice_date, r.due_date, r.currency, r.po_number,
       r.total_ht, r.total_vat, r.total_ttc,
       coalesce(r.lines, '[]'), coalesce(r.issues, '[]'),
       r.status, r.decided_by,
       CASE WHEN r.status = 'auto_approved' THEN now() END
FROM jsonb_populate_record(NULL::ap.invoices, $1::jsonb) AS r
RETURNING id, mode, status, decided_by, file_name, source_ref, supplier_name, invoice_number,
          invoice_date::text AS invoice_date, due_date::text AS due_date, po_number, currency,
          total_ht, total_vat, total_ttc, issues;


-- ---------------------------------------------------------------------
-- 3) "Record decision": after the human clicks Approve or Reject.
-- Query Parameters (Approve branch):
--   {{ [ $('Save invoice').item.json.id, 'approved', 'YOUR_APPROVER_EMAIL' ] }}
-- Query Parameters (Reject branch):
--   {{ [ $('Save invoice').item.json.id, 'rejected', 'YOUR_APPROVER_EMAIL' ] }}
-- ---------------------------------------------------------------------
UPDATE ap.invoices
SET status = $2, decided_by = $3, decided_at = now()
WHERE id = $1
RETURNING id, mode, status, decided_by, file_name, source_ref, supplier_name, invoice_number,
          invoice_date::text AS invoice_date, due_date::text AS due_date, po_number, currency,
          total_ht, total_vat, total_ttc, issues;
