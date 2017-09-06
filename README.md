Custom VSTS Build Tasks
===================

Repository for custom VSTS tasks that will work with Visual Studio Online or your on-premises TFS 2015 build system.

----------

Contents
-------------
AddTaskToTFS.ps1
> - This Powershell script interacts with the VSTS API to allow you to add a new build task.

Copy
> - Build task that can copy an entire directory and all of it's contents or individual files.

Octopus Deployer
> - Build task that gives the ability to push a Release and/or Deployment to your Octopus server with feedback to be able to fail the build if the deployment or release fail.

Version From Build
> - Build task that will use the "Build number format" field to apply the version number to AssemblyInfo.cs files.

Security Note
-------------------
For an on-premises TFS 2015 the user attempting to upload the task through the API will need to have full access as an "Administration Console User".  Several posts state that all that is needed is to be an agent pool administrator but that does not seem to be the case with an on-premises solution.
