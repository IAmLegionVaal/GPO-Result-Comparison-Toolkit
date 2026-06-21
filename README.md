# GPO Result Comparison Toolkit

PowerShell tools for collecting and comparing Group Policy results and applying guarded local policy repairs.

## Compare policy results

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\GPO_Result_Comparison_Toolkit.ps1
```

## Repair

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\GPO_Result_Repair_Toolkit.ps1 -ForceUpdate -Target Both -DryRun
```

Examples:

```powershell
.\GPO_Result_Repair_Toolkit.ps1 -ForceUpdate -Target Computer
.\GPO_Result_Repair_Toolkit.ps1 -RestartNetlogon -ForceUpdate
.\GPO_Result_Repair_Toolkit.ps1 -RepairWmiRepository -ForceUpdate
.\GPO_Result_Repair_Toolkit.ps1 -ResetLocalPolicyCache -ForceUpdate
```

The repair script backs up local policy cache folders before resetting them, captures `gpresult` and policy events before and after repair, and supports `-DryRun`, confirmation, logs and clear exit codes. It does not edit domain GPOs, links or security filtering.

## Author

Dewald Pretorius — L2 IT Support Engineer
