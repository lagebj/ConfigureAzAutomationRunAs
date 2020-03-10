#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $AutomationAccountName,

    [Parameter(Mandatory = $true)]
    [string] $ApplicationDisplayName,

    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $SelfSignedCertPlainPasswd,

    [Parameter(Mandatory = $false)]
    [int] $SelfSignedCertNoOfMonthsUntilExpired = 12
)

# Load required functions
foreach ($File in (Get-ChildItem .\functions)) {
    . $File
}

# Connect to Azure
Connect-AzAccount -Subscription $SubscriptionId

[Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] $Subscription = Get-AzSubscription

# Create a Run As account by using a service principal
[string] $CertifcateAssetName = 'AzRunAsCert'
[string ]$ConnectionAssetName = 'AzRunAsCon'
[string] $ConnectionTypeName = 'AzureServicePrincipal'

# Create self-signed certificate
[string] $CertificateName = $AutomationAccountName + '-' + $CertifcateAssetName
[string] $PfxCertPathForRunAsAccount = Join-Path -Path $env:TEMP -ChildPath ($CertificateName + ".pfx")
[string] $CerCertPathForRunAsAccount = Join-Path -Path $env:TEMP -ChildPath ($CertificateName + ".cer")
CreateSelfSignedCertificate $CertificateName $SelfSignedCertPlainPasswd $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired

# Create a service principal
[System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($PfxCertPathForRunAsAccount, $SelfSignedCertPlainPasswd)
[string] $ApplicationId = CreateServicePrincipal $PfxCert $ApplicationDisplayName

# Create the Automation certificate asset
CreateAutomationCertificateAsset $ResourceGroup $AutomationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount $SelfSignedCertPlainPasswd $true

# Populate the ConnectionFieldValues
[hashtable] $ConnectionFieldValues = @{
    ApplicationId = $ApplicationId
    TenantId = $Subscription.TenantId
    CertificateThumbprint = $PfxCert.Thumbprint
    SubscriptionId = $SubscriptionId
}

# Create an Automation connection asset named AzRunAsCon in the Automation account. This connection uses the service principal.
CreateAutomationConnectionAsset $ResourceGroup $AutomationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues
