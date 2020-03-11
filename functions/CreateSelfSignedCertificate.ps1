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

    [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert = New-SelfSignedCertificate -DnsName $CertName -CertStoreLocation 'cert:\LocalMachine\My' `
        -KeyExportPolicy Exportable -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' `
        -NotAfter (Get-Date).AddMonths($SelfSignedCertNoOfMonthsUntilExpired) -HashAlgorithm SHA256

    [securestring] $CertPasswd = ConvertTo-SecureString $SelfSignedCertPlainPasswd -AsPlainText -Force
    $null = Export-PfxCertificate -Cert ('Cert:\localmachine\my\' + $Cert.Thumbprint) -FilePath $CertPath -Password $CertPasswd -Force
    $null = Export-Certificate -Cert ('Cert:\localmachine\my\' + $Cert.Thumbprint) -FilePath $CertPathCer -Type CERT
}