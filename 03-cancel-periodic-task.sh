#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root
need_sqlite
ensure_db
check_backup_exists

COUNT="$(work_count)"
[ "$COUNT" = '1' ] || die "匹配到 $COUNT 项 ProvisioningJob（预期 1 项）；为安全起见，不做修改。"
STATE="$(work_state)"
case "$STATE" in
    5) info 'ProvisioningJob 已为 CANCELLED (5)，跳过数据库更新。' ;;
    0)
        info 'ProvisioningJob 为 ENQUEUED (0)。使用事务将其改为 CANCELLED (5)...'
        # Only the expected periodic job is modified; no DELETE or schema changes.
        CHANGED="$(sql_rw "PRAGMA busy_timeout=5000;
BEGIN IMMEDIATE;
UPDATE WorkSpec SET state=5
 WHERE state=0 AND interval_duration=86400000 AND worker_class_name='$WORKER'
 AND id IN (SELECT work_spec_id FROM WorkName WHERE name='$WORK_NAME');
SELECT changes();
COMMIT;")" || die 'SQLite 修改失败；请检查 DB 和备份。'
        [ "$(printf '%s\n' "$CHANGED" | tail -n 1)" = '1' ] || die "数据库更新行数不为 1：$CHANGED；请核查数据库。"
        info '仅更新了一条目标 WorkSpec。'
        ;;
    *) die "工作状态为 $STATE，不是预期的 ENQUEUED(0) 或 CANCELLED(5)。停止操作。" ;;
esac

# Mapping is discovered from the WorkManager DB; it is not safe to assume the ID will always be 2.
IDS="$(sql_ro "SELECT DISTINCT s.system_id FROM SystemIdInfo s
JOIN WorkSpec w ON s.work_spec_id=w.id
JOIN WorkName n ON n.work_spec_id=w.id
WHERE n.name='$WORK_NAME' AND w.worker_class_name='$WORKER' AND w.interval_duration=86400000;")"
if [ -z "$IDS" ]; then
    warn '数据库中没有该 WorkSpec 的 SystemIdInfo 映射。请用 04-status-verify.sh 查看是否还有 RKPD Job。'
else
    echo "$IDS" | while IFS= read -r JOBID; do
        case "$JOBID" in ''|*[!0-9]*) die "异常 Job ID: $JOBID" ;; esac
        info "取消 JobScheduler namespace=$NAMESPACE / job=$JOBID ..."
        cmd jobscheduler cancel -u 0 -n "$NAMESPACE" "$PKG" "$JOBID" \
            || die "取消 JobScheduler Job $JOBID 失败"
    done
fi
info '操作完成。请执行 04-status-verify.sh，之后重启并再次验证。'
