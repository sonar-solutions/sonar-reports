@echo off
REM Build script for Windows

echo Building sonar-reports executable...

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python is not installed
    exit /b 1
)

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt
pip install -r requirements-dev.txt

REM Detect architecture
set ARCH=%PROCESSOR_ARCHITECTURE%
echo Detected Architecture: %ARCH%

REM Build with PyInstaller
echo Building with PyInstaller...
if "%ARCH%"=="ARM64" (
    pyinstaller sonar-reports.spec --target-arch arm64
    set OUTPUT_NAME=sonar-reports-windows-arm64.exe
) else (
    pyinstaller sonar-reports.spec
    set OUTPUT_NAME=sonar-reports-windows-x86_64.exe
)

REM Rename the binary
echo Renaming binary to %OUTPUT_NAME%...
move dist\sonar-reports.exe "dist\%OUTPUT_NAME%"

echo Build complete! Binary available at: dist\%OUTPUT_NAME%
echo.
echo You can now run: dist\%OUTPUT_NAME% --help

pause
