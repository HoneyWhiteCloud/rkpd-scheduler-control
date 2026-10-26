#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root
need_sqlite
ensure_db

printf '\n===== 1. BootReceiver 状态 =====\n'
# Dump may include additional users (e.g. 999); we are targeting user 0 only.
BOOT_LIST="$(dumpsys package "$PKG" | grep -A 6 'disabledComponents:' | head -n 7 || true)"
printf '%s\n' "$BOOT_LIST"
printf '\n===== 2. ProvisioningJob 状态 =====\n'
sql_ro "SELECT n.name, w.worker_class_name, w.state,
 CASE w.state WHEN 0 THEN 'ENQUEUED' WHEN 1 THEN 'RUNNING'
 WHEN 2 THEN 'SUCCEEDED' WHEN 3 THEN 'FAILED'
 WHEN 4 THEN 'BLOCKED' WHEN 5 THEN 'CANCELLED'
 ELSE 'UNKNOWN' END AS state_text,
 w.interval_duration, s.system_id
FROM WorkSpec w JOIN WorkName n ON n.work_spec_id=w.id
LEFT JOIN SystemIdInfo s ON s.work_spec_id=w.id
WHERE n.name='$WORK_NAME';"

printf '\n===== 3. 所有现存 RKPD JobScheduler 任务 =====\n'
JOBS="$(dumpsys jobscheduler | grep -E '^  JOB .*com.google.android.rkpdapp/' || true)"
if [ -n "$JOBS" ]; then printf '%s\n' "$JOBS"; else echo '（无匹配任务）'; fi

printf '\n===== 4. RKP 相关 Binder / HAL =====\n'
service list | grep -iE 'remote_provisioning|IRemotelyProvisionedComponent|IKeyMintDevice' || true

printf '\n===== 结论 =====\n'
STATE="$(work_state)"
if [ "$STATE" = '5' ] && [ -z "$JOBS" ] && printf '%s\n' "$BOOT_LIST" | grep -q 'com.android.rkpdapp.BootReceiver'; then
    echo '当前检查通过：ProvisioningJob 已 CANCELLED，JobScheduler 中没有发现 RKPD 工作。'
    echo '仍需在重启后、使用 RKPConfig Renew 后重新检查；按需 RKP 不在本工具的禁用范围内。'
else
    echo '当前条件尚未全部符合。请核对上方数据；不要据此断言已经永久停用。'
fi
