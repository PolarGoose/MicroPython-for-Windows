Function Info($msg) {
    Write-Host -ForegroundColor DarkGreen "`nINFO: $msg`n"
}

Function Error($msg) {
  Write-Host `n`n
  Write-Error $msg
  exit 1
}

Function CheckReturnCodeOfPreviousCommand($msg) {
  if(-Not $?) {
    Error "${msg}. Error code: $LastExitCode"
  }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$buildDir = "$root/build"
$gitCommand = Get-Command -Name git

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Open Visual Studio 2022 Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Download MicroPython source code"
& $gitCommand clone --depth 1 --branch v1.23.0 https://github.com/micropython/micropython.git $buildDir/micropython
CheckReturnCodeOfPreviousCommand "Failed to clone the repository"

Info "Initialize git submodules"
Push-Location $buildDir/micropython
& $gitCommand submodule update --init lib/micropython-lib
CheckReturnCodeOfPreviousCommand "Failed to initialize submodules"
Pop-Location

Info "Build mpy-cross"
msbuild `
  /property:Configuration=Release `
  /property:Platform=x64 `
  /property:PyVariant=standard `
  -verbosity:Quiet `
  "$buildDir/micropython/mpy-cross/mpy-cross.vcxproj"
CheckReturnCodeOfPreviousCommand "Build failed"

Info "Build MicroPython"
msbuild `
  /property:Configuration=Release `
  /property:Platform=x64 `
  /property:PyVariant=standard `
  -verbosity:Quiet `
  "$buildDir/micropython/ports/windows/micropython.vcxproj"
CheckReturnCodeOfPreviousCommand "Build failed"

Info "Copy the MicroPython executable to the publish folder and create a zip archive out of it"
New-Item "$buildDir/publish" -Force -ItemType "directory" > $null
Copy-Item -Path "$buildDir/micropython/ports/windows/build-standard/Releasex64/micropython.exe" -Destination "$buildDir/publish"
Compress-Archive -Path "$buildDir/publish/micropython.exe" "$buildDir/publish/micropython.zip"
