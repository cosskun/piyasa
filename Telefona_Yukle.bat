@echo off
chcp 65001 > nul
title Piyasa - Telefona Yukle
echo ========================================================
echo        PİYASA OYUNUNU TELEFONA YÜKLEME ARACI
echo ========================================================
echo.
echo Bağlı cihazlar taranıyor...
flutter devices
echo --------------------------------------------------------
echo.
echo Telefonunuza yüklemek için flutter run başlatılıyor...
echo (Önbellek temizliği yapılıyor ve yeni logo ile derleniyor)
echo.
call flutter clean
call flutter pub get
call flutter run
pause
