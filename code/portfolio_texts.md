# Invoice Gatekeeper: ready-to-use texts (numbers from the 30 Oct 2026 run)

## Portfolio title
AI Invoice Gatekeeper (Demo): supplier invoices checked against purchase orders before anyone pays | n8n + OpenAI + PostgreSQL

## Portfolio description (Upwork, Malt, LinkedIn project)
A company receives supplier invoices by email and someone retypes and checks each one. This workflow does it: AI reads each PDF into a fixed JSON schema, then rules check it against the purchase orders in PostgreSQL (duplicates, price or quantity above the order, totals that don't add up, unknown supplier, approval limit). Clean invoices go to the ledger; exceptions go to a manager by email with the reasons and Approve / Reject buttons. Tested on 20 synthetic invoices (French and English) with 7 planted problems: 7/7 caught, 20/20 routed correctly, every field read correctly, about $0.001 and 3 seconds per invoice. Stack: n8n (self-hosted), OpenAI, PostgreSQL, Gmail, Google Sheets.

## CV line (EN)
Built an AI accounts-payable workflow (n8n, OpenAI, PostgreSQL): reads supplier invoices, checks them against purchase orders, blocks duplicates and routes exceptions to a human approver; 20/20 invoices routed correctly and 7/7 planted errors caught on a 20-invoice test set, at about $0.001 per invoice.

## CV line (FR)
Workflow IA de contrôle des factures fournisseurs (n8n, OpenAI, PostgreSQL) : lecture des PDF, rapprochement avec les bons de commande, blocage des doublons, validation humaine des anomalies ; 20/20 factures correctement orientées et 7/7 anomalies détectées sur un jeu de test de 20 factures, pour environ 0,001 $ par facture.

## Video script (60–90 s)
Hi, I'm Ilyas. This is Invoice Gatekeeper, an accounts-payable workflow I built in n8n on my own server.
[the email] A supplier emails an invoice. [the execution] AI reads the PDF, then plain rules check it against the purchase orders in PostgreSQL.
[the ledger] A clean invoice lands in the ledger in seconds.
[the approval email] This one bills a higher price than agreed, so the manager gets the reason and an Approve button.
[the duplicate email] If the same invoice comes twice, it's blocked.
[the eval result] I tested it on 20 invoices with 7 planted problems: all 7 caught, all 20 routed correctly, about a tenth of a cent per invoice. The code and test data are on my GitHub.

## LinkedIn post (5 lines)
Someone in accounts payable retypes every supplier invoice and checks it against the purchase order by hand.
I built a workflow that does it: AI reads the PDF, then plain rules in PostgreSQL decide, so every decision can be audited.
Clean invoices go to the ledger. A wrong price, a duplicate or a missing PO goes to a manager with the reason and an Approve button.
On 20 test invoices with 7 planted problems: 7/7 caught, 20/20 routed correctly, about $0.001 per invoice.
n8n (self-hosted) + OpenAI + PostgreSQL. Video and code: [GitHub link]
