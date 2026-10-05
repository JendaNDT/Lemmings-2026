# Paperlings: prepared publication, access pending

User authorized publishing both platforms on jenda.cool, and explicitly chose a
new signing key and independent clean Android installation. No additional
content approval is needed. Do not publish the old rc1 Android: it has no music.

## Ready

- `/paperlings/` download page, Czech/English, actual game screenshot.
- Homepage apps-section link, preserving the Supabase catalog.
- `binaries/paperlings-1.0.0-rc2/`: both music builds, SHA-256, public manifest,
  licenses and instructions. No private key or saved progress is included.
- Build/cache and existing regression checks passed, plus real Chromium
  downloads of both full files with matching hashes. Mobile/desktop layouts,
  translation and keyboard navigation passed.

## Current blocker

Reading JendaNDT/JendaWeb works, but actual push to main is rejected with HTTP
401. A dry-run using the existing gh credential helper succeeded; this did NOT
prove actual write access. Raising Git postBuffer did not fix the real push.
The remote main remains c30664f35c0ff5b2c6ac053e640ceb0251ed3a15 and public
https://jenda.cool/paperlings/ returns 404. Do not describe the page as deployed.

The environment draft now declares both checkouts and contains startup/export
instructions. Saving that draft is not publication, nor proof of access in a
new task. The user must enable/apply GitHub write access for JendaNDT/JendaWeb
through the environment/GitHub connection. Never request a token in chat.

## Resume after access works

1. Inspect the existing working tree and remote main; preserve any intervening
   work. The local Paperlings commits contain the complete website update.
2. Run `node build_site.cjs --check` and `node tests/startup-build.cjs` if the
   checkout was restored/rebased. Binaries must match the shipped SHA256SUMS.
3. Push main through the supported GitHub authentication. This repo deploys
   automatically to Vercel. No separate hosting secret is configured here.
4. Verify the public Paperlings page, the homepage link and BOTH complete
   downloads from jenda.cool against SHA-256. Record success only then.

## Independent recovery

Download branch in JendaNDT/Lemmings-2026: `downloads/android-1.0.0-rc2`.
It contains `android/Paperlings-1.0.0-rc2-Android.apk`,
`windows/Paperlings-1.0.0-rc2-Windows.zip`, and `web/JendaWeb-Paperlings-rc2.patch`.
The patch includes all website changes, images and metadata, excluding only
the two large installers. It applies to JendaWeb base commit
c30664f35c0ff5b2c6ac053e640ceb0251ed3a15; check before applying. Copy the two
installers from that branch into `binaries/paperlings-1.0.0-rc2/` and verify
SHA-256. This backup allows reconstructing the change without depending on a
local-only commit being restored by a new cloud task.
