// Code node "Normalize & validate" (Process workflow) — Mode: Run Once for Each Item
// Input:  the Information Extractor's answer ($json.output) + the file info from the "Start" trigger
// Output: one clean invoice + the list of problems found by plain rules (no AI here).
// Principle: the AI copies what is printed; this code checks it.

const ai = $json.output ?? $json;               // the extractor puts its result in "output"
const start = $('Start').item.json;             // mode, source, source_ref, file_name

// ---------- small helpers ----------
const r2 = (n) => Math.round(n * 100) / 100;                    // round to cents
const txt = (v) => (v === null || v === undefined ? '' : String(v).trim());

// "1 234,56 €" -> 1234.56   |   "€1,234.56" -> 1234.56   |   12.5 -> 12.5
function num(v) {
  if (typeof v === 'number') return v;
  let s = txt(v).replace(/[^\d,.\-]/g, '');                     // keep digits , . -
  if (s === '') return null;
  if (s.includes(',') && s.includes('.')) {
    // the separator that comes last is the decimal one
    s = s.lastIndexOf(',') > s.lastIndexOf('.') ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
  } else if (s.includes(',')) {
    s = s.replace(',', '.');
  }
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

// "2026-10-05" stays, "05/10/2026" -> "2026-10-05", anything else -> null
function isoDate(v) {
  const s = txt(v);
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const m = s.match(/^(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{4})$/);
  return m ? `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}` : null;
}

// ---------- 1. normalize ----------
const invoice = {
  mode: start.mode || 'live',
  source: start.source || '',
  source_ref: start.source_ref || '',
  file_name: start.file_name || '',
  supplier_name: txt(ai.supplier_name),
  supplier_vat: txt(ai.supplier_vat).replace(/\s/g, '').toUpperCase(),
  invoice_number: txt(ai.invoice_number).replace(/\s/g, ''),
  invoice_date: isoDate(ai.invoice_date),
  due_date: isoDate(ai.due_date),
  currency: txt(ai.currency).toUpperCase() || 'EUR',
  po_number: txt(ai.po_number).replace(/\s/g, '').toUpperCase(),
  lines: (ai.lines || []).map((l) => ({
    sku: txt(l.sku).replace(/\s/g, '').toUpperCase(),
    description: txt(l.description),
    quantity: num(l.quantity) ?? 0,
    unit_price: num(l.unit_price) ?? 0,
    line_total: num(l.line_total) ?? 0,
  })),
  total_ht: num(ai.total_ht),
  total_vat: num(ai.total_vat),
  total_ttc: num(ai.total_ttc),
};

// ---------- 2. check ----------
const issues = [];
const add = (code, message) => issues.push({ code, message });

// a) the fields a payment needs
const missing = ['supplier_vat', 'invoice_number', 'invoice_date', 'total_ttc']
  .filter((f) => invoice[f] === null || invoice[f] === '' || invoice[f] === 0);
if (missing.length) add('missing_field', `Missing on the invoice: ${missing.join(', ')}`);

// b) the lines add up to the total before VAT
const linesSum = r2(invoice.lines.reduce((sum, l) => sum + l.line_total, 0));
if (invoice.total_ht !== null && Math.abs(linesSum - invoice.total_ht) > 0.05) {
  add('math_lines', `Lines add up to ${linesSum}, but the total before VAT says ${invoice.total_ht}`);
}

// c) total before VAT + VAT = total to pay
if (invoice.total_ht !== null && invoice.total_vat !== null && invoice.total_ttc !== null) {
  const expected = r2(invoice.total_ht + invoice.total_vat);
  if (Math.abs(expected - invoice.total_ttc) > 0.05) {
    add('math_total', `${invoice.total_ht} + VAT ${invoice.total_vat} = ${expected}, but the invoice asks for ${invoice.total_ttc}`);
  }
}

// d) the VAT rate is one that exists in France (0 = reverse charge or export)
if (invoice.total_ht > 0 && invoice.total_vat !== null) {
  const rate = r2((invoice.total_vat / invoice.total_ht) * 100);
  const allowed = [0, 2.1, 5.5, 10, 20];
  if (!allowed.some((a) => Math.abs(a - rate) < 0.2)) add('vat_rate', `Unusual VAT rate: ${rate}%`);
}

// e) the dates make sense
if (invoice.invoice_date && invoice.due_date && invoice.due_date < invoice.invoice_date) {
  add('dates', `Due date ${invoice.due_date} is before the invoice date ${invoice.invoice_date}`);
}

return { json: { ...invoice, issues } };
