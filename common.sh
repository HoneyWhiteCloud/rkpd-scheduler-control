#!/system/bin/sh
# Common helpers for OnePlus 13 / Google RKPD WorkManager scripts.
# Run entry scripts as root: sudo sh ./01-backup-database.sh

PKG='com.google.android.rkpdapp'
BOOT_COMPONENT="${PKG}/com.android.rkpdapp.BootReceiver"
WORK_NAME='ProvisioningJob'
WORKER='com.android.rkpdapp.provisioner.PeriodicProvisioner'
NAMESPACE='androidx.work.systemjobscheduler'
DB="${RKPD_DB:-/data/user/0/com.google.android.rkpdapp/no_backup/androidx.work.workdb}"
BACKUP_DIR="${RKPD_BACKUP_DIR:-/data/adb/rkpd-workmanager-control/backups}"

# Termux's tools may disappear from PATH under some sudo implementations.
PATH="/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin:$PATH"
export PATH

info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

need_root() {
    [ "$(id -u)" = '0' ] || die '请以 Root 运行，例如 sudo sh ./01-backup-database.sh'
}

find_cmd() {
    x="$(command -v "$1" 2>/dev/null || true)"
    [ -n "$x" ] || return 1
    printf '%s\n' "$x"
}

need_sqlite() {
    SQLITE="$(find_cmd sqlite3 || true)"
    [ -n "$SQLITE" ] || die '缺少 sqlite3。Termux 请运行 pkg install sqlite'
    NSENTER="$(find_cmd nsenter || true)"
}

# Android App Data Isolation / root mount namespace may mask the app directory.
# Use the init (PID 1) mount namespace for just the sqlite3 command if needed.
run_db() {
    if [ -f "$DB" ]; then
        "$@"
    elif [ -n "${NSENTER:-}" ]; then
        "$NSENTER" -t 1 -m -- "$@"
    else
        die "当前挂载命名空间看不到数据库：$DB；且没有 nsenter（pkg install util-linux）"
    fi
}

ensure_db() {
    run_db "$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$DB" 'SELECT 1;' >/dev/null \
        || die "无法只读打开数据库：$DB"
}

sql_ro() { run_db "$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$DB" "$1"; }
sql_rw() { run_db "$SQLITE" -init /dev/null -batch -bail -noheader -list "$DB" "$1"; }

sql_backup_verify() {
    file="$1"
    [ -f "$file" ] || die "备份不存在：$file"
    result="$("$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$file" 'PRAGMA integrity_check;' 2>&1)" \
        || die "无法读取备份：$result"
    [ "$result" = 'ok' ] || die "备份完整性检查失败：$result"
}

# A single unique periodic work item is expected. Fail rather than update unexpected rows.
work_count() {
    sql_ro "SELECT COUNT(*) FROM WorkSpec w JOIN WorkName n ON n.work_spec_id=w.id WHERE n.name='$WORK_NAME' AND w.worker_class_name='$WORKER' AND w.interval_duration=86400000;"
}
work_state() {
    sql_ro "SELECT w.state FROM WorkSpec w JOIN WorkName n ON n.work_spec_id=w.id WHERE n.name='$WORK_NAME' AND w.worker_class_name='$WORKER' AND w.interval_duration=86400000;"
}

check_backup_exists() {
    # Require a backup made by 01 before modifying the database.
    marker="$BACKUP_DIR/latest.path"
    [ -f "$marker" ] || die '找不到本工具的备份标记。请先执行 01-backup-database.sh'
    backup="$(cat "$marker")"
    [ -n "$backup" ] || die '备份标记为空'
    case "$backup" in
        "$BACKUP_DIR"/*) : ;;
        *) die '备份标记中的路径不属于备份目录' ;;
    esac
    sql_backup_verify "$backup"
}

make_backup_dir() {
    mkdir -p "$BACKUP_DIR" || die '无法创建备份目录'
    chmod 700 "$BACKUP_DIR" || die '无法设置备份目录权限'
}
