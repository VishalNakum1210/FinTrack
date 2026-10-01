param(
    [Parameter(Mandatory = $true)][string]$DeviceSerial,
    [string]$AndroidSdk = "$env:LOCALAPPDATA/Android/sdk",
    [string]$Target = 'integration_test/device_smoke_test.dart',
    [string[]]$DartDefines = @(),
    [switch]$SkipBuild,
    [switch]$SkipInstall
)
$ErrorActionPreference = 'Stop'
$qaTarget = $Target
$qaPackage = 'com.vishalnakum.fintrack.qa'
$adbPath = Join-Path $AndroidSdk 'platform-tools/adb.exe'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory $qaTarget))
$integrationDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'integration_test'))
if (!$resolvedTarget.StartsWith($integrationDirectory + [System.IO.Path]::DirectorySeparatorChar) -or
    !$resolvedTarget.EndsWith('_test.dart') -or !(Test-Path -LiteralPath $resolvedTarget)) {
    throw 'Only existing integration_test/*_test.dart targets may run.'
}
$vmForwardPort = $null
$previousReportPath = $env:FINTRACK_QA_REPORT
function Get-ProtectedAppIdentity {
    $protectedPackages = & $adbPath -s $DeviceSerial shell pm list packages com.vishalnakum.fintrack
    if ($LASTEXITCODE -ne 0) { throw 'Could not list the protected package.' }
    if ($protectedPackages -notcontains 'package:com.vishalnakum.fintrack') { return '' }
    $protectedPaths = & $adbPath -s $DeviceSerial shell pm path com.vishalnakum.fintrack
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the protected app.' }
    $identity = @()
    foreach ($line in $protectedPaths) {
        if ($line -match '^package:(/data/app/.*\.apk)$') {
            $apkIdentity = & $adbPath -s $DeviceSerial shell sha256sum $Matches[1]
            if ($LASTEXITCODE -ne 0) { throw 'Cannot fingerprint the protected app.' }
            $identity += $apkIdentity
        } elseif ($line.Trim()) { throw 'Unexpected protected app location.' }
    }
    return ($identity -join "`n")
}
Push-Location $projectDirectory
try {
    & $adbPath -s $DeviceSerial get-state
    if ($LASTEXITCODE -ne 0) { throw 'The selected device is unavailable.' }
    $bootDeadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        $booted = ((& $adbPath -s $DeviceSerial shell getprop sys.boot_completed) -join '').Trim()
        if ($booted -eq '1') { break }
        Start-Sleep -Milliseconds 1000
    } while ([DateTime]::UtcNow -lt $bootDeadline)
    if ($booted -ne '1') { throw 'Android is not fully booted; nothing was installed.' }
    $protectedIdentity = Get-ProtectedAppIdentity
    # Building is safe; do not let Flutter install anything before inspecting it.
    if (!$SkipBuild) {
        $defineArguments = @($DartDefines | ForEach-Object { "--dart-define=$_" })
        & flutter build apk --debug --target $qaTarget @defineArguments
        if ($LASTEXITCODE -ne 0) { throw 'QA build failed; nothing was installed.' }
    }
    $apkPath = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/app-debug.apk'
    $metadata = Get-Content 'build/app/outputs/apk/debug/output-metadata.json' -Raw | ConvertFrom-Json
    if ($metadata.applicationId -ne $qaPackage) { throw 'Refusing a non-QA APK.' }
    $aaptPath = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Filter aapt2.exe -Recurse |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (!$aaptPath) { throw 'Cannot inspect the APK; nothing was installed.' }
    $badging = & $aaptPath dump badging $apkPath
    if ($LASTEXITCODE -ne 0 -or ($badging -join "`n") -notmatch "package: name='com\.vishalnakum\.fintrack\.qa'") {
        throw 'APK binary identity is not QA; nothing was installed.'
    }
    $resources = & $aaptPath dump resources $apkPath
    if ($LASTEXITCODE -ne 0 -or ($resources -join "`n") -notmatch 'demo-fintrack-audit' -or
        ($resources -join "`n") -match 'account-flutter-58a59') {
        throw 'Native Firebase configuration is not demo-only.'
    }
    $expectedTarget = [System.IO.Path]::GetRelativePath($projectDirectory, $resolvedTarget).Replace('\', '/')
    if (($resources -join "`n") -notmatch 'fintrack_qa_test_target' -or
        ($resources -join "`n") -notmatch [regex]::Escape($expectedTarget)) {
        throw 'QA APK target does not match the requested test; rebuild before using -SkipBuild.'
    }
    # Freeze the inspected binary. A subsequent Flutter command must not rebuild
    # a temporary listener with a different package or overwrite this APK.
    $verifiedDirectory = Join-Path $projectDirectory 'build/device-qa'
    New-Item -ItemType Directory -Path $verifiedDirectory -Force | Out-Null
    $verifiedApk = Join-Path $verifiedDirectory "verified-qa-$DeviceSerial.apk"
    Copy-Item -LiteralPath $apkPath -Destination $verifiedApk
    if ((Get-FileHash $verifiedApk).Hash -ne (Get-FileHash $apkPath).Hash) {
        throw 'Verified APK copy does not match.'
    }
    & $adbPath -s $DeviceSerial get-state
    if ($LASTEXITCODE -ne 0) { throw 'The selected device is unavailable.' }
    foreach ($port in @(61812, 61813)) {
        & $adbPath -s $DeviceSerial reverse "tcp:$port" "tcp:$port"
        if ($LASTEXITCODE -ne 0) { throw 'Could not connect the QA emulators.' }
    }
    # NEVER use flutter test -d: it builds a temporary listener, bypassing the
    # inspected target, and may uninstall an existing app on signature mismatch.
    if ($SkipInstall) {
        $installedQaPath = @(& $adbPath -s $DeviceSerial shell pm path $qaPackage)
        if ($LASTEXITCODE -ne 0 -or $installedQaPath.Count -ne 1 -or
            $installedQaPath[0] -notmatch '^package:(/data/app/.*\.apk)$') {
            throw 'Cannot verify the installed QA APK; -SkipInstall refused.'
        }
        $installedQaHash = ((& $adbPath -s $DeviceSerial shell sha256sum $Matches[1]) -join '').Split(' ')[0]
        if ($LASTEXITCODE -ne 0 -or $installedQaHash -ne (Get-FileHash $verifiedApk).Hash) {
            throw 'Installed QA APK differs; -SkipInstall refused.'
        }
    } else {
        & $adbPath -s $DeviceSerial install -r $verifiedApk
        if ($LASTEXITCODE -ne 0) { throw 'QA installation failed; NO uninstall fallback is allowed.' }
    }
    & $adbPath -s $DeviceSerial shell am force-stop $qaPackage
    & $adbPath -s $DeviceSerial shell am start -a android.intent.action.MAIN `
        -c android.intent.category.LAUNCHER --ez enable-dart-profiling true `
        --ez enable-checked-mode true --ez verify-entry-points true `
        -n "$qaPackage/com.vishalnakum.fintrack.MainActivity"
    if ($LASTEXITCODE -ne 0) { throw 'QA launch failed.' }
    $nativeServiceUri = $null
    $serviceDeadline = [DateTime]::UtcNow.AddSeconds(60)
    while (!$nativeServiceUri -and [DateTime]::UtcNow -lt $serviceDeadline) {
        $qaPid = ((& $adbPath -s $DeviceSerial shell pidof $qaPackage) -join '').Trim()
        if ($qaPid -match '^\d+$') {
            $qaLog = & $adbPath -s $DeviceSerial logcat -d --pid=$qaPid -s flutter:I '*:S'
            if (($qaLog -join "`n") -match 'The Dart VM service is listening on (http://127\.0\.0\.1:\d+/[^\s]+)') {
                $nativeServiceUri = [Uri]$Matches[1]
            }
        }
        if (!$nativeServiceUri) { Start-Sleep -Milliseconds 500 }
    }
    if (!$nativeServiceUri) { throw 'No QA VM service; no other app will be attached.' }
    $vmForwardPort = ((& $adbPath -s $DeviceSerial forward tcp:0 "tcp:$($nativeServiceUri.Port)") -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $vmForwardPort -notmatch '^\d+$') { throw 'QA VM forwarding failed.' }
    $hostServiceUri = "http://127.0.0.1:$vmForwardPort$($nativeServiceUri.AbsolutePath)"
    $reportName = "result-$([System.IO.Path]::GetFileNameWithoutExtension($resolvedTarget))-$DeviceSerial-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')).json"
    $env:FINTRACK_QA_REPORT = Join-Path $verifiedDirectory $reportName
    # Attach-only: Flutter has NO install, build, launch or uninstall role here.
    & flutter drive --driver tool/device_driver.dart --target $qaTarget -d $DeviceSerial `
        --use-existing-app $hostServiceUri --keep-app-running --no-pub --timeout 900
    if ($LASTEXITCODE -ne 0) { throw 'Device tests failed; QA app was retained.' }
    Write-Output "QA test evidence: $env:FINTRACK_QA_REPORT"
} finally {
    if ($vmForwardPort) { & $adbPath -s $DeviceSerial forward --remove "tcp:$vmForwardPort" 2>$null }
    foreach ($port in @(61812, 61813)) {
        & $adbPath -s $DeviceSerial reverse --remove "tcp:$port" 2>$null
    }
    $env:FINTRACK_QA_REPORT = $previousReportPath
    if ($null -ne $protectedIdentity -and (Get-ProtectedAppIdentity) -ne $protectedIdentity) {
        throw 'Protected FinTrack package identity changed unexpectedly.'
    }
    Pop-Location
}
