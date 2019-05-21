#Requires -Version 3.0

<#
.SYNOPSIS
Visual Studio 웹 프로젝트의 Microsoft Azure 가상 컴퓨터를 만들고 배포하세요.
자세한 설명서를 보려면 http://go.microsoft.com/fwlink/?LinkID=394472로 이동하세요. 

.EXAMPLE
PS C:\> .\Publish-WebApplicationVM.ps1 `
-Configuration .\Configurations\WebApplication1-VM-dev.json `
-WebDeployPackage ..\WebApplication1\WebApplication1.zip `
-VMPassword @{Name = "admin"; Password = "password"} `
-AllowUntrusted `
-Verbose


#>
[CmdletBinding(HelpUri = 'http://go.microsoft.com/fwlink/?LinkID=391696')]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [String]
    $Configuration,

    [Parameter(Mandatory = $false)]
    [String]
    $SubscriptionName,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [String]
    $WebDeployPackage,

    [Parameter(Mandatory = $false)]
    [Switch]
    $AllowUntrusted,

    [Parameter(Mandatory = $false)]
    [ValidateScript( { $_.Contains('Name') -and $_.Contains('Password') } )]
    [Hashtable]
    $VMPassword,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ !($_ | Where-Object { !$_.Contains('Name') -or !$_.Contains('Password')}) })]
    [Hashtable[]]
    $DatabaseServerPassword,

    [Parameter(Mandatory = $false)]
    [Switch]
    $SendHostMessagesToOutput = $false
)


function New-WebDeployPackage
{
    #웹 응용 프로그램을 빌드하고 패키지하는 함수를 쓰세요.

    #웹 응용 프로그램을 빌드하려면 MsBuild.exe를 사용하세요. 도움말은 MSBuild Command-Line Reference(http://go.microsoft.com/fwlink/?LinkId=391339)를 참조하세요.
}

function Test-WebApplication
{
    #이 함수를 편집하여 웹 응용 프로그램에서 단위 테스트를 실행하세요.

    #함수를 웹 응용 프로그램에서 단위 테스트를 실행하도록 쓰려면 VSTest.Console.exe를 사용하세요. 도움말은 VSTest.Console Command-Line Reference(http://go.microsoft.com/fwlink/?LinkId=391340)를 참조하세요.
}

function New-AzureWebApplicationVMEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Configuration,

        [Parameter (Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMPassword,

        [Parameter (Mandatory = $false)]
        [AllowNull()]
        [Hashtable[]]
        $DatabaseServerPassword
    )
   
    $VMInfo = New-AzureVMEnvironment `
        -CloudServiceConfiguration $Config.cloudService `
        -VMPassword $VMPassword

    # SQL 데이터베이스를 만드세요. 연결 문자열이 배포에 사용됩니다.
    $connectionString = New-Object -TypeName Hashtable
    
    if ($Config.Contains('databases'))
    {
        @($Config.databases) |
            Where-Object {$_.connectionStringName -ne ''} |
            Add-AzureSQLDatabases -DatabaseServerPassword $DatabaseServerPassword |
            ForEach-Object { $connectionString.Add($_.Name, $_.ConnectionString) }
    }
    
    return @{ConnectionString = $connectionString; VMInfo = $VMInfo}   
}

function Publish-AzureWebApplicationToVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Config,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $ConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMInfo           
    )
    $waitingTime = $VMWebDeployWaitTime

    $result = $null
    $attempts = 0
    $allAttempts = 60
    do 
    {
        $result = Publish-WebPackageToVM `
            -VMDnsName $VMInfo.VMUrl `
            -IisWebApplicationName $Config.webDeployParameters.IisWebApplicationName `
            -WebDeployPackage $WebDeployPackage `
            -UserName $VMInfo.UserName `
            -UserPassword $VMInfo.Password `
            -AllowUntrusted:$AllowUntrusted `
            -ConnectionString $ConnectionString
         
        if ($result)
        {
            Write-VerboseWithTime ($scriptName + ' VM으로 게시했습니다.')
        }
        elseif ($VMInfo.IsNewCreatedVM -and !$Config.cloudService.virtualMachine.enableWebDeployExtension)
        {
            Write-VerboseWithTime ($scriptName + ' "enableWebDeployExtension"을 $true로 설정해야 합니다.')
        }
        elseif (!$VMInfo.IsNewCreatedVM)
        {
            Write-VerboseWithTime ($scriptName + ' 기존의 VM이 Web Deploy를 지원하지 않습니다.')
        }
        else
        {
            Write-VerboseWithTime ('{0}: Publishing to VM failed. Attempt {1} of {2}.' -f $scriptName, ($attempts + 1), $allAttempts)
            Write-VerboseWithTime ('{0}: Publishing to VM will start after {1} seconds.' -f $scriptName, $waitingTime)
            
            Start-Sleep -Seconds $waitingTime
        }
                                                                                                                       
         $attempts++
    
         #Web Deploy가 설치된 새로 만든 가상 컴퓨터에 대해서만 다시 게시를 시도하세요. 
    } While( !$result -and $VMInfo.IsNewCreatedVM -and $attempts -lt $allAttempts -and $Config.cloudService.virtualMachine.enableWebDeployExtension)
    
    if (!$result)
    {                    
        Write-Warning ' 가상 시스템에 게시하지 못했습니다. 신뢰할 수 없거나 유효하지 않은 인증서로 인해 이러한 경우가 발생할 수 있습니다. -AllowUntrusted를 지정하여 신뢰할 수 없는 인증서를 수락할 수 있습니다.'
        throw ($scriptName + ' VM으로 게시하지 못했습니다.')
    }
}

# 스크립트 주요 루틴
Set-StrictMode -Version 3
Import-Module Azure

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$($host.name)".replace(" ","_"), "1.7")
} catch {}

Remove-Module AzureVMPublishModule -ErrorAction SilentlyContinue
$scriptDirectory = Split-Path -Parent $PSCmdlet.MyInvocation.MyCommand.Definition
Import-Module ($scriptDirectory + '\AzureVMPublishModule.psm1') -Scope Local -Verbose:$false

New-Variable -Name VMWebDeployWaitTime -Value 30 -Option Constant -Scope Script 
New-Variable -Name AzureWebAppPublishOutput -Value @() -Scope Global -Force
New-Variable -Name SendHostMessagesToOutput -Value $SendHostMessagesToOutput -Scope Global -Force

try
{
    $originalErrorActionPreference = $Global:ErrorActionPreference
    $originalVerbosePreference = $Global:VerbosePreference
    
    if ($PSBoundParameters['Verbose'])
    {
        $Global:VerbosePreference = 'Continue'
    }
    
    $scriptName = $MyInvocation.MyCommand.Name + ':'
    
    Write-VerboseWithTime ($scriptName + ' 시작')
    
    $Global:ErrorActionPreference = 'Stop'
    Write-VerboseWithTime ('{0} $ErrorActionPreference가 {1}(으)로 설정됩니다.' -f $scriptName, $ErrorActionPreference)
    
    Write-Debug ('{0}: $PSCmdlet.ParameterSetName = {1}' -f $scriptName, $PSCmdlet.ParameterSetName)

    # Azure 모듈이 버전 0.7.4 이상인지 확인합니다.
    $validAzureModule = Test-AzureModule

    if (-not ($validAzureModule))
    {
         throw 'Azure PowerShell을 로드할 수 없습니다. 최신 버전을 설치하려면 웹 사이트(http://go.microsoft.com/fwlink/?LinkID=320552)로 이동하세요. Azure PowerShell을 이미 설치했으면 컴퓨터를 다시 시작하거나 모듈을 수동으로 가져와야 할 수도 있습니다.'
    }

    # 현재 구독을 저장하세요. 스크립트 뒷부분에 Current 상태로 복원됩니다.
    Backup-Subscription -UserSpecifiedSubscription $SubscriptionName
        
    if ($SubscriptionName)
    {

        # 구독 이름을 제공한 경우 계정에 구독이 있는지 확인하세요.
        if (!(Get-AzureSubscription -SubscriptionName $SubscriptionName))
        {
            throw ("{0}: 구독 이름 $SubscriptionName을 찾을 수 없습니다." -f $scriptName)

        }

        # 지정된 구독을 현재 구독으로 설정하세요.
        Select-AzureSubscription -SubscriptionName $SubscriptionName | Out-Null

        Write-VerboseWithTime ('{0}: 구독이 {1}(으)로 설정됩니다.' -f $scriptName, $SubscriptionName)
    }

    $Config = Read-ConfigFile $Configuration -HasWebDeployPackage:([Bool]$WebDeployPackage)

    #웹 응용 프로그램을 빌드하고 패키지하세요.
    New-WebDeployPackage

    #이 함수를 웹 응용 프로그램에 단위 테스트를 실행하세요.
    Test-WebApplication

    #JSON 구성 파일에 설명된 Azure 환경을 만드세요.

    $newEnvironmentResult = New-AzureWebApplicationVMEnvironment -Configuration $Config -DatabaseServerPassword $DatabaseServerPassword -VMPassword $VMPassword

    #사용자가 $WebDeployPackage를 지정한 경우 웹 응용 프로그램 패키지를 배포하세요. 
    if($WebDeployPackage)
    {
        Publish-AzureWebApplicationToVM `
            -Config $Config `
            -ConnectionString $newEnvironmentResult.ConnectionString `
            -WebDeployPackage $WebDeployPackage `
            -VMInfo $newEnvironmentResult.VMInfo
    }
}
finally
{
    $Global:ErrorActionPreference = $originalErrorActionPreference
    $Global:VerbosePreference = $originalVerbosePreference

    # 원래 현재 구독을 Current 상태로 복원하세요.
    if($validAzureModule)
    {
           Restore-Subscription
    }   

    Write-Output $Global:AzureWebAppPublishOutput    
    $Global:AzureWebAppPublishOutput = @()
}
