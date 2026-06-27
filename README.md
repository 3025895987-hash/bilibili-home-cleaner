# B站首页清屏

隐藏 B 站首页推荐流和视频页右侧推荐。

## B 站客户端

解压或克隆本项目后，双击运行本目录下的：

```text
Start-BiliClientMask.bat
```

如果需要开机自启，双击运行：

```text
Install-Startup.bat
```

取消开机自启时，双击运行：

```text
Uninstall-Startup.bat
```

效果：

- B 站客户端首页在前台时，推荐流区域会被白色遮罩盖住。
- 视频播放页在前台时，右侧推荐列表会被深色遮罩盖住；视频选集会保留。
- 视频全屏播放时不会显示遮罩。
- 切到其他软件时，遮罩自动隐藏。
- 点击顶部搜索框、搜索框里有搜索词，或进入搜索结果页时，遮罩自动隐藏。
- “我的”、历史记录、收藏等个人页面不会显示遮罩。
- 托盘图标可以退出。
- `Ctrl+Alt+B`、`Ctrl+Alt+M` 或 `Ctrl+Shift+F12` 可以临时开关遮罩；再按一次就是手动恢复。
- 如果快捷键无效，双击 `Toggle-BiliClientMask.bat` 临时开关；程序没运行时会直接启动。
- 在首页临时关闭遮罩后，进入视频或搜索等页面再回到首页时，遮罩会自动恢复。
- 临时关闭只在当前运行期有效；下次开机默认开启，B 站客户端窗口全部关闭后也会自动恢复为开启。
- 如果遮罩卡住，双击 `Stop-BiliClientMask.bat` 直接退出。

如果遮罩位置和你的客户端窗口不完全贴合，可以改 `Start-BiliClientMask.ps1` 顶部的这几个值：

```powershell
$CoverLeft = 80
$CoverTop = 96
$CoverRight = 0
$CoverBottom = 0
$VideoRecommendMaskWidth = 460
$VideoRecommendProbeStartTop = 300
```

## 网页版

如果改用 Chrome 或 Edge 打开 `https://www.bilibili.com/`：

1. 打开扩展管理页。
2. 开启开发者模式。
3. 选择“加载已解压的扩展程序”。
4. 选择本项目目录。
