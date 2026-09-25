@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "MSYS2_RELEASE=2026-06-11"
set "MSYS2_VERSION=20260611"
set "MSYS2_SHA256=c105946e64e08f099ac0e4647461ce762b95333ad211777666476a9a41451d65"
set "GIT_RELEASE=v2.55.0.windows.5"
set "GIT_ARCHIVE_VERSION=2.55.0.5"
set "GIT_SHA256=5aa8a20f6e9abb2c755f0e73c91c687701a46b309ad84a0ca6509380fa4ae290"
set "VSCODE_VERSION=1.138.0"
set "VSCODE_COMMIT=7debcd0e2acdea1c52de81bf9ee1620444407dda"
set "VSCODE_SHA256=820df7a601d0179fc850433e1a1c047d2926a7a5a78ef01cd49fe8833fa2010d"
if not defined DEV_TOOLS_ROOT set "DEV_TOOLS_ROOT=%LOCALAPPDATA%\portable-dev"
set "MSYS2_ROOT=%DEV_TOOLS_ROOT%\msys64"
set "GIT_ROOT=%DEV_TOOLS_ROOT%\git"
set "GIT_CMD=%DEV_TOOLS_ROOT%\git\cmd"
set "VSCODE_DIR=%LOCALAPPDATA%\Programs\Microsoft VS Code"
set "MSYS2_STAGE=%DEV_TOOLS_ROOT%\msys2-stage-%RANDOM%-%RANDOM%"
set "GIT_STAGE=%DEV_TOOLS_ROOT%\git-stage-%RANDOM%-%RANDOM%"
set "WORK_DIR=%TEMP%\windows-dev-setup-%RANDOM%-%RANDOM%"
set "MSYS2_ARCHIVE=%WORK_DIR%\msys2-base-x86_64-%MSYS2_VERSION%.sfx.exe"
set "GIT_ARCHIVE=%WORK_DIR%\PortableGit-%GIT_ARCHIVE_VERSION%-64-bit.7z.exe"
set "VSCODE_SETUP=%WORK_DIR%\VSCodeUserSetup-x64-%VSCODE_VERSION%.exe"
set "MSYS2_URL=https://github.com/msys2/msys2-installer/releases/download/%MSYS2_RELEASE%/msys2-base-x86_64-%MSYS2_VERSION%.sfx.exe"
set "GIT_URL=https://github.com/git-for-windows/git/releases/download/%GIT_RELEASE%/PortableGit-%GIT_ARCHIVE_VERSION%-64-bit.7z.exe"
set "VSCODE_URL=https://vscode.download.prss.microsoft.com/dbazure/download/stable/%VSCODE_COMMIT%/VSCodeUserSetup-x64-%VSCODE_VERSION%.exe"

if /i not "%OS%"=="Windows_NT" (
    echo ERROR: This script must run on Windows.
    exit /b 1
)

if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto :architecture_ok
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" goto :architecture_ok
echo ERROR: This script supports 64-bit x86 Windows only.
exit /b 1

:architecture_ok
if not defined LOCALAPPDATA (
    echo ERROR: LOCALAPPDATA is not defined for this user.
    exit /b 1
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell is required.
    exit /b 1
)
if exist "%WORK_DIR%" (
    echo ERROR: Temporary directory "%WORK_DIR%" already exists.
    exit /b 1
)
if not exist "%DEV_TOOLS_ROOT%\" md "%DEV_TOOLS_ROOT%" >nul 2>&1
if not exist "%DEV_TOOLS_ROOT%\" (
    echo ERROR: Could not create per-user directory "%DEV_TOOLS_ROOT%".
    exit /b 1
)
md "%WORK_DIR%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Could not create temporary directory "%WORK_DIR%".
    exit /b 1
)

echo(
echo [1/4] Installing portable MSYS2 in "%MSYS2_ROOT%"...
if exist "%MSYS2_ROOT%\usr\bin\bash.exe" goto :msys2_ready
if exist "%MSYS2_ROOT%" (
    echo ERROR: "%MSYS2_ROOT%" exists but is not a valid MSYS2 installation.
    goto :failed
)
if exist "%MSYS2_STAGE%" (
    echo ERROR: Temporary staging path "%MSYS2_STAGE%" already exists.
    goto :failed
)

call :download "%MSYS2_URL%" "%MSYS2_ARCHIVE%"
if errorlevel 1 goto :failed
call :verify_sha256 "%MSYS2_ARCHIVE%" "%MSYS2_SHA256%"
if errorlevel 1 goto :failed
set "MSYS2_STAGE_CREATED=1"
"%MSYS2_ARCHIVE%" -y -o"%MSYS2_STAGE%"
if errorlevel 1 (
    echo ERROR: MSYS2 extraction failed.
    goto :failed
)
if not exist "%MSYS2_STAGE%\msys64\usr\bin\bash.exe" (
    echo ERROR: The extracted MSYS2 installation is incomplete.
    goto :failed
)
move "%MSYS2_STAGE%\msys64" "%MSYS2_ROOT%" >nul
if errorlevel 1 (
    echo ERROR: Could not move MSYS2 into "%MSYS2_ROOT%".
    goto :failed
)
rd /s /q "%MSYS2_STAGE%" >nul 2>&1
set "MSYS2_STAGE_CREATED="

:msys2_ready
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"
call :run_msys true
if errorlevel 1 (
    echo ERROR: MSYS2 initialization failed.
    goto :failed
)

echo(
echo [2/4] Updating MSYS2 and installing g++...
call :run_msys "pacman --noconfirm -Syuu"
if errorlevel 1 (
    echo ERROR: MSYS2 core package update failed.
    goto :failed
)
call :run_msys "pacman --noconfirm -Syuu"
if errorlevel 1 (
    echo ERROR: MSYS2 package update failed.
    goto :failed
)
call :run_msys "pacman --noconfirm --needed -S mingw-w64-ucrt-x86_64-gcc"
if errorlevel 1 (
    echo ERROR: g++ installation failed.
    goto :failed
)
call :run_msys "g++ --version"
if errorlevel 1 (
    echo ERROR: g++ verification failed.
    goto :failed
)

echo(
echo [3/4] Installing PortableGit with Git Bash in "%GIT_ROOT%"...
if exist "%GIT_ROOT%\cmd\git.exe" if exist "%GIT_ROOT%\git-bash.exe" goto :git_ready
if exist "%GIT_ROOT%" (
    echo ERROR: "%GIT_ROOT%" exists but is not a valid PortableGit installation.
    goto :failed
)
if exist "%GIT_STAGE%" (
    echo ERROR: Temporary staging path "%GIT_STAGE%" already exists.
    goto :failed
)

call :download "%GIT_URL%" "%GIT_ARCHIVE%"
if errorlevel 1 goto :failed
call :verify_sha256 "%GIT_ARCHIVE%" "%GIT_SHA256%"
if errorlevel 1 goto :failed
set "GIT_STAGE_CREATED=1"
set "GIT_INSTALL_PATH=%GIT_STAGE:\=\\%"
"%GIT_ARCHIVE%" -y -gm2 -InstallPath="%GIT_INSTALL_PATH%"
if errorlevel 1 (
    echo ERROR: PortableGit extraction failed.
    goto :failed
)
if not exist "%GIT_STAGE%\cmd\git.exe" (
    echo ERROR: The extracted PortableGit installation is incomplete.
    goto :failed
)
if not exist "%GIT_STAGE%\git-bash.exe" (
    echo ERROR: Git Bash was not found in the extracted PortableGit installation.
    goto :failed
)
move "%GIT_STAGE%" "%GIT_ROOT%" >nul
if errorlevel 1 (
    echo ERROR: Could not move PortableGit into "%GIT_ROOT%".
    goto :failed
)
set "GIT_STAGE_CREATED="

:git_ready
set "PATH=%GIT_CMD%;%PATH%"
"%GIT_ROOT%\cmd\git.exe" --version
if errorlevel 1 (
    echo ERROR: Git verification failed.
    goto :failed
)
if not exist "%GIT_ROOT%\git-bash.exe" (
    echo ERROR: Git Bash verification failed.
    goto :failed
)
call :add_git_to_user_path
if errorlevel 1 echo WARNING: Git could not be added to your user PATH. Use its full path shown below.

echo(
echo [4/4] Installing VS Code %VSCODE_VERSION% in "%VSCODE_DIR%"...
if exist "%VSCODE_DIR%\Code.exe" goto :vscode_ready
where code.cmd >nul 2>&1
if not errorlevel 1 (
    echo VS Code is already installed on this machine.
    goto :vscode_done
)
call :download "%VSCODE_URL%" "%VSCODE_SETUP%"
if errorlevel 1 goto :failed
call :verify_sha256 "%VSCODE_SETUP%" "%VSCODE_SHA256%"
if errorlevel 1 goto :failed
"%VSCODE_SETUP%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /MERGETASKS="!runcode,addtopath,addcontextmenufiles,addcontextmenufolders"
if errorlevel 1 (
    echo ERROR: VS Code installation failed.
    goto :failed
)
if not exist "%VSCODE_DIR%\Code.exe" (
    echo ERROR: VS Code was not installed to "%VSCODE_DIR%".
    goto :failed
)

:vscode_ready
call "%VSCODE_DIR%\bin\code.cmd" --version
if errorlevel 1 (
    echo ERROR: VS Code verification failed.
    goto :failed
)

:vscode_done
echo(
echo Installation complete. No administrator privileges were requested.
echo Portable tools: "%DEV_TOOLS_ROOT%"
echo MSYS2 UCRT64: "%MSYS2_ROOT%\ucrt64.exe"
echo g++:           "%MSYS2_ROOT%\ucrt64\bin\g++.exe"
echo Git:           "%GIT_ROOT%\cmd\git.exe"
echo Git Bash:      "%GIT_ROOT%\git-bash.exe"
if exist "%VSCODE_DIR%\Code.exe" echo VS Code:       "%VSCODE_DIR%\Code.exe"
echo Open a new terminal before using git or code from PATH.
rd /s /q "%WORK_DIR%" >nul 2>&1
exit /b 0

:download
set "DOWNLOAD_URL=%~1"
set "DOWNLOAD_FILE=%~2"
echo Downloading %DOWNLOAD_URL%
powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:DOWNLOAD_URL -OutFile $env:DOWNLOAD_FILE"
if errorlevel 1 (
    echo ERROR: Download failed.
    exit /b 1
)
exit /b 0

:verify_sha256
set "VERIFY_FILE=%~1"
set "EXPECTED_SHA256=%~2"
echo Verifying SHA-256 for "%VERIFY_FILE%"...
powershell.exe -NoLogo -NoProfile -Command "$actual = (Get-FileHash -LiteralPath $env:VERIFY_FILE -Algorithm SHA256).Hash.ToLowerInvariant(); if ($actual -ne $env:EXPECTED_SHA256) { Write-Error ('SHA-256 mismatch. Expected {0}, got {1}.' -f $env:EXPECTED_SHA256, $actual); exit 1 }"
exit /b %ERRORLEVEL%

:run_msys
"%MSYS2_ROOT%\usr\bin\bash.exe" -lc "%~1"
exit /b %ERRORLEVEL%

:add_git_to_user_path
powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference = 'Stop'; $gitCmd = $env:GIT_CMD.TrimEnd([char]92); $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment'); try { $names = @($key.GetValueNames()); $userPath = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); $entries = @($userPath -split ';' | ForEach-Object { $_.Trim().TrimEnd([char]92) }); if ($entries -notcontains $gitCmd) { $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $gitCmd } else { $userPath.TrimEnd([char]59) + ';' + $gitCmd }; $kind = if ($names -contains 'Path') { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }; $key.SetValue('Path', $newPath, $kind) } } finally { $key.Dispose() }; $quote = [char]34; $member = '[System.Runtime.InteropServices.DllImportAttribute(' + $quote + 'user32.dll' + $quote + ', SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Unicode)] public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint flags, uint timeout, out System.UIntPtr result);'; Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition $member; $result = [UIntPtr]::Zero; [Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null"
exit /b %ERRORLEVEL%

:failed
echo(
echo Setup failed. Review the errors above and run the script again.
if defined MSYS2_STAGE_CREATED rd /s /q "%MSYS2_STAGE%" >nul 2>&1
if defined GIT_STAGE_CREATED rd /s /q "%GIT_STAGE%" >nul 2>&1
rd /s /q "%WORK_DIR%" >nul 2>&1
exit /b 1
