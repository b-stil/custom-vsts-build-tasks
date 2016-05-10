##-----------------------------------------------------------------------------------------------------
## This script will increment the assemlby version based on the build number that is defined in 'Build number format' for build
## $(BuildDefinitionName)_$(Year:yy).$(Month).$(DayOfYear)$(Rev:.r) will become something like 2016.04.105.3
##
##-----------------------------------------------------------------------------------------------------
Write-Host "Beginning version increment..."
$versionPattern = "\d+\.\d+\.\d+\.\d+"

#extract the version numbers from the build
$buildNumber = $env:BUILD_BUILDNUMBER

$buildVersion = [regex]::matches($buildNumber, $versionPattern)
$assemblyVersion = $buildVersion[0]

#find the assemblyInfo.cs file
$srcPath = $Env:BUILD_SOURCESDIRECTORY
Write-Host "Build source directory: $srcPath"
Write-Host "Updating Assembly Version in path: $srcPath to version: $assemblyVersion"

$versionFiles = Get-ChildItem $srcPath AssemblyInfo.cs -Recurse
foreach($versionFile in $versionFiles)
{
    $backupFile = $versionFile.FullName + "._BAK"
    Write-Host "Creating backup of $versionFile.FullName as: $backupFile"
    Copy-Item $versionFile.FullName $backupFile -Force
    Write-Host "Updating $versionFile.FullName to version: $assemblyVersion"
    (Get-Content $versionFile.FullName) |
        %{$_ -replace 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyVersion(""$assemblyVersion"")" } |
        %{$_ -replace 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyFileVersion(""$assemblyVersion"")" } |
        Set-Content $versionFile.FullName -Force
}
