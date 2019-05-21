#  AzureVMPublishModule.psm1은 Windows PowerShell 스크립트 모듈입니다. 이 모듈에서는 웹 응용 프로그램에 대한 수명 주기 관리를 자동화하는 Windows PowerShell 함수를 내보냅니다. 함수를 그대로 사용하거나, 사용하는 응용 프로그램 및 게시 환경에 맞게 사용자 지정할 수 있습니다.

Set-StrictMode -Version 3

# 원래 구독을 저장하는 변수입니다.
$Script:originalCurrentSubscription = $null

# 원래 저장소 계정을 저장하는 변수입니다.
$Script:originalCurrentStorageAccount = $null

# 사용자가 지정한 구독의 저장소 계정을 저장하는 변수입니다.
$Script:originalStorageAccountOfUserSpecifiedSubscription = $null

# 구독 이름을 저장하는 변수입니다.
$Script:userSpecifiedSubscription = $null

# 웹 배포 포트 번호
New-Variable -Name WebDeployPort -Value 8172 -Option Constant

<#
.SYNOPSIS
메시지에 날짜와 시간을 추가합니다.

.DESCRIPTION
메시지에 날짜와 시간을 추가합니다. 이 함수는 Error와 Verbose 스트림에 쓴 메시지를 위해 설계된 것입니다.

.PARAMETER  Message
날짜 없이 메시지를 지정합니다.

.INPUTS
System.String

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Format-DevTestMessageWithTime -Message "디렉터리에 파일 $filename 추가"
2/5/2014 1:03:08 PM - 디렉터리에 파일 $filename 추가

.LINK
Write-VerboseWithTime

.LINK
Write-ErrorWithTime
#>
function Format-DevTestMessageWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    return ((Get-Date -Format G)  + ' - ' + $Message)
}


<#

.SYNOPSIS
현재 시간을 접두사로 한 오류 메시지를 쓰세요.

.DESCRIPTION
현재 시간을 접두사로 한 오류 메시지를 쓰세요. 이 함수는 Format-DevTestMessageWithTime 함수를 호출하여 시간을 추가한 다음 Error 스트림에 메시지를 씁니다.

.PARAMETER  Message
오류 메시지 호출에 메시지를 지정합니다. 함수에 메시지 문자열을 파이프할 수 있습니다.

.INPUTS
System.String

.OUTPUTS
없음. 함수가 Error 스트림에 씁니다.

.EXAMPLE
PS C:> Write-ErrorWithTime -Message "Failed. Cannot find the file."

Write-Error: 2/6/2014 8:37:29 AM - Failed. Cannot find the file.
 + CategoryInfo     : NotSpecified: (:) [Write-Error], WriteErrorException
 + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException

.LINK
Write-Error

#>
function Write-ErrorWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    $Message | Format-DevTestMessageWithTime | Write-Error
}


<#
.SYNOPSIS
현재 시간을 접두사로 한 자세한 메시지를 쓰세요.

.DESCRIPTION
현재 시간을 접두사로 한 자세한 메시지를 쓰세요. Write-Verbose를 호출하기 때문에, 스크립트가 Verbose 매개 변수와 실행되는 경우나 VerbosePreference 기본 설정이 Continue로 설정되어 있는 경우에만 메시지가 표시됩니다.

.PARAMETER  Message
자세한 메시지 호출에 메시지를 지정합니다. 함수에 메시지 문자열을 파이프할 수 있습니다.

.INPUTS
System.String

.OUTPUTS
없음. 함수가 Verbose 스트림에 씁니다.

.EXAMPLE
PS C:> Write-VerboseWithTime -Message "The operation succeeded."
PS C:>
PS C:\> Write-VerboseWithTime -Message "The operation succeeded." -Verbose
VERBOSE: 1/27/2014 11:02:37 AM - The operation succeeded.

.EXAMPLE
PS C:\ps-test> "The operation succeeded." | Write-VerboseWithTime -Verbose
VERBOSE: 1/27/2014 11:01:38 AM - The operation succeeded.

.LINK
Write-Verbose
#>
function Write-VerboseWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    $Message | Format-DevTestMessageWithTime | Write-Verbose
}


<#
.SYNOPSIS
현재 시간을 접두사로 한 호스트 메시지를 쓰세요.

.DESCRIPTION
이 함수는 현재 시간을 접두사로 한 호스트 프로그램(Write-Host)에 메시지를 씁니다. 호스트 프로그램에 쓰는 효과는 다양하게 나타납니다. Windows PowerShell을 호스팅하는 대부분의 프로그램은 표준 출력에 이러한 메시지를 씁니다.

.PARAMETER  Message
날짜 없이 기본 메시지를 지정합니다. 함수에 메시지 문자열을 파이프할 수 있습니다.

.INPUTS
System.String

.OUTPUTS
없음. 함수가 호스트 프로그램에 메시지를 씁니다.

.EXAMPLE
PS C:> Write-HostWithTime -Message "작업이 성공했습니다."
1/27/2014 11:02:37 AM - 작업이 성공했습니다.

.LINK
Write-Host
#>
function Write-HostWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )
    
    if ((Get-Variable SendHostMessagesToOutput -Scope Global -ErrorAction SilentlyContinue) -and $Global:SendHostMessagesToOutput)
    {
        if (!(Get-Variable -Scope Global AzureWebAppPublishOutput -ErrorAction SilentlyContinue) -or !$Global:AzureWebAppPublishOutput)
        {
            New-Variable -Name AzureWebAppPublishOutput -Value @() -Scope Global -Force
        }

        $Global:AzureWebAppPublishOutput += $Message | Format-DevTestMessageWithTime
    }
    else 
    {
        $Message | Format-DevTestMessageWithTime | Write-Host
    }
}


<#
.SYNOPSIS
속성 또는 방법이 개체의 멤버이면 $true를 반환합니다. 그렇지 않으면 $false를 반환합니다.

.DESCRIPTION
속성 또는 방법이 개체의 멤버이면 $true를 반환합니다. 이 함수는 클래스의 정적 방법과 PSBase와 PSObject 등의 뷰에 대해 $false를 반환합니다.

.PARAMETER  Object
테스트에서 개체를 지정합니다. 개체가 포함되어 있는 변수 또는 개체를 반환하는 식을 입력하세요. 이 함수에는 [DateTime]과 같은 형식을 지정하거나 개체를 파이프할 수 없습니다.

.PARAMETER  Member
테스트에서 속성 또는 방법의 이름을 지정합니다. 방법을 지정할 때는 방법 이름 뒤에 나오는 괄호를 생략하세요.

.INPUTS
없음. 이 함수는 파이프라인에서 입력을 꺼내지 않습니다.

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Test-Member -Object (Get-Date) -Member DayOfWeek
True

.EXAMPLE
PS C:\> $date = Get-Date
PS C:\> Test-Member -Object $date -Member AddDays
True

.EXAMPLE
PS C:\> [DateTime]::IsLeapYear((Get-Date).Year)
True
PS C:\> Test-Member -Object (Get-Date) -Member IsLeapYear
False

.LINK
Get-Member
#>
function Test-Member
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Object,

        [Parameter(Mandatory = $true)]
        [String]
        $Member
    )

    return $null -ne ($Object | Get-Member -Name $Member)
}


<#
.SYNOPSIS
Azure 모듈 버전이 0.7.4 이상이면 $true를 반환합니다. 아니면 $false를 반환합니다.

.DESCRIPTION
Test-AzureModuleVersion은 Azure 모듈 버전이 0.7.4 이상이면 $true를 반환합니다. 모듈이 설치되어 있지 않거나 이전 버전일 경우 $false를 반환합니다. 이 함수에는 매개 변수가 없습니다.

.INPUTS
없음

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Get-Module Azure -ListAvailable
PS C:\> #No module
PS C:\> Test-AzureModuleVersion
False

.EXAMPLE
PS C:\> (Get-Module Azure -ListAvailable).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
0      7      4      -1

PS C:\> Test-AzureModuleVersion
True

.LINK
Get-Module

.LINK
PSModuleInfo object (http://msdn.microsoft.com/en-us/library/system.management.automation.psmoduleinfo(v=vs.85).aspx)
#>
function Test-AzureModuleVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Version]
        $Version
    )

    return ($Version.Major -gt 0) -or ($Version.Minor -gt 7) -or ($Version.Minor -eq 7 -and $Version.Build -ge 4)
}


<#
.SYNOPSIS
설치된 Azure 모듈 버전이 0.7.4 이상이면 $true를 반환합니다.

.DESCRIPTION
Test-AzureModule은 설치된 Azure 모듈 버전이 0.7.4 이상이면 $true를 반환합니다. 모듈이 설치되어 있지 않거나 이전 버전일 경우 $false를 반환합니다. 이 함수에는 매개 변수가 없습니다.

.INPUTS
없음

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Get-Module Azure -ListAvailable
PS C:\> #No module
PS C:\> Test-AzureModule
False

.EXAMPLE
PS C:\> (Get-Module Azure -ListAvailable).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
    0      7      4      -1

PS C:\> Test-AzureModule
True

.LINK
Get-Module

.LINK
PSModuleInfo object (http://msdn.microsoft.com/en-us/library/system.management.automation.psmoduleinfo(v=vs.85).aspx)
#>
function Test-AzureModule
{
    [CmdletBinding()]

    $module = Get-Module -Name Azure

    if (!$module)
    {
        $module = Get-Module -Name Azure -ListAvailable

        if (!$module -or !(Test-AzureModuleVersion $module.Version))
        {
            return $false;
        }
        else
        {
            $ErrorActionPreference = 'Continue'
            Import-Module -Name Azure -Global -Verbose:$false
            $ErrorActionPreference = 'Stop'

            return $true
        }
    }
    else
    {
        return (Test-AzureModuleVersion $module.Version)
    }
}


<#
.SYNOPSIS
현재 Microsoft Azure 구독을 스크립트 범위의 $Script:originalSubscription 변수에 저장합니다.

.DESCRIPTION
Backup-Subscription 함수는 현재 Microsoft Azure 구독(Get-AzureSubscription -Current) 및 저장소 계정과 이 스크립트로 변경되는 구독($UserSpecifiedSubscription) 및 저장소 계정을 스크립트 범위에 저장합니다. 이 값을 저장하면 현재 상태가 변경된 경우 Restore-Subscription과 같은 함수를 사용하여 원래 현재 구독과 저장소 계정을 현재 상태로 복원할 수 있습니다.

.PARAMETER UserSpecifiedSubscription
새 리소스를 만들고 게시할 구독의 이름을 지정합니다. 함수는 스크립트 범위에 구독의 이름과 저장소 계정을 저장합니다. 이 매개 변수는 필수 사항입니다.

.INPUTS
없음

.OUTPUTS
없음

.EXAMPLE
PS C:\> Backup-Subscription -UserSpecifiedSubscription Contoso
PS C:\>

.EXAMPLE
PS C:\> Backup-Subscription -UserSpecifiedSubscription Contoso -Verbose
VERBOSE: Backup-Subscription: Start
VERBOSE: Backup-Subscription: Original subscription is Microsoft Azure MSDN - Visual Studio Ultimate
VERBOSE: Backup-Subscription: End
#>
function Backup-Subscription
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $UserSpecifiedSubscription
    )

    Write-VerboseWithTime 'Backup-Subscription: 시작'

    $Script:originalCurrentSubscription = Get-AzureSubscription -Current -ErrorAction SilentlyContinue
    if ($Script:originalCurrentSubscription)
    {
        Write-VerboseWithTime ('Backup-Subscription: 원래 구독이 다음과 같습니다. ' + $Script:originalCurrentSubscription.SubscriptionName)
        $Script:originalCurrentStorageAccount = $Script:originalCurrentSubscription.CurrentStorageAccountName
    }
    
    $Script:userSpecifiedSubscription = $UserSpecifiedSubscription
    if ($Script:userSpecifiedSubscription)
    {        
        $userSubscription = Get-AzureSubscription -SubscriptionName $Script:userSpecifiedSubscription -ErrorAction SilentlyContinue
        if ($userSubscription)
        {
            $Script:originalStorageAccountOfUserSpecifiedSubscription = $userSubscription.CurrentStorageAccountName
        }        
    }

    Write-VerboseWithTime 'Backup-Subscription: 끝'
}


<#
.SYNOPSIS
스크립트 범위의 $Script:originalSubscription 변수에 저장된 Microsoft Azure 구독을 "현재" 상태로 복원합니다.

.DESCRIPTION
Restore-Subscription 함수는 $Script:originalSubscription 변수에 저장된 구독을 다시 현재 구독으로 만듭니다. 원래 구독에 저장소 계정이 있으면 이 함수는 저장소 계정을 현재 구독 계정으로 만듭니다. 함수는 환경에 null이 아닌 $SubscriptionName 변수가 있을 경우에만 구독을 복원합니다. 그렇지 않으면 종료됩니다. $SubscriptionName은 채워져 있는데 $Script:originalSubscription이 $null이면, Restore-Subscription은 Select-AzureSubscription cmdlet을 사용하여 Microsoft Azure PowerShell에서 구독의 현재 및 기본 설정을 지웁니다. 이 함수에는 매개 변수가 없고, 입력을 사용하지 않고, 아무것도 반환하지 않습니다(void). -Verbose를 사용하여 Verbose 스트림에 메시지를 쓸 수 있습니다.

.INPUTS
없음

.OUTPUTS
없음

.EXAMPLE
PS C:\> Restore-Subscription
PS C:\>

.EXAMPLE
PS C:\> Restore-Subscription -Verbose
VERBOSE: Restore-Subscription: Start
VERBOSE: Restore-Subscription: End
#>
function Restore-Subscription
{
    [CmdletBinding()]
    param()

    Write-VerboseWithTime 'Restore-Subscription: 시작'

    if ($Script:originalCurrentSubscription)
    {
        if ($Script:originalCurrentStorageAccount)
        {
            Set-AzureSubscription `
                -SubscriptionName $Script:originalCurrentSubscription.SubscriptionName `
                -CurrentStorageAccountName $Script:originalCurrentStorageAccount
        }

        Select-AzureSubscription -SubscriptionName $Script:originalCurrentSubscription.SubscriptionName
    }
    else 
    {
        Select-AzureSubscription -NoCurrent
        Select-AzureSubscription -NoDefault
    }
    
    if ($Script:userSpecifiedSubscription -and $Script:originalStorageAccountOfUserSpecifiedSubscription)
    {
        Set-AzureSubscription `
            -SubscriptionName $Script:userSpecifiedSubscription `
            -CurrentStorageAccountName $Script:originalStorageAccountOfUserSpecifiedSubscription
    }

    Write-VerboseWithTime 'Restore-Subscription: 끝'
}

<#
.SYNOPSIS
현재 구독에서 이름이 "devtest*"인 Microsoft Azure 저장소 계정을 찾습니다.

.DESCRIPTION
Get-AzureVMStorage 함수는 지정된 위치 또는 선호도 그룹에 이름 패턴이 "devtest*"(대/소문자 구별)인 첫 저장소 계정의 이름을 반환합니다. "devtest*" 저장소 계정이 위치 또는 선호도 그룹과 일치하지 않아도 함수는 무시합니다. 위치 또는 선호도 그룹을 지정해야 합니다.

.PARAMETER  Location
저장소 계정의 위치를 지정합니다. 올바른 값은 "West US"와 같은 Microsoft Azure 위치입니다. 위치나 선호도 그룹을 입력할 수 있지만 둘 다 입력할 수는 없습니다.

.PARAMETER  AffinityGroup
저장소 계정의 선호도 그룹을 지정합니다. 위치나 선호도 그룹을 입력할 수 있지만 둘 다 입력할 수는 없습니다.

.INPUTS
없음. 이 함수에 입력을 파이프할 수 없습니다.

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Get-AzureVMStorage -Location "East US"
devtest3-fabricam

.EXAMPLE
PS C:\> Get-AzureVMStorage -AffinityGroup Finance
PS C:\>

.EXAMPLE\
PS C:\> Get-AzureVMStorage -AffinityGroup Finance -Verbose
VERBOSE: Get-AzureVMStorage: Start
VERBOSE: Get-AzureVMStorage: End

.LINK
Get-AzureStorageAccount
#>
function Get-AzureVMStorage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Location')]
        [String]
        $Location,

        [Parameter(Mandatory = $true, ParameterSetName = 'AffinityGroup')]
        [String]
        $AffinityGroup
    )

    Write-VerboseWithTime 'Get-AzureVMStorage: 시작'

    $storages = @(Get-AzureStorageAccount -ErrorAction SilentlyContinue)
    $storageName = $null

    foreach ($storage in $storages)
    {
        # 이름이 "devtest"로 시작되는 첫 저장소 계정을 가져오세요.
        if ($storage.Label -like 'devtest*')
        {
            if ($storage.AffinityGroup -eq $AffinityGroup -or $storage.Location -eq $Location)
            {
                $storageName = $storage.Label

                    Write-HostWithTime ('Get-AzureVMStorage: devtest 저장소 계정을 찾았습니다. ' + $storageName)
                    $storage | Out-String | Write-VerboseWithTime
                break
            }
        }
    }

    Write-VerboseWithTime 'Get-AzureVMStorage: 끝'
    return $storageName
}


<#
.SYNOPSIS
"devtest"로 시작되는 고유 이름으로 새 Microsoft Azure 저장소 계정을 만듭니다.

.DESCRIPTION
Add-AzureVMStorage 함수는 현재 구독에 새 Microsoft Azure 저장소 계정을 만듭니다. 계정의 이름은 "devtest"로 시작하고 그 뒤에 알파벳과 숫자로 된 고유 문자열이 붙습니다. 함수는 새 저장소 계정의 이름을 반환합니다. 새 저장소 계정의 위치 또는 선호도 그룹을 지정해야 합니다.

.PARAMETER  Location
저장소 계정의 위치를 지정합니다. 올바른 값은 "West US"와 같은 Microsoft Azure 위치입니다. 위치나 선호도 그룹을 입력할 수 있지만 둘 다 입력할 수는 없습니다.

.PARAMETER  AffinityGroup
저장소 계정의 선호도 그룹을 지정합니다. 위치나 선호도 그룹을 입력할 수 있지만 둘 다 입력할 수는 없습니다.

.INPUTS
없음. 이 함수에 입력을 파이프할 수 없습니다.

.OUTPUTS
System.String. 문자열은 새 저장소 계정의 이름입니다.

.EXAMPLE
PS C:\> Add-AzureVMStorage -Location "East Asia"
devtestd6b45e23a6dd4bdab

.EXAMPLE
PS C:\> Add-AzureVMStorage -AffinityGroup Finance
devtestd6b45e23a6dd4bdab

.EXAMPLE
PS C:\> Add-AzureVMStorage -AffinityGroup Finance -Verbose
VERBOSE: Add-AzureVMStorage: Start
VERBOSE: Add-AzureVMStorage: Created new storage acccount devtestd6b45e23a6dd4bdab"
VERBOSE: Add-AzureVMStorage: End
devtestd6b45e23a6dd4bdab

.LINK
New-AzureStorageAccount
#>
function Add-AzureVMStorage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Location')]
        [String]
        $Location,

        [Parameter(Mandatory = $true, ParameterSetName = 'AffinityGroup')]
        [String]
        $AffinityGroup
    )

    Write-VerboseWithTime 'Add-AzureVMStorage: 시작'

    # GUID의 일부분을 "devtest"에 추가하여 고유한 이름을 만드세요.
    $name = 'devtest'
    $suffix = [guid]::NewGuid().ToString('N').Substring(0,24 - $name.Length)
    $name = $name + $suffix

    # 위치/선호도 그룹으로 새 Microsoft Azure 저장소 계정을 만드세요.
    if ($PSCmdlet.ParameterSetName -eq 'Location')
    {
        New-AzureStorageAccount -StorageAccountName $name -Location $Location | Out-Null
    }
    else
    {
        New-AzureStorageAccount -StorageAccountName $name -AffinityGroup $AffinityGroup | Out-Null
    }

    Write-HostWithTime ("Add-AzureVMStorage: 새 저장소 계정 $name을 만들었습니다.")
    Write-VerboseWithTime 'Add-AzureVMStorage: 끝'
    return $name
}


<#
.SYNOPSIS
config 파일의 유효성을 검사하고 config 파일 값의 해시 테이블을 반환합니다.

.DESCRIPTION
Read-ConfigFile 함수는 JSON 구성 파일의 유효성을 검사하고 선택한 값의 해시 테이블을 반환합니다.
-- 먼저 JSON 파일을 PSCustomObject로 변환합니다.
클라우드 서비스 해시 테이블에는 다음 키가 있습니다.
-- webdeployparameters : 선택 사항입니다. $null 또는 비워둔 것일 수 있습니다.
-- Databases: SQL 데이터베이스

.PARAMETER  ConfigurationFile
웹 프로젝트에 대해 JSON 구성 파일의 경로와 이름을 지정합니다. Visual Studio는 웹 프로젝트를 만들면 JSON 파일을 자동으로 생성하고 솔루션의 PublishScripts 폴더에 저장합니다.

.PARAMETER HasWebDeployPackage
웹 응용 프로그램에 대한 웹 배포 패키지 ZIP 파일이 있음을 나타냅니다. $true 값을 지정하려면 -HasWebDeployPackage 또는 HasWebDeployPackage:$true를 사용하고, false 값을 지정하려면 HasWebDeployPackage:$false를 사용합니다. 이 매개 변수는 필수 사항입니다.

.INPUTS
없음. 이 함수에 입력을 파이프할 수 없습니다.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> Read-ConfigFile -ConfigurationFile <path> -HasWebDeployPackage


Name                           Value                                                                                                                                                                     
----                           -----                                                                                                                                                                     
databases                      {@{connectionStringName=; databaseName=; serverName=; user=; password=}}                                                                                                  
cloudService                   @{name="contoso"; affinityGroup="contosoEast"; location=; virtualNetwork=; subnet=; availabilitySet=; virtualMachine=}                                                      
webDeployParameters            @{iisWebApplicationName="Default Web Site"} 
#>
function Read-ConfigFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $ConfigurationFile,

        [Parameter(Mandatory = $true)]
        [Switch]
        $HasWebDeployPackage	    
    )

    Write-VerboseWithTime 'Read-ConfigFile: 시작'

    # JSON 파일의 콘텐츠(-raw는 줄 바뀜 무시)를 가져와 PSCustomObject로 변환하세요.
    $config = Get-Content $ConfigurationFile -Raw | ConvertFrom-Json

    if (!$config)
    {
        throw ('Read-ConfigFile: ConvertFrom-Json 실패: ' + $error[0])
    }

    # 속성 값에 관계없이 environmentSettings 개체에 'cloudService' 속성이 있는지 확인하세요.
    $hasCloudServiceProperty = Test-Member -Object $config.environmentSettings -Member 'cloudService'

    if (!$hasCloudServiceProperty)
    {
        throw 'Read-ConfigFile: 구성 파일에 cloudService 속성이 포함되어 있지 않습니다.'
    }

    # PSCustomObject의 값에서 해시 테이블을 빌드하세요.
    $returnObject = New-Object -TypeName Hashtable

        $returnObject.Add('cloudService', $config.environmentSettings.cloudService)
        if ($HasWebDeployPackage)
        {
            $returnObject.Add('webDeployParameters', $config.environmentSettings.webdeployParameters)
        }

    if (Test-Member -Object $config.environmentSettings -Member 'databases')
    {
        $returnObject.Add('databases', $config.environmentSettings.databases)
    }

    Write-VerboseWithTime 'Read-ConfigFile: 끝'

    return $returnObject
}

<#
.SYNOPSIS
가상 컴퓨터에 새 입력 끝점을 추가하고 새 끝점이 있는 가상 컴퓨터를 반환합니다.

.DESCRIPTION
Add-AzureVMEndpoints 함수는 가상 컴퓨터에 새 입력 끝점을 추가하고 새 끝점이 있는 가상 컴퓨터를 반환합니다. 이 함수는 Add-AzureEndpoint cmdlet(Azure 모듈)을 호출합니다.

.PARAMETER  VM
가상 컴퓨터 개체를 지정합니다. New-AzureVM 또는 Get-AzureVM cmdlet가 반환하는 것과 같은 유형의 VM 개체를 입력하세요. Get-AzureVM에서 Add-AzureVMEndpoints로 개체를 파이프할 수 있습니다.

.PARAMETER  Endpoints
VM에 추가할 끝점 어레이를 지정합니다. 일반적으로, 이 끝점의 소스는 Visual Studio가 웹 프로젝트에 대해 생성하는 JSON 구성 파일에서 발생합니다. 이 모듈의 Read-ConfigFile 함수를 사용하여 파일을 해시 테이블로 변환합니다. 끝점은 해시 테이블($<hashtable>.cloudservice.virtualmachine.endpoints)의 cloudservice 키 속성입니다. 예를 들면 다음과 같습니다.
PS C:\> $config.cloudservice.virtualmachine.endpoints
name      protocol publicport privateport
----      -------- ---------- -----------
http      tcp      80         80
https     tcp      443        443
WebDeploy tcp      8172       8172

.INPUTS
Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM

.OUTPUTS
Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM

.EXAMPLE
Get-AzureVM

.EXAMPLE

.LINK
Get-AzureVM

.LINK
Add-AzureEndpoint
#>
function Add-AzureVMEndpoints
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVM]
        $VM,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $Endpoints
    )

    Write-VerboseWithTime 'Add-AzureVMEndpoints: 시작'

    # JSON 파일에서 VM까지 각 끝점을 추가하세요.
    $Endpoints | ForEach-Object `
    {
        $_ | Out-String | Write-VerboseWithTime
        Add-AzureEndpoint -VM $VM -Name $_.name -Protocol $_.protocol -LocalPort $_.privateport -PublicPort $_.publicport | Out-Null
    }

    Write-VerboseWithTime 'Add-AzureVMEndpoints: 끝'
    return $VM
}

<#
.SYNOPSIS
Microsoft Azure 구독에 새 가상 컴퓨터의 모든 요소를 만듭니다.

.DESCRIPTION
이 함수는 Microsoft Azure VM(가상 컴퓨터)을 만들고 배포된 VM의 URL을 반환합니다. 함수는 전제 조건을 설정한 다음 New-AzureVM cmdlet(Azure 모듈)을 호출하여 새 VM을 만듭니다. 
-- New-AzureVMConfig cmdlet(Azure 모듈)을 호출하여 가상 컴퓨터 구성 개체를 가져옵니다. 
-- Subnet 매개 변수를 포함시켜 Azure 서브넷에 VM을 추가할 경우 Set-AzureSubnet을 호출하여 VM에 대해 서브넷 목록을 설정합니다. 
-- Add-AzureProvisioningConfig(Azure 모델)를 호출하여 VM 구성에 요소를 추가합니다. 관리자 계정과 암호로 독립 실행형 Windows 프로비전 구성(-Windows)을 만듭니다. 
-- 이 모듈에서 Add-AzureVMEndpoints 함수를 호출하여 Endpoints 매개 변수로 지정된 끝점을 추가합니다. 이 함수는 VM 개체를 사용하고 끝점이 추가된 VM 개체를 반환합니다. 
-- Add-AzureVM cmdlet을 호출하여 새 Microsoft Azure 가상 컴퓨터를 만들고 새 VM을 반환합니다. 함수 매개 변수의 값은 일반적으로 Visual Studio가 Microsoft Azure 통합 웹 프로젝트용으로 생성하는 JSON 구성 파일에서 가져옵니다. 이 모듈의 Read-ConfigFile 함수는 JSON 파일을 해시 테이블로 변환합니다. 변수(PSCustomObject 형식)에 해시 테이블의 cloudservice 키를 저장하고 사용자 지정 개체의 속성을 매개 변수 값으로 사용하세요.

.PARAMETER  VMName
새 VM의 이름을 지정합니다. VM 이름은 클라우드 서비스 내에서 고유해야 합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER  VMSize
VM의 크기를 지정합니다. 올바른 값은 "ExtraSmall", "Small", "Medium", "Large", "ExtraLarge", "A5", "A6", "A7"입니다. 이 값은 New-AzureVMConfig의 InstanceSize 매개 변수의 값으로 제출됩니다. 이 매개 변수는 필수 사항입니다. 

.PARAMETER  ServiceName
기존 Microsoft Azure 서비스 또는 새 Microsoft Azure 서비스의 이름을 지정합니다. 이 값은 기존 Microsoft Azure 서비스에 새 가상 컴퓨터를 추가하거나 Location 또는 AffinityGroup이 지정된 경우 현재 구독에 새 가상 컴퓨터와 서비스를 만드는 New-AzureVM cmdlet의 ServiceName 매개 변수에 제출됩니다. 이 매개 변수는 필수 사항입니다. 

.PARAMETER  ImageName
운영 체제 디스크에 사용할 가상 컴퓨터 이미지의 이름을 지정합니다. 이 매개 변수는 New-AzureVMConfig cmdlet의 ImageName 매개 변수 값으로 제출됩니다. 이 매개 변수는 필수 사항입니다. 

.PARAMETER  UserName
관리자 사용자 이름을 지정합니다. 이는 Add-AzureProvisioningConfig의 AdminUserName 매개 변수 값으로 제출됩니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER  UserPassword
관리자 사용자 계정의 암호를 지정합니다. 이는 Add-AzureProvisioningConfig의 Password 매개 변수 값으로 제출됩니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER  Endpoints
VM에 추가할 끝점 어레이를 지정합니다. 이 값은 모듈이 내보내는 Add-AzureVMEndpoints 함수에 제출됩니다. 이 매개 변수는 선택 사항입니다. 일반적으로, 이 끝점의 소스는 Visual Studio가 웹 프로젝트에 대해 생성하는 JSON 구성 파일에서 발생합니다. 이 모듈의 Read-ConfigFile 함수를 사용하여 파일을 해시 테이블로 변환합니다. 끝점은 해시 테이블($<hashtable>.cloudservice.virtualmachine.endpoints)의 cloudService 키 속성입니다. 

.PARAMETER  AvailabilitySetName
새 VM에 대한 가용성 세트의 이름을 지정합니다. 가용성 세트에 여러 대의 가상 컴퓨터를 배치하면 해당 가상 컴퓨터를 Microsoft Azure는 분리된 호스트에 유지하여 하나가 실패할 경우 서비스 연속성을 개선하려 합니다. 이 매개 변수는 선택 사항입니다. 

.PARAMETER  VNetName
새 가상 컴퓨터가 배포된 가상 네트워크 이름의 이름을 지정합니다. 이 값은 Add-AzureVM cmdlet의 VNetName 매개 변수에 제출됩니다. 이 매개 변수는 선택 사항입니다. 

.PARAMETER  Location
새 VM의 위치를 지정합니다. 올바른 값은 "West US"와 같은 Microsoft Azure 위치입니다. 기본값은 구독의 위치입니다. 이 매개 변수는 선택 사항입니다. 

.PARAMETER  AffinityGroup
새 VM의 선호도 그룹을 지정합니다. 선호도 그룹은 관련 리소스의 그룹입니다. 선호도 그룹을 지정하면 Microsoft Azure는 그룹의 리소스를 함께 유지하여 효율성을 개선하려 합니다. 

.PARAMETER  Subnet
새 VM 구성의 서브넷을 지정합니다. 이 값은 VM과 서브넷 이름의 어레이를 꺼내는 Set-AzureSubnet cmdlet(Azure 모듈)에 제출되고 구성에 서브넷이 포함된 VM을 반환합니다.

.PARAMETER EnableWebDeployExtension
배포할 VM을 준비합니다. 배포할 VM을 준비합니다. 이 매개 변수는 선택 사항입니다. 지정되어 있지 않으면 VM이 만들어지지만 배포되지는 않습니다. 이 매개 변수의 값은 Visual Studio가 클라우드 서비스용으로 생성하는 JSON 구성 파일에 포함됩니다.

.PARAMETER VMImage
ImageName이 OSImage가 아닌 VMImage의 이름이 되도록 지정합니다. 이 매개 변수는 선택 사항입니다. 이 매개 변수를 지정하지 않으면 ImageName이 OSImage로 처리됩니다. 이 매개 변수의 값은 Visual Studio가 가상 컴퓨터용으로 생성하는 JSON 구성 파일에 포함됩니다.

.PARAMETER GeneralizedImage
VMImage에서 OS 상태가 일반화되어 있는지 지정합니다. 이 매개 변수는 선택 사항입니다. 이 매개 변수를 지정하지 않으면 스크립트가 특수화된 VMImage에 대한 스크립트처럼 동작합니다. OSImage의 경우 이 매개 변수는 무시됩니다. 이 매개 변수의 값은 Visual Studio가 가상 컴퓨터용으로 생성하는 JSON 구성 파일에 포함됩니다.

.INPUTS
없음. 이 함수는 파이프라인에서 입력을 꺼내지 않습니다.

.OUTPUTS
System.Url

.EXAMPLE
 이 명령은 Add-AzureVM 함수를 호출합니다. 매개 변수 값 중 많은 수는 $CloudServiceConfiguration 개체에서 옵니다. 이 PSCustomObject는 cloudservice 키이고 Read-ConfigFile 함수가 반환하는 해시 테이블의 값입니다. 소스는 Visual Studio가 웹 프로젝트에 대해 생성하는 JSON 구성 파일입니다.

PS C:\> $config = Read-Configfile <name>.json
PS C:\> $CloudServiceConfiguration = $config.cloudservice

PS C:\> Add-AzureVM `
-UserName $userName `
-UserPassword  $userPassword `
-ImageName $CloudServiceConfiguration.virtualmachine.vhdImage `
-VMName $CloudServiceConfiguration.virtualmachine.name `
-VMSize $CloudServiceConfiguration.virtualmachine.size`
-Endpoints $CloudServiceConfiguration.virtualmachine.endpoints `
-ServiceName $serviceName `
-Location $CloudServiceConfiguration.location `
-AvailabilitySetName $CloudServiceConfiguration.availabilitySet `
-VNetName $CloudServiceConfiguration.virtualNetwork `
-Subnet $CloudServiceConfiguration.subnet `
-AffinityGroup $CloudServiceConfiguration.affinityGroup `
-EnableWebDeployExtension

http://contoso.cloudapp.net

.EXAMPLE
PS C:\> $endpoints = [PSCustomObject]@{name="http";protocol="tcp";publicport=80;privateport=80}, `
                        [PSCustomObject]@{name="https";protocol="tcp";publicport=443;privateport=443},`
                        [PSCustomObject]@{name="WebDeploy";protocol="tcp";publicport=8172;privateport=8172}
PS C:\> Add-AzureVM `
-UserName admin01 `
-UserPassword "password" `
-ImageName bd507d3a70934695bc2128e3e5a255ba__RightImage-Windows-2012-x64-v13.4.12.2 `
-VMName DevTestVM123 `
-VMSize Small `
-Endpoints $endpoints `
-ServiceName DevTestVM1234 `
-Location "West US"

.LINK
New-AzureVMConfig

.LINK
Set-AzureSubnet

.LINK
Add-AzureProvisioningConfig

.LINK
Get-AzureDeployment
#>
function Add-AzureVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $VMName,

        [Parameter(Mandatory = $true)]
        [String]
        $VMSize,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $ImageName,

        [Parameter(Mandatory = $false)]
        [String]
        $UserName,

        [Parameter(Mandatory = $false)]
        [String]
        $UserPassword,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Object[]]
        $Endpoints,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $AvailabilitySetName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $VNetName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $Location,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $AffinityGroup,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $Subnet,

        [Parameter(Mandatory = $false)]
        [Switch]
        $EnableWebDeployExtension,

        [Parameter(Mandatory=$false)]
        [Switch]
        $VMImage,

        [Parameter(Mandatory=$false)]
        [Switch]
        $GeneralizedImage
    )

    Write-VerboseWithTime 'Add-AzureVM: 시작'

	if ($VMImage)
	{
		$specializedImage = !$GeneralizedImage;
	}
	else
	{
		$specializedImage = $false;
	}

    # 새 Microsoft Azure VM 구성 개체를 만드세요.
    if ($AvailabilitySetName)
    {
        $vm = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $ImageName -AvailabilitySetName $AvailabilitySetName
    }
    else
    {
        $vm = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $ImageName
    }

    if (!$vm)
    {
        throw 'Add-AzureVM: Azure VM config를 만들지 못했습니다.'
    }

    if ($Subnet)
    {
        # 가상 컴퓨터 구성에 대해 서브넷 목록을 설정하세요.
        $subnetResult = Set-AzureSubnet -VM $vm -SubnetNames $Subnet

        if (!$subnetResult)
        {
            throw ('Add-AzureVM: 서브넷을 설정하지 못했습니다. ' + $Subnet)
        }
    }

    if (!$specializedImage)
    {
	    # VM 구성에 구성 데이터를 추가하세요.
        $vm = Add-AzureProvisioningConfig -VM $vm -Windows -Password $UserPassword -AdminUserName $UserName -NoRDPEndpoint -NoWinRMEndpoint

        if (!$vm)
		{
			throw ('Add-AzureVM: 프로비전 config를 만들지 못했습니다.')
		}
    }

    # VM에 입력 끝점을 추가하세요.
    if ($Endpoints -and $Endpoints.Count -gt 0)
    {
        $vm = Add-AzureVMEndpoints -Endpoints $Endpoints -VM $vm
    }

    if (!$vm)
    {
        throw ('Add-AzureVM: 끝점을 만들지 못했습니다.')
    }

    if ($EnableWebDeployExtension)
    {
        Write-VerboseWithTime 'Add-AzureVM: Webdeploy 확장을 추가하세요.'

        Write-VerboseWithTime 'WebDeploy 라이선스를 보려면 http://go.microsoft.com/fwlink/?LinkID=389744를 참조하세요. '

        $vm = Set-AzureVMExtension `
            -VM $vm `
            -ExtensionName WebDeployForVSDevTest `
            -Publisher 'Microsoft.VisualStudio.WindowsAzure.DevTest' `
            -Version '1.*' 

        if (!$vm)
        {
            throw ('Add-AzureVM: Webdeploy 확장을 추가하지 못했습니다.')
        }
    }

    # 스플래팅용 매개 변수 해시 테이블을 만드세요.
    $param = New-Object -TypeName Hashtable
    if ($VNetName)
    {
        $param.Add('VNetName', $VNetName)
    }

    # VMImages은(는) 당분간 위치를 지원하지 않습니다. 새 VM은 이미지가 존재하는 동일한 저장소 계정(위치)에서 만들어집니다.
    if (!$VMImage -and $Location)
    {
		$param.Add('Location', $Location)
    }

    if ($AffinityGroup)
    {
        $param.Add('AffinityGroup', $AffinityGroup)
    }

    $param.Add('ServiceName', $ServiceName)
    $param.Add('VMs', $vm)
    $param.Add('WaitForBoot', $true)

    $param | Out-String | Write-VerboseWithTime

    New-AzureVM @param | Out-Null

    Write-HostWithTime ('Add-AzureVM: 가상 컴퓨터를 만들었습니다. ' + $VMName)

    $url = [System.Uri](Get-AzureDeployment -ServiceName $ServiceName).Url

    if (!$url)
    {
        throw 'Add-AzureVM: VM Url을 찾을 수 없습니다.'
    }

    Write-HostWithTime ('Add-AzureVM: Url https://를 게시하세요.' + $url.Host + ':' + $WebDeployPort + '/msdeploy.axd')

    Write-VerboseWithTime 'Add-AzureVM: 끝'

    return $url.AbsoluteUri
}


<#
.SYNOPSIS
지정된 Microsoft Azure 가상 컴퓨터를 가져옵니다.

.DESCRIPTION
Find-AzureVM 함수는 서비스 이름과 VM 이름에 따라 Microsoft Azure VM(가상 컴퓨터)을 가져옵니다. 이 함수는 Test-AzureName cmdlet(Azure 모듈)을 호출하여 Microsoft Azure에 서비스 이름이 있는지 확인합니다. 있으면 함수가 Get-AzureVM cmdlet을 호출하여 VM을 가져옵니다. 이 함수는 VM과 foundService 키가 포함된 해시 테이블을 반환합니다.
-- FoundService: Test-AzureName이 서비스를 찾으면 $True를, 그렇지 않으면 $False를 반환합니다.
-- VM: FoundService가 true이고 Get-AzureVM이 VM 개체를 반환하면 VM 개체가 포함됩니다.

.PARAMETER  ServiceName
기존의 Microsoft Azure 서비스 이름. 이 매개 변수는 필수 사항입니다.

.PARAMETER  VMName
서비스의 가상 컴퓨터 이름. 이 매개 변수는 필수 사항입니다.

.INPUTS
없음. 이 함수에 입력을 파이프할 수 없습니다.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> Find-AzureVM -Service Contoso -Name ContosoVM2

Name                           Value
----                           -----
foundService                   True

DeploymentName        : Contoso
Name                  : ContosoVM2
Label                 :
VM                    : Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVM
InstanceStatus        : ReadyRole
IpAddress             : 100.71.114.118
InstanceStateDetails  :
PowerState            : Started
InstanceErrorCode     :
InstanceFaultDomain   : 0
InstanceName          : ContosoVM2
InstanceUpgradeDomain : 0
InstanceSize          : Small
AvailabilitySetName   :
DNSName               : http://contoso.cloudapp.net/
ServiceName           : Contoso
OperationDescription  : Get-AzureVM
OperationId           : 3c38e933-9464-6876-aaaa-734990a882d6
OperationStatus       : Succeeded

.LINK
Get-AzureVM
#>
function Find-AzureVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $VMName
    )

    Write-VerboseWithTime 'Find-AzureVM: 시작'
    $foundService = $false
    $vm = $null

    if (Test-AzureName -Service -Name $ServiceName)
    {
        $foundService = $true
        $vm = Get-AzureVM -ServiceName $ServiceName -Name $VMName
        if ($vm)
        {
            Write-HostWithTime ('Find-AzureVM: 기존의 가상 컴퓨터를 찾았습니다. ' + $vm.Name )
            $vm | Out-String | Write-VerboseWithTime
        }
    }

    Write-VerboseWithTime 'Find-AzureVM: 끝'
    return @{ VM = $vm; FoundService = $foundService }
}


<#
.SYNOPSIS
JSON 구성 파일의 값과 일치하는 구독에서 가상 컴퓨터를 찾거나 만듭니다.

.DESCRIPTION
New-AzureVMEnvironment 함수는 Visual Studio가 웹 프로젝트에 대해 생성하는 JSON 구성의 값과 일치하는 구독에서 가상 컴퓨터를 찾거나 만듭니다. Read-ConfigFile이 반환하는 해시 테이블의 cloudservice 키인 PSCustomObject가 필요합니다. 이 데이터는 Visual Studio가 생성하는 JSON 구성 파일에서 발생합니다. 함수는 서비스 이름과 가상 컴퓨터 이름이 CloudServiceConfiguration 사용자 지정 개체의 값과 일치하는 구독에서 VM(가상 컴퓨터)을 찾습니다. 일치하는 VM을 찾을 수 없을 경우 이 모듈에서 Add-AzureVM 함수를 호출하고 CloudServiceConfiguration 개체의 값을 사용하여 VM을 만듭니다. 가상 컴퓨터 환경에는 "devtest"로 시작하는 이름의 저장소 계정이 포함됩니다. 함수는 구독에서 해당 이름 패턴의 저장소 계정을 찾을 수 없으면 계정을 만듭니다. 함수가 VMUrl, userName, Password 키와 문자열 값이 포함된 해시 테이블을 반환합니다.

.PARAMETER  CloudServiceConfiguration
Read-ConfigFile 함수가 반환하는 해시 테이블의 cloudservice 속성이 포함된 PSCustomObject를 꺼냅니다. 모든 값은 Visual Studio가 웹 프로젝트에 대해 생성하는 JSON 구성 파일에서 발생합니다. 솔루션의 PublishScripts 폴더에서 이 파일을 찾을 수 있습니다. 이 매개 변수는 필수 사항입니다.
$config = Read-ConfigFile -ConfigurationFile <file>.json $cloudServiceConfiguration = $config.cloudService

.PARAMETER  VMPassword
@{Name = "admin"; Password = "password"}과(와) 같이 Name 및 Password 키를 사용하여 해시 테이블을 가져옵니다. 이 매개 변수는 선택 사항입니다. 생략하는 경우 JSON 구성 파일에서 가상 컴퓨터 사용자 이름과 암호가 기본값으로 사용됩니다.

.INPUTS
PSCustomObject  System.Collections.Hashtable

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$config = Read-ConfigFile -ConfigurationFile $<file>.json
$cloudSvcConfig = $config.cloudService
$namehash = @{name = "admin"; password = "password"}

New-AzureVMEnvironment `
    -CloudServiceConfiguration $cloudSvcConfig `
    -VMPassword $namehash

Name                           Value
----                           -----
UserName                       admin
VMUrl                          contoso.cloudnet.net
Password                       password

.LINK
Add-AzureVM

.LINK
New-AzureStorageAccount
#>
function New-AzureVMEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $CloudServiceConfiguration,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMPassword
    )

    Write-VerboseWithTime ('New-AzureVMEnvironment: 시작')

    if ($CloudServiceConfiguration.location -and $CloudServiceConfiguration.affinityGroup)
    {
        throw 'New-AzureVMEnvironment: 구성 파일이 잘못 형성되었습니다. location 및 affinityGroup이 둘 다 있습니다.'
    }

    if (!$CloudServiceConfiguration.location -and !$CloudServiceConfiguration.affinityGroup)
    {
        throw 'New-AzureVMEnvironment: 구성 파일이 잘못 형성되었습니다. location 또는 affinityGroup이 없습니다.'
    }

    # CloudServiceConfiguration 개체에 'name' 속성(서비스 이름)이 있고 'name' 속성에 값이 있을 경우 사용하세요. 그렇지 않으면 항상 채워진 CloudServiceConfiguration 개체에 가상 컴퓨터 이름을 사용하세요.
    if ((Test-Member $CloudServiceConfiguration 'name') -and $CloudServiceConfiguration.name)
    {
        $serviceName = $CloudServiceConfiguration.name
    }
    else
    {
        $serviceName = $CloudServiceConfiguration.virtualMachine.name
    }

    if (!$VMPassword)
    {
        $userName = $CloudServiceConfiguration.virtualMachine.user
        $userPassword = $CloudServiceConfiguration.virtualMachine.password
    }
    else
    {
        $userName = $VMPassword.Name
        $userPassword = $VMPassword.Password
    }

    # JSON 파일에서 VM 이름을 가져오세요.
    $findAzureVMResult = Find-AzureVM -ServiceName $serviceName -VMName $CloudServiceConfiguration.virtualMachine.name

    # 해당 클라우드 서비스에서 해당 이름의 VM을 찾을 수 없으면 VM을 만드세요.
    if (!$findAzureVMResult.VM)
    {
        if(!$CloudServiceConfiguration.virtualMachine.isVMImage)
        {
            $storageAccountName = $null
            $imageInfo = Get-AzureVMImage -ImageName $CloudServiceConfiguration.virtualmachine.vhdimage 
            if ($imageInfo -and $imageInfo.Category -eq 'User')
            {
                $storageAccountName = ($imageInfo.MediaLink.Host -split '\.')[0]
            }

            if (!$storageAccountName)
            {
                if ($CloudServiceConfiguration.location)
                {
                    $storageAccountName = Get-AzureVMStorage -Location $CloudServiceConfiguration.location
                }
                else
                {
                    $storageAccountName = Get-AzureVMStorage -AffinityGroup $CloudServiceConfiguration.affinityGroup
                }
            }

             # devtest* 저장소 계정이 없는 경우 만드세요.
            if (!$storageAccountName)
            {
                if ($CloudServiceConfiguration.location)
                {
                    $storageAccountName = Add-AzureVMStorage -Location $CloudServiceConfiguration.location
                }
                else
                {
                    $storageAccountName = Add-AzureVMStorage -AffinityGroup $CloudServiceConfiguration.affinityGroup
                }
            }

            $currentSubscription = Get-AzureSubscription -Current

            if (!$currentSubscription)
            {
                throw 'New-AzureVMEnvironment: 현재 Azure 구독을 가져올 수 없습니다.'
            }

            # devtest* 저장소 계정을 현재 계정으로 설정하세요.
            Set-AzureSubscription `
                -SubscriptionName $currentSubscription.SubscriptionName `
                -CurrentStorageAccountName $storageAccountName

            Write-VerboseWithTime ('New-AzureVMEnvironment: 저장소 계정이 다음으로 설정되어 있습니다. ' + $storageAccountName)
        }

        $location = ''            
        if (!$findAzureVMResult.FoundService)
        {
            $location = $CloudServiceConfiguration.location
        }

        $endpoints = $null
        if (Test-Member -Object $CloudServiceConfiguration.virtualmachine -Member 'Endpoints')
        {
            $endpoints = $CloudServiceConfiguration.virtualmachine.endpoints
        }

        # JSON 파일의 값 + 매개 변수 값으로 VM을 만드세요.
        $VMUrl = Add-AzureVM `
            -UserName $userName `
            -UserPassword $userPassword `
            -ImageName $CloudServiceConfiguration.virtualMachine.vhdImage `
            -VMName $CloudServiceConfiguration.virtualMachine.name `
            -VMSize $CloudServiceConfiguration.virtualMachine.size`
            -Endpoints $endpoints `
            -ServiceName $serviceName `
            -Location $location `
            -AvailabilitySetName $CloudServiceConfiguration.availabilitySet `
            -VNetName $CloudServiceConfiguration.virtualNetwork `
            -Subnet $CloudServiceConfiguration.subnet `
            -AffinityGroup $CloudServiceConfiguration.affinityGroup `
            -EnableWebDeployExtension:$CloudServiceConfiguration.virtualMachine.enableWebDeployExtension `
            -VMImage:$CloudServiceConfiguration.virtualMachine.isVMImage `
            -GeneralizedImage:$CloudServiceConfiguration.virtualMachine.isGeneralizedImage

        Write-VerboseWithTime ('New-AzureVMEnvironment: 끝')

        return @{ 
            VMUrl = $VMUrl; 
            UserName = $userName; 
            Password = $userPassword; 
            IsNewCreatedVM = $true; }
    }
    else
    {
        Write-VerboseWithTime ('New-AzureVMEnvironment: 기존의 가상 컴퓨터를 찾았습니다. ' + $findAzureVMResult.VM.Name)
    }

    Write-VerboseWithTime ('New-AzureVMEnvironment: 끝')

    return @{ 
        VMUrl = $findAzureVMResult.VM.DNSName; 
        UserName = $userName; 
        Password = $userPassword; 
        IsNewCreatedVM = $false; }
}


<#
.SYNOPSIS
명령을 반환하여 MsDeploy.exe 도구를 실행합니다.

.DESCRIPTION
Get-MSDeployCmd 함수는 유효한 명령을 조합 및 반환하여 웹 배포 도구인 MSDeploy.exe를 실행합니다. 레지스트리 키에서 로컬 컴퓨터의 도구로 연결되는 올바른 경로를 찾습니다. 이 함수에는 매개 변수가 없습니다.

.INPUTS
없음

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Get-MSDeployCmd
C:\Program Files\IIS\Microsoft Web Deploy V3\MsDeploy.exe

.LINK
Get-MSDeployCmd

.LINK
Web Deploy Tool
http://technet.microsoft.com/en-us/library/dd568996(v=ws.10).aspx
#>
function Get-MSDeployCmd
{
    Write-VerboseWithTime 'Get-MSDeployCmd: 시작'
    $regKey = 'HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy'

    if (!(Test-Path $regKey))
    {
        throw ('Get-MSDeployCmd: 찾을 수 없습니다. ' + $regKey)
    }

    $versions = @(Get-ChildItem $regKey -ErrorAction SilentlyContinue)
    $lastestVersion =  $versions | Sort-Object -Property Name -Descending | Select-Object -First 1

    if ($lastestVersion)
    {
        $installPathKeys = 'InstallPath','InstallPath_x86'

        foreach ($installPathKey in $installPathKeys)
        {		    	
            $installPath = $lastestVersion.GetValue($installPathKey)

            if ($installPath)
            {
                $installPath = Join-Path $installPath -ChildPath 'MsDeploy.exe'

                if (Test-Path $installPath -PathType Leaf)
                {
                    $msdeployPath = $installPath
                    break
                }
            }
        }
    }

    Write-VerboseWithTime 'Get-MSDeployCmd: 끝'
    return $msdeployPath
}


<#
.SYNOPSIS
URL이 절대이고 스키마가 https이면 $True를 반환합니다.

.DESCRIPTION
Test-HttpsUrl 함수는 입력 URL을 System.Uri 개체로 변환합니다. URL이 (상대가 아닌) 절대이고 스키마가 https이면 $True를 반환합니다. 둘 중 하나가 false이거나 입력 문자열을 URL로 변환할 수 없으면 함수가 $false를 반환합니다.

.PARAMETER Url
테스트에 URL을 지정합니다. URL 문자열을 입력하세요.

.INPUTS
없음.

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\>$profile.publishUrl
waws-prod-bay-001.publish.azurewebsites.windows.net:443

PS C:\>Test-HttpsUrl -Url 'waws-prod-bay-001.publish.azurewebsites.windows.net:443'
False

PS C:\>Test-HttpsUrl -Url 'https://waws-prod-bay-001.publish.azurewebsites.windows.net:443'
True
#>
function Test-HttpsUrl
{

    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Url
    )

    # $uri를 System.Uri 개체로 변환할 수 없으면 Test-HttpsUrl이 $false를 반환합니다.
    $uri = $Url -as [System.Uri]

    return $uri.IsAbsoluteUri -and $uri.Scheme -eq 'https'
}


<#
.SYNOPSIS
Microsoft Azure에 웹 패키지를 배포합니다.

.DESCRIPTION
Publish-WebPackage 함수는 MsDeploy.exe와 웹 배포 패키지 ZIP 파일을 사용하여 Microsoft Azure 웹 사이트에 리소스를 배포합니다. 이 함수는 어떠한 출력도 생성하지 않습니다. MSDeploy.exe 호출이 실패하면 함수가 예외를 throw합니다. 더 자세한 출력을 가져오려면 많이 사용되는 Verbose 매개 변수를 사용하세요.

.PARAMETER  WebDeployPackage
Visual Studio가 생성하는 웹 배포 패키지 ZIP 파일의 경로와 파일 이름을 지정합니다. 이 매개 변수는 필수 사항입니다. 웹 배포 패키지 ZIP 파일을 만들려면 "방법: Visual Studio에서 웹 배포 패키지 만들기"(http://go.microsoft.com/fwlink/?LinkId=391353)를 참조하세요.

.PARAMETER PublishUrl
리소스가 배포된 URL을 지정합니다. URL은 HTTPS 프로토콜을 사용하고 포트가 포함되어 있어야 합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER SiteName
웹 사이트의 이름을 지정합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER Username
웹 사이트 관리자의 사용자 이름을 지정합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER Password
웹 사이트 관리자의 암호를 지정합니다. 암호를 일반 텍스트로 입력하세요. 안전 문자열은 허용되지 않습니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER AllowUntrusted
웹 배포 끝점에 대한 신뢰할 수 없는 SSL 연결을 허용합니다. 이 매개 변수는 MSDeploy.exe를 호출하는 데 사용되며 선택 사항입니다.

.PARAMETER ConnectionString
SQL 데이터베이스의 연결 문자열을 지정합니다. 이 매개 변수는 Name과 ConnectionString 키가 있는 해시 테이블을 꺼냅니다. Name의 값은 데이터베이스의 이름입니다. ConnectionString의 값은 JSON 구성 파일의 connectionStringName입니다.

.INPUTS
없음. 이 함수는 파이프라인에서 입력을 꺼내지 않습니다.

.OUTPUTS
없음

.EXAMPLE
Publish-WebPackage -WebDeployPackage C:\Documents\Azure\ADWebApp.zip `
    -PublishUrl 'https://contoso.cloudapp.net:8172/msdeploy.axd' `
    -SiteName 'Contoso 테스트 사이트' `
    -UserName 'admin01' `
    -Password 'password' `
    -AllowUntrusted:$False `
    -ConnectionString @{Name="TestDB";ConnectionString="DefaultConnection"}

.LINK
Publish-WebPackageToVM

.LINK
Web Deploy Command Line Reference (MSDeploy.exe)
http://go.microsoft.com/fwlink/?LinkId=391354
#>
function Publish-WebPackage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-HttpsUrl $_ })]
        [String]
        $PublishUrl,

        [Parameter(Mandatory = $true)]
        [String]
        $SiteName,

        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [String]
        $Password,

        [Parameter(Mandatory = $false)]
        [Switch]
        $AllowUntrusted = $false,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $ConnectionString
    )

    Write-VerboseWithTime 'Publish-WebPackage: 시작'

    $msdeployCmd = Get-MSDeployCmd

    if (!$msdeployCmd)
    {
        throw 'Publish-WebPackage: MsDeploy.exe를 찾을 수 없습니다.'
    }

    $WebDeployPackage = (Get-Item $WebDeployPackage).FullName

    $msdeployCmd =  '"' + $msdeployCmd + '"'
    $msdeployCmd += ' -verb:sync'
    $msdeployCmd += ' -Source:Package="{0}"'
    $msdeployCmd += ' -dest:auto,computername="{1}?site={2}",userName={3},password={4},authType=Basic'
    if ($AllowUntrusted)
    {
        $msdeployCmd += ' -allowUntrusted'
    }
    $msdeployCmd += ' -setParam:name="IIS Web Application Name",value="{2}"'

    foreach ($DBConnection in $ConnectionString.GetEnumerator())
    {
        $msdeployCmd += (' -setParam:name="{0}",value="{1}"' -f $DBConnection.Key, $DBConnection.Value)
    }

    $msdeployCmd = $msdeployCmd -f $WebDeployPackage, $PublishUrl, $SiteName, $UserName, $Password
    $msdeployCmdForVerboseMessage = $msdeployCmd -f $WebDeployPackage, $PublishUrl, $SiteName, $UserName, '********'

    Write-VerboseWithTime ('Publish-WebPackage: MsDeploy: ' + $msdeployCmdForVerboseMessage)

    $msdeployExecution = Start-Process cmd.exe -ArgumentList ('/C "' + $msdeployCmd + '" ') -WindowStyle Normal -Wait -PassThru

    if ($msdeployExecution.ExitCode -ne 0)
    {
         Write-VerboseWithTime ('Msdeploy.exe가 오류로 인해 종료되었습니다. ExitCode:' + $msdeployExecution.ExitCode)
    }

    Write-VerboseWithTime 'Publish-WebPackage: 끝'
    return ($msdeployExecution.ExitCode -eq 0)
}


<#
.SYNOPSIS
Microsoft Azure에 가상 컴퓨터를 배포합니다.

.DESCRIPTION
Publish-WebPackageToVM 함수는 매개 변수 값을 확인한 다음 Publish-WebPackage 함수를 호출하므로 도우미 함수입니다.

.PARAMETER  VMDnsName
Microsoft Azure 가상 컴퓨터의 DNS 이름을 지정합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER IisWebApplicationName
가상 컴퓨터에 대한 IIS 웹 응용 프로그램의 이름을 지정합니다. 이 매개 변수는 필수 사항입니다. 이것은 Visual Studio 웹 앱의 이름입니다. Visual Studio가 생성하는 JSON 구성 파일의 webDeployparameters 속성에서 이름을 찾을 수 있습니다.

.PARAMETER WebDeployPackage
Visual Studio가 생성하는 웹 배포 패키지 ZIP 파일의 경로와 파일 이름을 지정합니다. 이 매개 변수는 필수 사항입니다. 웹 배포 패키지 ZIP 파일을 만들려면 "방법: Visual Studio에서 웹 배포 패키지 만들기"(http://go.microsoft.com/fwlink/?LinkId=391353)를 참조하세요.

.PARAMETER Username
가상 컴퓨터 관리자의 사용자 이름을 지정합니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER Password
가상 컴퓨터 관리자의 암호를 지정합니다. 암호를 일반 텍스트로 입력하세요. 안전 문자열은 허용되지 않습니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER AllowUntrusted
웹 배포 끝점에 대한 신뢰할 수 없는 SSL 연결을 허용합니다. 이 매개 변수는 MSDeploy.exe를 호출하는 데 사용되며 선택 사항입니다.

.PARAMETER ConnectionString
SQL 데이터베이스의 연결 문자열을 지정합니다. 이 매개 변수는 Name과 ConnectionString 키가 있는 해시 테이블을 꺼냅니다. Name의 값은 데이터베이스의 이름입니다. ConnectionString의 값은 JSON 구성 파일의 connectionStringName입니다.

.INPUTS
없음. 이 함수는 파이프라인에서 입력을 꺼내지 않습니다.

.OUTPUTS
없음.

.EXAMPLE
Publish-WebPackageToVM -VMDnsName contoso.cloudapp.net `
-IisWebApplicationName myTestWebApp `
-WebDeployPackage C:\Documents\Azure\ADWebApp.zip
-Username 'admin01' `
-Password 'password' `
-AllowUntrusted:$False `
-ConnectionString @{Name="TestDB";ConnectionString="DefaultConnection"}

.LINK
Publish-WebPackage
#>
function Publish-WebPackageToVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $VMDnsName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $IisWebApplicationName,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserPassword,

        [Parameter(Mandatory = $true)]
        [Bool]
        $AllowUntrusted,
        
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $ConnectionString
    )
    Write-VerboseWithTime 'Publish-WebPackageToVM: 시작'

    $VMDnsUrl = $VMDnsName -as [System.Uri]

    if (!$VMDnsUrl)
    {
        throw ('Publish-WebPackageToVM: 잘못된 url ' + $VMDnsUrl)
    }

    $publishUrl = 'https://{0}:{1}/msdeploy.axd' -f $VMDnsUrl.Host, $WebDeployPort

    $result = Publish-WebPackage `
        -WebDeployPackage $WebDeployPackage `
        -PublishUrl $publishUrl `
        -SiteName $IisWebApplicationName `
        -UserName $UserName `
        -Password $UserPassword `
        -AllowUntrusted:$AllowUntrusted `
        -ConnectionString $ConnectionString

    Write-VerboseWithTime 'Publish-WebPackageToVM: 끝'
    return $result
}


<#
.SYNOPSIS
Microsoft Azure SQL 데이터베이스에 연결할 수 있는 문자열을 만듭니다.

.DESCRIPTION
Get-AzureSQLDatabaseConnectionString 함수는 연결 문자열을 조합하여 Microsoft Azure SQL 데이터베이스에 연결합니다.

.PARAMETER  DatabaseServerName
Microsoft Azure 구독에서 기존 데이터베이스 서버의 이름을 지정합니다. 모든 Microsoft Azure SQL 데이터베이스는 SQL 데이터베이스 서버와 연결되어 있어야 합니다. 서버 이름을 가져오려면 Get-AzureSqlDatabaseServer cmdlet(Azure 모듈)을 사용하세요. 이 매개 변수는 필수 사항입니다.

.PARAMETER  DatabaseName
SQL 데이터베이스의 이름을 지정합니다. 이것은 기존의 SQL 데이터베이스 또는 새 SQL 데이터베이스에 사용되는 이름일 수 있습니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER  Username
SQL 데이터베이스 관리자의 이름을 지정합니다. 사용자 이름은 $Username@DatabaseServerName입니다. 이 매개 변수는 필수 사항입니다.

.PARAMETER  Password
SQL 데이터베이스 관리자의 암호를 지정합니다. 암호를 일반 텍스트로 입력하세요. 안전 문자열은 허용되지 않습니다. 이 매개 변수는 필수 사항입니다.

.INPUTS
없음.

.OUTPUTS
System.String

.EXAMPLE
PS C:\> $ServerName = (Get-AzureSqlDatabaseServer).ServerName[0]
PS C:\> Get-AzureSQLDatabaseConnectionString -DatabaseServerName $ServerName `
        -DatabaseName 'testdb' -UserName 'admin'  -Password 'password'

Server=tcp:testserver.database.windows.net,1433;Database=testdb;User ID=admin@bebad12345;Password=password;Trusted_Connection=False;Encrypt=True;Connection Timeout=20;
#>
function Get-AzureSQLDatabaseConnectionString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [String]
        $Password
    )

    return ('Server=tcp:{0}.database.windows.net,1433;Database={1};' +
           'User ID={2}@{0};' +
           'Password={3};' +
           'Trusted_Connection=False;' +
           'Encrypt=True;' +
           'Connection Timeout=20;') `
           -f $DatabaseServerName, $DatabaseName, $UserName, $Password
}


<#
.SYNOPSIS
Visual Studio가 생성하는 JSON 구성 파일의 값에서 Microsoft Azure SQL 데이터베이스를 만듭니다.

.DESCRIPTION
Add-AzureSQLDatabases 함수는 JSON 파일의 데이터베이스 섹션에서 정보를 가져갑니다. 이 함수 Add-AzureSQLDatabases(복수)는 JSON 파일의 각 SQL 데이터베이스에 대해 Add-AzureSQLDatabase(단수) 함수를 호출합니다. Add-AzureSQLDatabase(단수)는 SQL 데이터베이스를 만드는 New-AzureSqlDatabase cmdlet(Azure 모듈)을 호출합니다. 이 함수는 데이터베이스 개체를 반환하지 않습니다. 데이터베이스를 만드는 데 사용된 값의 해시 테이블을 반환합니다.

.PARAMETER DatabaseConfig
 JSON 파일에 웹 사이트 속성이 있을 경우 Read-ConfigFile 함수가 반환하는 JSON 파일에서 발생하는 PSCustomObjects의 어레이를 꺼냅니다. 여기에는 environmentSettings.databases 속성이 포함됩니다. 이 함수에 목록을 파이프할 수 있습니다.
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases| where {$_.connectionStringName}
PS C:\> $DatabaseConfig
connectionStringName: Default Connection
databasename : TestDB1
edition   :
size     : 1
collation  : SQL_Latin1_General_CP1_CI_AS
servertype  : New SQL Database Server
servername  : r040tvt2gx
user     : dbuser
password   : Test.123
location   : West US

.PARAMETER  DatabaseServerPassword
SQL 데이터베이스 서버 관리자의 암호를 지정합니다. Name 및 Password 키를 사용하여 해시 테이블을 입력합니다. Name 값은 SQL 데이터베이스 서버의 이름이고, Password 값은 관리자 암호입니다(예: @Name = "TestDB1"; Password = "password"). 이 매개 변수는 선택 사항입니다. 생략하거나 SQL 데이터베이스 서버 이름이 $DatabaseConfig 개체의 serverName 속성 값과 일치하지 않는 경우 함수가 연결 문자열에서 SQL 데이터베이스에 대해 $DatabaseConfig 개체의 Password 속성을 사용합니다.

.PARAMETER CreateDatabase
데이터베이스를 만들고자 함을 확인합니다. 이 매개 변수는 선택 사항입니다.

.INPUTS
System.Collections.Hashtable[]

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases| where {$_.connectionStringName}
PS C:\> $DatabaseConfig | Add-AzureSQLDatabases

Name                           Value
----                           -----
ConnectionString               Server=tcp:testdb1.database.windows.net,1433;Database=testdb;User ID=admin@testdb1;Password=password;Trusted_Connection=False;Encrypt=True;Connection Timeout=20;
Name                           Default Connection
Type                           SQLAzure

.LINK
Get-AzureSQLDatabaseConnectionString

.LINK
Create-AzureSQLDatabase
#>
function Add-AzureSQLDatabases
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        $DatabaseConfig,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable[]]
        $DatabaseServerPassword,

        [Parameter(Mandatory = $false)]
        [Switch]
        $CreateDatabase = $false
    )

    begin
    {
        Write-VerboseWithTime 'Add-AzureSQLDatabases: 시작'
    }
    process
    {
        Write-VerboseWithTime ('Add-AzureSQLDatabases: 만드는 중 ' + $DatabaseConfig.databaseName)

        if ($CreateDatabase)
        {
            # DatabaseConfig 값으로 새 SQL 데이터베이스 만들기(이미 존재하지 않는 경우)
            # 명령 출력이 생략되었습니다.
            Add-AzureSQLDatabase -DatabaseConfig $DatabaseConfig | Out-Null
        }

        $serverPassword = $null
        if ($DatabaseServerPassword)
        {
            foreach ($credential in $DatabaseServerPassword)
            {
               if ($credential.Name -eq $DatabaseConfig.serverName)
               {
                   $serverPassword = $credential.password             
                   break
               }
            }               
        }

        if (!$serverPassword)
        {
            $serverPassword = $DatabaseConfig.password
        }

        return @{
            Name = $DatabaseConfig.connectionStringName;
            Type = 'SQLAzure';
            ConnectionString = Get-AzureSQLDatabaseConnectionString `
                -DatabaseServerName $DatabaseConfig.serverName `
                -DatabaseName $DatabaseConfig.databaseName `
                -UserName $DatabaseConfig.user `
                -Password $serverPassword }
    }
    end
    {
        Write-VerboseWithTime 'Add-AzureSQLDatabases: 끝'
    }
}


<#
.SYNOPSIS
새 Microsoft Azure SQL 데이터베이스를 만듭니다.

.DESCRIPTION
Add-AzureSQLDatabase 함수는 Visual Studio가 생성하는 JSON 구성 파일의 데이터에서 Microsoft Azure SQL 데이터베이스를 생성하고 새 데이터베이스를 반환합니다. 구독에 이미 SQL 데이터베이스 서버에 데이터베이스 이름이 지정된 SQL 데이터베이스가 있는 경우 함수는 기존 데이터베이스를 반환합니다. 이 함수는 SQL 데이터베이스를 실제로 만드는 New-AzureSqlDatabase cmdlet(Azure 모듈)을 호출합니다.

.PARAMETER DatabaseConfig
JSON 파일에 웹 사이트 속성이 있을 경우 Read-ConfigFile 함수가 반환하는 JSON 구성 파일에서 발생하는 PSCustomObject를 꺼냅니다. 여기에는 environmentSettings.databases 속성이 포함됩니다. 이 함수에 개체를 파이프할 수 없습니다. Visual Studio는 모든 웹 프로젝트에 대해 JSON 구성 파일을 생성하고 솔루션의 PublishScripts 폴더에 저장합니다.

.INPUTS
없음. 이 함수는 파이프라인에서 입력을 꺼내지 않습니다.

.OUTPUTS
Microsoft.WindowsAzure.Commands.SqlDatabase.Services.Server.Database

.EXAMPLE
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases | where connectionStringName
PS C:\> $DatabaseConfig

connectionStringName    : Default Connection
databasename : TestDB1
edition      :
size         : 1
collation    : SQL_Latin1_General_CP1_CI_AS
servertype   : New SQL Database Server
servername   : r040tvt2gx
user         : dbuser
password     : Test.123
location     : West US

PS C:\> Add-AzureSQLDatabase -DatabaseConfig $DatabaseConfig

.LINK
Add-AzureSQLDatabases

.LINK
New-AzureSQLDatabase
#>
function Add-AzureSQLDatabase
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Object]
        $DatabaseConfig
    )

    Write-VerboseWithTime 'Add-AzureSQLDatabase: 시작'

    # 매개 변수 값에 serverName 속성이 없거나 serverName 속성 값이 채워져 있지 않으면 실패합니다.
    if (-not (Test-Member $DatabaseConfig 'serverName') -or -not $DatabaseConfig.serverName)
    {
        throw 'Add-AzureSQLDatabase: DatabaseConfig 값에 데이터베이스 serverName(필수 사항)이 없습니다.'
    }

    # 매개 변수 값에 databasename 속성이 없거나 databasename 속성 값이 채워져 있지 않으면 실패합니다.
    if (-not (Test-Member $DatabaseConfig 'databaseName') -or -not $DatabaseConfig.databaseName)
    {
        throw 'Add-AzureSQLDatabase: DatabaseConfig 값에 databasename(필수 사항)이 없습니다.'
    }

    $DbServer = $null

    if (Test-HttpsUrl $DatabaseConfig.serverName)
    {
        $absoluteDbServer = $DatabaseConfig.serverName -as [System.Uri]
        $subscription = Get-AzureSubscription -Current -ErrorAction SilentlyContinue

        if ($subscription -and $subscription.ServiceEndpoint -and $subscription.SubscriptionId)
        {
            $absoluteDbServerRegex = 'https:\/\/{0}\/{1}\/services\/sqlservers\/servers\/(.+)\.database\.windows\.net\/databases' -f `
                                     $subscription.serviceEndpoint.Host, $subscription.SubscriptionId

            if ($absoluteDbServer -match $absoluteDbServerRegex -and $Matches.Count -eq 2)
            {
                 $DbServer = $Matches[1]
            }
        }
    }

    if (!$DbServer)
    {
        $DbServer = $DatabaseConfig.serverName
    }

    $db = Get-AzureSqlDatabase -ServerName $DbServer -DatabaseName $DatabaseConfig.databaseName -ErrorAction SilentlyContinue

    if ($db)
    {
        Write-HostWithTime ('Create-AzureSQLDatabase: 기존 데이터베이스 사용 ' + $db.Name)
        $db | Out-String | Write-VerboseWithTime
    }
    else
    {
        $param = New-Object -TypeName Hashtable
        $param.Add('serverName', $DbServer)
        $param.Add('databaseName', $DatabaseConfig.databaseName)

        if ((Test-Member $DatabaseConfig 'size') -and $DatabaseConfig.size)
        {
            $param.Add('MaxSizeGB', $DatabaseConfig.size)
        }
        else
        {
            $param.Add('MaxSizeGB', 1)
        }

        # $DatabaseConfig 개체에 collation 속성이 있고 null 또는 비어 있지 않은 경우
        if ((Test-Member $DatabaseConfig 'collation') -and $DatabaseConfig.collation)
        {
            $param.Add('Collation', $DatabaseConfig.collation)
        }

        # $DatabaseConfig 개체에 edition 속성이 있고 null 또는 비어 있지 않은 경우
        if ((Test-Member $DatabaseConfig 'edition') -and $DatabaseConfig.edition)
        {
            $param.Add('Edition', $DatabaseConfig.edition)
        }

        # Verbose 스트림에 해시 테이블을 쓰세요.
        $param | Out-String | Write-VerboseWithTime
        # 스플래팅으로 New-AzureSqlDatabase를 호출하세요(출력 생략).
        $db = New-AzureSqlDatabase @param
    }

    Write-VerboseWithTime 'Add-AzureSQLDatabase: 끝'
    return $db
}
