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