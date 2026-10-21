@echo off
setlocal

if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
if not defined JAVA_HOME if exist "%LOCALAPPDATA%\Programs\Android Studio\jbr\bin\java.exe" set "JAVA_HOME=%LOCALAPPDATA%\Programs\Android Studio\jbr"

pushd "%~dp0"
if errorlevel 1 exit /b 1
if not exist "build" mkdir "build"
set "BUILD_LOG=%CD%\build\newpipe-build.log"
call "gradlew.bat" --no-daemon --console=plain --stacktrace fatJar > "%BUILD_LOG%" 2>&1
set "BUILD_RESULT=%ERRORLEVEL%"
type "%BUILD_LOG%"
popd
exit /b %BUILD_RESULT%
