# Script PowerShell untuk Build Flutter Web
$flutterCmd = "C:\flutter\bin\flutter.bat"

if (-not (Test-Path $flutterCmd)) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        $flutterCmd = "flutter"
    } else {
        Write-Error "Flutter SDK tidak ditemukan. Pastikan Flutter sudah terpasang di sistem atau C:\flutter."
        exit 1
    }
}

Write-Output "==> Memeriksa dependensi Flutter..."
& $flutterCmd pub get

Write-Output ""
Write-Output "==> Membangun Flutter Web Release..."
& $flutterCmd build web --release

Write-Output ""
Write-Output "==> Selesai! Berkas siap diunggah ke Suga App ada di folder: build/web"
