// n8n Code node "Match PO" (Run Once for Each Item)
// Checks the invoice against the supplier list and the purchase order found by "Lookup".

// 1. Get the two inputs
const inv = $('Normalize & validate').item.json;          // the invoice the AI read and the code cleaned
const { supplier, po, po_lines, existing_count } = $json; // what Lookup found in the database

// 2. Start from the problems already found, and make a helper to add new ones
const issues = [...inv.issues];
const add = (code, message) => issues.push({ code, message });

// Check 1: the supplier must be in our supplier list
if (!supplier) {
  add('unknown_supplier', `Supplier ${inv.supplier_name || inv.supplier_vat} is not in the supplier list`);
}

// Check 2: there must be a purchase order
if (!po) {
  add('po_not_found', inv.po_number ? `PO ${inv.po_number} does not exist` : 'No PO reference on the invoice');
} else {
  // Check 3: the PO must belong to this supplier and still be open
  if (supplier && po.supplier_id !== supplier.id) {
    add('po_supplier_mismatch', `PO ${po.po_number} belongs to another supplier`);
  }
  if (po.status !== 'open') {
    add('po_closed', `PO ${po.po_number} is ${po.status}`);
  }

  // Check 4: every invoice line against the PO line with the same product code
  for (const line of inv.lines) {
    const poLine = po_lines.find((p) => p.sku.toUpperCase() === line.sku);

    if (!poLine) {
      add('line_not_on_po', `${line.sku} is not on PO ${po.po_number}`);
      continue;   // nothing to compare, go to the next line
    }
    if (line.quantity > Number(poLine.qty)) {
      add('qty_above_po', `${line.sku}: ${line.quantity} billed, ${Number(poLine.qty)} ordered`);
    }
    if (line.unit_price > Number(poLine.unit_price) * 1.02) {   // 2% tolerance on the agreed price
      add('price_above_po', `${line.sku}: billed ${line.unit_price} each, agreed ${Number(poLine.unit_price)}`);
    }
  }
}

// 3. Send the invoice on, with the supplier id and the full list of problems
return {
  json: {
    ...inv,
    supplier_id: supplier ? supplier.id : null,
    existing_count: Number(existing_count) || 0,
    issues,
  },
};
