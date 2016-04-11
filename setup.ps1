$nl = [Environment]::NewLine

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Write-Host $nl"Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Break
}

# Set black background
$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

# define some variables
$temp="C:\Temp\saml-metadata-temp"
$setup="$temp\setup"
$npm="node-v4.4.2-x64.msi"
$config="c:\Program Files\Qlik\Sense\ServiceDispatcher"
$target="$config\Node\SAML-Metadata"

# check if module is installed
if(!(Test-Path -Path "$target\node_modules")) {

    $confirm = Read-Host "This script will install the SAML Metadata module, do you want to proceed? [Y/n]"
    if ($confirm -eq 'n') {
      Break
    }

    $wc = New-Object System.Net.WebClient

    # check if npm has been downloaded already
	if(!(Test-Path -Path "$temp\$npm")) {
        Write-Host "Downloading files..."
        New-Item -Path "$temp" -Type directory -force | Out-Null
        $wc.DownloadFile("http://nodejs.org/dist/v4.4.2/$npm", "$temp\$npm")
	}

    # check if module has been downloaded
    if(!(Test-Path -Path "$target\src")) {
        New-Item -Path "$target\src" -Type directory | Out-Null
        New-Item -Path "$target\src\css" -Type directory | Out-Null
        New-Item -Path "$target\src\views" -Type directory | Out-Null
        $wc.DownloadFile("http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/css/stylesheet.css", "$target\src\css\stylesheet.css")
        $wc.DownloadFile("http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/views/index.html", "$target\src\views\index.html")
        $wc.DownloadFile("http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/service.js", "$target\src\service.js")
        $wc.DownloadFile("http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/package.json", "$target\package.json")
    }

    # check if npm has been unzipped already
    if(!(Test-Path -Path "setup\nodejs")) {
        Write-Host "Extracting files..."
        Start-Process -Wait msiexec.exe "/a $temp\$npm /qn TARGETDIR=$setup"
    }

    # install module with dependencies
    Write-Host "Installing modules..."
    Push-Location "$target\src"
    $env:Path=$env:Path + ";$config\Node"
    &$setup\nodejs\npm.cmd config set spin=true
    &$setup\nodejs\npm.cmd --prefix "$target" install
    Pop-Location

    # cleanup temporary data
    Write-Host $nl"Removing temporary files..."
    Remove-Item $temp -recurse
}

# check if config has been added already
if (!(Select-String -path "$config\services.conf" -pattern "Identity=qlik-saml-metadata" -quiet)) {

	$settings = @"


[saml-metadata]
Identity=qlik-saml-metadata
Enabled=true
DisplayName=SAML Metadata
ExecType=nodejs
ExePath=Node\node.exe
Script=Node\SAML-Metadata\src\service.js

[saml-metadata.parameters]
Port=3001
"@
	Add-Content "$config\services.conf" $settings
}

Write-Host $nl"Done! Please restart the 'Qlik Sense Service Dispatcher' service for changes to take affect."$nl