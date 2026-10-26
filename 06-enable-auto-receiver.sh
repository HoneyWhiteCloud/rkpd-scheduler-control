#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root

info '恢复 BootReceiver：允许未来开机时重新登记周期 RKP 排程。'
pm enable --user 0 "$BOOT_COMPONENT"
info '建议重启，随后运行 04-status-verify.sh 确认 ProvisioningJob 是否被重新创建。'
info '启用 BootReceiver 不会立即重新创建已取消的 Job；通常要等下次 BOOT_COMPLETED。'
