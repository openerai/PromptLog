param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot "build\windows"
$distDir = Join-Path $projectRoot "dist"
$sourceFile = Join-Path $PSScriptRoot "PromptLogHost.cs"
$htmlFile = Join-Path $projectRoot "prompt-log.html"
$iconFile = Join-Path $buildDir "PromptLog.ico"
$exeFile = Join-Path $buildDir "PromptLog.exe"
$compiler = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "C# compiler not found: $compiler" }
if (!(Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw "Host source not found: $sourceFile" }
if (!(Test-Path -LiteralPath $htmlFile -PathType Leaf)) { throw "App HTML not found: $htmlFile" }

New-Item -ItemType Directory -Force -Path $buildDir, $distDir | Out-Null

Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 64, 64
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(20, 20, 25))
$gold = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(224, 177, 92))
$dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(20, 20, 25))
$graphics.FillRectangle($gold, 17, 12, 29, 40)
$graphics.FillPolygon($dark, [System.Drawing.Point[]]@(
    (New-Object System.Drawing.Point 38, 12),
    (New-Object System.Drawing.Point 46, 20),
    (New-Object System.Drawing.Point 38, 20)
))
$font = New-Object System.Drawing.Font "Segoe UI", 24, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$graphics.DrawString("P", $font, $dark, 21, 24)
$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
$stream = [System.IO.File]::Create($iconFile)
try { $icon.Save($stream) } finally { $stream.Dispose() }
$icon.Dispose(); $font.Dispose(); $gold.Dispose(); $dark.Dispose(); $graphics.Dispose(); $bitmap.Dispose()

$compilerArgs = @(
    "/nologo",
    "/target:winexe",
    "/platform:anycpu",
    "/optimize+",
    "/win32icon:$iconFile",
    "/reference:System.dll",
    "/reference:System.Core.dll",
    "/reference:System.Drawing.dll",
    "/reference:System.Windows.Forms.dll",
    "/resource:$htmlFile,PromptLog.Html",
    "/out:$exeFile",
    $sourceFile
)
& $compiler $compilerArgs
if ($LASTEXITCODE -ne 0) { throw "PromptLog.exe compilation failed with exit code $LASTEXITCODE" }

$isccCandidates = @(@(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:LOCALAPPDATA} "Programs\Inno Setup 6\ISCC.exe")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) })

if ($isccCandidates.Count -eq 0) {
    Write-Host "PromptLog.exe built: $exeFile"
    Write-Warning "Inno Setup 6 was not found. Install it, then run this script again to build the installer."
    exit 0
}

& ($isccCandidates[0]) (Join-Path $PSScriptRoot "PromptLog.iss")
if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed with exit code $LASTEXITCODE" }
Write-Host "Installer built: $(Join-Path $distDir 'PromptLog-Setup-0.4.0.exe')"
