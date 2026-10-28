$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
$env:ANDROID_HOME = "C:\Android\sdk"
$env:PATH = "C:\flutter\bin;C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin;" + $env:PATH
$flutterCmd = "C:\flutter\bin\flutter.bat"

Write-Output "Verifying Environment..."
& $flutterCmd doctor

Write-Output ""
Write-Output "Getting dependencies..."
& $flutterCmd pub get

Write-Output ""
Write-Output "Building Release APK..."
& $flutterCmd build apk --release

Write-Output ""
Write-Output "Build process completed!"
