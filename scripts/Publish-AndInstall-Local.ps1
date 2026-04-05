#requires -Version 5.1
<#
.SYNOPSIS
    Publishes the MSIX locally and installs it (ephemeral sign + trust + Add-AppxPackage by default).

.DESCRIPTION
    Builds CmdPal_UniversalSearchHub_Extension with the same publish flags as CI (Release, win-x64,
    sideload MSIX). Unsigned packages are signed with a short-lived self-signed certificate
    matching Package.appxmanifest Publisher (CN=Zunaid Farouque), then an elevated
    prompt imports the public cert to Local Machine\Trusted People and runs Add-AppxPackage.

    See docs/Install-After-Code-Changes.md for AI-oriented instructions and troubleshooting.

.PARAMETER SignedPublish
    Sign during dotnet publish using CmdPal_CI_Signing.pfx at the repo root (from
    New-CmdPalSigningCertificate.ps1). Trust CmdPal_CI_Public.cer once on the PC. No ephemeral signing.

.PARAMETER PfxPassword
    Plain-text PFX password for -SignedPublish only. If omitted, uses env CMDPAL_PFX_PASSWORD or empty.

.PARAMETER SkipPublish
    Skip restore/publish; use -MsixPath to install an existing .msix (ephemeral sign unless already signed + trusted).

.PARAMETER MsixPath
    Required when -SkipPublish. Path to a .msix file.

.PARAMETER RemoveExisting
    Before install, removes Get-AppxPackage -Name 'ZunaidFarouque.CmdPalSearchHub' if present.

.PARAMETER NoForceUpdateFromAnyVersion
    Do not pass -ForceUpdateFromAnyVersion to Add-AppxPackage (stricter version rules).

.PARAMETER SkipInstall
    Build (and sign) only; do not elevate or run Add-AppxPackage. Use with -SignedPublish to produce a signed .msix for release.

.EXAMPLE
    pwsh ./scripts/Publish-AndInstall-Local.ps1

.EXAMPLE
    pwsh ./scripts/Publish-AndInstall-Local.ps1 -SignedPublish

.EXAMPLE
    pwsh ./scripts/Publish-AndInstall-Local.ps1 -SkipPublish -MsixPath 'D:\artifacts\...\App.msix'
#>
[CmdletBinding()]
param(
    [switch] $SignedPublish,
    [string] $PfxPassword,
    [switch] $SkipPublish,
    [string] $MsixPath,
    [string] $Configuration = 'Release',
    [switch] $RemoveExisting,
    [switch] $NoForceUpdateFromAnyVersion,
    [switch] $SkipInstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projRel = 'CmdPal_UniversalSearchHub_Extension\CmdPal_UniversalSearchHub_Extension.csproj'
$projPath = Join-Path $repoRoot $projRel
$pfxPath = Join-Path $repoRoot 'CmdPal_CI_Signing.pfx'
$cerPublicPath = Join-Path $repoRoot 'CmdPal_CI_Public.cer'
$manifestPublisherCn = 'CN=Zunaid Farouque'

function Get-SignToolExe {
    $all = @(Get-ChildItem -Path 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue)
    $x64 = $all | Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } | Sort-Object FullName -Descending | Select-Object -First 1
    $exe = if ($x64) { $x64 } else { $all | Sort-Object FullName -Descending | Select-Object -First 1 }
    if (-not $exe) {
        throw 'signtool.exe not found under Windows Kits. Install Windows SDK or VS C++ workload (see docs/Install-After-Code-Changes.md).'
    }
    return $exe.FullName
}

function Sign-MsixFile {
    param(
        [Parameter(Mandatory)][string] $MsixPath,
        [Parameter(Mandatory)][string] $PfxPath,
        [string] $PfxPasswordPlain
    )
    # MSBuild/signing breaks when paths contain spaces; sign via temp file + x64 signtool.
    $signtool = Get-SignToolExe
    $item = Get-Item -LiteralPath $MsixPath
    $tempDir = Join-Path $env:TEMP ("cmdpal_sign_{0}" -f [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempMsix = Join-Path $tempDir $item.Name
    try {
        Copy-Item -LiteralPath $item.FullName -Destination $tempMsix -Force
        $signArgs = @('sign', '/fd', 'SHA256', '/f', $PfxPath)
        if ($PfxPasswordPlain) {
            $signArgs += @('/p', $PfxPasswordPlain)
        }
        $signArgs += $tempMsix
        & $signtool @signArgs
        if ($LASTEXITCODE -ne 0) {
            throw "signtool failed with exit code $LASTEXITCODE."
        }
        Copy-Item -LiteralPath $tempMsix -Destination $item.FullName -Force
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Find-PublishedMsix {
    $projDir = Join-Path $repoRoot 'CmdPal_UniversalSearchHub_Extension'
    if (-not (Test-Path -LiteralPath $projDir)) {
        throw "Project directory not found: $projDir"
    }
    $candidates = @(Get-ChildItem -LiteralPath $projDir -Recurse -Filter '*.msix' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'AppPackages' })
    if ($candidates.Count -eq 0) {
        throw "No .msix under **/AppPackages in $projDir. Publish may have failed."
    }
    return ($candidates | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1)
}

if ($SkipPublish) {
    if (-not $MsixPath) {
        throw '-SkipPublish requires -MsixPath.'
    }
    $builtMsix = Get-Item -LiteralPath $MsixPath
}
else {
    if (-not (Test-Path -LiteralPath $projPath)) {
        throw "Project not found: $projPath"
    }
    if ($SignedPublish -and -not (Test-Path -LiteralPath $pfxPath)) {
        throw "SignedPublish requires $pfxPath. Run scripts/New-CmdPalSigningCertificate.ps1 first."
    }

    Push-Location $repoRoot
    try {
        dotnet restore CmdPal_UniversalSearchHub_Extension.sln
        dotnet restore $projRel -r win-x64

        $pubArgs = @(
            'publish', $projRel,
            '-c', $Configuration,
            '-r', 'win-x64',
            '--no-restore',
            '/p:Platform=x64',
            '/p:GenerateAppxPackageOnBuild=true',
            '/p:UapAppxPackageBuildMode=SideloadOnly',
            '/p:AppxBundle=Never'
        )
        # Always produce an unsigned package here; Sign-MsixFile applies the PFX (avoids SignTool path bugs with spaces).
        $pubArgs += '/p:AppxPackageSigningEnabled=false'
        dotnet @pubArgs
    }
    finally {
        Pop-Location
    }

    $builtMsix = Find-PublishedMsix
    Write-Host "Published: $($builtMsix.FullName)"
    if ($SignedPublish) {
        $pwdPlain = if ($null -ne $PfxPassword -and $PfxPassword.Length -gt 0) { $PfxPassword } elseif ($env:CMDPAL_PFX_PASSWORD) { $env:CMDPAL_PFX_PASSWORD } else { '' }
        Write-Host 'Signing MSIX with CmdPal_CI_Signing.pfx (signtool)...'
        Sign-MsixFile -MsixPath $builtMsix.FullName -PfxPath $pfxPath -PfxPasswordPlain $pwdPlain
    }
}

$sourceMsix = $builtMsix.FullName
$installMsix = $sourceMsix
$cerToTrust = $null

if ($SignedPublish) {
    if (-not (Test-Path -LiteralPath $cerPublicPath)) {
        throw "SignedPublish build expects public cert at $cerPublicPath (export from New-CmdPalSigningCertificate.ps1)."
    }
    $cerToTrust = $cerPublicPath
}
elseif (-not $SkipInstall) {
    # Ephemeral sign a copy so LocalMachine trust + Add-AppxPackage succeed for unsigned CI/local builds.
    $signtool = Get-SignToolExe
    $installMsix = Join-Path $env:TEMP ("CmdPalSearchHub_local_{0}.msix" -f [guid]::NewGuid().ToString('n'))
    Copy-Item -LiteralPath $sourceMsix -Destination $installMsix -Force

    $pwd = [Security.SecureString]::new()
    $cert = New-SelfSignedCertificate `
        -Subject $manifestPublisherCn `
        -Type Custom `
        -KeySpec Signature `
        -KeyUsage DigitalSignature `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddHours(2) `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')

    $tempPfx = Join-Path $env:TEMP ("cmdpal_ephemeral_{0}.pfx" -f [guid]::NewGuid().ToString('n'))
    try {
        Export-PfxCertificate -Cert $cert -FilePath $tempPfx -Password $pwd | Out-Null
        # Call signtool directly; Start-Process + empty /p drops arguments on some hosts.
        & $signtool sign /fd SHA256 /f $tempPfx /p '' $installMsix
        if ($LASTEXITCODE -ne 0) {
            throw "signtool failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -LiteralPath $tempPfx -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue
    }

    $sig = Get-AuthenticodeSignature -FilePath $installMsix
    if (-not $sig.SignerCertificate) {
        throw 'Ephemeral signing did not produce a signer certificate on the MSIX.'
    }
    $cerToTrust = Join-Path $env:TEMP ("cmdpal_ephemeral_{0}.cer" -f [guid]::NewGuid().ToString('n'))
    Export-Certificate -Cert $sig.SignerCertificate -FilePath $cerToTrust -Type CERT | Out-Null
}

if ($SkipInstall) {
    Write-Host "SkipInstall: MSIX path: $sourceMsix"
    if ($SignedPublish) {
        Write-Host "Publish the matching trust certificate with your release: $cerPublicPath"
    }
    else {
        Write-Host 'Tip: use -SignedPublish for a stable cert users can trust (see docs/Signing.md).'
    }
    return
}

$forceArg = if (-not $NoForceUpdateFromAnyVersion) { "-ForceUpdateFromAnyVersion" } else { '' }
$removeBlock = if ($RemoveExisting) {
    @"
Get-AppxPackage -Name 'ZunaidFarouque.CmdPalSearchHub' -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
"@
} else { '' }

# Escape single quotes for single-quoted embedded paths in elevated script
$cerEsc = $cerToTrust.Replace("'", "''")
$msixEsc = $installMsix.Replace("'", "''")

$elevatedBody = @"
`$ErrorActionPreference = 'Stop'
try {
$removeBlock
    try {
        Import-Certificate -FilePath '$cerEsc' -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    }
    catch {
        # Same .cer may already be trusted from a previous install.
        if (`$_.Exception.Message -notmatch 'already|exists|duplicate') { throw }
    }
    Import-Module Appx -ErrorAction Stop
    Add-AppxPackage -Path '$msixEsc' $forceArg
}
catch {
    Write-Host (`$_.Exception.Message)
    exit 1
}
"@

$elevatedPath = Join-Path $env:TEMP ("cmdpal_elevated_install_{0}.ps1" -f [guid]::NewGuid().ToString('n'))
Set-Content -LiteralPath $elevatedPath -Value $elevatedBody -Encoding UTF8
try {
    Write-Host 'Requesting Administrator consent (import .cer to Local Machine\Trusted People + install MSIX)...'
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $elevatedPath)
    if ($null -eq $p.ExitCode) {
        throw 'Elevated step did not return an exit code (UAC cancelled or process did not start).'
    }
    if ($p.ExitCode -ne 0) {
        throw "Elevated install step exited with code $($p.ExitCode)."
    }
}
finally {
    Remove-Item -LiteralPath $elevatedPath -Force -ErrorAction SilentlyContinue
    if (-not $SignedPublish -and $cerToTrust -and (Test-Path -LiteralPath $cerToTrust) -and $cerToTrust.StartsWith($env:TEMP, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $cerToTrust -Force -ErrorAction SilentlyContinue
    }
    if (-not $SignedPublish -and $installMsix -ne $sourceMsix -and (Test-Path -LiteralPath $installMsix)) {
        Remove-Item -LiteralPath $installMsix -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Done. Verify: Get-AppxPackage -Name ''ZunaidFarouque.CmdPalSearchHub'''
