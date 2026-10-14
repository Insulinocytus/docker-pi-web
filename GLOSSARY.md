# docker-pi-web

把 pi-web 和 pi 打包成可一键部署的云端 agent 镜像。

## Language

**实例 (Instance)**:
一个运行中的容器，只服务一个用户，拥有自己的一份 Agent 数据和工作区。要多个用户就起多个实例。
_Avoid_: 租户、多用户部署

**Agent 数据 (Agent Data)**:
pi 与 pi-web 共用的凭据、模型配置、设置和会话记录。
_Avoid_: 配置、用户数据
