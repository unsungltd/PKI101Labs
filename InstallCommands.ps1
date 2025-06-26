Add-WindowsFeature "ADCS-Cert-Authority" -IncludeManagementTools 

$ValidityPeriodUnits=20
$ValidityPeriod="Years"
$RCACommonName = "Unsung-RCA"
$KeyLength = 4096
$credentials = (Get-Credential)
Install-AdcsCertificationAuthority -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CACommonName $RCACommonName -CAType StandaloneRootCA  -HashAlgorithmName "SHA256" -KeyLength $KeyLength -Credential $Credentials  -Force
