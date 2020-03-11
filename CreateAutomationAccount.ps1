#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $Location,

    [Parameter(Mandatory = $true)]
    [string] $AutomationAccountName
)

[hashtable] $AutomationAccount = @{
    ResourceGroupName = $ResourceGroup
    Location = $Location
    Name = $AutomationAccountName
}

New-AzAutomationAccount @AutomationAccount