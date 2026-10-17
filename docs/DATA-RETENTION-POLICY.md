# Data Retention and Disposal Policy — Max Power Panel

**Max Power Electrical Solutions, Inc.** · Effective October 16, 2026 · Version 1.0
**Owner:** Edgar Arboleya, Owner / President · edgararboleya@mxpes.com · info@mxpes.com

This policy is section 9 of the company's Information Security Policy, stated on its own. It is reviewed at least
once a year by the owner and whenever a service provider or a legal requirement changes.

## 1. What we hold and for how long

| Data | Retention | Why |
|---|---|---|
| Accounting records: ledger entries, bank and card transactions imported through Plaid or from statements, reconciliations, invoices, receipts and supporting documents | **7 years** after the end of the fiscal year they belong to | U.S. federal tax record-keeping requirements (IRS); Florida business records |
| Plaid access tokens | Until the bank connection is disconnected; **deleted immediately** on disconnection (`/item/remove`) | Needed only while the connection is active |
| Raw Plaid API responses not needed for the books (for example pending transactions, merchant enrichment fields) | Not retained beyond the import run | Only posted transactions and balances enter the ledger |
| Operational data: projects, hours, materials, photos, notes | While the company uses the application; **deleted within 90 days** of a documented request or of ceasing to use the application, except what is part of accounting records | Business operations |
| User accounts (name, e-mail, role) | While the person works with the company; disabled on departure and deleted within 90 days, except the identity kept in the audit trail of accounting records | Access control and audit trail |
| Application and database logs | According to the provider's log retention (Supabase), currently measured in days to weeks | Troubleshooting and security monitoring |
| Backups | According to the Supabase project plan; backups expire on the provider's schedule and are not kept separately | Disaster recovery |

## 2. Disposal

- Data past its retention period is deleted from the production database by the owner; deletions of accounting
  records are done per fiscal year, after the seven years have passed and the company's accountant confirms no
  open audit or inquiry concerns that year.
- Disposal is performed by database deletion; the provider's encrypted storage and backup expiry complete the
  disposal. No data is stored on removable media or printed for retention; paper documents scanned into the
  application are the company's accounting documents and follow the seven-year rule.
- Plaid connections are removed through Plaid's API, which revokes the access token at Plaid; the local copy of the
  token is deleted at the same time.

## 3. Requests

The owner and employees can ask to see, correct or delete their data (contact above). Requests are answered within
30 days. Data that is part of accounting records cannot be deleted before the seven-year period ends; the request
and the reason are recorded.

## 4. Review

The owner reviews this policy and the retention table yearly, in January, together with the Information Security
Policy, and when the company changes providers (bank, Plaid, Supabase) or when a new type of data enters the
application.

---

*Resumen en español:* los registros contables (asientos, movimientos del banco y las tarjetas, conciliaciones,
facturas y recibos) se guardan siete años después de cerrar el año fiscal, como exige el IRS, y después se borran.
El token de Plaid se borra al desconectar la cuenta. Lo operativo (proyectos, horas, fotos) se guarda mientras la
empresa use la app y se borra a los 90 días de pedirlo. Las solicitudes se contestan en 30 días. Se revisa cada enero.
