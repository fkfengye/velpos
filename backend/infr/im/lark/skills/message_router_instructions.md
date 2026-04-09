# 消息路由指南

本文档描述了 Lark Agent 如何在飞书/Lark 和 Velpos 会话之间路由消息。

## 绑定查询

每个 Lark 会话可能绑定了一个用户会话。查询方式：

```
GET /api/external/lark/binding/{lark_session_id}
```

绑定时的响应：
```json
{
  "code": 0,
  "data": {
    "user_session_id": "abc12345",
    "lark_session_id": "def67890"
  }
}
```

未绑定时的响应：
```json
{
  "code": 0,
  "data": null
}
```

## 消息转发

当收到飞书消息时：

1. 从消息事件中提取文本内容
2. 使用此会话的 ID 查询绑定 API
3. 如果已绑定，转发到用户会话：
   ```
   POST /api/external/lark/sessions/{user_session_id}/message
   Body: {"message": "extracted text"}
   ```
4. 等待会话完成（轮询状态端点）
5. 获取响应消息
6. 通过 lark-cli im 将响应发送回飞书用户

## 错误处理

- 如果用户会话正忙（status="running"），请等待并重试
- 如果转发失败，通知飞书用户错误信息
- 始终要回复——永远不要让飞书消息没有得到回应
