RKPD Scheduler Control

Take control of Android Remote Key Provisioning schedules.

RKPD Scheduler Control is a collection of root-based shell scripts designed to manage Android's Remote Key Provisioning Daemon (RKPD) periodic provisioning tasks.

It allows users to disable automatic periodic provisioning, inspect WorkManager job states, back up provisioning scheduler databases, and restore the original scheduling behavior when needed.

Features

- Disable RKPD's periodic provisioning scheduler
- Cancel persistent WorkManager provisioning jobs
- Back up and restore WorkManager SQLite databases
- Verify JobScheduler and WorkManager states
- Preserve TEE and StrongBox KeyMint services
- Keep on-demand remote provisioning available

Requirements

- Rooted Android device
- Android RKPD implementation using WorkManager
- SQLite3 and compatible shell utilities

Disclaimer

This project controls RKPD's periodic scheduling behavior, not the underlying hardware security implementation. It does not guarantee that all automatic or on-demand provisioning requests are disabled.

Directly modifying WorkManager databases is unsupported by Android and may require adjustments across different system versions.
