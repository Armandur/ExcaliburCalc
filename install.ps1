<#
.SYNOPSIS
    Installerar Excalibur RPN-räknare och binder calc-knappen på tangentbordet till den.

.DESCRIPTION
    Hämtar senaste Excalibur-release från GitHub, lägger den i en mapp tillsammans
    med excalibur-launcher.exe, och pekar tangentbordets calc-knapp (VK_LAUNCH_APP2)
    på launchern via HKCU\...\Explorer\AppKey\18.

    Launchern ser till att bara en instans körs: ett andra tryck fokuserar fönstret
    som redan är öppet.

    Kräver inget administratörskonto - allt ligger under användarens profil.

.EXAMPLE
    .\install.ps1 -RestartExplorer
#>
[CmdletBinding()]
param(
    # Mapp att installera i.
    [string]$InstallDir = "$env:LOCALAPPDATA\Excalibur",

    # Starta om Explorer så registerändringen slår igenom direkt.
    [switch]$RestartExplorer,

    # Hoppa över nedladdningen, använd Excal32.exe som redan ligger i InstallDir.
    [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$launcherSource = Join-Path $PSScriptRoot 'dist\excalibur-launcher.exe'
if (-not (Test-Path $launcherSource)) {
    throw "Hittar inte $launcherSource. Bygg den först med build.sh."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (-not $SkipDownload) {
    Write-Host "Hämtar senaste Excalibur-release..."
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/wavemotion-dave/Excalibur/releases/latest' `
                                 -Headers @{ 'User-Agent' = 'excalibur-installer' }
    $asset = $release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "Ingen zip-fil i release $($release.tag_name)." }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("excalibur-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        $exe = Get-ChildItem -Path $tmp -Filter 'Excal*.exe' -Recurse | Select-Object -First 1
        if (-not $exe) { throw "Ingen Excal*.exe i $($asset.name)." }

        Copy-Item $exe.FullName (Join-Path $InstallDir 'Excal32.exe') -Force
        Write-Host "Installerade $($release.tag_name) ($($exe.Name)) i $InstallDir"
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$targetExe = Join-Path $InstallDir 'Excal32.exe'
if (-not (Test-Path $targetExe)) {
    throw "Hittar inte $targetExe. Kör utan -SkipDownload."
}

$launcher = Join-Path $InstallDir 'excalibur-launcher.exe'
Copy-Item $launcherSource $launcher -Force

# AppKey 18 är calc-knappen (VK_LAUNCH_APP2). Explorer läser ShellExecute här.
$appKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AppKey\18'
New-Item -Path $appKey -Force | Out-Null
Set-ItemProperty -Path $appKey -Name 'ShellExecute' -Value $launcher -Type String

# Association vinner över ShellExecute om den ligger kvar.
Remove-ItemProperty -Path $appKey -Name 'Association' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $appKey -Name 'RegisteredApp' -ErrorAction SilentlyContinue

Write-Host "Calc-knappen pekar nu på $launcher"

if ($RestartExplorer) {
    Write-Host "Startar om Explorer..."
    Stop-Process -Name explorer -Force
} else {
    Write-Host "Logga ut och in, eller kör om med -RestartExplorer, så slår bindningen igenom."
}
