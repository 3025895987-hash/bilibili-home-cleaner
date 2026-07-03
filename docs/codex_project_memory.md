# Codex Project Memory

## Bilibili Client Mask Lessons

- Do not classify Bilibili client pages by title alone. The Windows client often keeps a generic Bilibili title across home, search, history, personal pages, and video pages. Combine title/process checks with visual or UI-state probes before showing a mask.
  中文：不要只靠窗口标题判断 B 站客户端页面。客户端在首页、搜索、历史、个人页、视频页经常共用泛标题；显示遮罩前必须结合标题/进程和视觉或 UI 状态探测。

- Never use a fixed rectangle for dynamic Bilibili panels without first identifying the actual content section. Video pages can contain creator info, action buttons, episode lists, playlists, and recommendation lists in different vertical positions. Detect the recommendation thumbnail region before masking it, and leave video episode/playlist sections visible.
  中文：不要对 B 站动态侧栏直接套固定矩形。视频页右侧可能有创作者信息、按钮、视频选集、播放列表和推荐列表，位置会变；必须先识别推荐缩略图区，再遮挡推荐，保留视频选集/播放列表。

- Do not hide the mask periodically just to take screenshots. It creates visible flicker. If screenshot-based probing is needed, probe before showing the mask, cache the result, and refresh only when the target window, title, size, or page state changes.
  中文：不要为了截图识别而周期性隐藏遮罩，这会造成明显闪烁。需要截图探测时，应在遮罩显示前探测并缓存结果，只在窗口、标题、尺寸或页面状态变化时刷新。

- Do not let the overlay become part of its own visual detection loop. If the mask is visible, either reuse a stable cached result or skip probing until the mask has been hidden by normal page-state transitions.
  中文：不要让遮罩参与自己的视觉识别循环。遮罩可见时，要么复用稳定缓存，要么等页面状态正常切换导致遮罩隐藏后再探测。

- Treat user screenshots as regression cases. For every screenshot that reports a wrong mask, run an offline probe against that image when feasible and confirm the detection result before claiming the fix is done.
  中文：用户发来的每张错误截图都要当成回归用例。只要可行，就用截图离线跑探测逻辑，确认识别结果后再说修好了。

- Fullscreen video, search results, personal/history pages, and user-requested content pages must not be masked. Home recommendations and video-page recommendation lists are the intended masking targets.
  中文：视频全屏、搜索结果、个人/历史页，以及用户主动进入的内容页不应遮挡。目标只应是首页推荐流和视频页推荐列表。

- Search detection must have a visual fallback. The Bilibili Windows client may not expose its search box or query text through UI Automation, so an active/focused header search box should also be detected from its central pink focus border before showing any home mask.
  中文：搜索检测必须有视觉兜底。B 站 Windows 客户端不一定通过 UI Automation 暴露搜索框或搜索词；显示首页遮罩前，也要通过顶部中间搜索框的粉色焦点边框识别搜索激活状态。

- Generic Bilibili titles must be protected by a video-page visual check before applying the home mask. If the top chrome/player strip and right tab strip are dark like a video page, route to video-page handling or hide the mask; never apply the large white home mask over the player.
  中文：泛 B 站标题在套首页遮罩前必须先做视频页视觉保护。如果顶部栏/播放器顶边和右侧标签栏呈视频页深色布局，就改走视频页逻辑或隐藏遮罩，绝不能把首页白色大遮罩盖到播放器上。

- Prefer conservative failure behavior: if the tool cannot confidently identify the exact recommendation region, hide the mask instead of covering useful content.
  中文：失败时保守处理：如果无法确信推荐区域位置，宁可不遮挡，也不要盖住用户要看的内容。
