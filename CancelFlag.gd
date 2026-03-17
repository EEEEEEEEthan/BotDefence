extends RefCounted
class_name CancelFlag

## 线程安全的取消标志，供 Bot 子线程读取、BotMain 主线程写入

var aborted := false
