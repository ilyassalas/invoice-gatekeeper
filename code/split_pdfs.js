// Code node "Split PDFs" (Intake workflow) — Mode: Run Once for All Items
// Turns every PDF attached to an email (or uploaded in the form) into its own item,
// always stored under the same binary name: "data".
// Works for both triggers:
//   - Gmail Trigger: attachments arrive as attachment_0, attachment_1, ...
//   - Form Trigger: files arrive as <field name>_0, <field name>_1, ...

const out = [];

for (const item of $input.all()) {
  const files = item.binary || {};
  const fromForm = 'Mode' in item.json || 'submittedAt' in item.json;   // form items carry these fields
  const fromGmail = !fromForm;

  for (const key of Object.keys(files)) {
    const file = files[key];
    const name = (file.fileName || '').toLowerCase();
    const isPdf = (file.mimeType || '').includes('pdf') || name.endsWith('.pdf');
    if (!isPdf) continue;                       // skip logos, signatures, images...

    out.push({
      json: {
        mode: String(item.json.Mode || 'live').toLowerCase(),   // the form's "Mode" field; Gmail is always live
        source: fromGmail ? 'gmail' : 'form',
        source_ref: fromGmail ? (item.json.id || "") : "",       // Gmail message id, to link back to the email
        file_name: file.fileName || key,
      },
      binary: { data: file },
    });
  }
}

// Same order every time (inv-01 before inv-14), whatever order the files were selected in
out.sort((a, b) => a.json.file_name.localeCompare(b.json.file_name));

return out;
