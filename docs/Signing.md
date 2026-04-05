# Signing the MSIX (GitHub Actions + install without Developer Mode)

Windows will not install an MSIX whose publisher is not trusted. There is **no supported command-line flag** to bypass that without **Developer Mode** or **trusting the signing certificate**.

## Troubleshooting: "Publisher: Unknown" / `0x800B010A`

1. **Open the same workflow run** you downloaded the MSIX from. Under **Artifacts**:
   - If you **only** see **`msix-win-x64`** and **not** **`install-trust-certificate`**, the build was **unsigned**. You never set **`CMDPAL_PFX_BASE64`** (or it was empty). Add the secret and run again.
2. If you **do** see **`install-trust-certificate`**:
   - Install the **`.cer`** from that artifact first: **Local Machine** → **Trusted People** (you need an admin prompt). Use the **`.cer` from the same run** as the `.msix`.
   - If **Install** stays blocked, try **Trusted Root Certification Authorities** instead (acceptable for your own test cert only).
3. **Base64 secret** must be **one continuous line**. If you pasted with line breaks, fix the secret or regenerate; the workflow strips whitespace, but a bad paste can still corrupt the PFX.
4. On your PC you can check whether the file is signed:

```powershell
Get-AuthenticodeSignature -FilePath "C:\path\to\your.msix"
```

`Status : Valid` (or similar) means signed; `NotSigned` means the GitHub build did not sign it.

This repo is set up so CI can **sign** the package using a **PFX** stored in GitHub Secrets. You install the matching **public certificate (.cer)** once on your PC (Trusted People), then normal double-click install works.

## 1. Create a PFX on your PC (one time)

Run PowerShell **as your user** (admin not required for creation):

```powershell
cd <path-to-this-repo>
.\scripts\New-CmdPalSigningCertificate.ps1
```

The script creates a cert with Subject **`CN=Zunaid Farouque`** (must match `Package.appxmanifest`), exports:

- `CmdPal_CI_Signing.pfx` — **secret**, for GitHub only  
- `CmdPal_CI_Public.cer` — **public**, you will trust this on your PC

Choose a password when prompted (or Enter for empty password).

## 2. Add GitHub Secrets

In the repo: **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|------|--------|
| `CMDPAL_PFX_BASE64` | Base64 of the **PFX** file (single line). PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\CmdPal_CI_Signing.pfx")) \| Set-Clipboard` |
| `CMDPAL_PFX_PASSWORD` | Optional. Only if you used a non-empty PFX password. If the PFX has no password, **omit** this secret entirely. |

## 3. Trust the public certificate on your PC (one time, no Developer Mode)

1. Copy `CmdPal_CI_Public.cer` to the PC (or download **`install-trust-certificate`** artifact from a successful signed workflow run and use the `.cer` inside).
2. Double-click the `.cer` → **Install Certificate** → **Local Machine** → **Place all certificates in the following store** → **Browse** → **Trusted People** → Finish.

## 4. Get and install the MSIX

After a successful **Build** workflow:

1. Download artifact **`msix-win-x64`**.
2. Open the `.msix` → **Install**.

## GitHub Release (signed MSIX for download)

1. Add **`CMDPAL_PFX_BASE64`** (and optional **`CMDPAL_PFX_PASSWORD`**) as repository **Actions** secrets (same as CI build).
2. On GitHub: **Actions** → **Release** → **Run workflow**, leave tag **`v0.0.1`** (or set another `vMAJOR.MINOR.PATCH`).
3. When the job finishes, open **Releases**: download **`CmdPal_CI_Public.cer`** and the **`.msix`**, trust the cert (Trusted People), then install the MSIX.

From a machine with the repo and **`CmdPal_CI_Signing.pfx`** at the root:

```powershell
$env:GH_TOKEN = '<personal access token with repo scope>'
pwsh ./scripts/Publish-GitHubRelease.ps1 -Tag v0.0.1
```

## Pull requests from forks

If `CMDPAL_PFX_BASE64` is not set, the workflow still builds an **unsigned** MSIX (install requires Developer Mode or local signing). Fork PRs do not receive your secrets.

## Download latest CI build locally (gitignored)

After a **successful** Build workflow on `main` (see the repository **Actions** tab), you can pull artifacts into **`artifacts/run-<runId>/`** (ignored by git) using the GitHub CLI.

**One-time setup**

1. **Either** install [GitHub CLI](https://cli.github.com/) and run `gh auth login` **or** set **`GH_TOKEN`** (or **`GITHUB_TOKEN`**) to a PAT with **`actions:read`** and **`repo`** (private repos). The script uses the REST API and does not require `gh` if a token is set.

**Download**

From the repository root:

```powershell
pwsh ./scripts/Download-LatestBuild.ps1
```

Optional parameters: `-Branch main`, `-Workflow build.yml`, `-Owner yourUser`, `-Repo yourRepo` (owner/repo default from `git remote origin`).

**Layout** (under `artifacts/run-<runId>/`)

- `msix-win-x64/` — artifact contents (often a `.zip` you extract to get the `.msix`).
- `install-trust-certificate/` — only when CI signed the package; contains `CmdPal_CI_Public.cer`.

Exact names match the workflow artifact names; GitHub may wrap files in a zip per artifact.

## Store / real distribution

Replace the publisher and use a real code-signing certificate from a public CA when you publish to the Microsoft Store or ship broadly.

## Local reinstall after code changes

For an AI-oriented checklist, HRESULT table, and scripts:

- **`scripts/Publish-AndInstall-Local.ps1`** — build + trust + install on your PC.
- **`scripts/Install-LocalSignedMsix.ps1`** — install only when an `.msix` already exists (same trust/sign flow; run from repo root).

See **`docs/Install-After-Code-Changes.md`**. Cursor/agents also load **`AGENTS.md`** (repo root) and **`.cursor/rules/msix-local-install.mdc`** for the same commands.
