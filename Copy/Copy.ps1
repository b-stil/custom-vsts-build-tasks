#parameters
param(
    [string]$source = "",
    [string]$destination = ""
)

$validationErrors = [string]::Empty

#validate parameters
if([string]::IsNullOrWhiteSpace($source)){ $validationErrors += "Parameter -source is required `r`n" }
if([string]::IsNullOrWhiteSpace($destination)){ $validationErrors += "Parameter -destination is required`r`n" }
if(![string]::IsNullOrWhiteSpace($validationErrors))
{ 
	Write-Error "$validationErrors"
    exit 1
}

#create the directory
Write-Host "Creating destination directory $destination"
New-Item -ItemType Directory -Force -Path $destination

Write-Host "Copying from $source to $destination"
Copy-Item $source $destination -Recurse