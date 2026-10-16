# Information Security Policy — Max Power Panel

**Max Power Electrical Solutions, Inc.** (Ocala, Florida) · Effective October 16, 2026 · Version 1.0
**Owner of this policy:** Edgar Arboleya, Owner / President · edgararboleya@mxpes.com · info@mxpes.com (monitored)

*Resumen en español al final.*

## 1. Scope and purpose

Max Power Panel is an **internal web application** used by Max Power Electrical Solutions, Inc. to run its own
operations (projects, hours, materials, estimates) and, since October 2026, its own **bookkeeping** (general
ledger, bank and credit card reconciliation). It is used by the company's owner and its small field team. It has
**no external consumers**: the only financial data it holds is the company's own, and the only person who can see
or act on financial data is the owner.

This policy states how that data is protected. It is reviewed at least once a year by the owner, and whenever a
new service provider (such as Plaid) is connected.

## 2. Systems and data

| Component | Provider / location | What it holds |
|---|---|---|
| Database and authentication | Supabase (PostgreSQL 17, AWS `us-east-1`, United States) | Operational data, the general ledger, bank and card transactions, user accounts |
| Serverless functions | Supabase Edge Functions (same project) | Server-side logic that needs secrets (e-mail, AI assistant, bank connector) |
| Front end | Static files on GitHub Pages, served over HTTPS | No data is stored in the front end beyond the signed-in user's session |
| Bank data connector | Plaid (Transactions product only) | Read-only import of the company's own bank and card transactions and balances |
| Source code | GitHub | Application code and SQL; **never** credentials or financial data |

Data classification: **financial data** (ledger, bank and card transactions, balances, statements) is the most
sensitive class and is restricted to the owner. **Operational data** (projects, hours, materials) is available to
the team according to role. **Credentials and secrets** (API keys, Plaid access tokens, passwords) are never
stored in code, in the front end, in chat tools or in documents.

## 3. Access control and authentication

- Every user signs in with an individual account (e-mail and password) managed by Supabase Auth. Sessions use
  short-lived signed tokens that are refreshed automatically and revoked on sign-out.
- Authorization is enforced **in the database**, not in the browser: PostgreSQL row-level security policies grant
  access by role (`owner`, `field`, `license holder`). Financial tables, views and functions check that the caller
  is the owner; anonymous and team roles have no access to them. The front end only hides what the database
  already denies.
- Server-side functions that touch money or the bank run as the database owner and verify the caller's identity
  before doing anything. The database's service key is never shipped to the client.
- **Least privilege:** the public API key can only do what row-level security allows; team members cannot read
  any monetary field; nobody can edit posted ledger entries (corrections are new, linked entries).
- **Multi-factor authentication is required** on every administrative console that can reach production assets
  or sensitive data: Supabase, GitHub, Plaid and the owner's e-mail. Administrative access is limited to the owner.
- Access reviews: the list of application users and of people with console access is reviewed by the owner when
  someone joins or leaves the company, and at least yearly.

## 4. Secrets management

- Third-party credentials (Plaid `client_id` and `secret`, e-mail, AI provider) live only in Supabase Edge Function
  secrets, set by the owner directly in the Supabase console. They are never pasted in chat, e-mail or code.
- Plaid **access tokens** are stored encrypted in the database's secret store (Supabase Vault), are used only by the
  server-side connector function, and are deleted when a bank connection is removed (`/item/remove`).
- Secrets are rotated when a person with access leaves, when a secret may have been exposed, and at least yearly.

## 5. Encryption

- **In transit:** all traffic between browsers, the database, the functions, GitHub Pages and Plaid uses HTTPS
  with TLS 1.2 or better. Plain HTTP is not served.
- **At rest:** Supabase encrypts database storage and backups at rest (AES-256). Plaid access tokens are
  additionally encrypted at the application layer (Vault).
- No financial data is stored on phones or laptops: the bookkeeping screens work online only and keep nothing in
  local storage beyond the session token.

## 6. Logging, monitoring and integrity

- The general ledger is append-only: every entry is numbered without gaps and chained with a cryptographic hash
  of the previous entry; history tables are immutable. A set of automated controls (ledger chain, balance checks,
  bank reconciliation, view-versus-table counts) runs every morning and on every screen load, and the screens
  refuse to render when a control fails.
- Supabase keeps API, authentication and database logs; the application records who did what on every financial
  action (who posted, matched, classified or reconciled, and the written reason when one is required).

## 7. Secure development and vulnerability management

- Code changes are reviewed and tested before publication: automated browser tests and database test suites run
  before any release, and security reviews are run on changes that touch authentication or money.
- The front end has **no third-party runtime dependencies** (plain HTML, CSS and JavaScript), which removes most
  supply-chain exposure. GitHub secret scanning is enabled on the repository and the repository never contains
  credentials or financial data.
- Servers, database engine and runtime are patched by the managed providers (Supabase, GitHub, Plaid). The
  owner's computers run a supported operating system with automatic updates and endpoint protection enabled.
- Secrets or data accidentally exposed are treated as an incident (section 8), not as a bug.

## 8. Incident response

If unauthorized access, loss or exposure of data or secrets is suspected:

1. **Contain:** rotate the affected secrets (Supabase keys, Plaid secrets), remove affected Plaid connections,
   sign out all sessions and reset affected passwords.
2. **Assess:** determine what data and which systems were involved, using the Supabase logs and the ledger trail.
3. **Notify:** inform Plaid and the financial institutions involved as required by their terms, and any person whose
   data was affected, within the timeframes the law and contracts require.
4. **Record and fix:** write down what happened, what was done and what changes prevent it from recurring.

Security contact: Edgar Arboleya, Owner / President · edgararboleya@mxpes.com · info@mxpes.com.

## 9. Data retention and deletion

- Accounting records (ledger entries, bank and card transactions, reconciliations, supporting documents) are kept
  for **seven years** after the end of the fiscal year, as required for U.S. tax purposes, and then deleted.
- Plaid access tokens are deleted immediately when a bank connection is disconnected. Raw bank data not needed for
  the books is not retained beyond the import.
- Operational data is kept while the company uses the application. Backups follow the Supabase project plan and
  are deleted on the provider's schedule.
- The owner can request deletion of any data not subject to the seven-year retention; requests are handled within
  30 days. This section is reviewed yearly together with the rest of this policy.

## 10. Service providers

Supabase (database, authentication, functions, United States), GitHub (code hosting and static site), Plaid
(bank data connector), and the AI provider used by the assistant features (which receives selected business data,
never bank credentials or Plaid tokens). Each provider is used under its commercial terms and privacy policy.

---

## Resumen en español

Max Power Panel es la aplicación interna de Max Power Electrical Solutions, Inc. Los datos viven en Supabase
(Estados Unidos), cifrados en tránsito y en reposo. Solo el dueño ve o toca el dinero: lo exige la base de datos
(reglas por fila), no la pantalla. Las llaves y los tokens de Plaid se guardan en el almacén de secretos del
servidor y nunca pasan por el chat, el código ni el teléfono. Todas las consolas de administración (Supabase,
GitHub, Plaid, correo) llevan verificación en dos pasos. El libro contable es inalterable y encadenado, con
controles automáticos cada mañana. Si algo se expone, se rotan las llaves, se evalúa, se avisa y se documenta. Los
registros contables se guardan siete años. Esta política se revisa cada año.
