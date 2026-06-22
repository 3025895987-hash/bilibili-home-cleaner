# B站首页清屏

隐藏 B 站首页推荐流，保留搜索和常用入口。

## B 站客户端

解压或克隆本项目后，双击运行本目录下的：

```text
Start-BiliClientMask.bat
```

效果：

- B 站客户端窗口在前台时，推荐流区域会被白色遮罩盖住。
- 切到其他软件时，遮罩自动隐藏。
- 托盘图标可以退出。
- `Ctrl+Alt+B`、`Ctrl+Alt+M` 或 `Ctrl+Shift+F12` 可以临时开关遮罩。
- 如果快捷键无效，双击 `Toggle-BiliClientMask.bat` 临时开关。
- 如果遮罩卡住，双击 `Stop-BiliClientMask.bat` 直接退出。

如果遮罩位置和你的客户端窗口不完全贴合，可以改 `Start-BiliClientMask.ps1` 顶部的这几个值：

```powershell
$CoverLeft = 80
$CoverTop = 96
$CoverRight = 0
$CoverBottom = 0
```

## 网页版

如果改用 Chrome 或 Edge 打开 `https://www.bilibili.com/`：

1. 打开扩展管理页。
2. 开启开发者模式。
3. 选择“加载已解压的扩展程序”。
4. 选择本项目目录。
