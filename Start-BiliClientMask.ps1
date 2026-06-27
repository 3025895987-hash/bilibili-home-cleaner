#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:CanUseAutomation = $false
try {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $script:CanUseAutomation = $true
} catch {
  $script:CanUseAutomation = $false
}

$createdNew = $false
$script:SingleInstanceMutex = [System.Threading.Mutex]::new($true, "Local\BiliClientMask", [ref]$createdNew)
if (-not $createdNew) {
  return
}

$ToggleEventName = "Local\BiliClientMaskToggle"
$script:ToggleEvent = [System.Threading.EventWaitHandle]::new(
  $false,
  [System.Threading.EventResetMode]::AutoReset,
  $ToggleEventName
)

$CoverLeft = 80
$CoverTop = 96
$CoverRight = 0
$CoverBottom = 0
$MinCoverWidth = 240
$MinCoverHeight = 160
$VideoRecommendMaskWidth = 460
$VideoRecommendMaskTop = 640
$VideoRecommendMaskRight = 0
$VideoRecommendMaskBottom = 0
$MinVideoRecommendMaskWidth = 260
$MinVideoRecommendMaskHeight = 140
$VideoRecommendProbeStartTop = 300
$VideoRecommendProbeBottomMargin = 160
$VideoRecommendProbeIntervalMilliseconds = 800
$LeftNavProbeIntervalMilliseconds = 500
$HomeMaskColor = [System.Drawing.Color]::White
$VideoRecommendMaskColor = [System.Drawing.Color]::FromArgb(22, 23, 25)
$SearchStateHoldMilliseconds = 2000
$LogFile = Join-Path $PSScriptRoot "BiliClientMask.log"

$ExcludedTitleProcesses = @(
  "chrome",
  "msedge",
  "firefox",
  "brave",
  "opera",
  "vivaldi"
)

$BilibiliCn = -join ([char[]]@(0x54D4, 0x54E9, 0x54D4, 0x54E9))
$BStationCn = "B" + ([char]0x7AD9)
$HomeCn = -join ([char[]]@(0x9996, 0x9875))
$RecommendCn = -join ([char[]]@(0x63A8, 0x8350))
$LiveCn = -join ([char[]]@(0x76F4, 0x64AD))
$HotCn = -join ([char[]]@(0x70ED, 0x95E8))
$BangumiCn = -join ([char[]]@(0x8FFD, 0x756A))
$FilmCn = -join ([char[]]@(0x5F71, 0x89C6))
$FeaturedCn = -join ([char[]]@(0x7CBE, 0x9009))
$DynamicCn = -join ([char[]]@(0x52A8, 0x6001))
$MyCn = -join ([char[]]@(0x6211, 0x7684))
$SearchCn = -join ([char[]]@(0x641C, 0x7D22))
$SearchInterestVideoCn = -join ([char[]]@(0x641C, 0x7D22, 0x4F60, 0x611F, 0x5174, 0x8DA3, 0x7684, 0x89C6, 0x9891))
$SearchVideoBangumiFilmCn = -join ([char[]]@(0x641C, 0x7D22, 0x89C6, 0x9891, 0x3001, 0x756A, 0x5267, 0x3001, 0x5F71, 0x89C6, 0x3001, 0x76F4, 0x64AD, 0x3001, 0x4E13, 0x680F, 0x3001, 0x8BDD, 0x9898))
$SearchPlaceholders = @(
  $SearchCn,
  $SearchInterestVideoCn,
  $SearchVideoBangumiFilmCn
)
$SearchIgnoredTexts = @(
  "bilibili",
  $BilibiliCn,
  $BStationCn,
  $HomeCn,
  $RecommendCn,
  $LiveCn,
  $HotCn,
  $BangumiCn,
  $FilmCn,
  $FeaturedCn,
  $DynamicCn,
  $MyCn
) + $SearchPlaceholders
if (-not ("BiliMask.Win32" -as [type])) {
  Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace BiliMask {
  public static class Win32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
      public int Left;
      public int Top;
      public int Right;
      public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const int WM_HOTKEY = 0x0312;
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
  }

  public class NoActivateMaskForm : Form {
    protected override bool ShowWithoutActivation {
      get { return true; }
    }

    protected override CreateParams CreateParams {
      get {
        CreateParams cp = base.CreateParams;
        cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
        cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW
        return cp;
      }
    }
  }

  public class HotkeyForm : Form {
    public event EventHandler HotkeyPressed;

    protected override bool ShowWithoutActivation {
      get { return true; }
    }

    protected override CreateParams CreateParams {
      get {
        CreateParams cp = base.CreateParams;
        cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
        cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW
        return cp;
      }
    }

    protected override void WndProc(ref Message m) {
      if (m.Msg == Win32.WM_HOTKEY && HotkeyPressed != null) {
        HotkeyPressed(this, EventArgs.Empty);
      }
      base.WndProc(ref m);
    }
  }
}
'@
}

[void][BiliMask.Win32]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Enabled = $true
$script:LastTargetHandle = [IntPtr]::Zero
$script:RegisteredHotkeys = @()
$script:LastSearchProbeHandle = [IntPtr]::Zero
$script:LastSearchProbeAt = [datetime]::MinValue
$script:LastSearchActive = $false
$script:LastSearchActiveConfirmedAt = [datetime]::MinValue
$script:LastBilibiliWindowProbeAt = [datetime]::MinValue
$script:LastBilibiliWindowExists = $false
$script:BilibiliWindowProbeFound = $false
$script:RestoreHomeMaskAfterLeavingHome = $false
$script:LeftHomeWhileMaskDisabled = $false
$script:LastVideoRecommendProbeKey = ""
$script:LastVideoRecommendProbeAt = [datetime]::MinValue
$script:LastVideoRecommendMaskTop = $null
$script:LastLeftNavProbeKey = ""
$script:LastLeftNavProbeAt = [datetime]::MinValue
$script:LastNonHomeLeftNavSelected = $false

function Get-WindowTitle {
  param([IntPtr]$Handle)

  $length = [BiliMask.Win32]::GetWindowTextLength($Handle)
  if ($length -le 0) {
    return ""
  }

  $builder = [System.Text.StringBuilder]::new($length + 1)
  [void][BiliMask.Win32]::GetWindowText($Handle, $builder, $builder.Capacity)
  return $builder.ToString()
}

function Get-WindowProcessName {
  param([IntPtr]$Handle)

  $processId = 0
  [void][BiliMask.Win32]::GetWindowThreadProcessId($Handle, [ref]$processId)
  if ($processId -le 0) {
    return ""
  }

  try {
    return ([System.Diagnostics.Process]::GetProcessById([int]$processId)).ProcessName
  } catch {
    return ""
  }
}

function Get-WindowBounds {
  param([IntPtr]$Handle)

  $rect = [BiliMask.Win32+RECT]::new()
  $dwmResult = [BiliMask.Win32]::DwmGetWindowAttribute(
    $Handle,
    [BiliMask.Win32]::DWMWA_EXTENDED_FRAME_BOUNDS,
    [ref]$rect,
    [System.Runtime.InteropServices.Marshal]::SizeOf($rect)
  )

  if ($dwmResult -ne 0) {
    [void][BiliMask.Win32]::GetWindowRect($Handle, [ref]$rect)
  }

  return [System.Drawing.Rectangle]::FromLTRB($rect.Left, $rect.Top, $rect.Right, $rect.Bottom)
}

function Test-FullscreenWindow {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$Bounds
  )

  $screenBounds = [System.Windows.Forms.Screen]::FromHandle($Handle).Bounds
  $tolerance = 4

  return (
    $Bounds.Left -le ($screenBounds.Left + $tolerance) -and
    $Bounds.Top -le ($screenBounds.Top + $tolerance) -and
    $Bounds.Right -ge ($screenBounds.Right - $tolerance) -and
    $Bounds.Bottom -ge ($screenBounds.Bottom - $tolerance)
  )
}

function Test-BilibiliPinkPixel {
  param([System.Drawing.Color]$Color)

  return (
    $Color.R -ge 220 -and
    $Color.G -ge 60 -and
    $Color.G -le 150 -and
    $Color.B -ge 100 -and
    $Color.B -le 200
  )
}

function Test-NonHomeLeftNavSelected {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$Bounds
  )

  $now = [datetime]::UtcNow
  $probeKey = "{0}:{1}:{2}:{3}:{4}" -f $Handle, $Bounds.Left, $Bounds.Top, $Bounds.Width, $Bounds.Height
  if ($probeKey -eq $script:LastLeftNavProbeKey -and (($now - $script:LastLeftNavProbeAt).TotalMilliseconds -lt $LeftNavProbeIntervalMilliseconds)) {
    return $script:LastNonHomeLeftNavSelected
  }

  $script:LastLeftNavProbeKey = $probeKey
  $script:LastLeftNavProbeAt = $now
  $script:LastNonHomeLeftNavSelected = $false

  $captureWidth = [Math]::Min(110, $Bounds.Width)
  $captureHeight = [Math]::Min(620, $Bounds.Height)
  if ($captureWidth -le 0 -or $captureHeight -le 0) {
    return $false
  }

  $bitmap = $null
  $graphics = $null
  try {
    $bitmap = [System.Drawing.Bitmap]::new($captureWidth, $captureHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($Bounds.Left, $Bounds.Top, 0, 0, $bitmap.Size)

    $pinkCount = 0
    $sumY = 0
    for ($y = 60; $y -lt $captureHeight; $y += 3) {
      for ($x = 0; $x -lt $captureWidth; $x += 3) {
        $color = $bitmap.GetPixel($x, $y)
        if (Test-BilibiliPinkPixel -Color $color) {
          $pinkCount++
          $sumY += $y
        }
      }
    }

    if ($pinkCount -lt 12) {
      return $false
    }

    $centerY = $Bounds.Top + ($sumY / $pinkCount)
    $script:LastNonHomeLeftNavSelected = ($centerY -gt ($Bounds.Top + 250))
    return $script:LastNonHomeLeftNavSelected
  } catch {
    $script:LastNonHomeLeftNavSelected = $false
    return $false
  } finally {
    if ($null -ne $graphics) {
      $graphics.Dispose()
    }
    if ($null -ne $bitmap) {
      $bitmap.Dispose()
    }
  }
}

function Test-ImageLikeRecommendationBlock {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [int]$Top,
    [int]$SampleLeft,
    [int]$SampleWidth
  )

  $sampleHeight = 88
  $hitCount = 0
  $totalCount = 0
  $rowsWithHits = 0
  $colsWithHits = @{}
  $maxX = [Math]::Min($Bitmap.Width - 1, $SampleLeft + $SampleWidth)
  $maxY = [Math]::Min($Bitmap.Height - 1, $Top + $sampleHeight)

  for ($y = $Top; $y -lt $maxY; $y += 4) {
    $rowHits = 0
    for ($x = $SampleLeft; $x -lt $maxX; $x += 4) {
      $totalCount++
      $color = $Bitmap.GetPixel($x, $y)
      $brightness = ($color.R + $color.G + $color.B) / 3
      if ($brightness -gt 58 -and -not ($color.R -lt 45 -and $color.G -lt 45 -and $color.B -lt 50)) {
        $hitCount++
        $rowHits++
        $colsWithHits[[int](($x - $SampleLeft) / 8)] = $true
      }
    }
    if ($rowHits -gt 1) {
      $rowsWithHits++
    }
  }

  return (
    $totalCount -gt 0 -and
    ($hitCount / $totalCount) -gt 0.20 -and
    $rowsWithHits -ge 10 -and
    $colsWithHits.Count -ge 8
  )
}

function Get-VideoRecommendMaskRectangle {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$Bounds,
    [string]$Title = ""
  )

  $width = [Math]::Min($VideoRecommendMaskWidth, $Bounds.Width - $VideoRecommendMaskRight)
  if ($width -lt $MinVideoRecommendMaskWidth) {
    return $null
  }

  $x = $Bounds.Right - $VideoRecommendMaskRight - $width
  $probeTop = $Bounds.Top + $VideoRecommendProbeStartTop
  $probeHeight = $Bounds.Height - $VideoRecommendProbeStartTop - $VideoRecommendProbeBottomMargin
  if ($probeHeight -lt 160) {
    return $null
  }

  $now = [datetime]::UtcNow
  $probeKey = "{0}:{1}:{2}:{3}:{4}:{5}" -f $Handle, $Bounds.Left, $Bounds.Top, $Bounds.Width, $Bounds.Height, $Title
  if ($probeKey -eq $script:LastVideoRecommendProbeKey -and $null -ne $script:LastVideoRecommendMaskTop) {
    $cachedHeight = $Bounds.Bottom - $script:LastVideoRecommendMaskTop - $VideoRecommendMaskBottom
    if ($cachedHeight -lt $MinVideoRecommendMaskHeight) {
      return $null
    }
    return [System.Drawing.Rectangle]::new($x, $script:LastVideoRecommendMaskTop, $width, $cachedHeight)
  }

  if ($probeKey -eq $script:LastVideoRecommendProbeKey -and (($now - $script:LastVideoRecommendProbeAt).TotalMilliseconds -lt $VideoRecommendProbeIntervalMilliseconds)) {
    return $null
  }

  if ($null -ne $mask -and $mask.Visible) {
    $script:LastVideoRecommendProbeKey = $probeKey
    $script:LastVideoRecommendProbeAt = [datetime]::MinValue
    $script:LastVideoRecommendMaskTop = $null
    return $null
  }

  $script:LastVideoRecommendProbeKey = $probeKey
  $script:LastVideoRecommendProbeAt = $now
  $script:LastVideoRecommendMaskTop = $null

  $bitmap = $null
  $graphics = $null
  try {
    $bitmap = [System.Drawing.Bitmap]::new($width, $probeHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($x, $probeTop, 0, 0, $bitmap.Size)

    $sampleLeft = 18
    $sampleWidth = [Math]::Min(190, $width - $sampleLeft - 30)
    if ($sampleWidth -lt 80) {
      return $null
    }

    for ($y = 0; $y -lt ($probeHeight - 80); $y += 8) {
      if (Test-ImageLikeRecommendationBlock -Bitmap $bitmap -Top $y -SampleLeft $sampleLeft -SampleWidth $sampleWidth) {
        $maskTop = $probeTop + [Math]::Max(0, $y - 8)
        $height = $Bounds.Bottom - $maskTop - $VideoRecommendMaskBottom
        if ($height -lt $MinVideoRecommendMaskHeight) {
          return $null
        }

        $script:LastVideoRecommendMaskTop = $maskTop
        return [System.Drawing.Rectangle]::new($x, $maskTop, $width, $height)
      }
    }

    return $null
  } catch {
    $script:LastVideoRecommendMaskTop = $null
    return $null
  } finally {
    if ($null -ne $graphics) {
      $graphics.Dispose()
    }
    if ($null -ne $bitmap) {
      $bitmap.Dispose()
    }
  }
}

function Test-BilibiliAppWindow {
  param(
    [string]$Title,
    [string]$ProcessName
  )

  if ([string]::IsNullOrWhiteSpace($Title) -and [string]::IsNullOrWhiteSpace($ProcessName)) {
    return $false
  }

  $process = $ProcessName.ToLowerInvariant()
  $titleText = $Title.ToLowerInvariant()

  if (($process -match "bili") -or $ProcessName.Contains($BilibiliCn)) {
    return $true
  }

  $titleMatches = ($titleText -match "bilibili") -or $Title.Contains($BilibiliCn) -or $Title.Contains($BStationCn)
  if ($titleMatches -and ($ExcludedTitleProcesses -notcontains $process)) {
    return $true
  }

  return $false
}

function Test-BilibiliWindowExists {
  $script:BilibiliWindowProbeFound = $false

  $callback = [BiliMask.Win32+EnumWindowsProc]{
    param([IntPtr]$Handle, [IntPtr]$LParam)

    if (-not [BiliMask.Win32]::IsWindowVisible($Handle)) {
      return $true
    }

    $title = Get-WindowTitle -Handle $Handle
    $processName = Get-WindowProcessName -Handle $Handle

    if (Test-BilibiliAppWindow -Title $title -ProcessName $processName) {
      $script:BilibiliWindowProbeFound = $true
      return $false
    }

    return $true
  }

  [void][BiliMask.Win32]::EnumWindows($callback, [IntPtr]::Zero)
  return $script:BilibiliWindowProbeFound
}

function Test-BilibiliWindowExistsCached {
  param([int]$CacheMilliseconds = 500)

  $now = [datetime]::UtcNow
  if (($now - $script:LastBilibiliWindowProbeAt).TotalMilliseconds -lt $CacheMilliseconds) {
    return $script:LastBilibiliWindowExists
  }

  $script:LastBilibiliWindowProbeAt = $now
  $script:LastBilibiliWindowExists = Test-BilibiliWindowExists
  return $script:LastBilibiliWindowExists
}

function Set-BilibiliWindowExistsCache {
  param([bool]$Exists)

  $script:LastBilibiliWindowExists = $Exists
  $script:LastBilibiliWindowProbeAt = [datetime]::UtcNow
}

function Write-MaskLog {
  param([string]$Message)

  try {
    $line = "{0:yyyy-MM-dd HH:mm:ss.fff} {1}" -f [datetime]::Now, $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  } catch {
  }
}

function Test-BilibiliHomeTitle {
  param([string]$Title)

  $trimmed = $Title.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmed)) {
    return $false
  }

  $lowerTitle = $trimmed.ToLowerInvariant()

  $allowedShortTitles = @(
    "bilibili",
    $BilibiliCn,
    $BStationCn,
    $HomeCn,
    $RecommendCn
  )

  if ($allowedShortTitles -contains $trimmed -or $allowedShortTitles -contains $lowerTitle) {
    return $true
  }

  if ($trimmed.Length -gt 40) {
    return $false
  }

  $mainViewHints = @(
    "bilibili",
    $BilibiliCn,
    $BStationCn,
    $HomeCn,
    $RecommendCn,
    $LiveCn,
    $HotCn,
    $BangumiCn,
    $FilmCn
  )

  foreach ($hint in $mainViewHints) {
    if ($trimmed.Contains($hint) -or $lowerTitle.Contains($hint)) {
      return $true
    }
  }

  return $false
}

function Test-BilibiliVideoTitle {
  param([string]$Title)

  $trimmed = $Title.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmed)) {
    return $false
  }

  if (Test-BilibiliHomeTitle -Title $trimmed) {
    return $false
  }

  if ($trimmed.Contains($SearchCn)) {
    return $false
  }

  return $true
}

function Get-AutomationElementText {
  param($Element)

  $value = ""

  try {
    $pattern = $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    if ($null -ne $pattern) {
      $value = $pattern.Current.Value
    }
  } catch {
    $value = ""
  }

  if ([string]::IsNullOrWhiteSpace($value)) {
    try {
      $value = $Element.Current.Name
    } catch {
      $value = ""
    }
  }

  return $value
}

function Test-MeaningfulSearchText {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $false
  }

  $trimmed = $Text.Trim()
  if ($SearchIgnoredTexts -contains $trimmed) {
    return $false
  }

  return $true
}

function Test-HeaderEditElement {
  param(
    $Element,
    [System.Drawing.Rectangle]$WindowBounds
  )

  try {
    $rect = $Element.Current.BoundingRectangle
  } catch {
    return $false
  }

  if ($rect.IsEmpty) {
    return $false
  }

  $minTop = $WindowBounds.Top - 8
  $maxTop = $WindowBounds.Top + 140
  $minHeight = 16

  return ($rect.Top -ge $minTop -and $rect.Top -le $maxTop -and $rect.Height -ge $minHeight)
}

function Test-HeaderSearchElement {
  param(
    $Element,
    [System.Drawing.Rectangle]$WindowBounds
  )

  try {
    $rect = $Element.Current.BoundingRectangle
  } catch {
    return $false
  }

  if ($rect.IsEmpty) {
    return $false
  }

  if ($rect.Width -lt 16 -or $rect.Width -gt 700 -or $rect.Height -lt 10 -or $rect.Height -gt 90) {
    return $false
  }

  try {
    $controlTypeName = $Element.Current.ControlType.ProgrammaticName
    if ($controlTypeName -in @(
      "ControlType.Pane",
      "ControlType.Window",
      "ControlType.Document",
      "ControlType.Group"
    )) {
      return $false
    }
  } catch {
    return $false
  }

  $minTop = $WindowBounds.Top - 8
  $maxTop = $WindowBounds.Top + 140
  $minCenterX = $WindowBounds.Left + [int]($WindowBounds.Width * 0.40)
  $maxCenterX = $WindowBounds.Left + [int]($WindowBounds.Width * 0.90)
  $centerX = $rect.Left + ($rect.Width / 2)

  return (
    $rect.Top -ge $minTop -and
    $rect.Top -le $maxTop -and
    $centerX -ge $minCenterX -and
    $centerX -le $maxCenterX
  )
}
function Test-BilibiliSearchActive {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$WindowBounds
  )

  if (-not $script:CanUseAutomation) {
    return $false
  }

  $now = [datetime]::UtcNow
  if ($Handle -eq $script:LastSearchProbeHandle -and (($now - $script:LastSearchProbeAt).TotalMilliseconds -lt 350)) {
    return $script:LastSearchActive
  }

  $script:LastSearchProbeHandle = $Handle
  $script:LastSearchProbeAt = $now
  $script:LastSearchActive = $false

  try {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    if ($null -eq $root) {
      return $false
    }

    $condition = [System.Windows.Automation.PropertyCondition]::new(
      [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
      [System.Windows.Automation.ControlType]::Edit
    )
    $edits = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)

    for ($i = 0; $i -lt $edits.Count; $i++) {
      $edit = $edits.Item($i)
      if (-not (Test-HeaderEditElement -Element $edit -WindowBounds $WindowBounds)) {
        continue
      }

      try {
        if ($edit.Current.HasKeyboardFocus) {
          $script:LastSearchActive = $true
          $script:LastSearchActiveConfirmedAt = $now
          return $true
        }
      } catch {
      }

      $searchText = Get-AutomationElementText -Element $edit
      if (Test-MeaningfulSearchText -Text $searchText) {
        $script:LastSearchActive = $true
        $script:LastSearchActiveConfirmedAt = $now
        return $true
      }
    }

    $elements = $root.FindAll(
      [System.Windows.Automation.TreeScope]::Descendants,
      [System.Windows.Automation.Condition]::TrueCondition
    )

    for ($i = 0; $i -lt $elements.Count; $i++) {
      $element = $elements.Item($i)
      if (-not (Test-HeaderSearchElement -Element $element -WindowBounds $WindowBounds)) {
        continue
      }

      $headerText = Get-AutomationElementText -Element $element
      if (Test-MeaningfulSearchText -Text $headerText) {
        $script:LastSearchActive = $true
        $script:LastSearchActiveConfirmedAt = $now
        return $true
      }
    }
  } catch {
    $script:LastSearchActive = $false
  }

  if (($now - $script:LastSearchActiveConfirmedAt).TotalMilliseconds -lt $SearchStateHoldMilliseconds) {
    $script:LastSearchActive = $true
    return $true
  }

  return $script:LastSearchActive
}
function Get-ForegroundBilibiliWindow {
  $foreground = [BiliMask.Win32]::GetForegroundWindow()
  if ($foreground -eq [IntPtr]::Zero) {
    return $null
  }

  $title = Get-WindowTitle -Handle $foreground
  $processName = Get-WindowProcessName -Handle $foreground

  if (-not (Test-BilibiliAppWindow -Title $title -ProcessName $processName)) {
    return $null
  }

  return [pscustomobject]@{
    Handle = $foreground
    Title = $title
    ProcessName = $processName
  }
}

function Get-TargetWindow {
  param($Window = $null)

  if ($null -eq $Window) {
    $Window = Get-ForegroundBilibiliWindow
  }

  if ($null -eq $Window) {
    return $null
  }

  $mode = $null
  if (Test-BilibiliHomeTitle -Title $Window.Title) {
    $mode = "Home"
  } elseif (Test-BilibiliVideoTitle -Title $Window.Title) {
    $mode = "Video"
  }

  if ($null -ne $mode) {
    return [pscustomobject]@{
      Handle = $Window.Handle
      Title = $Window.Title
      ProcessName = $Window.ProcessName
      Mode = $mode
    }
  }

  return $null
}

function Set-MaskVisible {
  param(
    [BiliMask.NoActivateMaskForm]$Mask,
    [bool]$Visible
  )

  if ($Visible -and -not $Mask.Visible) {
    $Mask.Show()
    return
  }

  if (-not $Visible -and $Mask.Visible) {
    $Mask.Hide()
  }
}

function Update-MenuState {
  if ($null -ne $toggleItem) {
    $toggleItem.Checked = $script:Enabled
    $toggleItem.Text = if ($script:Enabled) { "Recommendation mask: on" } else { "Recommendation mask: off" }
  }
}

function Set-EnabledState {
  param([bool]$Enabled)

  if ($script:Enabled -eq $Enabled) {
    return
  }

  $script:Enabled = $Enabled
  if ($Enabled) {
    $script:RestoreHomeMaskAfterLeavingHome = $false
    $script:LeftHomeWhileMaskDisabled = $false
  }
  Update-MenuState
}

function Sync-ControlRequests {
  if ($null -eq $script:ToggleEvent) {
    return
  }

  while ($script:ToggleEvent.WaitOne(0)) {
    Toggle-Enabled
  }
}

function Reset-EnabledStateWhenBilibiliClosed {
  if ($script:Enabled) {
    return
  }

  if (-not (Test-BilibiliWindowExistsCached)) {
    Set-EnabledState -Enabled $true
  }
}

function Update-DisabledHomeRestoreState {
  param(
    $ForegroundBilibiliWindow,
    $Target
  )

  if ($script:Enabled -or -not $script:RestoreHomeMaskAfterLeavingHome) {
    return
  }

  if ($null -eq $ForegroundBilibiliWindow) {
    return
  }

  if ($null -eq $Target -or $Target.Mode -ne "Home") {
    $script:LeftHomeWhileMaskDisabled = $true
    return
  }

  if ($script:LeftHomeWhileMaskDisabled) {
    Set-EnabledState -Enabled $true
  }
}

function Show-MaskBounds {
  param(
    [BiliMask.NoActivateMaskForm]$Mask,
    [System.Drawing.Color]$BackColor,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height
  )

  $Mask.BackColor = $BackColor
  Set-MaskVisible -Mask $Mask -Visible $true
  [void][BiliMask.Win32]::SetWindowPos(
    $Mask.Handle,
    [BiliMask.Win32]::HWND_TOPMOST,
    $X,
    $Y,
    $Width,
    $Height,
    [BiliMask.Win32]::SWP_NOACTIVATE -bor [BiliMask.Win32]::SWP_SHOWWINDOW
  )
}

function Update-HomeFeedMask {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$Bounds
  )

  if (Test-BilibiliSearchActive -Handle $Handle -WindowBounds $Bounds) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  $width = $Bounds.Width - $CoverLeft - $CoverRight
  $height = $Bounds.Height - $CoverTop - $CoverBottom

  if ($width -lt $MinCoverWidth -or $height -lt $MinCoverHeight) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  Show-MaskBounds `
    -Mask $mask `
    -BackColor $HomeMaskColor `
    -X ($Bounds.Left + $CoverLeft) `
    -Y ($Bounds.Top + $CoverTop) `
    -Width $width `
    -Height $height
}

function Update-VideoRecommendMask {
  param(
    [IntPtr]$Handle,
    [System.Drawing.Rectangle]$Bounds,
    [string]$Title = ""
  )

  $maskBounds = Get-VideoRecommendMaskRectangle -Handle $Handle -Bounds $Bounds -Title $Title
  if ($null -eq $maskBounds) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  Show-MaskBounds `
    -Mask $mask `
    -BackColor $VideoRecommendMaskColor `
    -X $maskBounds.X `
    -Y $maskBounds.Y `
    -Width $maskBounds.Width `
    -Height $maskBounds.Height
}

function Update-Mask {
  Sync-ControlRequests
  Reset-EnabledStateWhenBilibiliClosed

  $foregroundBilibiliWindow = Get-ForegroundBilibiliWindow
  $target = Get-TargetWindow -Window $foregroundBilibiliWindow
  Update-DisabledHomeRestoreState -ForegroundBilibiliWindow $foregroundBilibiliWindow -Target $target

  if (-not $script:Enabled) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  if ($null -eq $target) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  Set-BilibiliWindowExistsCache -Exists $true

  $bounds = Get-WindowBounds -Handle $target.Handle

  if (Test-FullscreenWindow -Handle $target.Handle -Bounds $bounds) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  if (Test-BilibiliSearchActive -Handle $target.Handle -WindowBounds $bounds) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  if ($target.Mode -eq "Home" -and (Test-NonHomeLeftNavSelected -Handle $target.Handle -Bounds $bounds)) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  if ($target.Mode -eq "Home") {
    Update-HomeFeedMask -Handle $target.Handle -Bounds $bounds
  } elseif ($target.Mode -eq "Video") {
    Update-VideoRecommendMask -Handle $target.Handle -Bounds $bounds -Title $target.Title
  } else {
    Set-MaskVisible -Mask $mask -Visible $false
  }

  $script:LastTargetHandle = $target.Handle
}

function Toggle-Enabled {
  if ($script:Enabled) {
    $target = Get-TargetWindow
    $script:RestoreHomeMaskAfterLeavingHome = ($null -ne $target -and $target.Mode -eq "Home")
    $script:LeftHomeWhileMaskDisabled = $false
    Set-EnabledState -Enabled $false
    return
  }

  Set-EnabledState -Enabled $true
}

$mask = [BiliMask.NoActivateMaskForm]::new()
$mask.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$mask.ShowInTaskbar = $false
$mask.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$mask.BackColor = $HomeMaskColor
$mask.TopMost = $true
$mask.Bounds = [System.Drawing.Rectangle]::new(-32000, -32000, 1, 1)

$controller = [BiliMask.HotkeyForm]::new()
$controller.ShowInTaskbar = $false
$controller.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$controller.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$controller.Location = [System.Drawing.Point]::new(-32000, -32000)
$controller.Size = [System.Drawing.Size]::new(1, 1)
$controller.Opacity = 0
$controller.add_HotkeyPressed({ Toggle-Enabled })
$controller.Show()

$hotkeyDefinitions = @(
  [pscustomobject]@{
    Id = 1
    Text = "Ctrl+Alt+B"
    Modifiers = [BiliMask.Win32]::MOD_CONTROL -bor [BiliMask.Win32]::MOD_ALT
    Key = [uint32][System.Windows.Forms.Keys]::B
  },
  [pscustomobject]@{
    Id = 2
    Text = "Ctrl+Alt+M"
    Modifiers = [BiliMask.Win32]::MOD_CONTROL -bor [BiliMask.Win32]::MOD_ALT
    Key = [uint32][System.Windows.Forms.Keys]::M
  },
  [pscustomobject]@{
    Id = 3
    Text = "Ctrl+Shift+F12"
    Modifiers = [BiliMask.Win32]::MOD_CONTROL -bor [BiliMask.Win32]::MOD_SHIFT
    Key = [uint32][System.Windows.Forms.Keys]::F12
  }
)

foreach ($hotkey in $hotkeyDefinitions) {
  $registered = [BiliMask.Win32]::RegisterHotKey(
    $controller.Handle,
    $hotkey.Id,
    $hotkey.Modifiers,
    $hotkey.Key
  )

  if ($registered) {
    $script:RegisteredHotkeys += $hotkey
  }
}

$menu = [System.Windows.Forms.ContextMenuStrip]::new()
$toggleItem = [System.Windows.Forms.ToolStripMenuItem]::new("Recommendation mask: on")
$toggleItem.add_Click({ Toggle-Enabled })
[void]$menu.Items.Add($toggleItem)

$hintText = if ($script:RegisteredHotkeys.Count -gt 0) {
  "Hotkeys: " + (($script:RegisteredHotkeys | Select-Object -ExpandProperty Text) -join " / ")
} else {
  "Use Toggle-BiliClientMask.bat"
}
$hintItem = [System.Windows.Forms.ToolStripMenuItem]::new($hintText)
$hintItem.Enabled = $false
[void]$menu.Items.Add($hintItem)

[void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

$exitItem = [System.Windows.Forms.ToolStripMenuItem]::new("Exit")
$exitItem.add_Click({
  $timer.Stop()
  foreach ($hotkey in $script:RegisteredHotkeys) {
    [void][BiliMask.Win32]::UnregisterHotKey($controller.Handle, $hotkey.Id)
  }
  if ($null -ne $script:ToggleEvent) {
    $script:ToggleEvent.Dispose()
  }
  $notify.Visible = $false
  $notify.Dispose()
  $mask.Close()
  $controller.Close()
  [System.Windows.Forms.Application]::Exit()
})
[void]$menu.Items.Add($exitItem)

$notify = [System.Windows.Forms.NotifyIcon]::new()
$notify.Icon = [System.Drawing.SystemIcons]::Application
$notify.Text = "Bili home mask"
$notify.ContextMenuStrip = $menu
$notify.Visible = $true

$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 120
$timer.add_Tick({
  try {
    Update-Mask
  } catch {
    Write-MaskLog -Message $_.Exception.ToString()
    Set-MaskVisible -Mask $mask -Visible $false
  }
})
$timer.Start()

if ($script:RegisteredHotkeys.Count -eq 0) {
  $hintItem.Text = "Use Toggle-BiliClientMask.bat"
}

Update-MenuState
[System.Windows.Forms.Application]::Run()
