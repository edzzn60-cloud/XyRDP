# ============================================================================ #
# setup-hardware-name.ps1 - Rename tampilan CPU/GPU (cosmetic, bukan spoofing)
# Dipakai di XyRDP: dot-source lib-common.ps1 untuk Log & Set-Reg.
# ============================================================================ #
$XyTag = 'XyRDP:hardware'
. "$PSScriptRoot/lib-common.ps1"

# --- Konfigurasi (bisa dioverride via env dari workflow) ---
$CpuName = if ($env:XY_CPU_NAME) { $env:XY_CPU_NAME } else { 'Intel(R) Core(TM) i9-14900K @ 3.20GHz' }
$GpuName = if ($env:XY_GPU_NAME) { $env:XY_GPU_NAME } else { 'NVIDIA GeForce RTX 4090' }

Log "Rename CPU -> $CpuName"
Log "Rename GPU -> $GpuName"

# ---------- CPU ----------
$cpuBase = 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor'
$cpu0 = "$cpuBase\0"

$oldCpu = (Get-ItemProperty -Path $cpu0 -Name 'ProcessorNameString' -ErrorAction SilentlyContinue).ProcessorNameString
Log "CPU lama: $oldCpu"

# Set core \0
Set-Reg -Path $cpu0 -Name 'ProcessorNameString' -Value $CpuName | Out-Null

# Mirror ke semua core (\0, \1, \2, ...)
Get-ChildItem $cpuBase -ErrorAction SilentlyContinue | ForEach-Object {
    $corePath = "$cpuBase\$($_.PSChildName)"
    Set-Reg -Path $corePath -Name 'ProcessorNameString' -Value $CpuName | Out-Null
}

# ---------- GPU ----------
$displayClassGuid = '{4d36e968-e325-11ce-bfc1-08002be10318}'
$classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$displayClassGuid"

Get-ChildItem $classPath -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^\d{4}$' } |
    ForEach-Object {
        $gpuKey = "$classPath\$($_.PSChildName)"
        $desc = (Get-ItemProperty -Path $gpuKey -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc
        if ($desc) {
            Log "  [$($_.PSChildName)] $desc -> $GpuName"
            Set-Reg -Path $gpuKey -Name 'DriverDesc' -Value $GpuName | Out-Null
        }
    }

# ---------- FriendlyName di Enum PCI (Device Manager / dxdiag) ----------
$enumBase = 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI'
Get-ChildItem $enumBase -ErrorAction SilentlyContinue | ForEach-Object {
    $venKey = $_
    Get-ChildItem $venKey.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
        $devKey = $_
        $friendly = (Get-ItemProperty -Path $devKey.PSPath -Name 'FriendlyName' -ErrorAction SilentlyContinue).FriendlyName
        if ($friendly -and ($friendly -match 'NVIDIA|AMD|Radeon|GeForce|Intel.*Graphics|Microsoft Basic')) {
            $devPath = "$enumBase\$($venKey.PSChildName)\$($devKey.PSChildName)"
            Set-Reg -Path $devPath -Name 'FriendlyName' -Value $GpuName | Out-Null
        }
    }
}

Log 'Selesai. Nama baru muncul di Task Manager setelah refresh / reboot.' -ForegroundColor Green
