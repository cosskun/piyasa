@echo off
chcp 65001 > nul
title Piyasa - Ticaret & Borsa Oyunu

if exist "%~dp0build\windows\x64\runner\Release\piyasa.exe" (
    start "" "%~dp0build\windows\x64\runner\Release\piyasa.exe"
) else (
    start "" "%~dp0build\windows\x64\runner\Debug\piyasa.exe"
)
