param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$BuildTools
)
$ErrorActionPreference = 'Stop'
$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$apksigner = Join-Path $BuildTools 'apksigner.bat'
$aapt = Join-Path $BuildTools 'aapt.exe'
$zipalign = Join-Path $BuildTools 'zipalign.exe'
$projectRoot = Split-Path $PSScriptRoot -Parent
$expectedSigner = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release_signer.sha256') -Raw).Trim()
if ($expectedSigner -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid pinned release certificate.' }
$pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { throw 'Invalid release version.' }
$expectedName = $Matches[1]
$expectedCode = $Matches[2]
& $zipalign -c -P 16 4 $resolvedApk | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'APK ZIP alignment failed (16 KB native pages).' }
& "$PSScriptRoot/verify_native_pages.ps1" -ArchivePath $resolvedApk | Out-Null
$signature = (& $apksigner verify --verbose --print-certs $resolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
if ($signature -notmatch 'Number of signers: 1' -or
    $signature -notmatch 'Verified using v2 scheme \(APK Signature Scheme v2\): true' -or
    $signature -notmatch "Signer #1 certificate SHA-256 digest: $expectedSigner") {
    throw 'APK is not signed with the pinned FinTrack release certificate and APK Signature Scheme v2.'
}
$badging = (& $aapt dump badging $resolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect APK metadata.' }
if ($badging -notmatch "package: name='com\.vishalnakum\.fintrack' versionCode='$expectedCode' versionName='$([regex]::Escape($expectedName))'") {
    throw 'APK package or version is not the requested production release.'
}
$manifest = (& $aapt dump xmltree $resolvedApk AndroidManifest.xml 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect release manifest.' }
foreach ($flag in @('debuggable', 'testOnly', 'allowBackup', 'usesCleartextTraffic')) {
    if ($manifest -match "android:$flag\([^)]*\)=\(type 0x12\)0xffffffff") {
        throw "Release manifest has forbidden flag: $flag"
    }
}
$resources = (& $aapt dump --values resources $resolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $resources -match 'fintrack_qa_test_target|demo-fintrack-audit') {
    throw 'QA resources detected in release APK or resources could not be inspected.'
}
if ($manifest -notmatch 'android:networkSecurityConfig\([^)]*\)=@(0x[0-9a-f]+)') {
    throw 'Missing explicit production network security configuration.'
}
$networkResourceId = $Matches[1]
# Android resource shrinking may rename res/xml/network_security_config.xml.
# Resolve the actual archive path from the manifest's resource ID.
if ($resources -notmatch "resource $networkResourceId [^\r\n]*:xml/network_security_config:[^\r\n]*\r?\n\s+\(string8\) `"(res/[^`"]+)`"") {
    throw 'Could not resolve the release network policy resource.'
}
$networkConfigPath = $Matches[1]
$networkConfig = (& $aapt dump xmltree $resolvedApk $networkConfigPath 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or
    $networkConfig -notmatch 'cleartextTrafficPermitted(?:\([^)]*\))?=\(type 0x12\)0x0' -or
    $networkConfig -match 'cleartextTrafficPermitted(?:\([^)]*\))?=\(type 0x12\)0xffffffff') {
    throw 'Release network security configuration permits cleartext traffic or cannot be inspected.'
}
[pscustomobject]@{
    File = $resolvedApk
    Package = 'com.vishalnakum.fintrack'
    Version = "$expectedName+$expectedCode"
    Bytes = (Get-Item -LiteralPath $resolvedApk).Length
    Sha256 = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()
    SignerSha256 = $expectedSigner.ToLowerInvariant()
    SignatureV2Verified = $true
    MinSdk = if ($badging -match "(?m)^sdkVersion:'(\d+)'") { [int]$Matches[1] } else { throw 'Missing minimum SDK.' }
    TargetSdk = if ($badging -match "(?m)^targetSdkVersion:'(\d+)'") { [int]$Matches[1] } else { throw 'Missing target SDK.' }
    NativeAbis = if ($badging -match "(?m)^native-code:\s*([^\r\n]+)") { $Matches[1].Trim() } else { throw 'Missing native architectures.' }
}
