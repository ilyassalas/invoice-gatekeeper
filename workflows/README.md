# Workflows

The n8n workflow exports go here once they're built:

- `IG_Intake.json`: Gmail trigger + upload form → split PDFs → extract text → call the process once per invoice
- `IG_Process_invoice.json`: AI reading, checks, decision, ledger, approval email, duplicate alert
- `IG_Error_alerts.json`: email alert for any failure

Credentials are never included in an n8n export. Before committing, open each file and remove anything that shouldn't be public (for example the approver's email address).
