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
    [Microsoft.Azure.Commands.ActiveDirectory.PSADApplication] $Application = New-AzADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $ApplicationDisplayName) -IdentifierUris ("http://" + $KeyId)

    # Requires Application administrator or GLOBAL ADMIN
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [Microsoft.Azure.Commands.ActiveDirectory.PSADCredential] $ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $KeyValue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter

    # Requires Application administrator or GLOBAL ADMIN
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSADServicePrincipalWrapper] $ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId

    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [Microsoft.Azure.Commands.ActiveDirectory.PSADServicePrincipal] $GetServicePrincipal = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id

    # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
    Start-Sleep -Seconds 15

    # Requires User Access Administrator or Owner.
    [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] $NewRole = New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue

    [int] $Retries = 0
    while ($null -eq $NewRole -and $Retries -le 6) {
        Start-Sleep -Seconds 10
        New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
        [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] $NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
        $Retries++
    }

    return $Application.ApplicationId.ToString();
}