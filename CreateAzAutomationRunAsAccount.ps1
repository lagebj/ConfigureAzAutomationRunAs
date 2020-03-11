#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $Location,

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

# Helper functions
function CreateAutomationCertificateAsset {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $ResourceGroup,

        [Parameter()]
        [string] $AutomationAccountName,

        [Parameter()]
        [string] $CertifcateAssetName,

        [Parameter()]
        [string] $CertPath,

        [Parameter()]
        [string] $CertPlainPasswd,

        [Parameter()]
        [bool] $Exportable
    )

    [securestring] $CertPassword = ConvertTo-SecureString $CertPlainPasswd -AsPlainText -Force

    Remove-AzAutomationCertificate -ResourceGroupName $ResourceGroup `
        -AutomationAccountName $AutomationAccountName `
        -Name $CertifcateAssetName `
        -ErrorAction SilentlyContinue

    New-AzAutomationCertificate -ResourceGroupName $ResourceGroup `
        -AutomationAccountName $AutomationAccountName `
        -Path $CertPath `
        -Name $CertifcateAssetName `
        -Password $CertPassword `
        -Exportable:$Exportable
}

function CreateAutomationConnectionAsset {
    param(
        [Parameter()]
        [string] $ResourceGroup,

        [Parameter()]
        [string] $AutomationAccountName,

        [Parameter()]
        [string] $ConnectionAssetName,

        [Parameter()]
        [string] $ConnectionTypeName,

        [Parameter()]
        [hashtable] $ConnectionFieldValues
    )

    Remove-AzAutomationConnection -ResourceGroupName $ResourceGroup `
        -AutomationAccountName $AutomationAccountName `
        -Name $ConnectionAssetName `
        -Force `
        -ErrorAction SilentlyContinue

    New-AzAutomationConnection -ResourceGroupName $ResourceGroup `
        -AutomationAccountName $AutomationAccountName `
        -Name $ConnectionAssetName `
        -ConnectionTypeName $ConnectionTypeName `
        -ConnectionFieldValues $ConnectionFieldValues
}

function CreateSelfSignedCertificate {
    [CmdletBinding()]
    [OutputType([void])]

    param (
        [Parameter()]
        [string] $CertName,

        [Parameter()]
        [string] $SelfSignedCertPlainPasswd,

        [Parameter()]
        [string] $CertPath,

        [Parameter()]
        [string] $CertPathCer,

        [Parameter()]
        [int] $SelfSignedCertNoOfMonthsUntilExpired
    )

    [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert = New-SelfSignedCertificate -DnsName $CertName `
        -CertStoreLocation 'cert:\LocalMachine\My' `
        -KeyExportPolicy Exportable `
        -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' `
        -NotAfter (Get-Date).AddMonths($SelfSignedCertNoOfMonthsUntilExpired) `
        -HashAlgorithm SHA256

    [securestring] $CertPasswd = ConvertTo-SecureString $SelfSignedCertPlainPasswd -AsPlainText -Force
    $null = Export-PfxCertificate -Cert ('Cert:\localmachine\my\' + $Cert.Thumbprint) -FilePath $CertPath -Password $CertPasswd -Force
    $null = Export-Certificate -Cert ('Cert:\localmachine\my\' + $Cert.Thumbprint) -FilePath $CertPathCer -Type CERT
}

function CreateServicePrincipal {
    [CmdletBinding()]
    [OutputType([string])]

    param (
        [Parameter()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert,

        [Parameter()]
        [string] $ApplicationDisplayName
    )

    [string] $KeyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
    [string] $KeyId = (New-Guid).Guid

    # Create an Azure AD application, AD App Credential, AD ServicePrincipal
    # Requires Application Developer Role, but works with Application administrator or GLOBAL ADMIN
    [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication] $Application = New-AzADApplication -DisplayName $ApplicationDisplayName `
        -HomePage ("http://" + $ApplicationDisplayName) `
        -IdentifierUris ("http://" + $KeyId)

    # Requires Application administrator or GLOBAL ADMIN
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [Microsoft.Azure.Commands.ActiveDirectory.PSADCredential] $ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId `
        -CertValue $KeyValue `
        -StartDate $PfxCert.NotBefore `
        -EndDate $PfxCert.NotAfter

    # Requires Application administrator or GLOBAL ADMIN
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSADServicePrincipalWrapper] $ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [Microsoft.Azure.Commands.ActiveDirectory.PSADServicePrincipal] $GetServicePrincipal = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id

    # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
    Start-Sleep -Seconds 15

    # Requires User Access Administrator or Owner
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] $NewRole = New-AzRoleAssignment -RoleDefinitionName Contributor `
        -ServicePrincipalName $Application.ApplicationId `
        -ErrorAction SilentlyContinue

    [int] $Retries = 0
    while ($null -eq $NewRole -and $Retries -le 6) {
        Start-Sleep -Seconds 10
        New-AzRoleAssignment -RoleDefinitionName Contributor `
            -ServicePrincipalName $Application.ApplicationId `
            -ErrorAction SilentlyContinue
        [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] $NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId `
            -ErrorAction SilentlyContinue
        $Retries++
    }

    return $Application.ApplicationId.ToString();
}

# Create resource group
[hashtable] $ResourceGroupParams = @{
    Name = $ResourceGroup
    Location = $Location
}

New-AzResourceGroup @ResourceGroupParams

# Create Automation Account
[hashtable] $AutomationAccount = @{
    ResourceGroupName = $ResourceGroup
    Location = $Location
    Name = $AutomationAccountName
}

New-AzAutomationAccount @AutomationAccount

# Connect to Azure
Connect-AzAccount -Subscription $SubscriptionId

# Get subscription details
[Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] $Subscription = Get-AzSubscription

[string] $CertifcateAssetName = 'AzRunAsCert'
[string] $ConnectionAssetName = 'AzRunAsConnection'
[string] $ConnectionTypeName = 'AzureServicePrincipal'

# Create self-signed certificate to be used for creating Azure AD application
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