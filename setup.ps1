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

    # check if npm has been downloaded already
	if(!(Test-Path -Path "$temp\$npm")) {
        New-Item -Path "$temp" -Type directory -force | Out-Null
		Invoke-WebRequest "https://nodejs.org/dist/v4.4.2/$npm" -OutFile "$temp\$npm"
	}

    # check if module has been downloaded
    if(!(Test-Path -Path "$target\src")) {
        New-Item -Path "$target\src" -Type directory | Out-Null
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/css/stylesheet.css" -OutFile "$target\src\css\service.js"
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/views/index.html" -OutFile "$target\src\views\index.html"
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/service.js" -OutFile "$target\src\service.js"
        Invoke-WebRequest "http://raw.githubusercontent.com/braathen/qlik-saml-metadata/master/package.json" -OutFile "$target\package.json"
    }

    # check if npm has been unzipped already
    if(!(Test-Path -Path "setup\nodejs")) {
        Write-Host "Extracting files..."
        Start-Process -Wait msiexec.exe "/a $temp\$npm /qn TARGETDIR=$setup"
        #Add-Type -assembly "system.io.compression.filesystem"
        #[io.compression.zipfile]::ExtractToDirectory("$temp\npm.zip", "$temp\")
    }

    # install module with dependencies
	Write-Host "Installing modules..."    
    Push-Location "$target\src"
    $env:Path=$env:Path + ";$config\Node"
	&$setup\nodejs\npm.cmd config set spin=false
	&$setup\nodejs\npm.cmd --prefix "$target" install
    Pop-Location

    # cleanup temporary data
    Write-Host $nl"Removing temporary files..."
    #Remove-Item $temp -recurse
}

# check if config has been added already
if (!(Select-String -path "$config\services.conf" -pattern "Identity=rfn-google-auth" -quiet)) {

	$settings = @"
[saml-metadata]
Identity=qlik-saml-metadata
Enabled=true
DisplayName=SAML Metadata
ExecType=nodejs
ExePath=Node\node.exe
Script=Node\data-prep\src\service.js

[saml-metadata.parameters]
Port=3001
"@
	#Add-Content "$config\services.conf" $settings
}

Write-Host $nl"Done! Please restart the 'Qlik Sense Service Dispatcher' service for changes to take affect."$nl