REM @echo off
REM ***************************************************************************
REM    msvc-env.cmd
REM    ---------------------
REM    begin                : June 2018
REM    copyright            : (C) 2018 by Juergen E. Fischer
REM    email                : jef at norbit dot de
REM ***************************************************************************
REM *                                                                         *
REM *   This program is free software; you can redistribute it and/or modify  *
REM *   it under the terms of the GNU General Public License as published by  *
REM *   the Free Software Foundation; either version 2 of the License, or     *
REM *   (at your option) any later version.                                   *
REM *                                                                         *
REM ***************************************************************************

echo "Start"

if defined PROGRAMFILES(X86) set PF86=%PROGRAMFILES(X86)%
if not defined PF86 set PF86=%PROGRAMFILES%
if not defined PF86 (echo PROGRAMFILES not set & goto error)

echo "Step 1"

if not defined VCSDK set VCSDK=10.0.18362.0

set VCARCH=amd64
set SETUPAPI_LIBRARY=%PF86%\Windows Kits\10\Lib\%VCSDK%\um\x64\SetupAPI.Lib
set DBGHLP_PATH=%PF86%\Windows Kits\10\Debuggers\x64

echo "Step 2"

if not exist "%SETUPAPI_LIBRARY%" (
  echo SETUPAPI_LIBRARY not found
  dir /s /b "%PF86%\setupapi.lib"
  goto error
)

echo "Step 3"

if not exist "%DBGHLP_PATH%\dbghelp.dll" (
  echo dbghelp.dll not found
  dir /s /b "%PF86%\dbghelp.dll" "%PF86%\symsrv.dll"
  goto error
)

if not defined CC set CC=cl.exe
if not defined CXX set CXX=cl.exe
if not defined OSGEO4W_ROOT set OSGEO4W_ROOT=C:\OSGeo4W

if not exist "%OSGEO4W_ROOT%\bin\o4w_env.bat" (echo o4w_env.bat not found & goto error)
call "%OSGEO4W_ROOT%\bin\o4w_env.bat"

echo "Step 4"

for %%e in (Community Professional Enterprise) do if exist "%PF86%\Microsoft Visual Studio\2019\%%e" set vcdir=%PF86%\Microsoft Visual Studio\2019\%%e
if not defined vcdir (echo Visual C++ not found & goto error)

set VS160COMNTOOLS=%vcdir%\Common7\Tools
call "%vcdir%\VC\Auxiliary\Build\vcvarsall.bat" %VCARCH% %VCSDK%
path %path%;%vcdir%\VC\bin

echo "Step 5"

set LIB=%LIB%;%OSGEO4W_ROOT%\lib
set INCLUDE=%INCLUDE%;%OSGEO4W_ROOT%\include

goto end

:usage
echo usage: %0
exit /b 1

:error
echo ENV ERROR %ERRORLEVEL%: %DATE% %TIME%
exit /b 1

:end
