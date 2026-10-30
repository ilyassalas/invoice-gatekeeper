-- =====================================================================
-- Weekly report: 5 queries on live invoices (last 7 days)
-- Used by the "IG | Weekly report" workflow (Milestone 8).
-- =====================================================================

-- 1) What came in this week, by decision
SELECT status, count(*) AS invoices, sum(total_ttc) AS amount
FROM ap.invoices
WHERE mode = 'live' AND created_at > now() - interval '7 days'
GROUP BY status
ORDER BY invoices DESC;

-- 2) Share handled with no human (duplicates excluded)
SELECT round(100.0 * avg((status = 'auto_approved')::int), 1) AS auto_approved_pct
FROM ap.invoices
WHERE mode = 'live' AND status <> 'duplicate' AND created_at > now() - interval '7 days';

-- 3) Most common problems
SELECT x->>'code' AS problem, count(*) AS times
FROM ap.invoices, jsonb_array_elements(issues) AS x
WHERE mode = 'live' AND created_at > now() - interval '7 days'
GROUP BY 1
ORDER BY 2 DESC;

-- 4) Approved invoices to pay in the next 7 days
SELECT supplier_name, invoice_number, due_date, total_ttc
FROM ap.invoices
WHERE mode = 'live' AND status IN ('auto_approved', 'approved')
  AND due_date BETWEEN current_date AND current_date + 7
ORDER BY due_date;

-- 5) How long a human takes to decide, on average
SELECT round(avg(extract(epoch FROM decided_at - created_at) / 3600)::numeric, 1) AS avg_hours_to_decision,
       count(*) AS decisions
FROM ap.invoices
WHERE mode = 'live' AND status IN ('approved', 'rejected')
  AND decided_at > now() - interval '7 days';
