# salesforce-metadata-automation

## Cursor Cloud specific instructions

### What this repo is
This is a **Salesforce DX (SFDX) metadata-as-source** project plus GitHub Actions automation.
There is **no local web/backend server and no local database** to run. The "runtime" is the
Salesforce CLI (`sf`) operating on the `force-app` source, and GitHub Actions workflows that
authenticate to a real Salesforce org. The only tracked content is declarative metadata under
`force-app/main/default/objects` (CustomObject/CustomField/RecordType/CustomTab/BusinessProcess).
There is currently **no Apex or LWC**, so there are no unit tests to run and nothing to build.

### Core dev workflow (offline, no org needed)
The Salesforce CLI is the core tool. These commands validate/parse the repo's real metadata
without any org or secret:
- Confirm project is recognized: `sf project list ignored`
- Parse + convert all source metadata to Metadata API format: `sf project convert source --root-dir force-app --output-dir /tmp/mdapi_out`
- Generate a manifest from source: `sf project generate manifest --source-dir force-app --name /tmp/generated`

### Operations that REQUIRE a live org (only run in GitHub Actions)
Deploy/retrieve/validate against an org depend on the `DEV_SFDX_AUTH_URL` secret, which lives in
**GitHub Actions secrets, not in this VM**. Do NOT attempt local org auth, retrieve, or dry-run
deploy here — they will fail with `NoDefaultEnvError`/auth errors. The relevant CI workflows are in
`.github/workflows/` (`salesforce-pr-validate.yml` runs a delta dry-run deploy; `salesforce-metadata-snapshot.yml`
and `salesforce-deploy-main.yml` retrieve metadata; `salesforce-auto-merge.yml` / `auto-ready-pr.yml`
manage PRs). See `.cursor/rules/salesforce-metadata-snapshot.mdc` for the Cursor→GitHub dispatch rule.

### Environment gotchas
- `sf` is installed as an npm global into `$HOME/.npm-global` (the default npm prefix in this image
  is not writable). `$HOME/.npm-global/bin` is added to `PATH` via `~/.bashrc`. If `sf: command not
  found`, run `export PATH="$HOME/.npm-global/bin:$PATH"` or open a new login shell.
- `salesforce-metadata-snapshots/*/package.json` is a committed **output snapshot** (a scaffolded
  SFDX project with eslint/prettier/jest), NOT the root dev project. Do not treat it as the repo's
  dependency manifest; the repo root has no `package.json`.
