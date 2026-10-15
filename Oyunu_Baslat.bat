@echo off
chcp 65001 > nul
title Piyasa - Ticaret & Borsa Oyunu
start "" "%~dp0build\windows\x64\runner\Debug\piyasa.exe"
