-- =====================================================================
-- Invoice Gatekeeper: database schema + demo data
-- All companies and numbers are fictional (synthetic test data).
--
-- Run it on the server, from ~/atlas-stack:
--   docker compose exec -T postgres psql -U n8n -d atlas < ~/seed.sql
--
-- It only touches the "ap" schema (ap = accounts payable). Your agent's
-- tables (n8n_vectors, n8n_chat_histories, demo_requests) are not touched.
-- Re-running it deletes and recreates everything in "ap", including any
-- invoices you processed.
-- =====================================================================

DROP SCHEMA IF EXISTS ap CASCADE;
CREATE SCHEMA ap;

-- Who the company buys from
CREATE TABLE ap.suppliers (
  id          serial PRIMARY KEY,
  name        text NOT NULL,
  vat_number  text NOT NULL UNIQUE,
  country     text NOT NULL
);

-- What the company ordered (purchase orders) ...
CREATE TABLE ap.purchase_orders (
  po_number    text PRIMARY KEY,
  supplier_id  int  NOT NULL REFERENCES ap.suppliers(id),
  order_date   date NOT NULL,
  currency     text NOT NULL DEFAULT 'EUR',
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed'))
);

-- ... line by line, at the agreed price
CREATE TABLE ap.po_lines (
  id           serial PRIMARY KEY,
  po_number    text NOT NULL REFERENCES ap.purchase_orders(po_number),
  sku          text NOT NULL,
  description  text NOT NULL,
  qty          numeric(12,2) NOT NULL,
  unit_price   numeric(12,2) NOT NULL,
  UNIQUE (po_number, sku)
);

-- Every invoice the workflow reads, with the decision and why
CREATE TABLE ap.invoices (
  id              bigserial PRIMARY KEY,
  mode            text NOT NULL DEFAULT 'live' CHECK (mode IN ('live', 'eval')),
  source          text,                -- gmail | form | pin
  source_ref      text,                -- Gmail message id
  file_name       text,
  supplier_id     int REFERENCES ap.suppliers(id),
  supplier_name   text,
  supplier_vat    text,
  invoice_number  text,
  invoice_date    date,
  due_date        date,
  currency        text,
  po_number       text,
  total_ht        numeric(12,2),
  total_vat       numeric(12,2),
  total_ttc       numeric(12,2),
  lines           jsonb NOT NULL DEFAULT '[]',
  issues          jsonb NOT NULL DEFAULT '[]',
  status          text NOT NULL CHECK (status IN ('auto_approved', 'needs_review', 'approved', 'rejected', 'duplicate')),
  decided_by      text,                -- 'rules' or the approver's email
  decided_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Safety net: the database itself refuses to record the same supplier
-- invoice twice (duplicates are only stored with status 'duplicate').
CREATE UNIQUE INDEX invoices_no_double_entry
  ON ap.invoices (mode, supplier_vat, invoice_number)
  WHERE status <> 'duplicate';

-- Answer key for the 20 test invoices (used by the evaluation queries)
CREATE TABLE ap.ground_truth (
  file_name        text PRIMARY KEY,
  supplier_vat     text,
  invoice_number   text,
  invoice_date     date,
  due_date         date,
  currency         text,
  po_number        text,
  total_ht         numeric(12,2),
  total_vat        numeric(12,2),
  total_ttc        numeric(12,2),
  expected_status  text NOT NULL,
  expected_issue   text NOT NULL DEFAULT ''
);


-- ---------------------------------------------------------------- demo data

INSERT INTO ap.suppliers (id, name, vat_number, country) VALUES
  (1, 'Cartonnages Rhône-Alpes SAS', 'FR00000111222', 'FR'),
  (2, 'Céramiques du Vallon SARL', 'FR11000222333', 'FR'),
  (3, 'Atelier Cire & Mèche', 'FR22000333444', 'FR'),
  (4, 'Shannon Pack Ltd', 'IE0001234X', 'IE'),
  (5, 'Bureau Express Fournitures', 'FR33000444555', 'FR');
SELECT setval('ap.suppliers_id_seq', (SELECT max(id) FROM ap.suppliers));

INSERT INTO ap.purchase_orders (po_number, supplier_id, order_date) VALUES
  ('PO-2026-0101', 1, '2026-09-01'),
  ('PO-2026-0102', 2, '2026-09-03'),
  ('PO-2026-0103', 3, '2026-09-04'),
  ('PO-2026-0104', 4, '2026-09-08'),
  ('PO-2026-0105', 1, '2026-09-10'),
  ('PO-2026-0106', 2, '2026-09-15'),
  ('PO-2026-0107', 3, '2026-09-18'),
  ('PO-2026-0108', 5, '2026-09-20'),
  ('PO-2026-0109', 5, '2026-09-22'),
  ('PO-2026-0110', 4, '2026-09-24');

INSERT INTO ap.po_lines (po_number, sku, description, qty, unit_price) VALUES
  ('PO-2026-0101', 'BOX-S-20', 'Carton d''expédition S (20×15×10 cm)', 500, 0.42),
  ('PO-2026-0101', 'BOX-M-30', 'Carton d''expédition M (30×20×15 cm)', 300, 0.68),
  ('PO-2026-0101', 'TAPE-48', 'Ruban adhésif 48 mm', 50, 1.90),
  ('PO-2026-0102', 'VASE-ARG-M', 'Vase argile M', 40, 18.50),
  ('PO-2026-0102', 'BOWL-SET4', 'Set de 4 bols', 25, 24.00),
  ('PO-2026-0103', 'CAND-SOJA-200', 'Bougie soja 200 g', 120, 6.80),
  ('PO-2026-0103', 'CAND-SOJA-400', 'Bougie soja 400 g', 60, 11.20),
  ('PO-2026-0104', 'MAIL-BAG-L', 'Padded mailer L', 1000, 0.31),
  ('PO-2026-0104', 'LABEL-ROLL', 'Thermal label roll (500 labels)', 20, 7.50),
  ('PO-2026-0105', 'BOX-L-40', 'Carton d''expédition L (40×30×20 cm)', 200, 1.05),
  ('PO-2026-0105', 'FILL-PAPER', 'Papier de calage (rouleau)', 30, 12.40),
  ('PO-2026-0106', 'VASE-ARG-L', 'Vase argile L', 80, 32.00),
  ('PO-2026-0106', 'PLATE-SET6', 'Set de 6 assiettes', 60, 29.50),
  ('PO-2026-0107', 'DIFF-REED-100', 'Diffuseur à bâtonnets 100 ml', 100, 9.40),
  ('PO-2026-0108', 'PAPER-A4', 'Ramette papier A4 80 g', 20, 4.20),
  ('PO-2026-0108', 'PEN-BLUE', 'Stylos bleus (boîte de 50)', 2, 11.90),
  ('PO-2026-0109', 'TONER-X2', 'Toner imprimante X2', 4, 46.00),
  ('PO-2026-0110', 'MAIL-BAG-M', 'Padded mailer M', 2000, 0.22);

INSERT INTO ap.ground_truth (file_name, supplier_vat, invoice_number, invoice_date, due_date, currency,
                             po_number, total_ht, total_vat, total_ttc, expected_status, expected_issue) VALUES
  ('inv-01.pdf', 'FR00000111222', 'FA-2026-0412', '2026-09-12', '2026-10-12', 'EUR', 'PO-2026-0101', 207.00, 41.40, 248.40, 'auto_approved', ''),
  ('inv-02.pdf', 'FR11000222333', 'F2026-118', '2026-09-14', '2026-10-14', 'EUR', 'PO-2026-0102', 610.00, 122.00, 732.00, 'auto_approved', ''),
  ('inv-03.pdf', 'FR22000333444', 'AC-00791', '2026-09-16', '2026-10-16', 'EUR', 'PO-2026-0103', 816.00, 163.20, 979.20, 'auto_approved', ''),
  ('inv-04.pdf', 'IE0001234X', 'SP-2026-3381', '2026-09-18', '2026-10-18', 'EUR', 'PO-2026-0104', 385.00, 0.00, 385.00, 'auto_approved', ''),
  ('inv-05.pdf', 'FR00000111222', 'FA-2026-0438', '2026-09-19', '2026-10-19', 'EUR', 'PO-2026-0105', 582.00, 116.40, 698.40, 'auto_approved', ''),
  ('inv-06.pdf', 'FR33000444555', 'BE-55120', '2026-09-23', '2026-10-23', 'EUR', 'PO-2026-0108', 107.80, 21.56, 129.36, 'auto_approved', ''),
  ('inv-07.pdf', 'FR22000333444', 'AC-00805', '2026-09-25', '2026-10-25', 'EUR', 'PO-2026-0107', 470.00, 94.00, 564.00, 'auto_approved', ''),
  ('inv-08.pdf', 'FR00000111222', 'FA-2026-0451', '2026-09-28', '2026-10-28', 'EUR', 'PO-2026-0101', 302.00, 60.40, 362.40, 'auto_approved', ''),
  ('inv-09.pdf', 'FR11000222333', 'F2026-131', '2026-09-30', '2026-10-30', 'EUR', 'PO-2026-0102', 730.00, 146.00, 876.00, 'auto_approved', ''),
  ('inv-10.pdf', 'IE0001234X', 'SP-2026-3417', '2026-10-01', '2026-10-31', 'EUR', 'PO-2026-0104', 75.00, 0.00, 75.00, 'auto_approved', ''),
  ('inv-11.pdf', 'FR22000333444', 'AC-00812', '2026-10-02', '2026-11-01', 'EUR', 'PO-2026-0103', 672.00, 134.40, 806.40, 'auto_approved', ''),
  ('inv-12.pdf', 'FR33000444555', 'BE-55187', '2026-10-05', '2026-11-04', 'EUR', 'PO-2026-0109', 92.00, 18.40, 110.40, 'auto_approved', ''),
  ('inv-13.pdf', 'IE0001234X', 'SP-2026-3460', '2026-10-06', '2026-11-05', 'EUR', 'PO-2026-0110', 440.00, 0.00, 440.00, 'auto_approved', ''),
  ('inv-14.pdf', 'FR00000111222', 'FA-2026-0412', '2026-09-12', '2026-10-12', 'EUR', 'PO-2026-0101', 207.00, 41.40, 248.40, 'duplicate', 'duplicate'),
  ('inv-15.pdf', 'FR11000222333', 'F2026-140', '2026-10-08', '2026-11-07', 'EUR', 'PO-2026-0106', 698.00, 139.60, 837.60, 'needs_review', 'price_above_po'),
  ('inv-16.pdf', 'FR22000333444', 'AC-00826', '2026-10-09', '2026-11-08', 'EUR', 'PO-2026-0107', 1128.00, 225.60, 1353.60, 'needs_review', 'qty_above_po'),
  ('inv-17.pdf', 'FR33000444555', 'BE-55203', '2026-10-12', '2026-11-11', 'EUR', 'PO-2026-0109', 92.00, 18.40, 120.40, 'needs_review', 'math_total'),
  ('inv-18.pdf', 'FR33000444555', 'BE-55219', '2026-10-13', '2026-11-12', 'EUR', NULL, 55.90, 11.18, 67.08, 'needs_review', 'po_not_found'),
  ('inv-19.pdf', 'GB000123456', 'BL-7781', '2026-10-14', '2026-11-13', 'EUR', NULL, 435.00, 0.00, 435.00, 'needs_review', 'unknown_supplier'),
  ('inv-20.pdf', 'FR11000222333', 'F2026-152', '2026-10-15', '2026-11-14', 'EUR', 'PO-2026-0106', 3690.00, 738.00, 4428.00, 'needs_review', 'above_approval_limit');

-- Check: you should see 5, 10, 18 and 20
SELECT 'suppliers' AS table_name, count(*) AS rows FROM ap.suppliers
UNION ALL SELECT 'purchase_orders', count(*) FROM ap.purchase_orders
UNION ALL SELECT 'po_lines', count(*) FROM ap.po_lines
UNION ALL SELECT 'ground_truth', count(*) FROM ap.ground_truth;
