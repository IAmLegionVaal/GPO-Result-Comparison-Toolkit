# GPO Result Comparison Toolkit

PowerShell tooling for collecting and comparing Group Policy results and applying guarded local policy repairs.

## Scripts

- `GPO_Result_Comparison_Toolkit.ps1` — read-only GPResult collection and result comparison.
- `GPO_Result_Repair_Toolkit.ps1` — local Group Policy refresh and supporting-component repair.

The repair script does not edit domain GPOs, links, permissions, or security filtering.

## Repair actions

- `-ForceUpdate` — runs `gpupdate /force` for `Computer`, `User`, or `Both`.
- `-RestartNetlogon` — restarts Netlogon and waits for it to run.
- `-RepairWmiRepository` — verifies WMI and runs salvage only when verification reports inconsistency.
- `-ResetLocalPolicyCache` — copies local GroupPolicy folders into the run backup and then removes the active cache before GPUpdate.

Actual repairs require Windows and an elevated PowerShell session.

## Examples

Preview a full refresh:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\GPO_Result_Repair_Toolkit.ps1 `
  -ForceUpdate -Target Both -DryRun
```

Back up and reset local policy caches, then refresh policy:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\GPO_Result_Repair_Toolkit.ps1 `
  -ResetLocalPolicyCache -Target Both -Yes
```

Omit `-Yes` to require typing `YES`.

## Evidence, backup, and verification

Each run creates a timestamped directory under `%ProgramData%\GPOResultRepair` unless `-OutputPath` is supplied. Outputs can include:

- `before.txt` and `after.txt` with GPResult and recent Group Policy events;
- `backup\GroupPolicy` and `backup\GroupPolicyUsers` when those caches are reset;
- WMI verify/salvage output;
- `gpupdate.txt`;
- `repair.log`.

Verification checks requested service state, WMI repository consistency, and GPUpdate evidence. `-DryRun` records planned actions without modifying or verifying the system.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including a successful dry run |
| 2 | Invalid arguments |
| 3 | Unsupported platform or missing Windows commands |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | One or more repair actions failed |
| 30 | Post-repair verification failed |

## Validation status

The scripts were source-reviewed during this update. They were not runtime-tested on a Windows domain endpoint.

## Author

Dewald Pretorius — L2 IT Support Engineer
