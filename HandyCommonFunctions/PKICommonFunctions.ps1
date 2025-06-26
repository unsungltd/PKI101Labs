#################################################################################################
# Useful functions for ADCS PKI Configuration and Builds
# Stevie Barr
# Caisteal Services
#################################################################################################

function Create-Root-CAPolicy()
{
    ScreenLog "Create-Root-CAPolicy ... " 1
    ScreenLog "Configuring CAPolicy.inf file in C:\\Windows folder ... " 2

    $capolicyInf = `
'[Version]
Signature="$Windows NT$"
[BasicConstraintsExtension]
Critical=Yes
[CRLDistributionPoint]
Empty=True
[AuthorityInformationAccess]
Empty=True
[Extensions]
;Removes CA version extension
1.3.6.1.4.1.311.21.1 =
;Removes the digital signature from the key usage extension
2.5.29.15=AwIBBg==
;Sets the key usage extension critical
Critical=2.5.29.15
[Certsrv_Server]
RenewalKeyLength=4096
RenewalValidityPeriod=Years
RenewalValidityPeriodUnits=20
CRLPeriod=Years
CRLPeriodUnits=1
CRLDeltaPeriod=Days
CRLDeltaPeriodUnits=0'

    [System.IO.File]::WriteAllText("c:\windows\capolicy.inf", $capolicyInf)
}

function Create-Issuing-CAPolicy()
{
    ScreenLog "Create-Issuing-CAPolicy ... " 1
    ScreenLog "Configuring CAPolicy.inf file in C:\\Windows folder ... " 2

$capolicyInf = `
'[Version]
Signature="$Windows NT$"
[BasicConstraintsExtension]
pathLength=0
Critical=Yes
[CRLDistributionPoint]
Empty=True
[AuthorityInformationAccess]
Empty=True
[Extensions]
;Removes CA version extension
1.3.6.1.4.1.311.21.1 =
;Removes Certificate Template extension 
1.3.6.1.4.1.311.21.7 =
;Removes the digital signature from the key usage extension
2.5.29.15=AwIBBg==
;Sets the key usage extension critical
Critical=2.5.29.15
[Certsrv_Server]
RenewalKeyLength=2048
RenewalValidityPeriod=Years
RenewalValidityPeriodUnits=10
CRLPeriod=weeks
CRLPeriodUnits=1
CRLDeltaPeriod=Days
CRLDeltaPeriodUnits=0
LoadDefaultTemplates=0'

    [System.IO.File]::WriteAllText("c:\windows\capolicy.inf", $capolicyInf)
}

function ScreenLog($message, $tabCount=0)
{
    $tabs = ""
    for ($i = 0; $i -lt $tabCount; $i++)
    {
        $tabs = $tabs + "-"
    }
    $timeStamp = (Get-Date).ToString("yyyy-MM-dd|HH:mm:ss| ")
    $message = $timeStamp + $tabs + $message
    Write-Host $message
}

function Install-YubiCNG($PathToYubiCNGMSI, $ConnectorUrl, $AuthKeysetPassword, $AuthKeysetID)
{
    ScreenLog "Install-YubiCNG ...." 1

    $installFile = get-item $pathToYubiCNGMSI
    $MSIArguments = @("/i"
                    ('"{0}"' -f $installFile.fullname)
                    "/qn"
                    "/norestart")

    Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
    Set-ItemProperty HKLM:\SOFTWARE\Yubico\YubiHSM -Name ConnectorURL $ConnectorUrl 
    Set-ItemProperty HKLM:\SOFTWARE\Yubico\YubiHSM -Name AuthKeysetPassword $AuthKeysetPassword 
    Set-ItemProperty HKLM:\SOFTWARE\Yubico\YubiHSM -Name AuthKeysetID $AuthKeysetID 
}

function Set-CRLPublicationUrlRegistry($CRLPublicationUrlsString)
{
    ScreenLog "Set-CRLPublicationUrlRegistry $CRLPublicationUrlsString ...." 1
    #Set the CRL distribution points
    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CRLPublicationURLs $CRLPublicationUrlsString
}

function Set-CAValidityPeriod($ValidityPeriodUnits, $ValidityPeriod)
{
    ScreenLog "Set-CAValidityPeriod | ValidityPeriodUnits : $ValidityPeriodUnits | ValidityPeriod : $ValidityPeriod" 1
    #Set the CRL distribution points
    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\ValidityPeriodUnits $ValidityPeriodUnits
    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\ValidityPeriod $ValidityPeriod
}

function Set-CACertPublicationUrlRegistry($CACertPublicationUrlsString)
{
    
    & "$($ENV:SystemRoot)\System32\certutil.exe" -setreg CA\CACertPublicationURLs $CACertPublicationUrlsString 
}

function Sign-SubCACert($ICACommonName, $RCACommonName)
{

    Write-Host "Submitting C:\Windows\System32\CertSrv\CertEnroll\$ICACommonName.req to $RCACommonName"
    [System.String]$RequestResult = & "$($ENV:SystemRoot)\System32\Certreq.exe" -Config ".\$RCACommonName" -Submit "C:\Windows\System32\CertSrv\CertEnroll\$ICACommonName.req"
    $Matches = [Regex]::Match($RequestResult, 'RequestId:\s([0-9]*)')

    if ($Matches.Groups.Count -lt 2)
    {
        Write-Verbose -Message "Error getting Request ID from SubCA certificate submission."
        Throw "Error getting Request ID from SubCA certificate submission."
    }
    [int]$RequestId = $Matches.Groups[1].Value
    Write-Host "Issuing $RequestId in $RCACommonName"
    [System.String]$SubmitResult = & "$($ENV:SystemRoot)\System32\CertUtil.exe" -Resubmit $RequestId
    if ($SubmitResult -notlike 'Certificate issued.*')
    {
        Write-Verbose -Message "Unexpected result issuing SubCA request."
        Throw "Unexpected result issuing SubCA request."
    }
    Write-Host "Retrieving C:\Windows\System32\CertSrv\CertEnroll\$ICACommonName.crt from $RCACommonName)"
    [System.String]$RetrieveResult = & "$($ENV:SystemRoot)\System32\Certreq.exe" -Config ".\$RCACommonName" -Retrieve $RequestId "C:\Windows\System32\CertSrv\CertEnroll\$ICACommonName.crt"
}