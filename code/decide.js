// n8n Code node "Decide" (Run Once for Each Item)
// Turns the list of problems into one decision: auto_approved, needs_review or duplicate.

// The company's approval policy, in code
const APPROVAL_LIMIT = 1500;   // above this total, a manager must sign

const inv = $json;             // the invoice coming from Match PO
const issues = [...inv.issues];
let status;                    // "let" instead of "const": the value is decided below

// Rule 1: already received → duplicate, and stop there (a duplicate is never paid)
if (inv.existing_count > 0) {
  status = 'duplicate';
  issues.push({ code: 'duplicate', message: `Already received: ${inv.invoice_number} from ${inv.supplier_name}` });
} else {
  // Rule 2: big invoices always need a human
  if (inv.total_ttc > APPROVAL_LIMIT) {
    issues.push({ code: 'above_approval_limit', message: `${inv.total_ttc} ${inv.currency} is above the ${APPROVAL_LIMIT} limit: a manager signs it` });
  }
  // Rules 3 and 4: any problem → a human looks; no problem → approved automatically
  status = issues.length > 0 ? 'needs_review' : 'auto_approved';
}

return {
  json: {
    ...inv,
    issues,
    status,
    decided_by: status === 'auto_approved' ? 'rules' : null,
  },
};
