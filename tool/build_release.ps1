param(
    [Parameter(Mandatory = $true)][string]$JdkHome
)
$ErrorActionPreference = 'Stop'
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
    & flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw 'Signed Android release build failed.' }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    $env:Path = $previousPath
    $env:GRADLE_OPTS = $previousGradleOptions
    Pop-Location
}
