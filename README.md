# ExcaliburCalc

Byter ut Windows kalkylator mot [Excalibur RPN Calculator](https://github.com/wavemotion-dave/Excalibur)
på calc-knappen, och ser till att bara en instans körs åt gången.

Ett tryck på calc-knappen startar räknaren. Nästa tryck hämtar upp fönstret som
redan är öppet i stället för att starta en till.

## Så fungerar det

Calc-knappen på tangentbordet skickar `VK_LAUNCH_APP2`. Explorer slår upp den i
registret under `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AppKey\18`
och kör det som står i `ShellExecute`. Installationen pekar det värdet på
`excalibur-launcher.exe`.

Ingen fil i `C:\Windows\System32` rörs. Windows egen `calc.exe` ligger kvar och
fungerar som förut om du skriver `calc` i Kör-dialogen. Bindningen ligger under
HKCU, så den kräver inget administratörskonto och överlever Windows-uppdateringar.

Launchern letar efter ett fönster med klassnamnet `EXCALIBUR`. Hittar den ett
sådant lyfter den fram det, annars startar den `Excal32.exe` från sin egen mapp.
En namngiven mutex serialiserar snabba dubbeltryck, så knappstuds inte hinner
starta två instanser.

## Installera

Bygg launchern på Linux:

    sudo apt install gcc-mingw-w64-x86-64
    ./build.sh

Kopiera mappen till Windows-datorn och kör i PowerShell:

    .\install.ps1 -RestartExplorer

PowerShell varnar för skript som kommer från en nätverksresurs. Slipp frågan
med `Unblock-File .\install.ps1`, eller kopiera mappen till en lokal disk först.

Skriptet stänger en Excalibur som redan körs från installationsmappen innan det
skriver över filerna, så det går att köra om för att uppgradera.

Skriptet hämtar senaste Excalibur-release från GitHub, lägger den i
`%LOCALAPPDATA%\Excalibur` tillsammans med launchern, och skriver registervärdet.
Utan `-RestartExplorer` slår bindningen igenom först när du loggat ut och in.

## Avinstallera

    .\uninstall.ps1 -RemoveFiles -RestartExplorer

## Numpad

Excalibur läser tangenttryck som `WM_CHAR` och matchar tecknet mot sin
knapptabell (`RPNkeys` i `src/Excal.c`). Numpadens siffror, `+`, `-`, `*`, `/`
och Enter ger samma tecken som motsvarande tangenter på huvudraden, så hela
numpaden fungerar direkt.

Ett undantag: på svensk layout ger numpadens decimaltangent komma, inte punkt.
Excalibur översätter komma till decimalpunkt bara när räknaren står i
kommaläge - ställ in det under Excalibur Settings om du vill använda den
tangenten.

Räknaren är RPN. Det finns ingen `=`-tangent: mata in talet, tryck Enter, mata
in nästa tal, tryck operator.

## Fönsterplacering

Launchern flyttar räknaren till muspekaren varje gång - både när den startar
den och när den hämtar fram ett fönster som redan är öppet. Fönstret centreras
under pekaren och klampas innanför arbetsytan på den skärm pekaren står på, så
det aldrig hamnar bakom aktivitetsfältet eller utanför skärmkanten.

Excalibur sparar sin fönsterposition när den stängs. Positionen som sparas blir
alltså den sista launchern flyttade den till - räknaren öppnas ändå alltid vid
pekaren, så det märks inte.

## Licens

MIT, se [LICENSE](LICENSE). Excalibur självt är ett separat MIT-licensierat
projekt av Dave Bernazzani och ingår inte här - installationsskriptet hämtar
det från GitHub vid installation.
