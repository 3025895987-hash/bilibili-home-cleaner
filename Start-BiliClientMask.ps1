#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$CoverLeft = 80
$CoverTop = 96
$CoverRight = 0
$CoverBottom = 0
$MinCoverWidth = 240
$MinCoverHeight = 160

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
$StateFile = Join-Path $PSScriptRoot "BiliClientMask.disabled"

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

$script:Enabled = -not (Test-Path -LiteralPath $StateFile)
$script:LastTargetHandle = [IntPtr]::Zero
$script:RegisteredHotkeys = @()

function Get-WindowTitle {
  param([IntPtr]$Handle)

  $length = [BiliMask.Win32]::GetWindowTextLength($Handle)
  if ($length -le 0) {
    return ""
  }

  $builder = [StringBuilder]::new($length + 1)
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
    [Runtime.InteropServices.Marshal]::SizeOf([BiliMask.Win32+RECT])
  )

  if ($dwmResult -ne 0) {
    [void][BiliMask.Win32]::GetWindowRect($Handle, [ref]$rect)
  }

  return [System.Drawing.Rectangle]::FromLTRB($rect.Left, $rect.Top, $rect.Right, $rect.Bottom)
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

function Get-TargetWindow {
  $foreground = [BiliMask.Win32]::GetForegroundWindow()
  if ($foreground -eq [IntPtr]::Zero) {
    return $null
  }

  $title = Get-WindowTitle -Handle $foreground
  $processName = Get-WindowProcessName -Handle $foreground

  if ((Test-BilibiliAppWindow -Title $title -ProcessName $processName) -and (Test-BilibiliHomeTitle -Title $title)) {
    return [pscustomobject]@{
      Handle = $foreground
      Title = $title
      ProcessName = $processName
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
    $toggleItem.Text = if ($script:Enabled) { "Home feed mask: on" } else { "Home feed mask: off" }
  }
}

function Set-EnabledState {
  param(
    [bool]$Enabled,
    [bool]$Persist
  )

  $script:Enabled = $Enabled

  if ($Persist) {
    if ($Enabled) {
      Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
    } else {
      Set-Content -LiteralPath $StateFile -Value "disabled" -Encoding ASCII
    }
  }

  Update-MenuState
}

function Sync-EnabledState {
  $enabledByFile = -not (Test-Path -LiteralPath $StateFile)
  if ($script:Enabled -ne $enabledByFile) {
    Set-EnabledState -Enabled $enabledByFile -Persist $false
  }
}

function Update-Mask {
  Sync-EnabledState

  if (-not $script:Enabled) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  $target = Get-TargetWindow
  if ($null -eq $target) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  $bounds = Get-WindowBounds -Handle $target.Handle
  $width = $bounds.Width - $CoverLeft - $CoverRight
  $height = $bounds.Height - $CoverTop - $CoverBottom

  if ($width -lt $MinCoverWidth -or $height -lt $MinCoverHeight) {
    Set-MaskVisible -Mask $mask -Visible $false
    return
  }

  $x = $bounds.Left + $CoverLeft
  $y = $bounds.Top + $CoverTop

  Set-MaskVisible -Mask $mask -Visible $true
  [void][BiliMask.Win32]::SetWindowPos(
    $mask.Handle,
    [BiliMask.Win32]::HWND_TOPMOST,
    $x,
    $y,
    $width,
    $height,
    [BiliMask.Win32]::SWP_NOACTIVATE -bor [BiliMask.Win32]::SWP_SHOWWINDOW
  )

  $script:LastTargetHandle = $target.Handle
}

function Toggle-Enabled {
  Set-EnabledState -Enabled (-not $script:Enabled) -Persist $true
  Update-Mask
}

$mask = [BiliMask.NoActivateMaskForm]::new()
$mask.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$mask.ShowInTaskbar = $false
$mask.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$mask.BackColor = [System.Drawing.Color]::White
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
    Key = [uint][System.Windows.Forms.Keys]::B
  },
  [pscustomobject]@{
    Id = 2
    Text = "Ctrl+Alt+M"
    Modifiers = [BiliMask.Win32]::MOD_CONTROL -bor [BiliMask.Win32]::MOD_ALT
    Key = [uint][System.Windows.Forms.Keys]::M
  },
  [pscustomobject]@{
    Id = 3
    Text = "Ctrl+Shift+F12"
    Modifiers = [BiliMask.Win32]::MOD_CONTROL -bor [BiliMask.Win32]::MOD_SHIFT
    Key = [uint][System.Windows.Forms.Keys]::F12
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
$toggleItem = [System.Windows.Forms.ToolStripMenuItem]::new("Home feed mask: on")
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
$timer.add_Tick({ Update-Mask })
$timer.Start()

if ($script:RegisteredHotkeys.Count -eq 0) {
  $hintItem.Text = "Use Toggle-BiliClientMask.bat"
}

Update-MenuState
[System.Windows.Forms.Application]::Run()
