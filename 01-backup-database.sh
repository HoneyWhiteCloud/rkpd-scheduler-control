#!/system/bin/sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/common.sh"
need_root
need_sqlite
ensure_db
make_backup_dir

STAMP="$(date '+%Y%m%d_%H%M%S')"
DEST="$BACKUP_DIR/workdb-$STAMP.sqlite"
[ ! -e "$DEST" ] || die "备份已经存在：$DEST（请稍后再运行）"

info '使用 SQLite 在线备份 API 创建一致性备份（包括已提交的 WAL 数据）...'
run_db "$SQLITE" -init /dev/null -readonly -batch -bail -noheader -list "$DB" ".backup '$DEST'" \
    || die '数据库备份失败'
chmod 600 "$DEST"
sql_backup_verify "$DEST"
printf '%s\n' "$DEST" > "$BACKUP_DIR/latest.path"
chmod 600 "$BACKUP_DIR/latest.path"
info "备份完成：$DEST"
info '完整性检查：ok'
info '该备份仅包含 WorkManager 数据库，不包含 RKP 凭证池 rkpd_database。'
