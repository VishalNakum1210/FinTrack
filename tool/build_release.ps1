param(
    [Parameter(Mandatory = $true)][string]$JdkHome,
    [ValidateSet('Apk', 'AppBundle', 'Both')][string]$Format = 'Apk',
    [string]$AndroidSdk,
    [switch]$PlaySubmission,
    [string]$PrivacyUrl,
    [string]$DeletionUrl
)
$ErrorActionPreference = 'Stop'
if ($PlaySubmission) {
    if ($Format -eq 'Apk') { throw 'A Play submission requires -Format AppBundle or Both.' }
    foreach ($policyUrl in @($PrivacyUrl, $DeletionUrl)) {
        $parsedPolicyUrl = $null
        if (![Uri]::TryCreate($policyUrl, [UriKind]::Absolute, [ref]$parsedPolicyUrl) -or
            $parsedPolicyUrl.Scheme -ne 'https' -or $parsedPolicyUrl.Host -match 'localhost|example\.|\.invalid$') {
            throw 'Play submission requires real public HTTPS privacy and account-deletion URLs. Candidate builds do not need this switch.'
        }
        $policyResponse = Invoke-WebRequest -Uri $policyUrl -TimeoutSec 30
        if ($policyResponse.StatusCode -ne 200 -or $policyResponse.Content -match 'DRAFT — NOT PUBLISHED') {
            throw 'Policy page is unavailable or is still a draft.'
        }
    }
}
$resolvedReleaseJdk = (Resolve-Path -LiteralPath $JdkHome).Path
$releaseJava = Join-Path $JdkHome 'bin/java.exe'
if (!(Test-Path -LiteralPath $releaseJava -PathType Leaf)) {
    throw 'JdkHome must point to a JDK 21 installation.'
}
$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$releaseJavaVersion = (& $releaseJava -version 2>&1 | Out-String)
$ErrorActionPreference = $previousEap
if ($LASTEXITCODE -ne 0 -or $releaseJavaVersion -notmatch 'version "21\.') {
    throw 'This release build requires JDK 21 for Gradle 8.14 compatibility.'
}
$previousJavaHome = $env:JAVA_HOME
$previousPath = $env:Path
$previousGradleOptions = $env:GRADLE_OPTS
$releaseProject = Split-Path $PSScriptRoot -Parent
Push-Location $releaseProject
try {
    $env:JAVA_HOME = $resolvedReleaseJdk
    $env:Path = "$env:JAVA_HOME/bin;$previousPath"
    $env:GRADLE_OPTS = "$previousGradleOptions -Dorg.gradle.java.home=`"$env:JAVA_HOME`""
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Release dependencies failed verification.' }
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
    & flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Automated tests failed.' }
    # Allow Flutter to regenerate its plugin registrant for release mode.
    # --no-pub can retain a debug registrant containing development plugins.
    if ($Format -in @('Apk', 'Both')) {
        if (!$AndroidSdk) {
            $sdkLine = Get-Content android/local.properties | Where-Object { $_ -match '^sdk.dir=' } | Select-Object -First 1
            if (!$sdkLine) { throw 'Pass -AndroidSdk with the Android SDK directory.' }
            $AndroidSdk = $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':')
        }
        $releaseBuildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
        if (!$releaseBuildTools) { throw 'Android SDK build tools are required for APK verification.' }
        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'Signed Android APK build failed.' }
        $verification = & "$PSScriptRoot/verify_release_apk.ps1" -ApkPath build/app/outputs/flutter-apk/app-release.apk -BuildTools $releaseBuildTools.FullName
        $releaseDirectory = Join-Path $releaseProject "build/direct-release/$($verification.Version)"
        New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
        $distributedApk = Join-Path $releaseDirectory "FinTrack-$($verification.Version)-universal.apk"
        Copy-Item -LiteralPath $verification.File -Destination $distributedApk
        if ((Get-FileHash -LiteralPath $distributedApk).Hash.ToLowerInvariant() -ne $verification.Sha256) {
            throw 'Distribution copy failed checksum verification.'
        }
        $verification.File = [IO.Path]::GetFileName($distributedApk)
        $verification | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $releaseDirectory 'verification.json') -Encoding utf8
        "$($verification.Sha256)  $($verification.File)" | Set-Content -LiteralPath (Join-Path $releaseDirectory 'SHA256SUMS.txt') -Encoding ascii
        Copy-Item -LiteralPath (Join-Path $releaseProject 'release/INSTALL.md') -Destination (Join-Path $releaseDirectory 'INSTALL_AND_RELEASE_NOTES.md')
        Write-Output "Verified direct-install release: $distributedApk"
    }
    if ($Format -in @('AppBundle', 'Both')) {
        & flutter build appbundle --release
        if ($LASTEXITCODE -ne 0) { throw 'Signed Android bundle build failed.' }
        $bundlePath = Join-Path $releaseProject 'build/app/outputs/bundle/release/app-release.aab'
        & "$PSScriptRoot/verify_native_pages.ps1" -ArchivePath $bundlePath | Out-Null
        $bundleSignature = (& (Join-Path $resolvedReleaseJdk 'bin/jarsigner.exe') -verify $bundlePath 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or $bundleSignature -notmatch 'jar verified') { throw 'AAB signature verification failed.' }
        $bundleCertificate = (& (Join-Path $resolvedReleaseJdk 'bin/keytool.exe') -printcert -jarfile $bundlePath 2>&1 | Out-String)
        $pinnedBundleSigner = (Get-Content "$PSScriptRoot/release_signer.sha256" -Raw).Trim().ToUpperInvariant()
        if ($LASTEXITCODE -ne 0 -or ($bundleCertificate.Replace(':','') -notmatch $pinnedBundleSigner)) { throw 'AAB release certificate does not match the pinned signer.' }
        $bundleSpec = Get-Content pubspec.yaml -Raw
        if ($bundleSpec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$') { throw 'Missing bundle version.' }
        $bundleVersion = $Matches[1]
        $bundleDirectory = Join-Path $releaseProject "build/play-release/$bundleVersion"
        New-Item -ItemType Directory -Path $bundleDirectory -Force | Out-Null
        $bundleDestination = Join-Path $bundleDirectory "FinTrack-$bundleVersion.aab"
        Copy-Item -LiteralPath $bundlePath -Destination $bundleDestination
        $bundleHash = (Get-FileHash -LiteralPath $bundleDestination -Algorithm SHA256).Hash.ToLowerInvariant()
        "$bundleHash  $([IO.Path]::GetFileName($bundleDestination))" | Set-Content (Join-Path $bundleDirectory 'SHA256SUMS.txt') -Encoding ascii
        Copy-Item release/INSTALL.md (Join-Path $bundleDirectory 'INSTALL_AND_RELEASE_NOTES.md')
        Write-Output "Verified signed Play release candidate: $bundleDestination"
    }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:Path = $previousPath
    $env:GRADLE_OPTS = $previousGradleOptions
    Pop-Location
}
