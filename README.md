# Google RKPD 每日 WorkManager 排程控制（Android 16 / Root）

针对已确认的：

- Package: `com.google.android.rkpdapp`
- WorkManager unique work: `ProvisioningJob`
- Worker: `com.android.rkpdapp.provisioner.PeriodicProvisioner`
- 周期：86,400,000 ms（24 小时）
- JobScheduler namespace: `androidx.work.systemjobscheduler`
- DB: `/data/user/0/com.google.android.rkpdapp/no_backup/androidx.work.workdb`
- BootReceiver: `com.google.android.rkpdapp/com.android.rkpdapp.BootReceiver`

## 使用前

- 安装 Termux 的 `sqlite3` 与 `nsenter`：`pkg install sqlite util-linux`。
- 具备 KernelSU Root、Termux `sudo` 或 `su`。
- 解压到手机后在该目录运行：`sudo sh ./文件名.sh`。
- 若 Termux 的 Root 无法访问应用私有目录，脚本会尝试 `nsenter -t 1 -m` 切换到 init mount namespace（仅对 SQL 命令）。
- **仅适用于已核实的这套 Google RKPD / WorkManager 结构。** OEM 更新可能改变数据库/Worker/JobScheduler 行为。

## 推荐操作顺序

```sh
sudo sh ./01-backup-database.sh
sudo sh ./02-disable-auto-receiver.sh
sudo sh ./03-cancel-periodic-task.sh
sudo sh ./04-status-verify.sh
# 手动重启设备
sudo sh ./04-status-verify.sh
# 再使用 RKPConfig 手动 Dump / Renew / Dump，然后再次验证
sudo sh ./04-status-verify.sh
```

## 恢复

只需要恢复每日自动排程时，**优先**执行：

```sh
sudo sh ./06-enable-auto-receiver.sh
# 然后重启，并用 04-status-verify.sh 验证
```

正常情况下，不必恢复 SQLite 备份：开机接收器会尝试重新登记 `ProvisioningJob`。若因 RKPD 版本差异未创建，再结合实际情况排查。

### 可选：从工作数据库备份回退

`05-restore-backup-OPTIONAL.sh` 是高风险、非日常操作，只回退 WorkManager 数据库，不回退 RKPD 的证书/密钥数据库。需要 RKPD 进程不在运行；脚本发现进程时会拒绝操作。它会先再备份一份恢复前的状态，之后用 SQLite `.restore` 恢复，不直接删除 `-wal`/`-shm`。

```sh
sudo sh ./05-restore-backup-OPTIONAL.sh --confirm-restore
# 或指定此工具生成的其他备份：
sudo sh ./05-restore-backup-OPTIONAL.sh --confirm-restore /data/adb/rkpd-workmanager-control/backups/workdb-YYYYMMDD_HHMMSS.sqlite
```

**切忌**把一个此前已经处于 `CANCELLED` 状态的备份当作能恢复自动任务的备份；备份只代表创建时的状态。不要手动删除实时使用中的 `-wal` / `-shm`，不要清除 RKPD App Data。

## 重要限制

- `02` 仅停用开机重新安排任务的 `BootReceiver`，**不会停用** `RemoteProvisioningService`、TEE/StrongBox KeyMint 和 RKP HAL。
- `03` 会直接写入 WorkManager 的内部 SQLite 数据库，把**唯一匹配且为 ENQUEUED** 的 `ProvisioningJob` 标记为 `CANCELLED(5)`，并取消其已登记的 JobScheduler 工作。这不是 Android 官方支持的 WorkManager 取消 API，存在不同步及 OTA 后兼容性风险。备份是前提。
- WorkManager 可能在应用、系统更新或其他初始化后重新创建任务，所以应定期复核，而不是依赖一次性验证。
- **按需 RKP 更新没有被关闭**：正常 Keystore Attestation 仍可能触发补充。如果目标是严格禁止所有自动网络佈建，需另行分析，不能仅靠这些脚本。
- RKPConfig 的 Renew、Dump 需单独在 App 中测试。不要因为任务消失就认定设备硬件认证永久有效。
- 不建议无差别停用 `SystemJobService`、`RescheduleReceiver` 或整个 `com.google.android.rkpdapp` 套件。

## 故障排查

- `sqlite3 not found`：Termux `pkg install sqlite`。
- `nsenter not found`：Termux `pkg install util-linux`。
- `No such file or directory`：确认 `Root` namespace 与真实路径，可执行 `sudo nsenter -t 1 -m -- ls -l /data/user/0/com.google.android.rkpdapp/no_backup/`。
- `database is locked`：不要删除 WAL/SHM；确认没有并发佈建/WorkManager 工作后再尝试。
- `state=1`：工作正在执行，不要在这个脚本中强行改状态。
- `matched count != 1`：脚本拒绝修改；可能被系统重新创建或 Android 版本差异，应先查询再决定。

## 参考

- AOSP RemoteProvisioner: https://android.googlesource.com/platform/packages/apps/RemoteProvisioner/
- Android WorkManager: https://developer.android.com/develop/background-work/background-tasks/persistent
- SQLite WAL: https://www.sqlite.org/wal.html
- SQLite backup API: https://www.sqlite.org/backup.html
