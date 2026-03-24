# ROS Bridge Client

Flutter 桌面应用，通过 WebSocket 连接 `rosbridge_websocket` 服务器，支持测试 ROS 的 Topic、Service 和 Action。

## 功能

- **连接管理** — 输入 WebSocket URL（默认 `ws://localhost:9090`）连接/断开，实时显示通信日志
- **Topic 测试** — 订阅/发布任意 Topic，实时查看收到的消息
- **Service 调用** — 调用 ROS Service 并查看响应结果
- **Action 测试** — 发送 Action Goal，实时接收 Feedback，查看最终 Result，支持取消

## 运行

```bash
# 确保 rosbridge_websocket 已启动
# ROS 2:
ros2 launch rosbridge_server rosbridge_websocket_launch.xml

# 运行 Flutter 应用
cd ros_bridge_client
flutter run -d macos
```

## 依赖

- `web_socket_channel` — WebSocket 通信
- `provider` — 状态管理

## 项目结构

```
lib/
├── main.dart                       # 入口，TabBar 布局
├── services/
│   └── rosbridge_service.dart      # rosbridge WebSocket 通信服务
└── screens/
    ├── connection_tab.dart         # 连接设置 + 日志
    ├── topic_tab.dart              # Topic 订阅/发布
    ├── service_tab.dart            # Service 调用
    └── action_tab.dart             # Action Goal/Feedback/Result
```

## 网络权限

macOS 已配置 `com.apple.security.network.client` 和 `com.apple.security.network.server` 沙箱权限，允许 WebSocket 连接。
