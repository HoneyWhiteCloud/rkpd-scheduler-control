#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root

info '仅禁用 RKPD 的 BootReceiver（开机登记自动排程的入口）。'
pm disable --user 0 "$BOOT_COMPONENT"
info '不禁用 com.android.rkpdapp.service.RemoteProvisioningService、KeyMint 或 RKP HAL。'
info '这一步不会取消已经存在的 WorkManager 周期任务。'
