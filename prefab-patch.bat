@echo off
chcp 65001
set current_dir=%~dp0
set exe=bin\msvc\debug\vaststars.exe
set titlemsg=debug
set param=.\startup\prefab.lua
set /p choose="choose: 1:apply patch; 2:save patch; default: 1;"

if "%choose%"=="1" set command="patch"
if "%choose%"=="2" set command="save"
if /i "%choose%"=="" set command="patch"

pushd %current_dir%

if not exist "%exe%" (
	set exe=bin\msvc\release\vaststars.exe
	set titlemsg=release
)

%current_dir%%exe% %param% %command%

popd
pause