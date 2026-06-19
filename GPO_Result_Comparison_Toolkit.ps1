#requires -Version 5.1
[CmdletBinding()]
param([string]$BaselineFile,[string]$ComparisonFile,[string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'GPO_Result_Reports'}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$localHtml=Join-Path $OutputPath "gpresult_$env:COMPUTERNAME`_$stamp.html"
$localText=Join-Path $OutputPath "gpresult_$env:COMPUTERNAME`_$stamp.txt"
try{gpresult.exe /H $localHtml /F|Out-Null}catch{}
try{gpresult.exe /R|Out-File $localText -Encoding UTF8}catch{}
$comparison=@()
if($BaselineFile -and $ComparisonFile -and (Test-Path $BaselineFile) -and (Test-Path $ComparisonFile)){$base=Get-Content $BaselineFile;$current=Get-Content $ComparisonFile;$comparison=Compare-Object $base $current|Select-Object InputObject,SideIndicator;$comparison|Export-Csv (Join-Path $OutputPath "gpo_comparison_$stamp.csv") -NoTypeInformation -Encoding UTF8}
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;Generated=Get-Date;LocalHtmlReport=$localHtml;LocalTextReport=$localText;ComparedFiles=[bool]($BaselineFile -and $ComparisonFile);DifferenceCount=@($comparison).Count}
$summary|ConvertTo-Json|Set-Content (Join-Path $OutputPath "gpo_summary_$stamp.json") -Encoding UTF8
$summary|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
