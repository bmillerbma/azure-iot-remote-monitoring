<# 
    .SYNOPSIS  
    Publishes a Windows Azure website project 
             
    .DESCRIPTION 
    The Publish-AzureWebsiteDevbox.ps1 script publishes 
    the project that is associated with a Windows Azure 
    website.  
 
    To run this script, you must have a Windows Azure  
    website associated with your Windows Azure account. 
    To verify, run the Get-AzureWebsite cmdlet. 
             
    .PARAMETER  ProjectFile 
    Specifies the .csproj file of the project that you 
    want to deploy. This parameter is required. 
 
    .PARAMETER  PublishXmlFile 
    The publish settings downloaded from the Azure web site.

    .PARAMETER  Configuration
    The build configuration: Debug, Release

    .PARAMETER  NoLaunch 
    Do not start a browser that displays the website. This 
    switch parameter is optional. 
 
    .INPUTS 
    System.String 
 
    .OUTPUTS 
    None. This script does not return any objects. 
 
    .NOTES 
    This script automatically sets the $VerbosePreference to Continue,  
    so all verbose messages are displayed, and the $ErrorActionPreference 
    to Stop so that non-terminating errors stop the script. 
 
    .EXAMPLE
    .\Publish-AzureWebsite.ps1 -ProjectFile ..\..\DeviceAdministration\web\Web.csproj -PublishXmlFile ..\..\pfsiotsuitedev.PublishSettings -Configuration Debug
    Publish the web project and launch the site.  NOTE: Requires taht you download the *.publishsettings file from Azure

    .LINK 
    Show-AzureWebsite 
#>  
Param( 
    [Parameter(Mandatory = $true)] 
    [String]
    $ProjectFile, 
    [String]
    [Parameter(Mandatory = $true)] 
    $PublishXmlFile, 
    [ValidateSet("Debug", "Release")]
    [String]
    $Configuration = "Release",
    [Switch]
    $NoLaunch=$false
) 
 
# Init libraries ----------------------------------------------------------------------------------------------------------------------------- 
Import-Module "$(Split-Path $MyInvocation.MyCommand.Path)\Invoke-MsBuild.psm1"


# Begin - Actual script ----------------------------------------------------------------------------------------------------------------------------- 

try 
{
    # Set the output level to verbose and make the script stop on error 
    $VerbosePreference = "Continue" 
    $ErrorActionPreference = "Stop" 
  
    $scriptPath = Split-Path -parent $PSCommandPath 
 
    # Verify that the account credentials are current in the Windows  
    #  PowerShell session. This call fails if the credentials have 
    #  expired in the session. 
    Write-Verbose "Verifying that Windows Azure credentials in the Windows PowerShell session have not expired." 
    Get-AzureWebsite | Out-Null 
  
    # Mark the start time of the script execution 
    $startTime = Get-Date 

    # Verify Publishsettings
    if(-not (Test-Path $PublishXmlFile)) {
        throw "Cannot find file: $PublishXmlFile"
    }
    $PublishXmlFile = Resolve-Path $PublishXmlFile 

    # Verify csproj file
    if(-not (Test-Path $ProjectFile)) {
        throw "Cannot find file: $ProjectFile"
    }
    $ProjectFile = Resolve-Path $ProjectFile 


    [Xml]$xml = Get-Content $PublishXmlFile
    if (!$xml) {throw "Error: Cannot parse $PublishXmlFile"} 
    $password = $xml.publishData.publishProfile.userPWD[0] 
    $websiteName = $xml.publishData.publishProfile.msdeploySite[0] 
 

    # Get the publish xml template and generate the .pubxml file
    $publishProfile = Join-Path (Get-Item -Path $PublishXmlFile).DirectoryName "$websiteName.pubxml"
    [String]$template = Get-Content $scriptPath\pubxml.template
    ($template -f $xml.publishData.publishProfile.destinationAppUrl.Get(0),  $xml.publishData.publishProfile.publishUrl.Get(0), $WebsiteName) `
        | Out-File -Encoding utf8 $publishProfile

    # Run MSBuild to publish the project 
    $params = "/p:Configuration=$Configuration"
    $params += " /p:DeployOnBuild=true"
    $params += " /p:PublishProfile=$publishProfile"
    $params += " /p:Password=$password "
    Write-Host "Buiding and publishing..."
    $result = Invoke-MsBuild -Path $ProjectFile -Params $params -ShowBuildWindowAndPromptForInputBeforeClosing
    if (-Not $result)
    {
        $log = Invoke-MsBuild -Path $ProjectFile  -Params $params -GetLogPath
        throw "MSBuild failed.  Additional detail in the log: $log"
    }
 
    Write-Verbose "[Finish] deploying to Windows Azure website $websiteName" 
    # Mark the finish time of the script execution 
    $finishTime = Get-Date 
 
    # Output the time consumed in seconds 
    Write-Output "Total time used (seconds): ($finishTime - $startTime).TotalSeconds)"
 
    # if -Launch, launch the browser to show the website 
    If (-not $NoLaunch) 
    { 
        Show-AzureWebsite -Name $websiteName 
    } 
 
}
catch
{
    $host.ui.WriteErrorLine("`n" + $_ + "`n")
}

# End - Actual script -------------------------------------------------------------------------------------------------------------------------------