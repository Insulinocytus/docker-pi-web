# Agent 以非 root 用户运行，但拥有免密 sudo

容器内以 UID 1000 的 `pi` 用户运行 pi-web，并授予免密 sudo。隔离边界是容器本身而非容器内的用户权限；agent 需要能自行 `sudo apt install` 缺失的工具，而镜像只预装精简工具集。非 root 运行只是为了让 home 目录下的文件属主正常、避免 pi-web 以 root 身份写文件，不是安全措施。

## Considered Options

- **直接用 root**：最简单，但用户文件属主全为 root。
- **非 root 且无 sudo**：容器内最安全，但 agent 无法安装系统包，迫使镜像预装大量工具。
