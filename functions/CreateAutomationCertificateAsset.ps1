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