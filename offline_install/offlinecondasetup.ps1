## SETUP COMPONENTS
# tar containing anaconda skeleton (with root folder)
$condatar = Resolve-Path ".\anaconda.tar"
# tar containing pkgs folder
$pkgstar = Resolve-Path ".\pkgs.tar"
# folder containing environment tar archives (with root folders)
$envtars = Resolve-Path ".\envs"
# reg file for registry configuration
$regfile = Resolve-Path ".\python.reg"
# tar containing shortcuts for start menu
$lnktar = Resolve-Path ".\shortcuts.tar"
# folder containing config files as they would appear in %APPDATA%
$configfiles = Resolve-Path ".\config"
# folder containing IRkernel setup files
$irfiles = Resolve-Path ".\irkernel"

## SETUP CONFIGURATION
# directory into witch the conda root folder will be placed
$installparent = "C:\"
# name of conda root folder in $condatar
$rootname = "anaconda"
# conda start menu folder
$startmenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Anaconda3 (64-bit)"
# %APPDATA% for Default user
$appdata = "C:\Users\Default\AppData\Roaming"
# R installation dir (can be set to $false if R not installed)
$rhome = "C:\Program Files\R"
# ProgramData folder
$programdata = "C:\ProgramData"

## GLOBAL VARS
# no need to change if all setup constants above defined correctly
$condapath = Join-Path $installparent $rootname
$envsdir = Join-Path $condapath "envs"

## HELPERS
function Get-Timestamp {return "[$(Get-Date -Format HH:mm:ss)]"}

function Write-TimestampedHost ($string) {
    Write-Host "$(Get-Timestamp) $string"
}

## MAIN
# check for existing files in $condapath
if (Test-Path $condapath) {
    Write-TimestampedHost "Existing files detected at $condapath"
    Write-TimestampedHost "Attempting removal of existing files..."
    Remove-Item -Recurse -Force -Path $condapath -ErrorAction Stop
    Write-TimestampedHost "All files successfully removed from $condapath"
}

# extract anaconda skeleton
Write-TimestampedHost "Extracting anaconda skeleton..."
tar.exe -xf $condatar -C $installparent

# set permissions for anaconda folder
Write-TimestampedHost "Setting permissions for conda root..."
icacls.exe $condapath /inheritance:d /C /Q
icacls.exe $condapath /remove "Authenticated Users" /C /Q
icacls.exe $condapath /grant "CREATOR OWNER:(OI)(CI)(IO)(F)" /C /Q
icacls.exe $condapath /grant "BUILTIN\Users:(CI)(WD,AD,WEA,WA)" /C /Q

# extract pkgs folder
Write-TimestampedHost "Extracting pkgs folder..."
tar.exe -xf $pkgstar -C $condapath

# extract environments
Write-TimestampedHost "Extracting datalab environment..."
tar.exe -xf (Join-Path $envtars "datalab.tar") -C $envsdir
Write-TimestampedHost "Extracting essentials environment..."
tar.exe -xf (Join-Path $envtars "essentials.tar") -C $envsdir
Write-TimestampedHost "Extracting writable environment..."
tar.exe -xf (Join-Path $envtars "writable.tar") -C $envsdir

# set permissions
Write-TimestampedHost "Setting permissions for writable environment..."
$writable = Join-Path $envsdir "writable"
$history = Join-Path $writable "conda-meta\history"
icacls.exe $writable /grant "BUILTIN\Users:(OI)(CI)(IO)M" /C /Q
icacls.exe $writable /grant "BUILTIN\Users:(RX,W)" /C /Q
icacls.exe $history /inheritance:d /C /Q
icacls.exe $history /remove BUILTIN\Users /C /Q
icacls.exe $history /grant "BUILTIN\Users:(RX,W)" /C /Q
Remove-Variable "writable"
Remove-Variable "history"

# set registry values
Write-TimestampedHost "Setting registry values..."
reg.exe import $regfile

# configure start menu shortcuts
Write-TimestampedHost "Configuring start menu..."
if (Test-Path $startmenu) {
    Get-ChildItem -Path $startmenu | ForEach-Object {Remove-Item -Recurse -Force -LiteralPath $_.FullName}
} else {
    [void](New-Item -ItemType Directory -Path $startmenu)
}
tar.exe -xf $lnktar -C $startmenu

# copy configuration files
Write-TimestampedHost "Copying configuration files..."
Copy-Item -Path (Join-Path $configfiles "*") -Destination $appdata -Recurse -Force

#configure IRKernel (if R installed)
Write-TimestampedHost "Configuring irkernel..."
$rscript = Join-Path $rhome "bin\Rscript.exe"
$offlineinstallr = Join-Path $irfiles "offlineinstallr.R"
$rpkgs = Join-Path $irfiles "pkgs"
$configdir = Join-Path $programdata "jupyter\kernels\ir"
if (Test-Path $rscript) {
    Start-Process -FilePath $rscript -ArgumentList "`"$offlineinstallr`" `"$rpkgs`"" -NoNewWindow -Wait
    if (Test-Path $configdir) {
        Get-ChildItem -Path $configdir | ForEach-Object {Remove-Item -Recurse -Force -LiteralPath $_.FullName}
    } else {
        [void](New-Item -ItemType Directory -Path $configdir)
    }
    tar.exe -xf (Join-Path $irfiles "config.tar") -C $configdir
}
Remove-Variable "rscript"
Remove-Variable "offlineinstallr"
Remove-Variable "rpkgs"
Remove-Variable "configdir"

Write-TimestampedHost "DONE"