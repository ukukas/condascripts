## WARNING: conda installer writes temporary files to %USERPROFILE%
#           must be run from account with %USERPROFILE%
#           might result in corrupted install when ran from SYSTEM account

## SETUP COMPONENTS
# miniconda installer
$installer = Resolve-Path ".\miniconda.exe"
# folder containing yml (conda) and txt (jupyter) specfiles
$specfiles = Resolve-Path ".\specfiles"
# folder containing ico-files for start menu
$icons = Resolve-Path ".\icons"
# folder containing lnk-files for start menu
$shortcuts = Resolve-Path ".\shortcuts"
# folder containing config files as they would appear in %APPDATA%
$configfiles = Resolve-Path ".\configfiles"
# setup script for IRkernel
$irsetup = Resolve-Path ".\irsetup.R"

## SETUP CONFIGURATION
# conda installation directory
$condapath = "C:\anaconda"
# start menu folder
$startmenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Anaconda3 (64-bit)"
# %APPDATA% for Default user
$appdata = "C:\Users\Default\AppData\Roaming"
# R installation dir (can be set to $false if R not installed)
$rhome = "C:\Program Files\R"

## HELPERS
function Get-Timestamp {return "[$(Get-Date -Format HH:mm:ss)]"}

function Write-TimestampedHost ($string) {
    Write-Host "$(Get-Timestamp) $string"
}

## MAIN
# install miniconda
Write-TimestampedHost "Running installer..."
Start-Process $installer -ArgumentList "/S /InstallationType=AllUsers /AddToPath=0 /RegisterPython=1 /D=$condapath" -Wait

# configure permissions for conda install (mimic ProgramData)
Write-TimestampedHost "Setting permissions for conda root..."
icacls.exe $condapath /inheritance:d /C /Q
icacls.exe $condapath /remove "Authenticated Users" /C /Q
icacls.exe $condapath /grant "CREATOR OWNER:(OI)(CI)(IO)(F)" /C /Q
icacls.exe $condapath /grant "BUILTIN\Users:(CI)(WD,AD,WEA,WA)" /C /Q

# setup powershell environment to use conda
Write-TimestampedHost "Configuring powershell for use of conda commands..."
Invoke-Expression (Join-Path $condapath "shell\condabin\conda-hook.ps1")

# update base environment
Write-TimestampedHost "Updating base environment..."
Invoke-Conda env update --file (Join-Path $specfiles "base.yml") --prune --quiet

# create and populate other environments
Write-TimestampedHost "Creating datalab environment..."
Invoke-Conda env create --file (Join-Path $specfiles "datalab.yml") --quiet
Write-TimestampedHost "Creating essentials environment..."
Invoke-Conda env create --file (Join-Path $specfiles "essentials.yml") --quiet
Write-TimestampedHost "Creating writable environment..."
Invoke-Conda env create --file (Join-Path $specfiles "writable.yml") --quiet

# configure jupyter
Write-TimestampedHost "Installing jupyterlab packages..."
$jupyter = Join-Path $condapath "envs\datalab\Scripts\jupyter.exe"
$extdir = Join-Path $condapath "envs\datalab\share\jupyter\lab\extensions"
Invoke-Conda activate datalab
foreach ($pkg in (Get-Content (Join-Path $specfiles "datalab_jupyter.txt"))) {
    Start-Process -FilePath $jupyter -ArgumentList "labextension install --no-build $pkg" -Wait -NoNewWindow
}
Write-TimestampedHost "Building jupyterlab..."
Start-Process -FilePath $jupyter -ArgumentList "lab build --dev-build=False --minimize=False" -Wait -NoNewWindow
Write-TimestampedHost "Cleaning jupyterlab build cache..."
Start-Process -FilePath $jupyter -ArgumentList "lab clean"
Invoke-Conda deactivate
Write-TimestampedHost "Setting permissions for jupyterlab..."
icacls.exe (Join-Path $extdir "*") /reset /C /Q
Remove-Variable "jupyter"
Remove-Variable "extdir"

# configure permissons for writable environment
Write-TimestampedHost "Setting permissions for writable environment..."
$writable = Join-Path $condapath "envs\writable"
$history = Join-Path $writable "conda-meta\history"
icacls.exe $writable /grant "BUILTIN\Users:(OI)(CI)(IO)M" /C /Q
icacls.exe $writable /grant "BUILTIN\Users:(RX,W)" /C /Q
icacls.exe $history /inheritance:d /C /Q
icacls.exe $history /remove BUILTIN\Users /C /Q
icacls.exe $history /grant "BUILTIN\Users:(RX,W)" /C /Q
Remove-Variable "writable"
Remove-Variable "history"

# configure start menu shortcuts
Write-TimestampedHost "Configuring start menu shortcuts..."
Copy-Item -Path (Join-Path $icons "*") -Destination (Join-Path $condapath "envs\datalab\Menu") -Force
if (Test-Path $startmenu) {
    Get-ChildItem -Path $startmenu | ForEach-Object {Remove-Item -Recurse -Force -LiteralPath $_.FullName}
} else {
    [void](New-Item -ItemType Directory -Path $startmenu)
}
Copy-Item -Path (Join-Path $shortcuts "*") -Destination $startmenu

# copy configuration files
Write-TimestampedHost "Copying configuration files"
Copy-Item -Path (Join-Path $configfiles "*") -Destination $appdata -Recurse -Force

# configure IRkernel (if R installed)
Write-TimestampedHost "Configuring irkernel..."
$rscript = Join-Path $rhome "bin\Rscript.exe"
if (Test-Path $rscript) {
    Invoke-Conda activate datalab
    Start-Process -FilePath $rscript -ArgumentList "`"$irsetup`""
    Invoke-Conda deactivate
}
Remove-Variable "rscript"

# clean temporary files
Write-TimestampedHost "Cleaning up..."
Invoke-Conda clean --all --yes --quiet

Write-TimestampedHost "DONE"