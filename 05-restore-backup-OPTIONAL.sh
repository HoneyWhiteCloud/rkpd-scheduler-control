#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root
need_sqlite
ensure_db

if [ "${1:-}" != '--confirm-restore' ]; then
    cat <<'USAGE'
危险操作：完整恢复 WorkManager 备份会覆盖备份之后的 WorkManager 记录。
仅当数据库出现问题或明确需要回退时使用；普通恢复每日排程优先执行 06-enable-auto-receiver.sh。
用法：sudo sh ./05-restore-backup-OPTIONAL.sh --confirm-restore [备份路径]
恢复前必须确保 RKPD 进程没有运行；本脚本不会强制停止系统服务。
USAGE
    exit 2
fi

make_backup_dir
SOURCE="${2:-}"
if [ -z "$SOURCE" ]; then
    MARKER="$BACKUP_DIR/latest.path"
    [ -f "$MARKER" ] || die "没有 $MARKER；请指定备份路径"
    SOURCE="$(cat "$MARKER")"
fi
case "$SOURCE" in "$BACKUP_DIR"/*) : ;; *) die '只允许从本工具的备份目录恢复' ;; esac
sql_backup_verify "$SOURCE"

# For a safety guard, refuse restoration while the app process is detected.
# An Android process can be restarted by system_server at any time; test is not a guarantee.
if command -v pidof >/dev/null 2>&1 && pidof "$PKG" >/dev/null 2>&1; then
    die "检测到 RKPD 进程正在运行。为避免恢复时和 WorkManager 写库冲突，已中止。请在系统维护窗口处理，不要直接删 -wal/-shm。"
fi

# Capture the current state before the rollback, with an independent name.
STAMP="$(date '+%Y%m%d_%H%M%S')"
PRE="$BACKUP_DIR/pre-restore-$STAMP.sqlite"
[ ! -e "$PRE" ] || die "目标文件已存在：$PRE"
info "备份当前状态到 $PRE ..."
run_db "$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$DB" ".backup '$PRE'" || die '恢复前备份失败'
chmod 600 "$PRE"
sql_backup_verify "$PRE"

warn '将通过 SQLite .restore 覆盖当前 WorkManager 数据库（不直接操作 WAL/SHM 文件）。'
run_db "$SQLITE" -init /dev/null -batch -bail -noheader -list "$DB" ".restore '$SOURCE'" || die '恢复失败；请检查恢复前快照'
RESULT="$(run_db "$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$DB" 'PRAGMA integrity_check;' 2>&1)" \
    || die "恢复后无法校验数据库：$RESULT"
[ "$RESULT" = 'ok' ] || die "恢复后完整性检查失败：$RESULT"
info 'SQLite 备份已恢复。请重启后执行 04-status-verify.sh。'
info '如果要恢复自动排程，还必须启用 BootReceiver（06）。'
