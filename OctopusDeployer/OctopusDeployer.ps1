param(
    [string]$octoProjectName,
    [string]$octoEnvironmentName,
    [string]$connectedServiceName,
    [string]$specifyVersion,
    [string]$specificVersionNumber,
    [string]$deployRelease,
	[string]$octoDeploymentStepName
)

# Regular expression pattern to find the version in the build number
$versionRegex = "\d+\.\d+\.\d+(?:\.\d+)?"
$projectId = $null

Write-Verbose "Importing modules"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

function GetEndpointData
{
	param([string][ValidateNotNullOrEmpty()]$connectedServiceName)

	$serviceEndpoint = Get-ServiceEndpoint -Context $distributedTaskContext -Name $connectedServiceName

	if (!$serviceEndpoint)
	{
		throw "A Connected Service with name '$ConnectedServiceName' could not be found.  Ensure that this Connected Service was successfully provisioned using the services tab in the Admin UI."
	}

    return $serviceEndpoint
}

Write-Verbose "Entering script $MyInvocation.MyCommand.Name"
Write-Verbose "Parameter Values"
foreach($key in $PSBoundParameters.Keys)
{
    Write-Verbose ($key + ' = ' + $PSBoundParameters[$key])
}

Write-Verbose "Using service endpoint URL"
$serviceEndpoint = GetEndpointData $connectedServiceName

Write-Verbose "Octopus serverUrl = $($serviceEndpoint.Url)"
$octopusServer = $($serviceEndpoint.Url)

#Write-Verbose "Octopus serverApiKey = $($serviceEndpoint.Authorization.Parameters.Password)"
$octopusApiKey = $($serviceEndpoint.Authorization.Parameters.Password)

##Checking parameters
Write-Host "Checking for server url"
if (!$octopusServer)
{
    throw "Ocotopus server must be sepcified, set the server url in generic service"
}

Write-Host "Checking for octopus API key"
if (!$octopusApiKey)
{
    throw "Octopus API Key must be set, set the password in generic service"
}

Write-Host "Checking octopus environment name set"
if(!$octoEnvironmentName){
    throw "Octopus environment must be specified"
}

Write-Host "Checking octopus project name specified"
if(!$octoProjectName){
    throw "Octopus project must be set"
}

$buildVersion = $null
Write-Host "Checking to see if specific version is to be used"
if([System.Convert]::ToBoolean($specifyVersion)) {
    if(!$specificVersionNumber){
        throw "Build number was not specified with specifyVersion set to true"
    }
    else{
        $buildVersion = $specificVersionNumber
    }
}
else{
    Write-Host "Getting version from build number"
    $buildNumber = [regex]::matches($Env:BUILD_BUILDNUMBER,$versionRegex)
    $buildVersion = $buildNumber[0]
    if(!$buildVersion){
        throw "Build number could not be determined"
    }
}

Write-Host "Setting up Octopus API call"
$Header = @{ "X-Octopus-ApiKey" = $octopusApiKey }

Write-Host "Getting Octopus project information"
try{
    $Project = Invoke-WebRequest -Uri "$octopusServer/api/projects/all" -Headers $Header| ConvertFrom-Json
    $Project = $Project | ?{$_.name -eq $octoProjectName}
}
catch{
    Write-Error $_
    throw "Project not found: $octoProjectName"
}
if($Project.count -eq 0){
    throw "Project not found: $octoProjectName"
}
else{
    $projectId = $Project.Id
}

Write-Host "Getting Octopus environment information"
try{
    $Environment = Invoke-WebRequest -Uri "$octopusServer/api/Environments/all" -Headers $Header| ConvertFrom-Json
    $Environment = $Environment | ?{$_.name -eq $octoEnvironmentName}
}
catch{
    Write-Error $_
    throw "Environment not found: $octoEnvironmentName"
}
if($Environment.count -eq 0){
    throw "Environment not found: $octoEnvironmentName"
}

if(!$projectId){
    throw "Unable to determine projectId for release"
}

$ReleaseBody =  @"
{
    "Projectid": "$projectId",
    "Version": "$buildVersion",
    "SelectedPackages":[{"StepName":"$octoDeploymentStepName", "Version":"$buildVersion"}]
}
"@

Write-Host "Setting up release for project: '$octoProjectName' with version: '$buildVersion'"
Write-Verbose "Queuing release using: '$ReleaseBody'"
try{
    $release = Invoke-WebRequest -Uri $octopusServer/api/releases -Method Post -Headers $Header -Body $ReleaseBody | ConvertFrom-Json
    Write-Verbose $release
}
catch{
    Write-Error $_
    throw "Unable to setup a release for environment: '$octoEnvironmentName' and project: '$octoProjectName'"
}

if([System.Convert]::ToBoolean($deployRelease)) {
    Write-Host "Setting up deployment for project: '$octoProjectName' to environment: '$octoEnvironmentName'"
    $DeploymentBody = @{ 
                ReleaseID = $release.Id
                EnvironmentID = $Environment.Id           
              } | ConvertTo-Json

    Write-Verbose "Queuing deployment using: '$DeploymentBody'"          
    try{
        $deployment = Invoke-WebRequest -Uri $octopusServer/api/deployments -Method Post -Headers $Header -Body $DeploymentBody | ConvertFrom-Json
        Write-Verbose $deployment
    }
    catch{
        Write-Error $_
        throw "Unable to setup deployment for release: $release.Id"
    }

    ##Get current deployment TaskId to monitor completion
    $taskId = $deployment.TaskId
    $completed = $false

    Write-Host "Checking on taskId: '$taskId' for completion..."    
    while(!$completed){
        Write-Verbose "Checking on taskId: '$taskId' for completion"    
        try{
            $task = Invoke-WebRequest -Uri $octopusServer/api/tasks/$taskId -Method Get -Headers $Header | ConvertFrom-Json
            Write-Verbose $task
        }
        catch{
            Write-Error $_
            Write-Host "Unable to get task status. You will have to manually check it in Octopus."
            $completed = $true
        }
        if($task.CompletedTime -ne $null){
            $completed = $true
            $taskStatus = $task.State
            Write-Host "Deployment done with state of: '$taskStatus'"
            if($taskStatus -eq "Failed")
            {
                throw "Deployment failed. Check task log for more information."
            }
        }
        else{
            start-sleep -seconds 5
        }
    }
}
else{
    Write-Host "Deployment not selected for this build."
}
Write-Host "Octopus Deployer task completed."