# Get Flutter SDK path
$flutterCmd = (Get-Command flutter).Source
$sdkDir = Split-Path (Split-Path $flutterCmd)
Write-Output "Flutter SDK at: $sdkDir"

# Check if packages/flutter_tools/gradle exists
$gradlePath = Join-Path $sdkDir "packages\flutter_tools\gradle"
Write-Output "Checking gradle path: $gradlePath"
Write-Output "Exists: $(Test-Path $gradlePath)"

# List packages directory
$pkgPath = Join-Path $sdkDir "packages"
if (Test-Path $pkgPath) {
    Write-Output "Packages dir contents:"
    Get-ChildItem $pkgPath | Select-Object Name
} else {
    Write-Output "Packages dir does NOT exist at: $pkgPath"
}

# Create a junction link at C:\flutter to avoid non-ASCII path issues
$targetLink = "C:\flutter"
if (-not (Test-Path $targetLink)) {
    Write-Output "Creating junction: $targetLink -> $sdkDir"
    cmd /c "mklink /J `"$targetLink`" `"$sdkDir`""
} else {
    Write-Output "Junction already exists at $targetLink"
}

# Verify the junction
if (Test-Path "$targetLink\bin\flutter.bat") {
    Write-Output "Junction verified OK: $targetLink\bin\flutter.bat exists"
} else {
    Write-Output "Junction FAILED"
}
