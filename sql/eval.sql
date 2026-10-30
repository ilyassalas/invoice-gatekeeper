-- =====================================================================
-- Evaluation: how good is the workflow on the 20 test invoices?
-- Before each evaluation run, start clean:
--   DELETE FROM ap.invoices WHERE mode = 'eval';
-- Then upload the 20 PDFs through the form with Mode = eval,
-- wait until all executions finish, and run the 4 queries below.
-- =====================================================================

-- 1) Field accuracy: % of the 20 invoices where each field is exactly right
SELECT
  count(*)                                                                               AS invoices,
  round(100.0 * avg((i.supplier_vat   IS NOT DISTINCT FROM g.supplier_vat)::int), 1)     AS supplier_vat_pct,
  round(100.0 * avg((i.invoice_number IS NOT DISTINCT FROM g.invoice_number)::int), 1)   AS invoice_number_pct,
  round(100.0 * avg((i.invoice_date   IS NOT DISTINCT FROM g.invoice_date)::int), 1)     AS invoice_date_pct,
  round(100.0 * avg((i.due_date       IS NOT DISTINCT FROM g.due_date)::int), 1)         AS due_date_pct,
  round(100.0 * avg((coalesce(i.po_number, '') = coalesce(g.po_number, ''))::int), 1)    AS po_number_pct,
  round(100.0 * avg((i.total_ht       IS NOT DISTINCT FROM g.total_ht)::int), 1)         AS total_ht_pct,
  round(100.0 * avg((i.total_ttc      IS NOT DISTINCT FROM g.total_ttc)::int), 1)        AS total_ttc_pct
FROM ap.ground_truth g
LEFT JOIN ap.invoices i ON i.file_name = g.file_name AND i.mode = 'eval';

-- 2) Decisions: routed correctly, planted problems caught, false alarms
SELECT
  count(*)                                                                          AS invoices,
  coalesce(sum((i.status = g.expected_status)::int), 0)                             AS routed_correctly,
  sum((g.expected_issue <> '')::int)                                                AS planted_problems,
  coalesce(sum((g.expected_issue <> ''
        AND i.issues @> jsonb_build_array(jsonb_build_object('code', g.expected_issue)))::int), 0) AS problems_caught,
  coalesce(sum((g.expected_status = 'auto_approved' AND i.status <> 'auto_approved')::int), 0)    AS false_alarms
FROM ap.ground_truth g
LEFT JOIN ap.invoices i ON i.file_name = g.file_name AND i.mode = 'eval';

-- 3) Which invoices got the wrong decision (no rows = perfect)
SELECT g.file_name, g.expected_status, i.status AS got_status, g.expected_issue,
       (SELECT string_agg(x->>'code', ', ') FROM jsonb_array_elements(i.issues) AS x) AS issues_found
FROM ap.ground_truth g
LEFT JOIN ap.invoices i ON i.file_name = g.file_name AND i.mode = 'eval'
WHERE i.status IS DISTINCT FROM g.expected_status
ORDER BY g.file_name;

-- 4) Which fields the AI misread (no rows = perfect)
SELECT g.file_name,
       CASE WHEN i.invoice_number IS DISTINCT FROM g.invoice_number THEN coalesce(i.invoice_number, '∅') || ' ≠ ' || g.invoice_number END AS invoice_number,
       CASE WHEN i.invoice_date   IS DISTINCT FROM g.invoice_date   THEN coalesce(i.invoice_date::text, '∅') || ' ≠ ' || g.invoice_date END AS invoice_date,
       CASE WHEN i.total_ttc      IS DISTINCT FROM g.total_ttc      THEN coalesce(i.total_ttc::text, '∅') || ' ≠ ' || g.total_ttc END AS total_ttc,
       CASE WHEN i.supplier_vat   IS DISTINCT FROM g.supplier_vat   THEN coalesce(i.supplier_vat, '∅') || ' ≠ ' || g.supplier_vat END AS supplier_vat
FROM ap.ground_truth g
LEFT JOIN ap.invoices i ON i.file_name = g.file_name AND i.mode = 'eval'
WHERE i.invoice_number IS DISTINCT FROM g.invoice_number
   OR i.invoice_date   IS DISTINCT FROM g.invoice_date
   OR i.total_ttc      IS DISTINCT FROM g.total_ttc
   OR i.supplier_vat   IS DISTINCT FROM g.supplier_vat
ORDER BY g.file_name;
