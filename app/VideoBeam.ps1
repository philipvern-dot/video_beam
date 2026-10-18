# Video Beam
# Open "Video Beam" in the parent folder. This file is the program window.

param(
    [switch]$SmokeTest,
    [switch]$TestDownload
)

$ErrorActionPreference = 'Stop'
$script:SmokeTest = [bool]$SmokeTest

if (-not ('VideoDownloader.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Runtime.InteropServices;
namespace VideoDownloader {
  public static class Native {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  }

  public static class YtLinePump {
    static readonly Regex Ansi = new Regex("\x1b\\[[0-9;]*[A-Za-z]", RegexOptions.Compiled);
    static readonly Regex Percent = new Regex(@"\[download\]\s+([\d.]+)%", RegexOptions.Compiled);
    static readonly ConcurrentQueue<string> Lines = new ConcurrentQueue<string>();
    public static volatile bool Exited;
    public static int Generation;
    public static int ExitCode;
    public static double LivePercent = -1;
    public static string LiveDetail;

    public static void BeginJob() {
      Generation++;
      string discard;
      while (Lines.TryDequeue(out discard)) {}
      LivePercent = -1;
      LiveDetail = null;
      ExitCode = 0;
      Exited = false;
    }

    public static void ClearPercent() {
      LivePercent = -1;
      LiveDetail = null;
    }

    public static void Accept(string line) {
      if (string.IsNullOrEmpty(line)) return;
      line = Ansi.Replace(line, string.Empty).TrimEnd('\r');
      if (line.Length == 0) return;
      Match match = Percent.Match(line);
      if (match.Success) {
        double pct;
        if (double.TryParse(match.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out pct)) {
          LivePercent = pct;
          LiveDetail = line;
        }
        return;
      }
      Lines.Enqueue(line);
    }

    public static void OnData(object sender, DataReceivedEventArgs e) {
      Accept(e.Data);
    }

    public static void OnExit(object sender, EventArgs e) {
      int gen = Generation;
      int code = -1;
      try {
        Process process = sender as Process;
        if (process != null) code = process.ExitCode;
      } catch {}
      if (gen != Generation) return;
      ExitCode = code;
      Exited = true;
    }

    public static string[] Drain() {
      List<string> batch = new List<string>();
      string line;
      while (Lines.TryDequeue(out line)) {
        if (!string.IsNullOrEmpty(line)) batch.Add(line);
      }
      return batch.ToArray();
    }
  }
}
'@
}

function Hide-OwnConsole {
    try {
        $hwnd = [VideoDownloader.Native]::GetConsoleWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return }
        $owner = [uint32]0
        [void][VideoDownloader.Native]::GetWindowThreadProcessId($hwnd, [ref]$owner)
        if ($owner -eq [uint32]$PID) {
            [void][VideoDownloader.Native]::ShowWindow($hwnd, 0)
        }
    } catch {
    }
}

if (-not $SmokeTest -and -not $TestDownload) {
    Hide-OwnConsole
}

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA' -and -not $TestDownload) {
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $argList = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($SmokeTest) {
        $argList += '-SmokeTest'
        $child = Start-Process -FilePath $ps -ArgumentList $argList -Wait -PassThru
        exit $child.ExitCode
    }
    Start-Process -FilePath $ps -ArgumentList $argList | Out-Null
    exit 0
}

$script:AppDir = $PSScriptRoot
if (-not $script:AppDir) { $script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:Root = Split-Path -Parent $script:AppDir
$script:ToolsDir = Join-Path $script:Root 'tools'
$script:DefaultDownloadsDir = Join-Path $script:Root 'downloads'
$script:DownloadsDir = $script:DefaultDownloadsDir
$script:ListsDir = Join-Path $script:Root 'saved-lists'
$script:YtDlp = Join-Path $script:ToolsDir 'yt-dlp.exe'
$script:Ffmpeg = Join-Path $script:ToolsDir 'ffmpeg.exe'
$script:Ffprobe = Join-Path $script:ToolsDir 'ffprobe.exe'
$script:Deno = Join-Path $script:ToolsDir 'deno.exe'
$script:SettingsPath = Join-Path $script:AppDir 'settings.json'
$script:ArchiveFile = Join-Path $script:AppDir 'download-history.txt'
$script:AudioArchiveFile = Join-Path $script:AppDir 'audio-history.txt'
$script:UpdateRepo = 'video_beam'
$script:UpdateAsset = 'video_beam.exe'
$script:UpdateProduct = 'Video Beam'
$script:UpdateFallback = '1.0.4'
$script:UpdateOffer = $null
$script:UpdateClosing = $false

foreach ($dir in @($script:DownloadsDir, $script:ListsDir, $script:ToolsDir)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

Add-Type -AssemblyName System.Drawing

$script:ColorPage = [Drawing.Color]::FromArgb(238, 241, 244)
$script:ColorInk = [Drawing.Color]::FromArgb(17, 24, 39)
$script:ColorBody = [Drawing.Color]::FromArgb(55, 65, 81)
$script:ColorMuted = [Drawing.Color]::FromArgb(75, 85, 99)
$script:ColorLine = [Drawing.Color]::FromArgb(214, 218, 225)
$script:ColorHeader = [Drawing.Color]::FromArgb(28, 36, 48)
$script:ColorHeaderMuted = [Drawing.Color]::FromArgb(209, 213, 219)
$script:ColorPrimary = [Drawing.Color]::FromArgb(29, 78, 216)
$script:ColorPrimaryHover = [Drawing.Color]::FromArgb(30, 64, 175)
$script:ColorDanger = [Drawing.Color]::FromArgb(185, 28, 28)
$script:ColorLogBg = [Drawing.Color]::FromArgb(28, 36, 48)
$script:ColorLogText = [Drawing.Color]::FromArgb(229, 231, 235)
$script:ColorLogOk = [Drawing.Color]::FromArgb(134, 239, 172)
$script:ColorLogWarn = [Drawing.Color]::FromArgb(252, 211, 77)
$script:ColorLogErr = [Drawing.Color]::FromArgb(252, 165, 165)
$script:ColorLogMuted = [Drawing.Color]::FromArgb(156, 163, 175)
$script:ColorOkText = [Drawing.Color]::FromArgb(22, 101, 52)
$script:ColorErrText = [Drawing.Color]::FromArgb(153, 27, 27)

function ConvertTo-Arg([string]$value) {
    if ($null -eq $value) { return '""' }
    if ($value -notmatch '[\s"]') { return $value }
    return '"' + ($value -replace '"', '\"') + '"'
}

function ConvertTo-CommandLine([string[]]$parts) {
    return (($parts | ForEach-Object { ConvertTo-Arg $_ }) -join ' ')
}

function Test-YouTubeHost([string]$Url) {
    try {
        $uri = [Uri]$Url
    } catch {
        return $false
    }
    if ($uri.Scheme -ne 'http' -and $uri.Scheme -ne 'https') { return $false }
    $hostName = $uri.Host.ToLowerInvariant()
    if ($hostName -eq 'youtu.be' -or $hostName -eq 'youtube.com') { return $true }
    if ($hostName.EndsWith('.youtube.com') -or $hostName.EndsWith('.youtu.be')) { return $true }
    return $false
}

function Get-LinkKind([string]$Url, [bool]$ExpandAttached) {
    if (-not (Test-YouTubeHost $Url)) { return 'open' }

    $hasVideoId = (
        $Url -match '(?i)youtu\.be/[^/?#]+' -or
        $Url -match '(?i)[?&]v=[^&#]+' -or
        $Url -match '(?i)/shorts/[^/?#]+' -or
        $Url -match '(?i)/embed/[^/?#]+' -or
        $Url -match '(?i)/live/[^/?#]+'
    )
    $isPlaylist = $Url -match '(?i)/playlist(\?|/|$)' -or (($Url -match '(?i)[?&]list=[^&#]+') -and -not $hasVideoId)
    if ($hasVideoId -and $ExpandAttached -and ($Url -match '(?i)[?&]list=')) { return 'playlist' }
    if ($isPlaylist) { return 'playlist' }

    $path = $Url
    try { $path = ([Uri]$Url).AbsolutePath } catch { }
    $path = $path -replace '%40', '@'
    if (-not $hasVideoId -and $path -match '(?i)^/(@[^/]+|channel/[^/]+|c/[^/]+|user/[^/]+)(/|$)') {
        return 'channel'
    }
    return 'video'
}

function Trim-UrlTail([string]$url) {
    $trim = @(
        [char]')', [char]']', [char]'}', [char]'>',
        [char]'"', [char]"'", [char]'.', [char]',', [char]';'
    )
    return $url.TrimEnd($trim)
}

function Resolve-Line([string]$line) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) {
        return [pscustomobject]@{ Status = 'skip' }
    }
    $t = $t.Trim(@([char]'"', [char]"'", [char]'<', [char]'>'))
    $url = $null
    if ($t -match '(?i)https?://\S+') {
        $url = Trim-UrlTail $Matches[0]
    } elseif ($t -match '(?i)^((?:www\.)?youtube\.com/\S+|youtu\.be/\S+)') {
        $url = Trim-UrlTail ('https://' + $Matches[1])
    }
    if (-not $url) {
        return [pscustomobject]@{ Status = 'invalid'; Text = $line.Trim() }
    }
    return [pscustomobject]@{ Status = 'ok'; Url = $url }
}

function Get-LinksFromText([string]$Text, [bool]$ExpandAttached) {
    $items = New-Object System.Collections.Generic.List[object]
    $invalid = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $dupes = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $parsed = Resolve-Line $line
        if ($parsed.Status -eq 'skip') { continue }
        if ($parsed.Status -eq 'invalid') {
            $invalid.Add([string]$parsed.Text)
            continue
        }
        $url = [string]$parsed.Url
        if ($seen.ContainsKey($url)) {
            $dupes++
            continue
        }
        $seen[$url] = $true
        $items.Add([pscustomobject]@{
            Url = $url
            Kind = (Get-LinkKind $url $ExpandAttached)
        })
    }
    return [pscustomobject]@{
        Items = $items
        Invalid = $invalid
        DuplicateCount = $dupes
    }
}

function Get-BlockedSitesPath {
    return (Join-Path $script:AppDir 'blocked-sites.md')
}

function Get-DefaultBlockedSitesText {
    return @'
# Blocked sites

Video Beam will not download a link whose site is listed here. One site per line. A line that starts with # is a note. Subdomains count: `music.youtube.com` matches `youtube.com`.

# Video sites that do not allow third-party downloads
youtube.com
youtu.be
youtube-nocookie.com
googlevideo.com
netflix.com
disneyplus.com
hulu.com
max.com
hbomax.com
primevideo.com
tv.apple.com
paramountplus.com
peacocktv.com
crunchyroll.com
discoveryplus.com
dropout.tv
mubi.com
shudder.com
starz.com
britbox.com
plus.espn.com
sling.com
fubo.tv
philo.com
tubitv.com
pluto.tv
vudu.com

# Music sites that do not allow third-party downloads
spotify.com
music.apple.com
tidal.com
deezer.com
pandora.com

# Social sites that do not allow third-party downloads
tiktok.com
instagram.com
facebook.com
fb.watch
twitch.tv
snapchat.com
dailymotion.com

'@
}

function Get-BlockedSites {
    $path = Get-BlockedSitesPath
    if (-not (Test-Path -LiteralPath $path)) {
        $utf8 = New-Object System.Text.UTF8Encoding $true
        [IO.File]::WriteAllText($path, (Get-DefaultBlockedSitesText), $utf8)
    }
    $raw = ''
    try { $raw = [IO.File]::ReadAllText($path) } catch { return @() }
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $sites = New-Object System.Collections.ArrayList
    foreach ($line in ($raw -split "`r?`n")) {
        $text = ([string]$line).Trim()
        if ($text -eq '' -or $text.StartsWith('#')) { continue }
        $text = $text.TrimStart([char]'-', [char]'*', [char]' ', [char]'`').TrimEnd([char]'`').Trim()
        if ($text -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
            try { $text = ([Uri]$text).Host } catch { continue }
        }
        $text = $text.Split('/')[0].Trim().TrimEnd('.').ToLowerInvariant()
        if ($text.StartsWith('www.')) { $text = $text.Substring(4) }
        if ($text -match '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$') {
            [void]$sites.Add($text)
        }
    }
    if ($sites.Count -eq 0) { return @() }
    return @($sites.ToArray())
}

function Test-BlockedUrl([string]$url, $sites) {
    $hostName = ''
    try { $hostName = ([Uri]$url).Host.ToLowerInvariant() } catch { return $false }
    if ($hostName.StartsWith('www.')) { $hostName = $hostName.Substring(4) }
    if ($null -eq $sites) { return $false }
    foreach ($site in $sites) {
        $name = ([string]$site).Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name.StartsWith('www.')) { $name = $name.Substring(4) }
        if ($hostName -eq $name -or $hostName.EndsWith('.' + $name)) { return $true }
    }
    return $false
}

function Open-BlockedSites {
    $path = Get-BlockedSitesPath
    if (-not (Test-Path -LiteralPath $path)) { [void](Get-BlockedSites) }
    Start-Process -FilePath $path
}

function Get-JobKey([string]$kind) {
    if ($kind -eq 'video') { return 'video' }
    if ($kind -eq 'open') { return 'open' }
    return 'collection'
}

function Build-Jobs($items) {
    $jobs = New-Object System.Collections.Generic.List[object]
    foreach ($item in $items) {
        $key = Get-JobKey $item.Kind
        $last = $null
        if ($jobs.Count -gt 0) { $last = $jobs[$jobs.Count - 1] }
        if ($null -eq $last -or $last.Key -ne $key) {
            $last = [pscustomobject]@{
                Key = $key
                Urls = (New-Object System.Collections.Generic.List[string])
                Channels = 0
            }
            $jobs.Add($last)
        }
        $last.Urls.Add([string]$item.Url)
        if ($item.Kind -eq 'channel') { $last.Channels++ }
    }
    # A bare list would collapse into one object, and one playlist would never start.
    return ,@($jobs.ToArray())
}

function ConvertTo-ClipSeconds([string]$text) {
    $t = $text.Trim()
    if ($t -eq '') { return $null }
    if ($t -match '^\d+(\.\d+)?$') {
        $n = [double]$t
        if ($n -lt 0) { return -1 }
        return $n
    }
    if ($t -match '^(\d+):(\d{1,2})(\.\d+)?$') {
        $sec = [int]$Matches[2]
        if ($sec -ge 60) { return -1 }
        $frac = 0.0
        if ($Matches[3]) { $frac = [double]$Matches[3] }
        return (([int]$Matches[1] * 60) + $sec + $frac)
    }
    if ($t -match '^(\d+):(\d{1,2}):(\d{1,2})(\.\d+)?$') {
        $min = [int]$Matches[2]
        $sec = [int]$Matches[3]
        if ($min -ge 60 -or $sec -ge 60) { return -1 }
        $frac = 0.0
        if ($Matches[4]) { $frac = [double]$Matches[4] }
        return (([int]$Matches[1] * 3600) + ($min * 60) + $sec + $frac)
    }
    return -1
}

function Get-ClipParts([double]$seconds) {
    $whole = [math]::Floor($seconds)
    $h = [int][math]::Floor($whole / 3600)
    $m = [int][math]::Floor(($whole % 3600) / 60)
    $s = [int]($whole % 60)
    return @($h, $m, $s)
}

function Format-ClipClock([double]$seconds) {
    $part = Get-ClipParts $seconds
    return ('{0}:{1:00}:{2:00}' -f $part[0], $part[1], $part[2])
}

function Format-ClipFileStamp([double]$seconds) {
    $part = Get-ClipParts $seconds
    if ($part[0] -gt 0) { return ('{0}h{1}m{2}s' -f $part[0], $part[1], $part[2]) }
    return ('{0}m{1}s' -f $part[1], $part[2])
}

function Get-ClipRequest {
    $startText = ''
    $endText = ''
    if ($script:ClipStartBox) { $startText = [string]$script:ClipStartBox.Text }
    if ($script:ClipEndBox) { $endText = [string]$script:ClipEndBox.Text }
    $start = ConvertTo-ClipSeconds $startText
    $end = ConvertTo-ClipSeconds $endText
    $result = [pscustomobject]@{
        Active = $false
        Ok = $true
        Message = ''
        Section = ''
        Stamp = ''
        StartLabel = 'the beginning'
        EndLabel = 'the end'
        StartSeconds = $null
        EndSeconds = $null
    }
    if ($null -eq $start -and $null -eq $end) { return $result }
    if (($null -ne $start -and $start -lt 0) -or ($null -ne $end -and $end -lt 0)) {
        $result.Ok = $false
        $result.Message = "Use m:ss, such as 1:30 for one minute and 30 seconds.`r`n`r`nFor an hour or more, use 1:02:05. A plain number such as 90 means 90 seconds."
        return $result
    }
    if ($null -eq $start) { $start = 0 }
    if ($null -ne $end -and $end -le $start) {
        $result.Ok = $false
        $result.Message = 'The clip end needs to be later than the start.'
        return $result
    }
    $endToken = 'inf'
    $stampEnd = 'end'
    $endLabel = 'the end'
    if ($null -ne $end) {
        $endToken = Format-ClipClock $end
        $stampEnd = Format-ClipFileStamp $end
        $endLabel = $endToken
    }
    $result.Active = $true
    $result.Section = ('*' + (Format-ClipClock $start) + '-' + $endToken)
    $result.Stamp = ((Format-ClipFileStamp $start) + '-' + $stampEnd)
    $result.StartLabel = Format-ClipClock $start
    $result.EndLabel = $endLabel
    $result.StartSeconds = $start
    $result.EndSeconds = $end
    return $result
}

function Format-FfmpegTime([double]$seconds) {
    if ($seconds -lt 0) { $seconds = 0 }
    return ([math]::Round($seconds, 3)).ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Test-ClipNeedsCut($clip) {
    if ($null -eq $clip) { return $false }
    $start = 0.0
    if ($null -ne $clip.StartSeconds) { $start = [double]$clip.StartSeconds }
    $hasEnd = $null -ne $clip.EndSeconds
    if ($start -le 0.05 -and -not $hasEnd) { return $false }
    return $true
}

function Get-SaveFolderName {
    $path = [string]$script:DownloadsDir
    if ([string]::IsNullOrWhiteSpace($path)) { return 'Downloads' }
    $name = [IO.Path]::GetFileName($path.TrimEnd('\', '/'))
    if ([string]::IsNullOrWhiteSpace($name)) { return $path }
    return $name
}

function Update-LinkHint {
    if (-not $script:LinkHint) { return }
    $base = 'One link per line. A playlist link downloads every video in the playlist. A video link downloads only that video.'
    $count = 0
    if ($script:LinkBox) {
        $expand = $false
        if ($script:AttachedCheck) { $expand = [bool]$script:AttachedCheck.Checked }
        $count = @(Get-LinksFromText $script:LinkBox.Text $expand).Items.Count
    }
    if ($count -eq 1) { $script:LinkHint.Text = $base + '  1 link.' }
    elseif ($count -gt 1) { $script:LinkHint.Text = $base + "  $count links." }
    else { $script:LinkHint.Text = $base }
}

function Get-HeightFormat([string]$resolution) {
    $known = @(360, 480, 720, 1080, 1440, 2160)
    $height = 0
    if (-not [int]::TryParse($resolution, [ref]$height)) { return $null }
    if ($known -notcontains $height) { return $null }
    $selectors = New-Object System.Collections.Generic.List[string]
    foreach ($cap in @($known | Where-Object { $_ -ge $height })) {
        $selectors.Add("bv*[height<=$cap]+ba/b[height<=$cap]")
    }
    $selectors.Add('bv*+ba/b')
    return ($selectors -join '/')
}

function Get-YtArguments {
    param(
        [string]$Key,
        [bool]$PlaylistFolders,
        [bool]$SkipExisting,
        [string]$Destination,
        [string]$ArchiveFile,
        [string]$BatchFile,
        [string]$Resolution = 'best',
        [bool]$AudioOnly = $false,
        [string]$ClipStamp = '',
        [switch]$NoContinue
    )
    $template = '%(title).80s [%(id)s].%(ext)s'
    if ($Key -eq 'collection') {
        if ($PlaylistFolders) {
            $template = '%(playlist).70s/%(playlist_index)s - %(title).70s [%(id)s].%(ext)s'
        } else {
            $template = '%(playlist_index)s - %(title).80s [%(id)s].%(ext)s'
        }
    } elseif ($Key -eq 'open') {
        $template = '%(playlist_index&{} - |)s%(title).80s [%(id)s].%(ext)s'
    }
    if (-not [string]::IsNullOrWhiteSpace($ClipStamp)) {
        $template = $template -replace '\.%\(ext\)s$', (' ' + $ClipStamp + '.%(ext)s')
    }

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('--ignore-config')
    if ($AudioOnly) {
        $parts.Add('-t')
        $parts.Add('mp3')
        $parts.Add('--audio-quality')
        $parts.Add('0')
    } else {
        $parts.Add('-t')
        $parts.Add('mp4')
        $heightFormat = Get-HeightFormat $Resolution
        if ($heightFormat) {
            $parts.Add('-f')
            $parts.Add($heightFormat)
        }
    }
    if ($script:Deno -and (Test-Path -LiteralPath $script:Deno)) {
        $parts.Add('--js-runtimes')
        $parts.Add('deno:' + $script:Deno)
    }
    foreach ($part in @(
        '--ffmpeg-location', $script:ToolsDir,
        '--paths', $Destination,
        '-o', $template,
        '--windows-filenames',
        '--trim-filenames', '150',
        '--newline',
        '--progress',
        '--color', 'no_color',
        '--ignore-errors',
        '--embed-metadata',
        '--no-embed-info-json',
        '--retries', '10',
        '--fragment-retries', '10',
        '--socket-timeout', '30',
        '--print', 'after_move:YD_SAVED:%(filepath)s'
    )) {
        $parts.Add([string]$part)
    }
    if ($Key -eq 'video') {
        $parts.Add('--no-playlist')
    } elseif ($Key -eq 'collection') {
        $parts.Add('--yes-playlist')
    }
    $remember = [bool]$SkipExisting -and [string]::IsNullOrWhiteSpace($ClipStamp)
    if ($remember) {
        $parts.Add('--download-archive')
        $parts.Add($ArchiveFile)
        $parts.Add('--no-overwrites')
    } else {
        $parts.Add('--force-overwrites')
    }
    if ($NoContinue) {
        $parts.Add('--no-continue')
    }
    $parts.Add('-a')
    $parts.Add($BatchFile)
    return $parts.ToArray()
}

function Get-MediaDuration([string]$path) {
    $probe = Join-Path $script:ToolsDir 'ffprobe.exe'
    if (-not (Test-Path -LiteralPath $probe) -or -not (Test-Path -LiteralPath $path)) { return 0 }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $probe
    $psi.Arguments = ConvertTo-CommandLine @('-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', $path)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    $null = $errTask.Result
    $dur = 0.0
    $text = [string]$outTask.Result
    if ([double]::TryParse($text.Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$dur)) {
        return $dur
    }
    return 0
}

function Get-ClipCutArguments {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [double]$StartSeconds,
        $EndSeconds
    )
    # Cut a file that is already on disk. Seeking with ffmpeg over a YouTube
    # URL is throttled and shows no progress, so the download stays normal
    # and this cut runs afterward. Re-encoding makes the cut match the typed
    # times. A stream copy would start at the previous keyframe. -t is the
    # length to keep, not an end time.
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('-y')
    $parts.Add('-hide_banner')
    $parts.Add('-loglevel')
    $parts.Add('error')
    $parts.Add('-stats_period')
    $parts.Add('0.5')
    if ($StartSeconds -gt 0.05) {
        $parts.Add('-ss')
        $parts.Add((Format-FfmpegTime $StartSeconds))
    }
    $parts.Add('-i')
    $parts.Add($InputPath)
    if ($null -ne $EndSeconds) {
        $duration = [double]$EndSeconds - $StartSeconds
        if ($duration -lt 0.05) { $duration = 0.05 }
        $parts.Add('-t')
        $parts.Add((Format-FfmpegTime $duration))
    }
    $ext = [IO.Path]::GetExtension($OutputPath)
    if ($ext -match '^\.mp3$') {
        $parts.Add('-vn')
        $parts.Add('-c:a')
        $parts.Add('libmp3lame')
        $parts.Add('-q:a')
        $parts.Add('0')
    } else {
        $parts.Add('-map')
        $parts.Add('0:v:0')
        $parts.Add('-map')
        $parts.Add('0:a:0?')
        $parts.Add('-c:v')
        $parts.Add('libx264')
        $parts.Add('-preset')
        $parts.Add('veryfast')
        $parts.Add('-crf')
        $parts.Add('18')
        $parts.Add('-pix_fmt')
        $parts.Add('yuv420p')
        $parts.Add('-c:a')
        $parts.Add('aac')
        $parts.Add('-b:a')
        $parts.Add('192k')
        $parts.Add('-movflags')
        $parts.Add('+faststart')
    }
    $parts.Add('-progress')
    $parts.Add('pipe:1')
    $parts.Add('-nostats')
    $parts.Add($OutputPath)
    return $parts.ToArray()
}

function Format-Count([int]$count, [string]$word) {
    if ($count -eq 1) { return "1 $word" }
    return "$count ${word}s"
}

function Get-MissingTools {
    $missing = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $script:YtDlp)) { $missing.Add($script:YtDlp) }
    if (-not (Test-Path -LiteralPath $script:Ffmpeg)) { $missing.Add($script:Ffmpeg) }
    return $missing
}

function Update-Shortcut {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $script:Root 'Video Beam.lnk'
        $oldLnk = Join-Path $script:Root 'Video Downloader.lnk'
        if ((Test-Path -LiteralPath $oldLnk) -and ($oldLnk -ne $lnkPath)) {
            Remove-Item -LiteralPath $oldLnk -Force -ErrorAction SilentlyContinue
        }
        $lnk = $wsh.CreateShortcut($lnkPath)
        $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
        $vbs = Join-Path $script:AppDir 'launch.vbs'
        $lnk.Arguments = "//nologo `"$vbs`""
        $lnk.WorkingDirectory = $script:Root
        $lnk.WindowStyle = 1
        $lnk.Description = 'Download videos and playlists as MP4 or MP3 files'
        $iconPath = Get-AppIconPath
        if ($iconPath) { $lnk.IconLocation = $iconPath + ',0' }
        $lnk.Save()
    } catch {
    }
}

function Load-Settings {
    $defaults = @{
        PlaylistFolders = $true
        SkipExisting = $true
        ExpandAttached = $false
        Detailed = $false
        SeenWelcome = $false
        Resolution = 'best'
        AudioOnly = $false
        DownloadsFolder = ''
        UpdatePrompt = ''
    }
    if (-not (Test-Path -LiteralPath $script:SettingsPath)) { return $defaults }
    try {
        $json = Get-Content -Raw -LiteralPath $script:SettingsPath -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $json.playlistFolders) { $defaults.PlaylistFolders = [bool]$json.playlistFolders }
        if ($null -ne $json.skipExisting) { $defaults.SkipExisting = [bool]$json.skipExisting }
        if ($null -ne $json.expandAttached) { $defaults.ExpandAttached = [bool]$json.expandAttached }
        if ($null -ne $json.detailed) { $defaults.Detailed = [bool]$json.detailed }
        if ($null -ne $json.seenWelcome) { $defaults.SeenWelcome = [bool]$json.seenWelcome }
        if ($json.resolution) { $defaults.Resolution = [string]$json.resolution }
        if ($null -ne $json.audioOnly) { $defaults.AudioOnly = [bool]$json.audioOnly }
        if ($json.downloadsFolder) { $defaults.DownloadsFolder = [string]$json.downloadsFolder }
        if ($json.updatePrompt) { $defaults.UpdatePrompt = [string]$json.updatePrompt }
    } catch {
    }
    return $defaults
}

function Resolve-DownloadsFolder([string]$saved) {
    if ([string]::IsNullOrWhiteSpace($saved)) { return $script:DefaultDownloadsDir }
    try {
        $full = [IO.Path]::GetFullPath($saved.Trim())
    } catch {
        return $script:DefaultDownloadsDir
    }
    if ([string]::IsNullOrWhiteSpace($full)) { return $script:DefaultDownloadsDir }
    if (Test-Path -LiteralPath $full -PathType Leaf) { return $script:DefaultDownloadsDir }
    $root = [IO.Path]::GetPathRoot($full)
    if ($root -and -not (Test-Path -LiteralPath $root)) { return $script:DefaultDownloadsDir }
    return $full
}

function Save-Settings {
    if ($script:SmokeTest) { return }
    if ($null -eq $script:FolderCheck) { return }
    $obj = [ordered]@{
        playlistFolders = [bool]$script:FolderCheck.Checked
        skipExisting = [bool]$script:SkipCheck.Checked
        expandAttached = [bool]$script:AttachedCheck.Checked
        detailed = [bool]$script:DetailedCheck.Checked
        seenWelcome = [bool]$script:SeenWelcome
        resolution = (Get-SelectedResolution)
        audioOnly = [bool]$script:AudioCheck.Checked
        downloadsFolder = [string]$script:DownloadsDir
        updatePrompt = [string]$script:UpdatePrompt
    }
    $json = $obj | ConvertTo-Json
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($script:SettingsPath, $json, $utf8)
}

function Invoke-TestDownload {
    $dest = Join-Path $env:TEMP 'video-downloader-test'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Path $dest | Out-Null
    $batch = Join-Path $env:TEMP 'video-downloader-test-links.txt'
    $archive = Join-Path $env:TEMP 'video-downloader-test-history.txt'
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($batch, @('https://www.youtube.com/watch?v=jNQXAC9IVRw'), $utf8)
    $parts = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $false -Destination $dest -ArchiveFile $archive -BatchFile $batch
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:YtDlp
    $psi.Arguments = ConvertTo-CommandLine $parts
    $psi.WorkingDirectory = $script:Root
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        throw "Test download failed ($($proc.ExitCode)).`r`n$stdout`r`n$stderr"
    }
    if ($stdout -notmatch 'YD_SAVED:') {
        throw "The downloader did not report the saved file.`r`n$stdout`r`n$stderr"
    }
    if ($stderr -match '(?m)^ERROR:') {
        throw "The downloader reported a problem.`r`n$stdout`r`n$stderr"
    }
    if ($stderr -match 'No supported JavaScript runtime') {
        throw "Deno was not used.`r`n$stderr"
    }
    $file = Get-ChildItem -LiteralPath $dest -Filter '*.mp4' -Recurse | Select-Object -First 1
    if ($null -eq $file) { throw "Test download did not create an MP4.`r`n$stdout`r`n$stderr" }
    if ($file.Name -notmatch '\[jNQXAC9IVRw\]\.mp4$') { throw "Unexpected file name: $($file.Name)" }
    $probe = & $script:Ffprobe -v error -show_entries format=format_name -show_entries stream=codec_type,codec_name -of default=nw=1 $file.FullName
    $probeText = ($probe | Out-String)
    if ($probeText -notmatch 'codec_name=h264') { throw "Video codec was not h264.`r`n$probeText" }
    if ($probeText -notmatch 'codec_name=aac') { throw "Audio codec was not aac.`r`n$probeText" }
    if ($probeText -notmatch 'format_name=mov,mp4') { throw "Container was not mp4.`r`n$probeText" }

    $audioArchive = Join-Path $env:TEMP 'video-downloader-test-audio-history.txt'
    $audioParts = Get-YtArguments -Key 'video' -PlaylistFolders $false -SkipExisting $false -Destination $dest -ArchiveFile $audioArchive -BatchFile $batch -AudioOnly $true
    $audioPsi = New-Object System.Diagnostics.ProcessStartInfo
    $audioPsi.FileName = $script:YtDlp
    $audioPsi.Arguments = ConvertTo-CommandLine $audioParts
    $audioPsi.WorkingDirectory = $script:Root
    $audioPsi.UseShellExecute = $false
    $audioPsi.CreateNoWindow = $true
    $audioPsi.RedirectStandardOutput = $true
    $audioPsi.RedirectStandardError = $true
    $audioProc = [Diagnostics.Process]::Start($audioPsi)
    $audioOut = $audioProc.StandardOutput.ReadToEnd()
    $audioErr = $audioProc.StandardError.ReadToEnd()
    $audioProc.WaitForExit()
    if ($audioProc.ExitCode -ne 0 -or $audioOut -notmatch 'YD_SAVED:' -or $audioErr -match '(?m)^ERROR:') {
        throw "MP3 download failed.`r`n$audioOut`r`n$audioErr"
    }
    $audioFile = Get-ChildItem -LiteralPath $dest -Filter '*.mp3' -Recurse | Select-Object -First 1
    if ($null -eq $audioFile) { throw "MP3 download did not create an MP3.`r`n$audioOut`r`n$audioErr" }
    $audioProbe = & $script:Ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1 $audioFile.FullName
    if (($audioProbe | Out-String) -notmatch 'codec_name=mp3') { throw "Audio codec was not mp3.`r`n$audioProbe" }
    Remove-Item -LiteralPath $audioArchive -Force -ErrorAction SilentlyContinue

    $plBatch = Join-Path $env:TEMP 'video-downloader-test-playlist.txt'
    [System.IO.File]::WriteAllLines($plBatch, @('https://www.youtube.com/playlist?list=PL4cUxeGkcC9gQeDH6xYhmO-db2mhoTSrT'), $utf8)
    $plParts = @(Get-YtArguments -Key 'collection' -PlaylistFolders $true -SkipExisting $false -Destination $dest -ArchiveFile $archive -BatchFile $plBatch)
    $plParts += @('--skip-download', '--playlist-end', '1', '--print', 'filename')
    $plPsi = New-Object System.Diagnostics.ProcessStartInfo
    $plPsi.FileName = $script:YtDlp
    $plPsi.Arguments = (ConvertTo-CommandLine $plParts)
    $plPsi.WorkingDirectory = $script:Root
    $plPsi.UseShellExecute = $false
    $plPsi.CreateNoWindow = $true
    $plPsi.RedirectStandardOutput = $true
    $plPsi.RedirectStandardError = $true
    $plProc = [Diagnostics.Process]::Start($plPsi)
    $plOut = $plProc.StandardOutput.ReadToEnd()
    $plErr = $plProc.StandardError.ReadToEnd()
    $plProc.WaitForExit()
    if ($plProc.ExitCode -ne 0 -or $plOut -notmatch 'CSS Tutorials For Beginners\\1 - .+\[I9XRrlOOazo\]\.mp4') {
        throw "Playlist naming failed.`r`n$plOut`r`n$plErr"
    }
    Remove-Item -LiteralPath $plBatch -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $dest -Recurse -Force
    Remove-Item -LiteralPath $batch -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Write-Output 'TEST DOWNLOAD OK'
}

if ($TestDownload) {
    try {
        Invoke-TestDownload
        exit 0
    } catch {
        Write-Output ("TEST DOWNLOAD FAIL: " + $_.Exception.Message)
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$script:FontTitle = New-Object Drawing.Font('Segoe UI', 22, [Drawing.FontStyle]::Bold)
$script:FontSubtitle = New-Object Drawing.Font('Segoe UI', 10)
$script:FontSection = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)
$script:FontUi = New-Object Drawing.Font('Segoe UI', 10)
$script:FontHint = New-Object Drawing.Font('Segoe UI', 9)
$script:FontButton = New-Object Drawing.Font('Segoe UI', 10)
$script:FontButtonBold = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
$script:FontLog = New-Object Drawing.Font('Consolas', 10)
$script:FontHelpHeading = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)
$script:FontHelpBody = New-Object Drawing.Font('Segoe UI', 10)

function Enable-DoubleBuffer($control) {
    $prop = $control.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic')
    if ($prop) { $prop.SetValue($control, $true, $null) }
}

function Get-AppIconPath {
    $path = Join-Path $script:Root 'vb-icon.ico'
    if (Test-Path -LiteralPath $path) { return $path }
    return $null
}

function Get-AppIcon {
    try {
        $path = Get-AppIconPath
        if (-not $path) { return $null }
        return New-Object Drawing.Icon $path
    } catch {
        return $null
    }
}

function Update-ButtonFace($btn) {
    if ($null -eq $btn) { return }
    $role = [string]$btn.Tag
    $gray = [Drawing.Color]::FromArgb(229, 231, 235)
    $grayText = [Drawing.Color]::FromArgb(156, 163, 175)
    if (-not $btn.Enabled) {
        $btn.BackColor = $gray
        $btn.ForeColor = $grayText
        $btn.FlatAppearance.BorderColor = $gray
        $btn.FlatAppearance.MouseOverBackColor = $gray
        $btn.FlatAppearance.MouseDownBackColor = $gray
        return
    }
    if ($role -eq 'primary') {
        $btn.BackColor = $script:ColorPrimary
        $btn.ForeColor = [Drawing.Color]::White
        $btn.FlatAppearance.BorderColor = $script:ColorPrimary
        $btn.FlatAppearance.MouseOverBackColor = $script:ColorPrimaryHover
        $btn.FlatAppearance.MouseDownBackColor = $script:ColorPrimaryHover
    } elseif ($role -eq 'danger') {
        $btn.BackColor = [Drawing.Color]::White
        $btn.ForeColor = $script:ColorDanger
        $btn.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(252, 165, 165)
        $btn.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(254, 242, 242)
        $btn.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(254, 226, 226)
    } else {
        $btn.BackColor = [Drawing.Color]::White
        $btn.ForeColor = $script:ColorInk
        $btn.FlatAppearance.BorderColor = $script:ColorLine
        $btn.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(243, 244, 246)
        $btn.FlatAppearance.MouseDownBackColor = [Drawing.Color]::FromArgb(229, 231, 235)
    }
}

function New-Button([string]$text, [string]$role, [int]$width, [int]$height) {
    $btn = New-Object Windows.Forms.Button
    $btn.Text = $text
    $btn.Tag = $role
    $btn.Width = $width
    $btn.Height = $height
    $btn.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 1
    $btn.Cursor = [Windows.Forms.Cursors]::Hand
    $btn.UseVisualStyleBackColor = $false
    $btn.Margin = New-Object Windows.Forms.Padding(0, 4, 8, 0)
    if ($role -eq 'primary') { $btn.Font = $script:FontButtonBold } else { $btn.Font = $script:FontButton }
    $btn.Add_EnabledChanged({ Update-ButtonFace $this })
    Update-ButtonFace $btn
    return $btn
}

function Set-Tip($control, [string]$text) {
    $script:Tips.SetToolTip($control, $text)
    $script:TipMap[$control] = $text
}

function Set-Status([string]$text, [string]$kind) {
    if ($null -eq $script:StatusLabel) { return }
    if ($script:StatusLabel.Text -eq $text -and $script:StatusKind -eq $kind) { return }
    $script:StatusKind = $kind
    $script:StatusLabel.Text = $text
    if ($kind -eq 'ok') { $script:StatusLabel.ForeColor = $script:ColorOkText }
    elseif ($kind -eq 'err') { $script:StatusLabel.ForeColor = $script:ColorErrText }
    elseif ($kind -eq 'busy') { $script:StatusLabel.ForeColor = $script:ColorInk }
    else { $script:StatusLabel.ForeColor = $script:ColorMuted }
}

function Set-Progress([double]$percent) {
    if ($percent -lt 0) { $percent = 0 }
    if ($percent -gt 100) { $percent = 100 }
    $script:ProgressValue = $percent
    if ($null -eq $script:ProgressTrack) { return }
    $width = $script:ProgressTrack.ClientSize.Width
    $fill = [int][Math]::Round($width * ($percent / 100.0))
    if ($fill -lt 0) { $fill = 0 }
    if ($percent -gt 0 -and $fill -lt 6 -and $width -gt 0) { $fill = 6 }
    if ($fill -gt $width) { $fill = $width }
    $script:ProgressFill.Width = $fill
    $script:ProgressFill.Height = $script:ProgressTrack.ClientSize.Height
}

function Test-LogPinned {
    $box = $script:Log
    if ($null -eq $box -or $box.TextLength -le 1) { return $true }
    $last = $box.GetPositionFromCharIndex($box.TextLength - 1)
    return ($last.Y -le ($box.ClientSize.Height + 8))
}

function Write-Activity([string]$message, [string]$kind) {
    $box = $script:Log
    if ($null -eq $box -or $box.IsDisposed) { return }
    $color = $script:ColorLogText
    if ($kind -eq 'ok') { $color = $script:ColorLogOk }
    elseif ($kind -eq 'warn') { $color = $script:ColorLogWarn }
    elseif ($kind -eq 'err') { $color = $script:ColorLogErr }
    elseif ($kind -eq 'dim') { $color = $script:ColorLogMuted }
    $follow = Test-LogPinned
    if ($box.TextLength -gt 180000) {
        $box.Select(0, 60000)
        $box.SelectedText = ''
    }
    $box.SelectionStart = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionColor = $color
    $box.AppendText($message + [Environment]::NewLine)
    if ($follow) {
        $box.SelectionStart = $box.TextLength
        $box.ScrollToCaret()
    }
}

function Remember-Raw([string]$line) {
    if ($null -eq $script:RecentRaw) { return }
    $script:RecentRaw.Add($line)
    if ($script:RecentRaw.Count -gt 40) { $script:RecentRaw.RemoveAt(0) }
}

function Ensure-OutputHandlers {
    if ($script:DataHandler) { return }
    $script:DataHandler = [Delegate]::CreateDelegate([System.Diagnostics.DataReceivedEventHandler], [VideoDownloader.YtLinePump].GetMethod('OnData'))
    $script:ExitHandler = [Delegate]::CreateDelegate([System.EventHandler], [VideoDownloader.YtLinePump].GetMethod('OnExit'))
}

function Add-PendingLine([string]$line) {
    [VideoDownloader.YtLinePump]::Accept($line)
    $script:LivePercent = [double][VideoDownloader.YtLinePump]::LivePercent
    $detail = [VideoDownloader.YtLinePump]::LiveDetail
    if ($null -ne $detail) { $script:LiveDetail = [string]$detail }
}

function Read-PendingLines {
    $batch = [VideoDownloader.YtLinePump]::Drain()
    if ($null -eq $batch -or $batch -is [string]) { return ,@($batch) }
    return ,$batch
}

function Publish-SavedFile([string]$path) {
    $script:Saved++
    $root = ''
    if ($script:DownloadsDir) { $root = $script:DownloadsDir.TrimEnd('\') }
    $name = $path
    if ($root -and $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $name = $path.Substring($root.Length).TrimStart('\', '/')
    } else {
        $name = [IO.Path]::GetFileName($path)
    }
    Write-Activity "Saved  $name" 'ok'
    Set-Status "Saved  $name" 'ok'
}

function Remove-ClipTemp {
    if ($script:ClipTemp -and (Test-Path -LiteralPath $script:ClipTemp)) {
        Remove-Item -LiteralPath $script:ClipTemp -Force -ErrorAction SilentlyContinue
    }
    $script:ClipTemp = $null
}

function Update-ClipProgress([double]$elapsedSeconds) {
    if ($script:ClipPhase -ne 'cut') { return }
    $pct = 0.0
    if ($script:ClipDuration -gt 0) {
        $pct = ($elapsedSeconds / [double]$script:ClipDuration) * 100.0
    }
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 99) { $pct = 99 }
    $script:LivePercent = $pct
    $script:LiveDetail = 'cutting'
}

function Receive-Line([string]$line) {
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    $line = $line.TrimEnd()
    # ffmpeg -progress prints one field per line. out_time_us and out_time_ms
    # are both microseconds on the bundled build.
    if ($line -match '^out_time_us=(\d+)$' -or $line -match '^out_time_ms=(\d+)$') {
        Update-ClipProgress ([double]$Matches[1] / 1000000.0)
        return
    }
    if ($line -match '^out_time=(\d+):(\d+):(\d+(?:\.\d+)?)$') {
        $elapsed = ([double]$Matches[1] * 3600) + ([double]$Matches[2] * 60) + [double]$Matches[3]
        Update-ClipProgress $elapsed
        return
    }
    if ($line -eq 'progress=end') {
        if ($script:ClipPhase -eq 'cut') {
            $script:LivePercent = 100
            $script:LiveDetail = 'cutting'
        }
        return
    }
    if ($line -match '^(frame|fps|bitrate|total_size|dup_frames|drop_frames|speed|progress|stream_\d+_\d+_q)=') {
        return
    }
    Remember-Raw $line

    if ($line.StartsWith('YD_SAVED:')) {
        $path = $line.Substring(9).Trim().Trim('"')
        if ($script:ActiveClip -and $script:ClipPhase -eq 'download') {
            $script:ClipSource = $path
            Set-Status 'Cutting video' 'busy'
            return
        }
        Publish-SavedFile $path
        return
    }
    if ($line -match 'has already been downloaded') {
        $script:Skipped++
        $name = 'a video already in Downloads'
        if ($line -match '\]\s*(.+?)\s+has already been downloaded') {
            $name = [IO.Path]::GetFileName($Matches[1].Trim())
        }
        Write-Activity "Skipped  $name" 'dim'
        return
    }
    if ($line -match 'already been recorded in the archive') {
        $script:Skipped++
        $name = 'a video already in the history'
        if ($line -match '\]\s*([^:\]]+):\s+has already been recorded') {
            $name = $Matches[1].Trim()
        }
        Write-Activity "Skipped  $name" 'dim'
        return
    }
    if ($line -match 'Downloading item (\d+) of (\d+)') {
        $script:ItemIndex = [int]$Matches[1]
        $script:ItemCount = [int]$Matches[2]
        Write-Activity "Video $($Matches[1]) of $($Matches[2])" 'text'
        Set-Status "Video $($Matches[1]) of $($Matches[2])" 'busy'
        return
    }
    if ($line -match '\[download\] Destination:\s*(.+)$') {
        $script:CurrentName = [IO.Path]::GetFileName($Matches[1].Trim())
        [VideoDownloader.YtLinePump]::ClearPercent()
        $script:LivePercent = -1
        $script:LiveDetail = ''
        Set-Progress 0
        Set-Status "Starting  $($script:CurrentName)" 'busy'
        if ($script:DetailedCheck.Checked) { Write-Activity $line 'dim' }
        return
    }
    if ($line -match '\[(Merger|VideoRemuxer|VideoConvertor|Metadata|Fixup)\]') {
        Set-Status 'Packaging MP4...' 'busy'
        if ($script:DetailedCheck.Checked) { Write-Activity $line 'dim' }
        return
    }
    if ($line.StartsWith('ERROR:')) {
        $script:Failed++
        $script:JobHadError = $true
        Write-Activity $line 'err'
        Set-Status 'A video failed. The rest will continue.' 'err'
        return
    }
    if ($line.StartsWith('WARNING:')) {
        if ($script:DetailedCheck.Checked) { Write-Activity $line 'warn' }
        return
    }
    if ($script:DetailedCheck.Checked) { Write-Activity $line 'dim' }
}

function Update-LiveProgress {
    if (-not $script:Running) { return }
    if ($script:ClipPhase -eq 'cut') {
        if ($script:LivePercent -lt 0) { return }
        $cutPct = [double]$script:LivePercent
        Set-Progress $cutPct
        Set-Status ("Cutting video   {0:N0}%" -f $cutPct) 'busy'
        return
    }
    $pumpPercent = [double][VideoDownloader.YtLinePump]::LivePercent
    if ($pumpPercent -ge 0) {
        $script:LivePercent = $pumpPercent
        $detail = [VideoDownloader.YtLinePump]::LiveDetail
        if ($null -ne $detail) { $script:LiveDetail = [string]$detail }
    }
    if ($script:LivePercent -lt 0) { return }
    if ([string]::IsNullOrEmpty($script:LiveDetail)) { return }
    $pct = [double]$script:LivePercent
    Set-Progress $pct
    $speed = ''
    $eta = ''
    if ($script:LiveDetail -match 'at\s+(\S+)\s+ETA\s+(\S+)') {
        $speed = $Matches[1]
        $eta = $Matches[2]
    }
    $bits = New-Object System.Collections.Generic.List[string]
    if ($script:ItemCount -gt 0) { $bits.Add("Video $($script:ItemIndex) of $($script:ItemCount)") }
    $bits.Add(("{0:N0}%" -f $pct))
    if ($speed -and $speed -ne 'Unknown') { $bits.Add($speed) }
    if ($eta -and $eta -ne 'Unknown') { $bits.Add("ETA $eta") }
    if ($script:CurrentName) { $bits.Add([string]$script:CurrentName) }
    Set-Status ($bits -join '   ') 'busy'
}

function Test-DownloadRefused {
    if (-not $script:RecentRaw) { return $false }
    foreach ($line in $script:RecentRaw) {
        if ([string]$line -match 'HTTP Error 403') { return $true }
    }
    return $false
}

function Remove-RefusedPartials {
    $folder = [string]$script:DownloadsDir
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder)) { return }
    $since = [DateTime]::MinValue
    if ($script:JobStarted) { $since = $script:JobStarted.AddSeconds(-5) }
    $stamp = ''
    if ($script:ActiveClip) { $stamp = [string]$script:ActiveClip.Stamp }
    foreach ($pattern in @('*.part', '*.ytdl')) {
        $files = @(Get-ChildItem -LiteralPath $folder -File -Recurse -Filter $pattern -ErrorAction SilentlyContinue)
        foreach ($file in $files) {
            $named = $stamp -and ($file.Name -like ('*' + $stamp + '*'))
            $fresh = $file.LastWriteTime -ge $since
            if ($named -or $fresh) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-BatchFile {
    if ($script:BatchFile -and (Test-Path -LiteralPath $script:BatchFile)) {
        Remove-Item -LiteralPath $script:BatchFile -Force -ErrorAction SilentlyContinue
    }
    $script:BatchFile = $null
}

function Stop-DownloadProcess {
    $script:CancelRequested = $true
    $proc = $script:Process
    if ($proc -and -not $proc.HasExited) {
        $taskkill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
        & $taskkill /PID $proc.Id /T /F | Out-Null
    }
}

function Get-JobLabel($job) {
    $n = $job.Urls.Count
    if ($job.Key -eq 'video') {
        if ($n -eq 1) { return 'Downloading 1 video...' }
        return "Downloading $n videos..."
    }
    if ($job.Key -eq 'collection') {
        if ($job.Channels -eq $n) {
            if ($n -eq 1) { return 'Downloading 1 channel...' }
            return "Downloading $n channels..."
        }
        if ($n -eq 1) { return 'Downloading 1 playlist...' }
        return "Downloading $n playlists..."
    }
    if ($n -eq 1) { return 'Downloading 1 link...' }
    return "Downloading $n links..."
}

function Complete-Run([bool]$cancelled) {
    Remove-BatchFile
    Remove-ClipTemp
    if ($script:Process) {
        try { $script:Process.Dispose() } catch { }
        $script:Process = $null
    }
    $fullLeftBehind = $false
    if ($cancelled -and $script:ClipSource -and (Test-Path -LiteralPath $script:ClipSource) -and $script:Saved -eq 0) {
        $fullLeftBehind = $true
    }
    $script:Running = $false
    $script:ActiveClip = $null
    $script:ClipPhase = ''
    $script:ClipSource = $null
    $script:ClipDuration = 0
    $script:LivePercent = -1
    $script:LiveDetail = ''
    Set-Busy $false
    if ($cancelled) {
        Set-Progress 0
        if ($fullLeftBehind) { $text = 'Cancelled. The full video was saved, and the clip was not cut.' }
        elseif ($script:Saved -eq 0) { $text = 'Cancelled. Nothing was saved.' }
        else { $text = "Cancelled. $(Format-Count $script:Saved 'file') saved before the stop." }
        Set-Status $text 'err'
        Write-Activity $text 'warn'
        return
    }
    $bits = New-Object System.Collections.Generic.List[string]
    $bits.Add("$(Format-Count $script:Saved 'file') saved")
    if ($script:Skipped -gt 0) { $bits.Add("$(Format-Count $script:Skipped 'video') skipped") }
    if ($script:Failed -gt 0) { $bits.Add("$(Format-Count $script:Failed 'video') failed") }
    $text = 'Finished. ' + ($bits -join ', ') + '.'
    if ($script:Failed -gt 0) {
        Set-Status $text 'err'
        Write-Activity $text 'warn'
    } else {
        Set-Progress 100
        Set-Status $text 'ok'
        Write-Activity $text 'ok'
    }
}

function Start-JobProcess($job) {
    $script:BatchFile = Join-Path $env:TEMP ("video-downloader-" + [guid]::NewGuid().ToString('n') + '.txt')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($script:BatchFile, $job.Urls.ToArray(), $utf8)
    $archive = $script:ArchiveFile
    $audioOnly = $false
    if ($script:AudioCheck -and $script:AudioCheck.Checked) {
        $archive = $script:AudioArchiveFile
        $audioOnly = $true
    }
    $clipStamp = ''
    $script:ClipPhase = ''
    $script:ClipSource = $null
    $script:ClipDuration = 0
    Remove-ClipTemp
    if ($script:ActiveClip -and $job.Key -ne 'collection') {
        $clipStamp = [string]$script:ActiveClip.Stamp
        $script:ClipPhase = 'download'
    }
    $script:JobStarted = Get-Date
    $argParts = Get-YtArguments -Key $job.Key -PlaylistFolders $script:FolderCheck.Checked -SkipExisting $script:SkipCheck.Checked -Destination $script:DownloadsDir -ArchiveFile $archive -BatchFile $script:BatchFile -Resolution (Get-SelectedResolution) -AudioOnly $audioOnly -ClipStamp $clipStamp -NoContinue:($script:ForbiddenRetries -gt 0)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:YtDlp
    $psi.Arguments = ConvertTo-CommandLine $argParts
    $psi.WorkingDirectory = $script:Root
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $utf8out = New-Object System.Text.UTF8Encoding $false
    $psi.StandardOutputEncoding = $utf8out
    $psi.StandardErrorEncoding = $utf8out
    $psi.EnvironmentVariables['PATH'] = $script:ToolsDir + ';' + $psi.EnvironmentVariables['PATH']
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $psi.EnvironmentVariables['PYTHONUNBUFFERED'] = '1'
    if ($script:DetailedCheck.Checked) {
        Write-Activity ('Command  ' + $psi.FileName + ' ' + $psi.Arguments) 'dim'
    }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true
    $script:Process = $proc
    $script:ExitSeen = $false
    $script:ExitGraceDone = $false
    $script:JobCleaned = $false
    $script:ExitCode = 0
    $script:JobHadError = $false
    $script:LivePercent = -1
    $script:LiveDetail = ''
    $script:CurrentName = ''
    $script:ItemIndex = 0
    $script:ItemCount = 0
    $script:RecentRaw = New-Object System.Collections.Generic.List[string]
    Ensure-OutputHandlers
    [VideoDownloader.YtLinePump]::BeginJob()
    $proc.add_OutputDataReceived($script:DataHandler)
    $proc.add_ErrorDataReceived($script:DataHandler)
    $proc.add_Exited($script:ExitHandler)
    [void]$proc.Start()
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()
}

function Start-NextJob {
    if ($script:CancelRequested) {
        Complete-Run $true
        return
    }
    $script:ForbiddenRetries = 0
    $jobs = @($script:Jobs)
    if ($null -eq $script:Jobs -or $script:JobPos -ge $jobs.Count) {
        Complete-Run $false
        return
    }
    $job = $jobs[$script:JobPos]
    $script:JobPos++
    Write-Activity (Get-JobLabel $job) 'text'
    Set-Status 'Looking up the videos...' 'busy'
    Set-Progress 0
    try {
        Start-JobProcess $job
    } catch {
        Write-Activity ('Could not start the downloader. ' + $_.Exception.Message) 'err'
        $script:Failed++
        $script:JobHadError = $true
        Remove-BatchFile
        Start-NextJob
    }
}

function Start-ClipCut {
    $source = [string]$script:ClipSource
    if (-not (Test-Path -LiteralPath $source)) {
        $script:Failed++
        Write-Activity 'The clip could not be cut because the download is missing.' 'err'
        return $false
    }
    $ext = [IO.Path]::GetExtension($source)
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.mp4' }
    $tempOut = $source + '.cutting' + $ext
    if (Test-Path -LiteralPath $tempOut) { Remove-Item -LiteralPath $tempOut -Force }
    $script:ClipTemp = $tempOut
    $start = 0.0
    if ($script:ActiveClip -and $null -ne $script:ActiveClip.StartSeconds) {
        $start = [double]$script:ActiveClip.StartSeconds
    }
    $end = $null
    if ($script:ActiveClip -and $null -ne $script:ActiveClip.EndSeconds) {
        $end = [double]$script:ActiveClip.EndSeconds
    }
    $media = Get-MediaDuration $source
    if ($null -ne $end) {
        $script:ClipDuration = $end - $start
    } elseif ($media -gt $start) {
        $script:ClipDuration = $media - $start
    } else {
        $script:ClipDuration = 0
    }
    if ($script:ClipDuration -lt 0) { $script:ClipDuration = 0 }
    $script:CurrentName = [IO.Path]::GetFileName($source)
    $argParts = Get-ClipCutArguments -InputPath $source -OutputPath $tempOut -StartSeconds $start -EndSeconds $end
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:Ffmpeg
    $psi.Arguments = ConvertTo-CommandLine $argParts
    $psi.WorkingDirectory = $script:Root
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $utf8out = New-Object System.Text.UTF8Encoding $false
    $psi.StandardOutputEncoding = $utf8out
    $psi.StandardErrorEncoding = $utf8out
    if ($script:DetailedCheck.Checked) {
        Write-Activity ('Command  ' + $psi.FileName + ' ' + $psi.Arguments) 'dim'
    }
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true
    $script:Process = $proc
    $script:ClipPhase = 'cut'
    $script:ExitSeen = $false
    $script:ExitGraceDone = $false
    $script:JobCleaned = $false
    $script:ExitCode = 0
    $script:LivePercent = -1
    $script:LiveDetail = ''
    $script:RecentRaw = New-Object System.Collections.Generic.List[string]
    Ensure-OutputHandlers
    [VideoDownloader.YtLinePump]::BeginJob()
    $proc.add_OutputDataReceived($script:DataHandler)
    $proc.add_ErrorDataReceived($script:DataHandler)
    $proc.add_Exited($script:ExitHandler)
    [void]$proc.Start()
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()
    Write-Activity 'Cutting video' 'text'
    Set-Status 'Cutting video' 'busy'
    Set-Progress 0
    return $true
}

function Complete-ClipCut([int]$code) {
    $temp = [string]$script:ClipTemp
    $source = [string]$script:ClipSource
    $ok = $false
    if ($code -eq 0 -and $temp -and (Test-Path -LiteralPath $temp)) {
        $len = (Get-Item -LiteralPath $temp).Length
        if ($len -ge 1024) { $ok = $true }
    }
    if (-not $ok) {
        Remove-ClipTemp
        $script:Failed++
        Write-Activity 'The clip could not be cut. The full download is still in the save folder.' 'err'
        if ($script:RecentRaw -and $script:RecentRaw.Count -gt 0) {
            $start = [Math]::Max(0, $script:RecentRaw.Count - 8)
            for ($i = $start; $i -lt $script:RecentRaw.Count; $i++) {
                Write-Activity $script:RecentRaw[$i] 'dim'
            }
        }
        return
    }
    $backup = $source + '.fulltmp'
    try {
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
        Move-Item -LiteralPath $source -Destination $backup
        Move-Item -LiteralPath $temp -Destination $source
        Remove-Item -LiteralPath $backup -Force
        $script:ClipTemp = $null
        Publish-SavedFile $source
    } catch {
        Remove-ClipTemp
        if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $source)) {
            Move-Item -LiteralPath $backup -Destination $source -Force
        }
        $script:Failed++
        Write-Activity ('The clip could not be saved. ' + $_.Exception.Message) 'err'
    }
}

function Finish-CurrentJob {
    $code = 0
    if ($null -ne $script:ExitCode) { $code = [int]$script:ExitCode }
    if ($script:Process) {
        try { $script:Process.Dispose() } catch { }
        $script:Process = $null
    }
    if ($script:ClipPhase -ne 'cut') { Remove-BatchFile }
    if ($script:CancelRequested) {
        Complete-Run $true
        return
    }
    if ($script:ClipPhase -eq 'cut') {
        Complete-ClipCut $code
        $script:ClipPhase = ''
        $script:ClipSource = $null
        Start-NextJob
        return
    }
    if ((Test-DownloadRefused) -and $script:ForbiddenRetries -lt 2) {
        if ($script:Failed -gt 0) { $script:Failed-- }
        $script:JobHadError = $false
        $script:ForbiddenRetries++
        Remove-RefusedPartials
        Write-Activity 'YouTube refused that download. Trying again.' 'warn'
        Set-Status 'Trying that download again...' 'busy'
        Set-Progress 0
        $jobs = @($script:Jobs)
        $job = $null
        if ($script:JobPos -gt 0 -and $script:JobPos -le $jobs.Count) {
            $job = $jobs[$script:JobPos - 1]
        }
        if ($null -ne $job) {
            try {
                Start-JobProcess $job
                return
            } catch {
                Write-Activity ('Could not try that download again. ' + $_.Exception.Message) 'err'
                $script:Failed++
                $script:JobHadError = $true
            }
        }
    }
    if ($code -ne 0 -and -not $script:JobHadError) {
        $script:Failed++
        Write-Activity "The downloader stopped with an error (code $code)." 'err'
        if ($script:RecentRaw -and $script:RecentRaw.Count -gt 0) {
            $start = [Math]::Max(0, $script:RecentRaw.Count - 12)
            for ($i = $start; $i -lt $script:RecentRaw.Count; $i++) {
                Write-Activity $script:RecentRaw[$i] 'dim'
            }
        }
    }
    if ($script:ClipPhase -eq 'download' -and $script:ClipSource) {
        $sourceOk = $false
        if (Test-Path -LiteralPath $script:ClipSource) {
            $sourceOk = ((Get-Item -LiteralPath $script:ClipSource).Length -ge 1024)
        }
        $clean = ($code -eq 0 -and -not $script:JobHadError -and $sourceOk)
        if ($clean -and (Test-ClipNeedsCut $script:ActiveClip)) {
            if (Start-ClipCut) { return }
        } elseif ($clean) {
            Publish-SavedFile $script:ClipSource
        } else {
            Write-Activity 'The clip was not cut.' 'warn'
        }
        $script:ClipSource = $null
        $script:ClipPhase = ''
    }
    Start-NextJob
}

function Invoke-DownloadTick {
    if ($script:InTick) { return }
    $script:InTick = $true
    try {
        if (-not $script:Running) { return }
        if ([VideoDownloader.YtLinePump]::Exited) {
            $script:ExitSeen = $true
            $script:ExitCode = [int][VideoDownloader.YtLinePump]::ExitCode
        }
        $pending = Read-PendingLines
        if ($null -ne $pending) {
            for ($i = 0; $i -lt $pending.Count; $i++) {
                $line = [string]$pending[$i]
                if (-not [string]::IsNullOrWhiteSpace($line)) { Receive-Line $line }
            }
        }
        Update-LiveProgress
        if ($script:ExitSeen) {
            $late = Read-PendingLines
            if ($null -ne $late) {
                for ($i = 0; $i -lt $late.Count; $i++) {
                    $line = [string]$late[$i]
                    if (-not [string]::IsNullOrWhiteSpace($line)) { Receive-Line $line }
                }
            }
            if (-not $script:ExitGraceDone) {
                $script:ExitGraceDone = $true
                return
            }
            if (-not $script:JobCleaned) {
                $script:JobCleaned = $true
                Finish-CurrentJob
            }
        } elseif ($script:CancelRequested -and $null -eq $script:Process) {
            Complete-Run $true
        }
    } catch {
        try { Write-Activity ('The window hit a problem. ' + $_.Exception.Message) 'err' } catch { }
    } finally {
        $script:InTick = $false
    }
}

function Set-Busy([bool]$busy) {
    $script:Running = $busy
    $canEdit = -not $busy
    $script:LinkBox.ReadOnly = $busy
    $script:PasteButton.Enabled = $canEdit
    $script:ClearButton.Enabled = $canEdit
    $script:LoadButton.Enabled = $canEdit
    $script:SaveButton.Enabled = $canEdit
    $script:FolderCheck.Enabled = $canEdit
    $script:SkipCheck.Enabled = $canEdit
    $script:AttachedCheck.Enabled = $canEdit
    $script:DownloadButton.Enabled = $canEdit -and $script:ToolsOk
    $script:CancelButton.Enabled = $busy
    if ($script:AudioCheck) { $script:AudioCheck.Enabled = $canEdit }
    if ($script:ClipStartBox) { $script:ClipStartBox.Enabled = $canEdit }
    if ($script:ClipEndBox) { $script:ClipEndBox.Enabled = $canEdit }
    if ($script:ChangeFolderButton) { $script:ChangeFolderButton.Enabled = $canEdit }
    Update-UpdateButtons
    Update-DownloadMode
    if ($busy) {
        $script:LinkBox.BackColor = [Drawing.Color]::FromArgb(249, 250, 251)
        $script:Form.Text = 'Video Beam - Downloading'
    } else {
        $script:LinkBox.BackColor = [Drawing.Color]::White
        $script:Form.Text = 'Video Beam'
    }
}

function Get-SelectedResolution {
    if (-not $script:ResolutionBox -or -not $script:ResolutionValues) { return 'best' }
    $index = [int]$script:ResolutionBox.SelectedIndex
    if ($index -lt 0 -or $index -ge @($script:ResolutionValues).Count) { return 'best' }
    return [string]$script:ResolutionValues[$index]
}

function Update-DownloadMode {
    $audio = $false
    if ($script:AudioCheck) { $audio = [bool]$script:AudioCheck.Checked }
    $editable = -not $script:Running
    if ($script:ResolutionBox) { $script:ResolutionBox.Enabled = $editable -and -not $audio }
    if ($script:ResolutionLabel) { $script:ResolutionLabel.Enabled = $editable -and -not $audio }
    if ($script:SubtitleLabel) {
        $folderName = Get-SaveFolderName
        if ($audio) {
            $script:SubtitleLabel.Text = "Paste a video or playlist link. Each download is saved as an MP3 in $folderName."
        } else {
            $script:SubtitleLabel.Text = "Paste a video or playlist link. Each download is saved as an MP4 in $folderName."
        }
    }
}

function Add-LinkText([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $text = $text.Trim()
    if ([string]::IsNullOrWhiteSpace($script:LinkBox.Text)) {
        $script:LinkBox.Text = $text
    } else {
        $script:LinkBox.Text = $script:LinkBox.Text.TrimEnd() + [Environment]::NewLine + $text
    }
}

function Read-DroppedFile([string]$path) {
    $item = Get-Item -LiteralPath $path
    if ($item.Length -gt 2MB) {
        Write-Activity "Skipped a dropped file larger than 2 MB: $($item.Name)" 'warn'
        return
    }
    $ext = $item.Extension.ToLowerInvariant()
    if ($ext -ne '.txt' -and $ext -ne '.url') {
        Write-Activity "Skipped $($item.Name). Drop a link or a .txt list." 'warn'
        return
    }
    $text = [IO.File]::ReadAllText($path)
    if ($ext -eq '.url' -and $text -match '(?m)^URL=(.+)$') {
        Add-LinkText $Matches[1].Trim()
        return
    }
    Add-LinkText $text
}

function Add-DroppedData($data) {
    if ($script:Running) { return }
    if ($data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        $files = @($data.GetData([Windows.Forms.DataFormats]::FileDrop))
        foreach ($file in $files) { Read-DroppedFile $file }
        return
    }
    $payload = $null
    if ($data.GetDataPresent([Windows.Forms.DataFormats]::UnicodeText)) {
        $payload = [string]$data.GetData([Windows.Forms.DataFormats]::UnicodeText)
    } elseif ($data.GetDataPresent([Windows.Forms.DataFormats]::Text)) {
        $payload = [string]$data.GetData([Windows.Forms.DataFormats]::Text)
    }
    if ($payload) { Add-LinkText $payload }
}

function Request-Cancel {
    if (-not $script:Running) { return }
    $script:CancelRequested = $true
    Set-Status 'Stopping...' 'busy'
    Stop-DownloadProcess
}

function Start-Download {
    if ($script:Running) { return }
    $missing = @(Get-MissingTools)
    if ($missing.Count -gt 0) {
        $text = "The downloader tools are missing:`r`n`r`n" + ($missing -join "`r`n")
        [Windows.Forms.MessageBox]::Show($text, 'Video Beam', 'OK', 'Error') | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($script:LinkBox.Text)) {
        [Windows.Forms.MessageBox]::Show("Add at least one link.`r`n`r`nA video:`r`nhttps://example.com/video/123`r`n`r`nA playlist:`r`nhttps://example.com/playlist/abc", 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    $parsed = Get-LinksFromText $script:LinkBox.Text $script:AttachedCheck.Checked
    $items = $parsed.Items
    if ($parsed.Invalid.Count -gt 0 -and $items.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show("None of these lines are web links.`r`n`r`nPaste a full link, one per line.", 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    if ($parsed.Invalid.Count -gt 0) {
        $shown = @($parsed.Invalid | Select-Object -First 6)
        $extra = ''
        if ($parsed.Invalid.Count -gt 6) { $extra = "`r`n...and $($parsed.Invalid.Count - 6) more" }
        $ask = "Some lines are not web links:`r`n`r`n" + ($shown -join "`r`n") + $extra + "`r`n`r`nDownload the links that are ready?"
        $answer = [Windows.Forms.MessageBox]::Show($ask, 'Video Beam', 'YesNo', 'Question')
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    }
    $channels = @($items | Where-Object { $_.Kind -eq 'channel' })
    if ($channels.Count -gt 0) {
        $shown = @($channels | Select-Object -First 6 | ForEach-Object { $_.Url })
        $extra = ''
        if ($channels.Count -gt 6) { $extra = "`r`nand $($channels.Count - 6) more" }
        $ask = "These links look like channels. A channel can contain a large number of videos.`r`n`r`n" + ($shown -join "`r`n") + $extra + "`r`n`r`nDownload the channels along with any other links?"
        $answer = [Windows.Forms.MessageBox]::Show($ask, 'Video Beam', 'YesNoCancel', 'Question')
        if ($answer -eq [Windows.Forms.DialogResult]::Cancel) { return }
        if ($answer -eq [Windows.Forms.DialogResult]::No) {
            $kept = New-Object System.Collections.Generic.List[object]
            foreach ($item in $items) {
                if ($item.Kind -ne 'channel') { $kept.Add($item) }
            }
            $items = $kept
        }
    }
    if ($null -eq $items -or $items.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show('No links left to download.', 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    $blockedSites = @(Get-BlockedSites)
    $allowed = New-Object System.Collections.Generic.List[object]
    $blocked = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        if (Test-BlockedUrl $item.Url $blockedSites) { [void]$blocked.Add([string]$item.Url) }
        else { [void]$allowed.Add($item) }
    }
    if ($blocked.Count -gt 0) {
        [Windows.Forms.MessageBox]::Show('site is blocked', 'Video Beam', 'OK', 'Information') | Out-Null
        if ($allowed.Count -eq 0) { return }
        $items = $allowed
    }
    if (-not (Test-Path -LiteralPath $script:DownloadsDir)) {
        New-Item -ItemType Directory -Path $script:DownloadsDir | Out-Null
    }
    $clip = Get-ClipRequest
    if (-not $clip.Ok) {
        [Windows.Forms.MessageBox]::Show($clip.Message, 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    $script:ActiveClip = $null
    if ($clip.Active) {
        $oneVideo = ($items.Count -eq 1 -and ($items[0].Kind -eq 'video' -or $items[0].Kind -eq 'open'))
        if ($oneVideo) {
            $script:ActiveClip = $clip
        } else {
            Write-Activity 'Clip times apply to one video link. This download will save the full files.' 'warn'
        }
    }
    $script:Jobs = Build-Jobs $items
    $script:JobPos = 0
    $script:Saved = 0
    $script:Skipped = 0
    $script:Failed = 0
    $script:CancelRequested = $false
    $script:ForbiddenRetries = 0
    $script:LivePercent = -1
    $script:Process = $null
    Set-Busy $true
    Set-Progress 0
    Write-Activity '--------' 'dim'
    Write-Activity 'Starting download.' 'text'
    if ($script:ActiveClip) {
        Write-Activity ("Saving a clip from $($script:ActiveClip.StartLabel) to $($script:ActiveClip.EndLabel). The full video downloads first, then it is cut.") 'text'
    }
    if ($parsed.DuplicateCount -gt 0) {
        Write-Activity ("Left out $(Format-Count $parsed.DuplicateCount 'duplicate link').") 'dim'
    }
    Start-NextJob
}

function Choose-DownloadsFolder {
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose where new videos and MP3s are saved'
    $dlg.ShowNewFolderButton = $true
    if (Test-Path -LiteralPath $script:DownloadsDir) {
        $dlg.SelectedPath = $script:DownloadsDir
    } else {
        $dlg.SelectedPath = $script:DefaultDownloadsDir
    }
    if ($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
    $chosen = Resolve-DownloadsFolder $dlg.SelectedPath
    if ($chosen -ne $dlg.SelectedPath -and $chosen -eq $script:DefaultDownloadsDir) {
        [Windows.Forms.MessageBox]::Show('That folder cannot be used. New files will stay in the current folder.', 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    $script:DownloadsDir = $chosen
    if ($script:DownloadsPathBox) { $script:DownloadsPathBox.Text = $chosen }
    Update-DownloadMode
    Save-Settings
    Write-Activity ("New downloads will be saved to $chosen") 'text'
}

function Open-DownloadsFolder {
    if (-not (Test-Path -LiteralPath $script:DownloadsDir)) {
        New-Item -ItemType Directory -Path $script:DownloadsDir | Out-Null
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'explorer.exe'
    $psi.Arguments = '/e,"' + $script:DownloadsDir + '"'
    $psi.UseShellExecute = $true
    [void][Diagnostics.Process]::Start($psi)
}

function Paste-Links {
    if (-not [Windows.Forms.Clipboard]::ContainsText()) {
        [Windows.Forms.MessageBox]::Show('The clipboard does not have any text to paste.', 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    Add-LinkText ([Windows.Forms.Clipboard]::GetText())
}

function Load-ListFile {
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = 'Open a list of links'
    $dlg.Filter = 'Text files (*.txt)|*.txt|All files (*.*)|*.*'
    $dlg.InitialDirectory = $script:ListsDir
    if ($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
    $text = [IO.File]::ReadAllText($dlg.FileName)
    if (-not [string]::IsNullOrWhiteSpace($script:LinkBox.Text)) {
        $answer = [Windows.Forms.MessageBox]::Show("Add these links below the ones already in the box?`r`n`r`nYes adds them. No replaces the box.", 'Video Beam', 'YesNoCancel', 'Question')
        if ($answer -eq [Windows.Forms.DialogResult]::Cancel) { return }
        if ($answer -eq [Windows.Forms.DialogResult]::No) { $script:LinkBox.Clear() }
    }
    Add-LinkText $text
}

function Save-ListFile {
    if ([string]::IsNullOrWhiteSpace($script:LinkBox.Text)) {
        [Windows.Forms.MessageBox]::Show('There are no links to save.', 'Video Beam', 'OK', 'Information') | Out-Null
        return
    }
    $dlg = New-Object Windows.Forms.SaveFileDialog
    $dlg.Title = 'Save this list'
    $dlg.Filter = 'Text files (*.txt)|*.txt'
    $dlg.InitialDirectory = $script:ListsDir
    $dlg.FileName = 'my-links.txt'
    $dlg.OverwritePrompt = $true
    if ($dlg.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [IO.File]::WriteAllText($dlg.FileName, $script:LinkBox.Text.Trim() + [Environment]::NewLine, $utf8)
    Write-Activity ("Saved the list to " + [IO.Path]::GetFileName($dlg.FileName)) 'ok'
}

function Get-HelpSections {
    $downloads = $script:DownloadsDir
    $history = $script:ArchiveFile
    $audioHistory = $script:AudioArchiveFile
    $license = Join-Path $script:ToolsDir 'FFmpeg-LICENSE.txt'
    return @(
        @{
            Title = 'Opening the program'
            Body = "Double-click Video Beam in this folder. The window that opens is the whole program.`r`n`r`nIf you move this folder and that shortcut stops opening, open app\launch.vbs. That starts the program and repairs the shortcut."
        },
        @{
            Title = 'Adding links'
            Body = "Paste one or more links into the box, one per line. You can mix video links and playlist links. Blank lines are ignored.`r`n`r`nLoad a list reads a text file of links. Save this list writes the box to a text file you can open later. You can also drop a link, or a .txt file, onto the box.`r`n`r`nCtrl+Enter starts the download."
        },
        @{
            Title = 'Videos, playlists, and channels'
            Body = "A link to one video downloads that video. A link to a playlist downloads every video in the playlist, in playlist order.`r`n`r`nYouTube often adds a playlist to the end of a video link. Those links still download as a single video. Turn on `"Download the playlist attached to a video link`" only when you want every video in that attached playlist.`r`n`r`nA channel link can contain a large number of videos. The program asks before downloading one.`r`n`r`nLinks from other sites work too, when the downloader supports that site."
        },
        @{
            Title = 'Where the files go'
            Body = "Videos are saved as MP4 files in:`r`n`r`n$downloads`r`n`r`nChange, next to that folder path, picks a different place. The choice is remembered the next time you open the program. Files already saved stay where they are.`r`n`r`nTurn on `"Audio only, save as MP3`" to save the soundtrack instead, in that same folder. Turn on `"Save each playlist into its own folder`" to put a playlist's files in a folder named after the playlist. Single videos stay directly in the chosen folder.`r`n`r`nOpen Downloads shows this folder in File Explorer."
        },
        @{
            Title = 'Picture size and audio only'
            Body = "Resolution is used when a video offers more than one picture size. Best available keeps the usual choice: the best MP4 that plays in ordinary video players. Pick a size such as 1080p or 720p to prefer that size. If the video does not offer it, the closest size that does exist is used. A video with only one size is downloaded as it is.`r`n`r`nAudio only, save as MP3 keeps the soundtrack and does not save a picture. The file is a high-quality MP3. Videos you already saved are not replaced.`r`n`r`nClip start and Clip end save part of one video. Type the time as m:ss, such as 1:30. For an hour or more, type 1:02:05. A plain number such as 90 means 90 seconds. Leave the start blank to begin at the beginning. Leave the end blank to continue to the end of the video. The times are used only when the box has one video link. A playlist or several links are saved in full, and the activity box says so. The full video downloads first, then the clip is cut to the times you typed. The clip's file name includes the times, so a full copy of that video stays where it is."
        },
        @{
            Title = 'What is inside the MP4'
            Body = "The video and the audio are saved together in one file. The program prefers a format that plays in ordinary video players, and repackages other formats into MP4 when it needs to.`r`n`r`nThe file name is the video title plus a short id, so two videos with the same title do not overwrite each other. When the site provides a post date, that date is used as the file date."
        },
        @{
            Title = 'Skipping videos you already have'
            Body = "Turn on `"Skip videos you have already downloaded`" to remember each finished video in:`r`n`r`n$history`r`n`r`nMP3 downloads are remembered separately, in:`r`n`r`n$audioHistory`r`n`r`nSaving an MP3 does not skip the video, and saving a video does not skip the MP3. Uncheck the option to download something again. The history keeps an item even after you delete the file. Delete the matching history file as well when you want that item downloaded again."
        },
        @{
            Title = 'Progress, problems, and stopping'
            Body = "The line under the buttons names the current video. The bar shows how much of that file has downloaded. The activity box lists saved files, skipped videos, and problems.`r`n`r`nShow detailed activity adds the downloader's own technical messages. Turn it on when a video will not download and you want the full reason.`r`n`r`nCancel, or the Esc key, stops the download. Videos that already finished stay in Downloads. A half-finished video continues the next time you download that link.`r`n`r`nPrivate, deleted, region-locked, or age-restricted videos are reported in the activity box, and the rest of the list continues. This program downloads publicly available videos. A video that asks for a login will usually fail."
        },
        @{
            Title = 'Updates'
            Body = "The bottom right corner shows this copy's version. The program checks for a newer version when it opens. Check for updates looks again. When a newer version is found, a window tells you once. Closing that window keeps it from opening again until a later version is published. The status line keeps saying that version is available. Update downloads it and opens the setup program. The setup replaces the installed copy and keeps your settings.`r`n`r`nFinish or cancel the current download before you update. The program closes while the setup runs, then you can open it again."
        },
        @{
            Title = 'What is in this folder'
            Body = "Video Beam: double-click this to open the program.`r`napp: the program, your settings, the download history, and blocked-sites.md. Blocked sites opens that file. A site listed there is not downloaded.`r`ntools: yt-dlp, which fetches the videos, FFmpeg, which packages them as MP4 or MP3, and Deno, which lets YouTube offer its full list of sizes. FFmpeg is free software. Its license is $license.`r`ndownloads: your files.`r`nsaved-lists: link lists you save. links.txt is the list that was already in this folder."
        }
    )
}

function Add-HelpHeading($box, [string]$text) {
    if ($box.TextLength -gt 0) {
        $box.SelectionStart = $box.TextLength
        $box.SelectionLength = 0
        $box.SelectionFont = $script:FontHelpBody
        $box.SelectionColor = $script:ColorBody
        $box.AppendText([Environment]::NewLine)
    }
    $box.SelectionStart = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionFont = $script:FontHelpHeading
    $box.SelectionColor = $script:ColorInk
    $box.AppendText($text + [Environment]::NewLine)
}

function Add-HelpBody($box, [string]$text) {
    $box.SelectionStart = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionFont = $script:FontHelpBody
    $box.SelectionColor = $script:ColorBody
    $box.AppendText($text.Trim() + [Environment]::NewLine)
}

function New-HelpForm {
    $help = New-Object Windows.Forms.Form
    $help.Text = 'How this works'
    $help.StartPosition = 'CenterParent'
    $help.Font = $script:FontUi
    $help.BackColor = [Drawing.Color]::White
    $help.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $help.MinimizeBox = $false
    $help.MaximizeBox = $true
    $help.ShowInTaskbar = $false
    $help.KeyPreview = $true
    $area = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w = [Math]::Min(760, $area.Width - 40)
    $h = [Math]::Min(820, $area.Height - 40)
    $help.ClientSize = New-Object Drawing.Size($w, $h)
    $help.MinimumSize = New-Object Drawing.Size([Math]::Min(640, $area.Width), [Math]::Min(480, $area.Height))
    $icon = Get-AppIcon
    if ($icon) { $help.Icon = $icon }
    Enable-DoubleBuffer $help

    $header = New-Object Windows.Forms.Panel
    $header.Dock = 'Top'
    $header.Height = 92
    $header.BackColor = $script:ColorHeader
    $title = New-Object Windows.Forms.Label
    $title.Text = 'How this works'
    $title.Font = $script:FontTitle
    $title.ForeColor = [Drawing.Color]::White
    $title.BackColor = $script:ColorHeader
    $title.AutoSize = $false
    $sub = New-Object Windows.Forms.Label
    $sub.Text = 'Links, folders, skipping, and what is in this folder.'
    $sub.Font = $script:FontSubtitle
    $sub.ForeColor = $script:ColorHeaderMuted
    $sub.BackColor = $script:ColorHeader
    $sub.AutoSize = $false
    $header.Controls.Add($title)
    $header.Controls.Add($sub)
    $header.Tag = @{ Title = $title; Sub = $sub }
    $header.Add_Resize({
        $this.Tag.Title.SetBounds(28, 16, ($this.ClientSize.Width - 56), 36)
        $this.Tag.Sub.SetBounds(28, 54, ($this.ClientSize.Width - 56), 24)
    })

    $footer = New-Object Windows.Forms.Panel
    $footer.Dock = 'Bottom'
    $footer.Height = 64
    $footer.BackColor = $script:ColorPage
    $close = New-Button 'Close' 'secondary' 110 34
    $footer.Controls.Add($close)
    $footer.Tag = $close
    $footer.Add_Resize({
        $button = $this.Tag
        $button.Location = New-Object Drawing.Point(($this.ClientSize.Width - $button.Width - 24), 14)
    })
    $footer.Add_Paint({
        $pen = New-Object Drawing.Pen $script:ColorLine
        $_.Graphics.DrawLine($pen, 0, 0, $this.Width, 0)
        $pen.Dispose()
    })
    $close.Add_Click({ $script:HelpForm.Close() })
    Set-Tip $close 'Close this guide. Esc does this too.'

    $bodyHost = New-Object Windows.Forms.Panel
    $bodyHost.Dock = 'Fill'
    $bodyHost.BackColor = [Drawing.Color]::White
    $bodyHost.Padding = New-Object Windows.Forms.Padding(24, 12, 12, 8)
    $box = New-Object Windows.Forms.RichTextBox
    $box.Dock = 'Fill'
    $box.BorderStyle = 'None'
    $box.ReadOnly = $true
    $box.BackColor = [Drawing.Color]::White
    $box.Font = $script:FontHelpBody
    $box.DetectUrls = $false
    $box.ScrollBars = 'Vertical'
    $box.ShortcutsEnabled = $true
    $bodyHost.Controls.Add($box)
    foreach ($section in (Get-HelpSections)) {
        Add-HelpHeading $box $section.Title
        Add-HelpBody $box $section.Body
    }
    $box.SelectionStart = 0
    $box.SelectionLength = 0
    $script:HelpBox = $box

    $help.Controls.Add($bodyHost)
    $help.Controls.Add($footer)
    $help.Controls.Add($header)
    $help.Add_KeyDown({
        if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) {
            $script:HelpForm.Close()
            $_.SuppressKeyPress = $true
        }
    })
    $help.Add_FormClosed({ $script:HelpForm = $null })
    $header.PerformLayout()
    return $help
}

function Show-Help {
    if ($script:HelpForm -and -not $script:HelpForm.IsDisposed) {
        $script:HelpForm.Activate()
        return
    }
    $script:HelpForm = New-HelpForm
    [void]$script:HelpForm.Show($script:Form)
}

function Write-Welcome {
    Write-Activity 'Ready. Paste a video or playlist link, then click Download.' 'text'
    Write-Activity 'A playlist link downloads every video in the playlist. A video link downloads only that video.' 'text'
    $oldList = Join-Path $script:ListsDir 'links.txt'
    if ((Test-Path -LiteralPath $oldList) -and -not $script:SeenWelcome) {
        Write-Activity 'An older link list is saved at saved-lists\links.txt. Use Load a list to open it.' 'dim'
        $script:SeenWelcome = $true
        Save-Settings
    }
}

function Warn-MissingTools {
    $missing = @(Get-MissingTools)
    if ($missing.Count -eq 0) {
        $script:ToolsOk = $true
        return
    }
    $script:ToolsOk = $false
    $text = "The downloader tools are missing:`r`n" + ($missing -join "`r`n")
    Write-Activity $text 'err'
    if (-not $script:SmokeTest) {
        [Windows.Forms.MessageBox]::Show($text, 'Video Beam', 'OK', 'Error') | Out-Null
    }
}

function Test-UpdateBusy {
    return [bool]$script:Running
}

function Remove-VersionPrefix([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $clean = $text.Trim()
    if (($clean.StartsWith('v') -or $clean.StartsWith('V')) -and $clean.Length -gt 1) {
        $rest = $clean.Substring(1)
        if ($rest -match '^\d+\.\d+\.\d+$') { return $rest }
    }
    return $clean
}

function ConvertTo-VersionNumbers([string]$text) {
    $clean = ''
    if ($null -ne $text) { $clean = $text.Trim() }
    if ($clean -match '^(\d+)\.(\d+)\.(\d+)$') {
        $numbers = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
        return ,$numbers
    }
    return $null
}

function Compare-AppVersion([string]$left, [string]$right) {
    $a = ConvertTo-VersionNumbers (Remove-VersionPrefix $left)
    $b = ConvertTo-VersionNumbers (Remove-VersionPrefix $right)
    if ($null -eq $a -or $null -eq $b) { return $null }
    for ($i = 0; $i -lt 3; $i++) {
        if ($a[$i] -gt $b[$i]) { return 1 }
        if ($a[$i] -lt $b[$i]) { return -1 }
    }
    return 0
}

function Get-AppVersion {
    $path = Join-Path $script:AppDir 'version.txt'
    if (Test-Path -LiteralPath $path) {
        $text = ''
        try { $text = [IO.File]::ReadAllText($path).Trim() } catch { $text = '' }
        if ($text -match '^\d+\.\d+\.\d+$') { return $text }
    }
    return [string]$script:UpdateFallback
}

function Test-InstalledCopy {
    $programs = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
    if (-not $programs.EndsWith('\')) { $programs = $programs + '\' }
    $root = [IO.Path]::GetFullPath($script:Root)
    if (-not $root.EndsWith('\')) { $root = $root + '\' }
    return $root.StartsWith($programs, [StringComparison]::OrdinalIgnoreCase)
}

function Get-WindowsLabel {
    $build = 0
    try {
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        [void][int]::TryParse([string]$cv.CurrentBuild, [ref]$build)
    } catch { }
    $name = 'Windows'
    if ($build -ge 22000) { $name = 'Windows 11' }
    elseif ($build -ge 10240) { $name = 'Windows 10' }
    if ($build -gt 0) { return "$name (build $build)" }
    return $name
}

function Get-LatestActivityText {
    param([int]$MaxEncoded = 4500)
    if ($null -eq $script:Log) { return '' }
    $raw = [string]$script:Log.Text
    if ([string]::IsNullOrWhiteSpace($raw)) { return '' }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($raw -split '\r?\n')) {
        if ($line -ne '') { [void]$lines.Add($line) }
    }
    if ($lines.Count -eq 0) { return '' }
    $kept = New-Object System.Collections.Generic.List[string]
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $candidate = New-Object System.Collections.Generic.List[string]
        [void]$candidate.Add([string]$lines[$i])
        foreach ($older in $kept) { [void]$candidate.Add([string]$older) }
        $text = [string]::Join("`n", $candidate.ToArray())
        if (([uri]::EscapeDataString($text)).Length -le $MaxEncoded) {
            $kept.Insert(0, [string]$lines[$i])
            continue
        }
        if ($kept.Count -eq 0) {
            $line = [string]$lines[$i]
            $low = 0
            $high = $line.Length
            while ($low -lt $high) {
                $mid = [int](($low + $high + 1) / 2)
                $slice = $line.Substring($line.Length - $mid)
                if (([uri]::EscapeDataString($slice)).Length -le $MaxEncoded) { $low = $mid } else { $high = $mid - 1 }
            }
            if ($low -gt 0) { return $line.Substring($line.Length - $low) }
        }
        break
    }
    if ($kept.Count -eq 0) { return '' }
    return [string]::Join("`n", $kept.ToArray())
}

function Get-BugReportUrl {
    param([string]$Activity = '')
    $version = [uri]::EscapeDataString((Get-AppVersion))
    $windows = [uri]::EscapeDataString((Get-WindowsLabel))
    $url = "https://github.com/philipvern-dot/video_beam/issues/new?template=bug_report.yml&version=$version&windows=$windows"
    if (-not [string]::IsNullOrWhiteSpace($Activity)) {
        $url = $url + '&activity=' + [uri]::EscapeDataString($Activity)
    }
    return $url
}

function Open-HttpLink([string]$Url) {
    $allowed = $false
    if ($Url -eq 'https://ko-fi.com/philipvern') { $allowed = $true }
    elseif ($Url.StartsWith('https://github.com/philipvern-dot/video_beam/issues/new?')) { $allowed = $true }
    if (-not $allowed) { return }
    Start-Process $Url
}

function Show-BugReport {
    $form = New-Object Windows.Forms.Form
    $form.Text = 'Video Beam'
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $form.StartPosition = 'CenterParent'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $false
    $form.ClientSize = New-Object Drawing.Size(520, 262)
    $form.Font = $script:FontUi
    $form.BackColor = [Drawing.Color]::White
    $icon = Get-AppIcon
    if ($icon) { $form.Icon = $icon }
    $label = New-Object Windows.Forms.Label
    $label.Font = $script:FontUi
    $label.ForeColor = $script:ColorInk
    $label.BackColor = [Drawing.Color]::White
    $label.SetBounds(24, 16, 472, 128)
    $label.Text = "Report a bug opens a GitHub page. This version and the Windows version are filled in. Nothing else is added unless you check the box.`r`n`r`nInclude latest activity adds the latest lines from the activity box to that page. Those lines can include folder paths. This program does not send the report. You submit it on the GitHub page."
    $include = New-Check 'Include latest activity'
    $include.Checked = $false
    $include.Enabled = -not [string]::IsNullOrWhiteSpace((Get-LatestActivityText))
    $include.SetBounds(24, 156, 280, 24)
    $open = New-Button 'Open report' 'primary' 140 34
    $cancel = New-Button 'Cancel' 'secondary' 110 34
    $open.SetBounds(238, 204, 140, 34)
    $cancel.SetBounds(386, 204, 110, 34)
    Set-Tip $open 'Open the GitHub page with this version filled in.'
    Set-Tip $cancel 'Close this window without opening GitHub.'
    $form.Controls.Add($label)
    $form.Controls.Add($include)
    $form.Controls.Add($open)
    $form.Controls.Add($cancel)
    $state = [pscustomobject]@{ Open = $false; Include = $false }
    $open.DialogResult = [Windows.Forms.DialogResult]::OK
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $form.AcceptButton = $open
    $form.CancelButton = $cancel
    $open.Add_Click({ $state.Open = $true; $state.Include = [bool]$include.Checked }.GetNewClosure())
    try { [void]$form.ShowDialog($script:Form) }
    finally { $form.Dispose() }
    if (-not $state.Open) { return }
    $activity = ''
    if ($state.Include) { $activity = Get-LatestActivityText }
    Open-HttpLink (Get-BugReportUrl $activity)
}

function Update-UpdateButtons {
    $busy = Test-UpdateBusy
    if ($script:CheckUpdateButton) { $script:CheckUpdateButton.Enabled = -not $busy }
    if ($script:UpdateButton) {
        $ready = (-not $busy) -and ($null -ne $script:UpdateOffer) -and [bool]$script:UpdateOffer.Newer
        $script:UpdateButton.Enabled = $ready
    }
}

function Get-UpdateOffer($release) {
    $remote = Remove-VersionPrefix ([string]$release.tag_name)
    $cmp = Compare-AppVersion $remote (Get-AppVersion)
    $asset = $null
    foreach ($want in @($script:UpdateAsset, 'video_downloader.exe')) {
        foreach ($item in @($release.assets)) {
            if ($null -eq $item) { continue }
            if ([string]$item.name -eq $want) { $asset = $item; break }
        }
        if ($null -ne $asset) { break }
    }
    $result = [pscustomobject]@{
        Newer = $false
        Version = $remote
        Url = ''
        Size = [int64]0
        Message = ''
        Kind = 'idle'
    }
    if ($null -eq $cmp) {
        $result.Message = 'The latest release has no version number.'
        $result.Kind = 'err'
        return $result
    }
    $url = ''
    $size = [int64]0
    if ($null -ne $asset) {
        $url = [string]$asset.browser_download_url
        try { $size = [int64]$asset.size } catch { $size = 0 }
    }
    if ([string]::IsNullOrWhiteSpace($url) -or $size -le 0 -or $url -notmatch '^https://github\.com/philipvern-dot/') {
        $result.Message = 'The latest release does not include the setup program.'
        $result.Kind = 'err'
        return $result
    }
    if ($cmp -le 0) {
        $result.Message = 'You have the latest version (' + (Get-AppVersion) + ').'
        $result.Kind = 'ok'
        return $result
    }
    $result.Newer = $true
    $result.Url = $url
    $result.Size = $size
    $result.Message = 'Version ' + $remote + ' is available.'
    $result.Kind = 'ok'
    return $result
}

function Test-UpdatePromptDue($offer) {
    if ($null -eq $offer -or -not $offer.Newer) { return $false }
    return ([string]$script:UpdatePrompt -ne [string]$offer.Version)
}

function Remember-UpdatePrompt([string]$version) {
    $script:UpdatePrompt = [string]$version
    Save-Settings
}

function Show-UpdateReady($offer) {
    if ($script:SmokeTest -or -not (Test-UpdatePromptDue $offer)) { return }
    [Windows.Forms.MessageBox]::Show($script:Form, "Version $($offer.Version) is available.`r`n`r`nClick Update to install it.", 'Video Beam', 'OK', 'Information') | Out-Null
    Remember-UpdatePrompt $offer.Version
}

function Apply-UpdateOffer($offer) {
    if ($offer.Newer) { $script:UpdateOffer = $offer } else { $script:UpdateOffer = $null }
    Update-UpdateButtons
    Set-Status $offer.Message $offer.Kind
    $kind = 'dim'
    if ($offer.Kind -eq 'err') { $kind = 'err' }
    elseif ($offer.Newer) { $kind = 'ok' }
    Write-Activity $offer.Message $kind
    if ($offer.Newer) { Show-UpdateReady $offer }
}

function Start-UpdateCheck {
    if (Test-UpdateBusy) {
        [Windows.Forms.MessageBox]::Show($script:Form, 'Finish or cancel the current job before checking for updates.', $script:UpdateProduct, 'OK', 'Information') | Out-Null
        return
    }
    $script:UpdateOffer = $null
    Update-UpdateButtons
    Set-Status 'Checking for updates...' 'busy'
    $script:Form.Cursor = [Windows.Forms.Cursors]::WaitCursor
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $url = 'https://api.github.com/repos/philipvern-dot/' + $script:UpdateRepo + '/releases/latest'
        $headers = @{ 'User-Agent' = $script:UpdateProduct; 'Accept' = 'application/vnd.github+json' }
        $release = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        Apply-UpdateOffer (Get-UpdateOffer $release)
    } catch {
        $script:UpdateOffer = $null
        Update-UpdateButtons
        $status = 0
        try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        if ($status -eq 404) { $message = 'No published update was found.' }
        else { $message = 'Could not reach GitHub to check for updates.' }
        Set-Status $message 'err'
        Write-Activity $message 'err'
    } finally {
        $script:Form.Cursor = [Windows.Forms.Cursors]::Default
    }
}

function Receive-SetupFile([string]$url, [string]$dest, [int64]$expected) {
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $client = New-Object Net.WebClient
    $client.Headers['User-Agent'] = $script:UpdateProduct
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = 'Update'
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.ClientSize = New-Object Drawing.Size(420, 128)
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ControlBox = $false
    $dialog.Font = $script:FontUi
    $label = New-Object Windows.Forms.Label
    $label.Text = 'Downloading the update...'
    $label.SetBounds(20, 18, 380, 24)
    $bar = New-Object Windows.Forms.ProgressBar
    $bar.SetBounds(20, 50, 380, 22)
    $bar.Minimum = 0
    $bar.Maximum = 100
    $cancel = New-Button 'Cancel' 'secondary' 100 32
    $cancel.SetBounds(300, 82, 100, 32)
    $dialog.Controls.Add($label)
    $dialog.Controls.Add($bar)
    $dialog.Controls.Add($cancel)
    $state = New-Object psobject -Property @{ Done = $false; Error = $null; Cancelled = $false }
    $client.add_DownloadProgressChanged({
        try {
            $pct = [int]$args[1].ProgressPercentage
            if ($pct -lt 0) { $pct = 0 }
            if ($pct -gt 100) { $pct = 100 }
            $bar.Value = $pct
            $label.Text = 'Downloading the update... ' + $pct + '%'
        } catch { }
    })
    $client.add_DownloadFileCompleted({
        $state.Done = $true
        if ($args[1].Cancelled) { $state.Cancelled = $true }
        elseif ($args[1].Error) { $state.Error = $args[1].Error }
        try { if (-not $dialog.IsDisposed) { $dialog.Close() } } catch { }
    })
    $cancel.Add_Click({
        $state.Cancelled = $true
        try { $client.CancelAsync() } catch { }
    })
    $dialog.Add_Shown({
        try { $client.DownloadFileAsync([Uri]$url, $dest) }
        catch {
            $state.Done = $true
            $state.Error = $_.Exception
            try { $dialog.Close() } catch { }
        }
    })
    [void]$dialog.ShowDialog($script:Form)
    $client.Dispose()
    if ($state.Cancelled) {
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue }
        Set-Status 'Update cancelled.' 'idle'
        Write-Activity 'Update cancelled.' 'dim'
        return $false
    }
    if ($state.Error -or -not (Test-Path -LiteralPath $dest)) {
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue }
        Set-Status 'The download did not finish.' 'err'
        Write-Activity 'The download did not finish.' 'err'
        return $false
    }
    $got = [int64](Get-Item -LiteralPath $dest).Length
    if ($expected -gt 0 -and $got -ne $expected) {
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        Set-Status 'The download did not match the size published on GitHub.' 'err'
        Write-Activity ('The download was ' + $got + ' bytes. GitHub published ' + $expected + ' bytes.') 'err'
        return $false
    }
    return $true
}

function Start-UpdateInstall {
    if (Test-UpdateBusy) {
        [Windows.Forms.MessageBox]::Show($script:Form, 'Finish or cancel the current job before updating.', $script:UpdateProduct, 'OK', 'Information') | Out-Null
        return
    }
    $offer = $script:UpdateOffer
    if ($null -eq $offer -or -not $offer.Newer) { return }
    $prompt = 'Version ' + $offer.Version + ' is ready to install. This window will close and the setup program will open.'
    if (-not (Test-InstalledCopy)) {
        $prompt = 'Version ' + $offer.Version + ' is ready to install. This folder was not installed by the setup program, so the setup installs the new version for this Windows user and leaves this folder as it is. This window will close.'
    }
    $answer = [Windows.Forms.MessageBox]::Show($script:Form, $prompt, $script:UpdateProduct, 'OKCancel', 'Question')
    if ($answer -ne [Windows.Forms.DialogResult]::OK) { return }
    $dest = Join-Path $env:TEMP ($script:UpdateAsset.Replace('.exe', '') + '-' + $offer.Version + '.exe')
    if (-not (Receive-SetupFile $offer.Url $dest $offer.Size)) { return }
    Start-Process -FilePath $dest | Out-Null
    $script:UpdateClosing = $true
    $script:Form.Close()
}

function Layout-Actions {
    $panel = $script:ActionPanel
    if ($null -eq $panel -or $panel.ClientSize.Width -lt 20) { return }
    $y = [Math]::Max(0, [int](($panel.ClientSize.Height - $script:DownloadButton.Height) / 2))
    $script:DownloadButton.Location = New-Object Drawing.Point(0, $y)
    $script:CancelButton.Location = New-Object Drawing.Point(($script:DownloadButton.Right + 8), ($y + 2))
    $script:HelpButton.Location = New-Object Drawing.Point(($panel.ClientSize.Width - $script:HelpButton.Width), ($y + 2))
    $script:OpenButton.Location = New-Object Drawing.Point(($script:HelpButton.Left - 8 - $script:OpenButton.Width), ($y + 2))
}

function Layout-Options {
    $card = $script:OptionsCard
    if ($null -eq $card -or $card.ClientSize.Width -lt 20) { return }
    $script:OptionsTitle.SetBounds(16, 12, ($card.ClientSize.Width - 32), 22)
    $y = 40
    foreach ($chk in @($script:FolderCheck, $script:SkipCheck, $script:AttachedCheck, $script:DetailedCheck)) {
        $chk.Location = New-Object Drawing.Point(16, $y)
        $y += 28
    }
    if ($script:ModeRow) {
        $script:ModeRow.SetBounds(16, ($y + 2), ($card.ClientSize.Width - 32), 32)
        $script:ResolutionLabel.Location = New-Object Drawing.Point(0, 6)
        $script:ResolutionBox.Location = New-Object Drawing.Point(84, 2)
        $script:AudioCheck.Location = New-Object Drawing.Point(276, 4)
        $y += 36
    }
    if ($script:ClipRow) {
        $script:ClipRow.SetBounds(16, ($y + 2), ($card.ClientSize.Width - 32), 32)
        $script:ClipStartLabel.Location = New-Object Drawing.Point(0, 6)
        $startX = $script:ClipStartLabel.PreferredSize.Width + 8
        $script:ClipStartBox.Location = New-Object Drawing.Point($startX, 2)
        $endLabelX = $script:ClipStartBox.Right + 14
        $script:ClipEndLabel.Location = New-Object Drawing.Point($endLabelX, 6)
        $endX = $script:ClipEndLabel.Right + 8
        $script:ClipEndBox.Location = New-Object Drawing.Point($endX, 2)
        if ($script:ClipFormatLabel) {
            $formatX = $script:ClipEndBox.Right + 12
            $formatWidth = [Math]::Max(40, $script:ClipRow.ClientSize.Width - $formatX)
            $script:ClipFormatLabel.SetBounds($formatX, 6, $formatWidth, 22)
        }
        $y += 36
    }
    if ($script:FolderRow) {
        $rowWidth = $card.ClientSize.Width - 32
        $script:FolderRow.SetBounds(16, $y, $rowWidth, 32)
        $script:ChangeFolderButton.Location = New-Object Drawing.Point(($rowWidth - 88), 0)
        $script:DownloadsPathBox.SetBounds(64, 4, ([Math]::Max(40, $rowWidth - 64 - 96)), 24)
    }
}

function Update-ChromeLayout {
    $header = $script:Header
    if ($header -and $header.ClientSize.Width -gt 0) {
        $reserve = 28
        $leftEdge = $header.ClientSize.Width
        if ($script:CheckUpdateButton -and $script:UpdateButton) {
            $right = $header.ClientSize.Width - 24
            $script:UpdateButton.Location = New-Object Drawing.Point(($right - $script:UpdateButton.Width), 16)
            $script:CheckUpdateButton.Location = New-Object Drawing.Point(($script:UpdateButton.Left - 8 - $script:CheckUpdateButton.Width), 16)
            $leftEdge = $script:CheckUpdateButton.Left
        }
        if ($script:ReportBugButton -and $script:DonateButton) {
            $right = $header.ClientSize.Width - 24
            $script:ReportBugButton.Location = New-Object Drawing.Point(($right - $script:ReportBugButton.Width), 58)
            $script:DonateButton.Location = New-Object Drawing.Point(($script:ReportBugButton.Left - 8 - $script:DonateButton.Width), 58)
            if ($script:DonateButton.Left -lt $leftEdge) { $leftEdge = $script:DonateButton.Left }
        }
        $reserve = $header.ClientSize.Width - $leftEdge + 16
        $textWidth = [Math]::Max(160, ($header.ClientSize.Width - 28 - $reserve))
        $script:TitleLabel.SetBounds(28, 18, $textWidth, 36)
        $script:SubtitleLabel.SetBounds(28, 56, $textWidth, 40)
    }
    $status = $script:StatusPanel
    if ($status -and $status.ClientSize.Width -gt 0) {
        $versionGap = 0
        if ($script:VersionLabel) {
            $vw = $script:VersionLabel.PreferredSize.Width
            if ($vw -lt 1) { $vw = 48 }
            $script:VersionLabel.SetBounds(($status.ClientSize.Width - 24 - $vw), 8, $vw, 22)
            $versionGap = $vw + 12
        }
        $script:StatusLabel.SetBounds(24, 8, ([Math]::Max(80, $status.ClientSize.Width - 48 - $versionGap)), 22)
        $script:ProgressTrack.SetBounds(24, 36, ([Math]::Max(0, $status.ClientSize.Width - 48)), 8)
        Set-Progress $script:ProgressValue
    }
    Layout-Actions
    Layout-Options
}

function New-Check([string]$text) {
    $chk = New-Object Windows.Forms.CheckBox
    $chk.Text = $text
    $chk.AutoSize = $true
    $chk.Font = $script:FontUi
    $chk.ForeColor = $script:ColorInk
    $chk.BackColor = [Drawing.Color]::White
    $chk.UseVisualStyleBackColor = $false
    return $chk
}

# Window
$script:ToolsOk = $false
$script:Running = $false
$script:SeenWelcome = $false
$script:ProgressValue = 0
$script:LivePercent = -1
$script:Saved = 0
$script:Skipped = 0
$script:Failed = 0
$script:CancelRequested = $false
$script:ForbiddenRetries = 0
$script:JobStarted = [DateTime]::MinValue
$script:ActiveClip = $null
$script:ClipPhase = ''
$script:ClipSource = $null
$script:ClipTemp = $null
$script:ClipDuration = 0
$script:PendingLines = New-Object System.Collections.ArrayList
$script:QueueLock = New-Object Object
$script:RecentRaw = New-Object System.Collections.Generic.List[string]
$script:TipMap = @{}
$script:Tips = New-Object Windows.Forms.ToolTip
$script:Tips.InitialDelay = 400
$script:Tips.ReshowDelay = 200
$script:Tips.AutoPopDelay = 20000
$script:Tips.ShowAlways = $true

$settings = Load-Settings
$script:DownloadsDir = Resolve-DownloadsFolder $settings.DownloadsFolder
$script:SeenWelcome = [bool]$settings.SeenWelcome
$script:UpdatePrompt = [string]$settings.UpdatePrompt

$script:Form = New-Object Windows.Forms.Form
$script:Form.Text = 'Video Beam'
$script:Form.Font = $script:FontUi
$script:Form.BackColor = $script:ColorPage
$script:Form.StartPosition = 'CenterScreen'
$script:Form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$script:Form.KeyPreview = $true
$area = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$wantW = 1040
$wantH = 900
if ($wantW -gt ($area.Width - 24)) { $wantW = [Math]::Max(760, $area.Width - 24) }
if ($wantH -gt ($area.Height - 24)) { $wantH = [Math]::Max(640, $area.Height - 24) }
$script:Form.ClientSize = New-Object Drawing.Size($wantW, $wantH)
$script:Form.MinimumSize = New-Object Drawing.Size([Math]::Min(880, $area.Width), [Math]::Min(840, $area.Height))
$appIcon = Get-AppIcon
if ($appIcon) { $script:Form.Icon = $appIcon }
Enable-DoubleBuffer $script:Form

$script:Header = New-Object Windows.Forms.Panel
$script:Header.Dock = 'Top'
$script:Header.Height = 112
$script:Header.BackColor = $script:ColorHeader
$script:TitleLabel = New-Object Windows.Forms.Label
$script:TitleLabel.Text = 'Video Beam'
$script:TitleLabel.Font = $script:FontTitle
$script:TitleLabel.ForeColor = [Drawing.Color]::White
$script:TitleLabel.BackColor = $script:ColorHeader
$script:SubtitleLabel = New-Object Windows.Forms.Label
$script:SubtitleLabel.Text = "Paste a video or playlist link. Each download is saved as an MP4 in the Downloads folder."
$script:SubtitleLabel.Font = $script:FontSubtitle
$script:SubtitleLabel.ForeColor = $script:ColorHeaderMuted
$script:SubtitleLabel.BackColor = $script:ColorHeader
$script:CheckUpdateButton = New-Button 'Check for updates' 'secondary' 168 34
$script:UpdateButton = New-Button 'Update' 'primary' 100 34
$script:UpdateButton.Enabled = $false
$script:DonateButton = New-Button 'Donate' 'secondary' 96 28
$script:ReportBugButton = New-Button 'Report a bug' 'secondary' 132 28
$script:Header.Controls.Add($script:TitleLabel)
$script:Header.Controls.Add($script:SubtitleLabel)
$script:Header.Controls.Add($script:CheckUpdateButton)
$script:Header.Controls.Add($script:UpdateButton)
$script:Header.Controls.Add($script:DonateButton)
$script:Header.Controls.Add($script:ReportBugButton)

$script:StatusPanel = New-Object Windows.Forms.Panel
$script:StatusPanel.Dock = 'Bottom'
$script:StatusPanel.Height = 58
$script:StatusPanel.BackColor = [Drawing.Color]::White
$script:StatusLabel = New-Object Windows.Forms.Label
$script:StatusLabel.Text = 'Ready'
$script:StatusLabel.Font = $script:FontUi
$script:StatusLabel.ForeColor = $script:ColorMuted
$script:StatusLabel.AutoEllipsis = $true
$script:StatusLabel.BackColor = [Drawing.Color]::White
$script:ProgressTrack = New-Object Windows.Forms.Panel
$script:ProgressTrack.BackColor = [Drawing.Color]::FromArgb(229, 231, 235)
$script:ProgressTrack.Height = 8
$script:ProgressFill = New-Object Windows.Forms.Panel
$script:ProgressFill.BackColor = $script:ColorPrimary
$script:ProgressFill.Height = 8
$script:ProgressFill.Width = 0
$script:ProgressTrack.Controls.Add($script:ProgressFill)
$script:VersionLabel = New-Object Windows.Forms.Label
$script:VersionLabel.Text = Get-AppVersion
$script:VersionLabel.Font = $script:FontHint
$script:VersionLabel.ForeColor = $script:ColorMuted
$script:VersionLabel.BackColor = [Drawing.Color]::White
$script:VersionLabel.TextAlign = 'MiddleRight'
$script:VersionLabel.AutoSize = $true
$script:StatusPanel.Controls.Add($script:StatusLabel)
$script:StatusPanel.Controls.Add($script:VersionLabel)
$script:StatusPanel.Controls.Add($script:ProgressTrack)
$script:StatusPanel.Add_Paint({
    $pen = New-Object Drawing.Pen $script:ColorLine
    $_.Graphics.DrawLine($pen, 0, 0, $script:StatusPanel.Width, 0)
    $pen.Dispose()
})

$table = New-Object Windows.Forms.TableLayoutPanel
$table.Dock = 'Fill'
$table.BackColor = $script:ColorPage
$table.ColumnCount = 1
$table.RowCount = 8
$table.Padding = New-Object Windows.Forms.Padding(24, 16, 24, 8)
$table.Margin = New-Object Windows.Forms.Padding(0)
$table.GrowStyle = 'FixedSize'
[void]$table.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 26)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 36)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 48)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 288)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 28)))
[void]$table.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 64)))

$linksLabel = New-Object Windows.Forms.Label
$linksLabel.Text = 'Links'
$linksLabel.Font = $script:FontSection
$linksLabel.ForeColor = $script:ColorInk
$linksLabel.BackColor = $script:ColorPage
$linksLabel.Dock = 'Fill'
$linksLabel.TextAlign = 'BottomLeft'

$script:LinkHost = New-Object Windows.Forms.Panel
$script:LinkHost.Dock = 'Fill'
$script:LinkHost.BackColor = [Drawing.Color]::White
$script:LinkHost.Padding = New-Object Windows.Forms.Padding(8, 6, 8, 6)
$script:LinkHost.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 4)
$script:LinkBox = New-Object Windows.Forms.TextBox
$script:LinkBox.Multiline = $true
$script:LinkBox.ScrollBars = 'Vertical'
$script:LinkBox.BorderStyle = 'None'
$script:LinkBox.Font = $script:FontUi
$script:LinkBox.BackColor = [Drawing.Color]::White
$script:LinkBox.ForeColor = $script:ColorInk
$script:LinkBox.Dock = 'Fill'
$script:LinkBox.AcceptsReturn = $true
$script:LinkBox.AcceptsTab = $false
$script:LinkBox.HideSelection = $false
$script:LinkBox.WordWrap = $true
$script:LinkHost.Controls.Add($script:LinkBox)
$script:LinkHost.Add_Paint({
    $color = $script:ColorLine
    if ($script:LinkFocused) { $color = $script:ColorPrimary }
    $pen = New-Object Drawing.Pen $color
    $_.Graphics.DrawRectangle($pen, 0, 0, ($script:LinkHost.Width - 1), ($script:LinkHost.Height - 1))
    $pen.Dispose()
})
$script:LinkBox.Add_Enter({ $script:LinkFocused = $true; $script:LinkHost.Invalidate() })
$script:LinkBox.Add_Leave({ $script:LinkFocused = $false; $script:LinkHost.Invalidate() })
$script:LinkBox.AllowDrop = $true
$script:LinkBox.Add_DragEnter({
    if ($script:Running) { $_.Effect = 'None'; return }
    $data = $_.Data
    if ($data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop) -or $data.GetDataPresent([Windows.Forms.DataFormats]::UnicodeText) -or $data.GetDataPresent([Windows.Forms.DataFormats]::Text)) {
        $_.Effect = 'Copy'
    } else {
        $_.Effect = 'None'
    }
})
$script:LinkBox.Add_DragDrop({ Add-DroppedData $_.Data })
$script:LinkBox.Add_TextChanged({ Update-LinkHint })

$script:LinkHint = New-Object Windows.Forms.Label
$script:LinkHint.Text = 'One link per line. A playlist link downloads every video in the playlist. A video link downloads only that video.'
$script:LinkHint.Font = $script:FontHint
$script:LinkHint.ForeColor = $script:ColorMuted
$script:LinkHint.BackColor = $script:ColorPage
$script:LinkHint.Dock = 'Fill'
$script:LinkHint.TextAlign = 'TopLeft'

$linkButtons = New-Object Windows.Forms.FlowLayoutPanel
$linkButtons.Dock = 'Fill'
$linkButtons.FlowDirection = 'LeftToRight'
$linkButtons.WrapContents = $false
$linkButtons.BackColor = $script:ColorPage
$linkButtons.Margin = New-Object Windows.Forms.Padding(0)
$script:PasteButton = New-Button 'Paste' 'secondary' 84 32
$script:ClearButton = New-Button 'Clear' 'secondary' 84 32
$script:LoadButton = New-Button 'Load a list' 'secondary' 118 32
$script:SaveButton = New-Button 'Save this list' 'secondary' 128 32
$script:BlockedButton = New-Button 'Blocked sites' 'secondary' 130 32
$linkButtons.Controls.Add($script:PasteButton)
$linkButtons.Controls.Add($script:ClearButton)
$linkButtons.Controls.Add($script:LoadButton)
$linkButtons.Controls.Add($script:SaveButton)
$linkButtons.Controls.Add($script:BlockedButton)

$script:OptionsCard = New-Object Windows.Forms.Panel
$script:OptionsCard.Dock = 'Fill'
$script:OptionsCard.BackColor = [Drawing.Color]::White
$script:OptionsCard.Margin = New-Object Windows.Forms.Padding(0, 6, 0, 6)
$script:OptionsTitle = New-Object Windows.Forms.Label
$script:OptionsTitle.Text = 'Options'
$script:OptionsTitle.Font = $script:FontSection
$script:OptionsTitle.ForeColor = $script:ColorInk
$script:OptionsTitle.BackColor = [Drawing.Color]::White
$script:FolderCheck = New-Check 'Save each playlist into its own folder'
$script:SkipCheck = New-Check 'Skip videos you have already downloaded'
$script:AttachedCheck = New-Check 'Download the playlist attached to a video link'
$script:DetailedCheck = New-Check 'Show detailed activity'
$script:FolderCheck.Checked = [bool]$settings.PlaylistFolders
$script:SkipCheck.Checked = [bool]$settings.SkipExisting
$script:AttachedCheck.Checked = [bool]$settings.ExpandAttached
$script:DetailedCheck.Checked = [bool]$settings.Detailed
$script:ResolutionValues = @('best', '2160', '1440', '1080', '720', '480', '360')
$script:ResolutionLabel = New-Object Windows.Forms.Label
$script:ResolutionLabel.Text = 'Resolution'
$script:ResolutionLabel.AutoSize = $true
$script:ResolutionLabel.Font = $script:FontUi
$script:ResolutionLabel.ForeColor = $script:ColorInk
$script:ResolutionLabel.BackColor = [Drawing.Color]::White
$script:ResolutionBox = New-Object Windows.Forms.ComboBox
$script:ResolutionBox.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
$script:ResolutionBox.Font = $script:FontUi
$script:ResolutionBox.Width = 160
$script:ResolutionBox.IntegralHeight = $true
foreach ($label in @('Best available', '2160p (4K)', '1440p', '1080p', '720p', '480p', '360p')) {
    [void]$script:ResolutionBox.Items.Add($label)
}
$resolutionIndex = [array]::IndexOf($script:ResolutionValues, [string]$settings.Resolution)
if ($resolutionIndex -lt 0) { $resolutionIndex = 0 }
$script:ResolutionBox.SelectedIndex = $resolutionIndex
$script:AudioCheck = New-Check 'Audio only, save as MP3'
$script:AudioCheck.Checked = [bool]$settings.AudioOnly
$script:ModeRow = New-Object Windows.Forms.Panel
$script:ModeRow.BackColor = [Drawing.Color]::White
$script:ModeRow.Height = 32
$script:ModeRow.Controls.Add($script:ResolutionLabel)
$script:ModeRow.Controls.Add($script:ResolutionBox)
$script:ModeRow.Controls.Add($script:AudioCheck)
$script:OptionsCard.Controls.Add($script:OptionsTitle)
$script:OptionsCard.Controls.Add($script:FolderCheck)
$script:OptionsCard.Controls.Add($script:SkipCheck)
$script:OptionsCard.Controls.Add($script:AttachedCheck)
$script:OptionsCard.Controls.Add($script:DetailedCheck)
$script:OptionsCard.Controls.Add($script:ModeRow)
$script:ClipStartLabel = New-Object Windows.Forms.Label
$script:ClipStartLabel.Text = 'Start'
$script:ClipStartLabel.AutoSize = $true
$script:ClipStartLabel.Font = $script:FontUi
$script:ClipStartLabel.ForeColor = $script:ColorInk
$script:ClipStartLabel.BackColor = [Drawing.Color]::White
$script:ClipStartBox = New-Object Windows.Forms.TextBox
$script:ClipStartBox.Font = $script:FontUi
$script:ClipStartBox.Width = 88
$script:ClipEndLabel = New-Object Windows.Forms.Label
$script:ClipEndLabel.Text = 'End'
$script:ClipEndLabel.AutoSize = $true
$script:ClipEndLabel.Font = $script:FontUi
$script:ClipEndLabel.ForeColor = $script:ColorInk
$script:ClipEndLabel.BackColor = [Drawing.Color]::White
$script:ClipEndBox = New-Object Windows.Forms.TextBox
$script:ClipEndBox.Font = $script:FontUi
$script:ClipEndBox.Width = 88
$script:ClipRow = New-Object Windows.Forms.Panel
$script:ClipRow.BackColor = [Drawing.Color]::White
$script:ClipRow.Height = 32
$script:ClipFormatLabel = New-Object Windows.Forms.Label
$script:ClipFormatLabel.Text = 'm:ss, such as 1:30.  An hour or more is 1:02:05.'
$script:ClipFormatLabel.AutoEllipsis = $true
$script:ClipFormatLabel.Font = $script:FontHint
$script:ClipFormatLabel.ForeColor = $script:ColorMuted
$script:ClipFormatLabel.BackColor = [Drawing.Color]::White
$script:ClipRow.Controls.Add($script:ClipStartLabel)
$script:ClipRow.Controls.Add($script:ClipStartBox)
$script:ClipRow.Controls.Add($script:ClipEndLabel)
$script:ClipRow.Controls.Add($script:ClipEndBox)
$script:ClipRow.Controls.Add($script:ClipFormatLabel)
if (-not ('VideoBeam.Cue' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VideoBeam {
  public static class Cue {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
  }
}
'@
}
[void][VideoBeam.Cue]::SendMessage($script:ClipStartBox.Handle, 0x1501, [IntPtr]1, '1:30')
[void][VideoBeam.Cue]::SendMessage($script:ClipEndBox.Handle, 0x1501, [IntPtr]1, '4:15')
$script:OptionsCard.Controls.Add($script:ClipRow)
$script:DownloadsLabel = New-Object Windows.Forms.Label
$script:DownloadsLabel.Text = 'Save to'
$script:DownloadsLabel.AutoSize = $true
$script:DownloadsLabel.Font = $script:FontUi
$script:DownloadsLabel.ForeColor = $script:ColorInk
$script:DownloadsLabel.BackColor = [Drawing.Color]::White
$script:DownloadsLabel.Location = New-Object Drawing.Point(0, 6)
$script:DownloadsPathBox = New-Object Windows.Forms.TextBox
$script:DownloadsPathBox.ReadOnly = $true
$script:DownloadsPathBox.Font = $script:FontUi
$script:DownloadsPathBox.BackColor = [Drawing.Color]::White
$script:DownloadsPathBox.ForeColor = $script:ColorInk
$script:DownloadsPathBox.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$script:DownloadsPathBox.Text = $script:DownloadsDir
$script:ChangeFolderButton = New-Button 'Change' 'secondary' 88 28
$script:ChangeFolderButton.Margin = New-Object Windows.Forms.Padding(0)
$script:FolderRow = New-Object Windows.Forms.Panel
$script:FolderRow.BackColor = [Drawing.Color]::White
$script:FolderRow.Height = 32
$script:FolderRow.Controls.Add($script:DownloadsLabel)
$script:FolderRow.Controls.Add($script:DownloadsPathBox)
$script:FolderRow.Controls.Add($script:ChangeFolderButton)
$script:OptionsCard.Controls.Add($script:FolderRow)
$script:ChangeFolderButton.Add_Click({ Choose-DownloadsFolder })
$script:OptionsCard.Add_Paint({
    $pen = New-Object Drawing.Pen $script:ColorLine
    $_.Graphics.DrawRectangle($pen, 0, 0, ($script:OptionsCard.Width - 1), ($script:OptionsCard.Height - 1))
    $pen.Dispose()
})
foreach ($chk in @($script:FolderCheck, $script:SkipCheck, $script:AttachedCheck, $script:DetailedCheck, $script:AudioCheck)) {
    $chk.Add_CheckedChanged({
        try {
            Update-DownloadMode
            Update-LinkHint
            if (-not $script:LoadingSettings) { Save-Settings }
        } catch {
            Write-Activity ('Could not save that option. ' + $_.Exception.Message) 'warn'
        }
    })
}
$script:ResolutionBox.Add_SelectedIndexChanged({
    try {
        if (-not $script:LoadingSettings) { Save-Settings }
    } catch {
        Write-Activity ('Could not save that option. ' + $_.Exception.Message) 'warn'
    }
})

$script:ActionPanel = New-Object Windows.Forms.Panel
$script:ActionPanel.Dock = 'Fill'
$script:ActionPanel.BackColor = $script:ColorPage
$script:ActionPanel.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 0)
$script:DownloadButton = New-Button 'Download' 'primary' 156 38
$script:CancelButton = New-Button 'Cancel' 'danger' 108 34
$script:OpenButton = New-Button 'Open Downloads' 'secondary' 160 34
$script:HelpButton = New-Button 'How this works' 'secondary' 148 34
$script:CancelButton.Enabled = $false
$script:ActionPanel.Controls.Add($script:DownloadButton)
$script:ActionPanel.Controls.Add($script:CancelButton)
$script:ActionPanel.Controls.Add($script:OpenButton)
$script:ActionPanel.Controls.Add($script:HelpButton)

$activityLabel = New-Object Windows.Forms.Label
$activityLabel.Text = 'Activity'
$activityLabel.Font = $script:FontSection
$activityLabel.ForeColor = $script:ColorInk
$activityLabel.BackColor = $script:ColorPage
$activityLabel.Dock = 'Fill'
$activityLabel.TextAlign = 'BottomLeft'

$logHost = New-Object Windows.Forms.Panel
$logHost.Dock = 'Fill'
$logHost.BackColor = $script:ColorLogBg
$logHost.Padding = New-Object Windows.Forms.Padding(10, 8, 10, 8)
$logHost.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 0)
$script:Log = New-Object Windows.Forms.RichTextBox
$script:Log.Dock = 'Fill'
$script:Log.BorderStyle = 'None'
$script:Log.ReadOnly = $true
$script:Log.BackColor = $script:ColorLogBg
$script:Log.ForeColor = $script:ColorLogText
$script:Log.Font = $script:FontLog
$script:Log.DetectUrls = $false
$script:Log.ScrollBars = 'Vertical'
$script:Log.WordWrap = $true
$script:Log.ShortcutsEnabled = $true
$logHost.Controls.Add($script:Log)
$logHost.Add_Paint({
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(55, 65, 81))
    $_.Graphics.DrawRectangle($pen, 0, 0, ($this.Width - 1), ($this.Height - 1))
    $pen.Dispose()
})

[void]$table.Controls.Add($linksLabel, 0, 0)
[void]$table.Controls.Add($script:LinkHost, 0, 1)
[void]$table.Controls.Add($script:LinkHint, 0, 2)
[void]$table.Controls.Add($linkButtons, 0, 3)
[void]$table.Controls.Add($script:OptionsCard, 0, 4)
[void]$table.Controls.Add($script:ActionPanel, 0, 5)
[void]$table.Controls.Add($activityLabel, 0, 6)
[void]$table.Controls.Add($logHost, 0, 7)

$script:Form.Controls.Add($table)
$script:Form.Controls.Add($script:StatusPanel)
$script:Form.Controls.Add($script:Header)

Set-Tip $script:LinkBox 'One web link per line. Each line can be a single video or a whole playlist. You can also drop a link or a .txt file here.'
Set-Tip $script:PasteButton 'Paste links from the clipboard onto the end of the list.'
Set-Tip $script:ClearButton 'Empty the links box. Downloaded files stay in the Downloads folder.'
Set-Tip $script:LoadButton 'Add links from a text file. Lines that are not links are left out.'
Set-Tip $script:SaveButton 'Save the links in the box to a text file you can open later.'
Set-Tip $script:BlockedButton 'Open blocked-sites.md. A site listed in that file is not downloaded.'
Set-Tip $script:FolderCheck "Put each playlist's videos in a folder named after the playlist, inside Downloads. Single videos stay directly in Downloads."
Set-Tip $script:SkipCheck 'Remember finished videos and skip them next time. Uncheck this to download them again. The memory is the download history file in the app folder.'
Set-Tip $script:AttachedCheck "YouTube often adds a playlist to a video's address. Leave this off to download only the video. Turn it on to download every video in that attached playlist."
Set-Tip $script:DetailedCheck "Show the downloader's own technical messages in the activity box. Useful when a video will not download."
Set-Tip $script:ResolutionBox 'Pick a picture size when a video offers more than one. If that size is missing, the closest available size is used. Best available keeps the best MP4 that plays in ordinary players.'
Set-Tip $script:ResolutionLabel 'Pick a picture size when a video offers more than one. If that size is missing, the closest available size is used.'
Set-Tip $script:AudioCheck 'Save only the soundtrack, as a high-quality MP3. MP4 files already in Downloads stay there. MP3s are remembered separately from videos.'
Set-Tip $script:DownloadButton 'Download every link in the box. Videos are saved as MP4. With Audio only turned on, the soundtrack is saved as an MP3. Ctrl+Enter does this too.'
Set-Tip $script:CancelButton 'Stop the download. Videos that already finished stay in Downloads. Esc does this too.'
Set-Tip $script:DownloadsPathBox 'New videos and MP3s are saved in this folder. The choice is remembered the next time you open the program.'
Set-Tip $script:DownloadsLabel 'New videos and MP3s are saved in this folder.'
Set-Tip $script:ChangeFolderButton 'Choose a different folder for new downloads. Files already saved stay where they are.'
Set-Tip $script:OpenButton 'Open the current save folder in File Explorer.'
Set-Tip $script:HelpButton 'Open a short guide to links, folders, skipping, and what each part of this folder is for.'
Set-Tip $script:CheckUpdateButton 'Look on GitHub for a newer version of Video Beam.'
Set-Tip $script:DonateButton 'Free forever. Tips of $5 or more can include a feature suggestion.'
Set-Tip $script:ReportBugButton 'Open a GitHub bug report with this version and the Windows version filled in. Include latest activity is optional. Leave it unchecked and nothing else is added.'
Set-Tip $script:UpdateButton 'Download the newer version and open its setup program. This window closes while that setup runs.'
Set-Tip $script:Log 'Saved files, skipped videos, and problems are listed here.'
Set-Tip $script:ProgressTrack 'How much of the current file has been downloaded.'
Set-Tip $script:StatusLabel 'What the program is doing right now.'
Set-Tip $script:VersionLabel 'This copy of Video Beam.'
Set-Tip $script:ClipStartBox 'Where the clip begins. Type 1:30 for one minute and 30 seconds. For an hour or more, type 1:02:05. 90 means 90 seconds. Leave this blank to start at the beginning. The full video downloads first, then the clip is cut. Used only when the box has one video link.'
Set-Tip $script:ClipEndBox 'Where the clip ends. Type 4:15 for four minutes and 15 seconds. Leave this blank to continue to the end of the video.'
Set-Tip $script:ClipStartLabel 'Where the clip begins. The time is m:ss, such as 1:30.'
Set-Tip $script:ClipEndLabel 'Where the clip ends. The time is m:ss, such as 4:15.'
Set-Tip $script:ClipFormatLabel 'Type minutes and seconds as 1:30. For an hour or more, type 1:02:05. A plain number such as 90 means 90 seconds.'

$script:PasteButton.Add_Click({ Paste-Links })
$script:ClearButton.Add_Click({ $script:LinkBox.Clear() })
$script:LoadButton.Add_Click({ Load-ListFile })
$script:SaveButton.Add_Click({ Save-ListFile })
$script:BlockedButton.Add_Click({ Open-BlockedSites })
$script:DownloadButton.Add_Click({ Start-Download })
$script:CancelButton.Add_Click({ Request-Cancel })
$script:OpenButton.Add_Click({ Open-DownloadsFolder })
$script:HelpButton.Add_Click({ Show-Help })
$script:CheckUpdateButton.Add_Click({ Start-UpdateCheck })
$script:DonateButton.Add_Click({ Open-HttpLink 'https://ko-fi.com/philipvern' })
$script:ReportBugButton.Add_Click({ Show-BugReport })
$script:UpdateButton.Add_Click({ Start-UpdateInstall })

$script:Form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::Enter) {
        $_.SuppressKeyPress = $true
        if (-not $script:Running) { Start-Download }
    } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Escape -and $script:Running) {
        $_.SuppressKeyPress = $true
        Request-Cancel
    }
})
$script:Form.Add_FormClosing({
    if ($script:SmokeTest) { return }
    if (-not $script:UpdateClosing -and $script:Running) {
        $answer = [Windows.Forms.MessageBox]::Show('A download is still running. Stop it and close?', 'Video Beam', 'YesNo', 'Question')
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) {
            $_.Cancel = $true
            return
        }
        $script:Closing = $true
        Stop-DownloadProcess
        $deadline = [DateTime]::UtcNow.AddSeconds(4)
        while ($script:Process -and -not $script:Process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
            [Threading.Thread]::Sleep(100)
        }
    }
    Save-Settings
})
$script:Form.Add_FormClosed({
    if ($script:Timer) { $script:Timer.Stop(); $script:Timer.Dispose() }
    if ($script:HelpForm -and -not $script:HelpForm.IsDisposed) { $script:HelpForm.Close() }
})
$script:Header.Add_Resize({ Update-ChromeLayout })
$script:StatusPanel.Add_Resize({ Update-ChromeLayout })
$script:ActionPanel.Add_Resize({ Layout-Actions })
$script:OptionsCard.Add_Resize({ Layout-Options })
$script:Form.Add_Shown({
    Update-ChromeLayout
    if (-not $script:SmokeTest) {
        try {
            $script:Form.WindowState = [Windows.Forms.FormWindowState]::Normal
            $script:Form.Visible = $true
            [void][VideoDownloader.Native]::ShowWindow($script:Form.Handle, 9)
            [void][VideoDownloader.Native]::SetForegroundWindow($script:Form.Handle)
        } catch {
        }
        $script:LinkBox.Focus() | Out-Null
        Start-UpdateCheck
    }
})

$script:Timer = New-Object Windows.Forms.Timer
$script:Timer.Interval = 100
$script:Timer.Add_Tick({ Invoke-DownloadTick })
$script:Timer.Start()

Update-LinkHint
Write-Welcome
Warn-MissingTools
Set-Busy $false
Set-Status 'Ready' 'idle'
Update-Shortcut
Update-ChromeLayout

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Invoke-Tool([string]$file, [string[]]$argParts) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $file
    $psi.Arguments = ConvertTo-CommandLine $argParts
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $utf8out = New-Object System.Text.UTF8Encoding $false
    $psi.StandardOutputEncoding = $utf8out
    $psi.StandardErrorEncoding = $utf8out
    $proc = [Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    return [pscustomobject]@{
        Code = [int]$proc.ExitCode
        Out = [string]$outTask.Result
        Err = [string]$errTask.Result
    }
}

function Invoke-ClipCutCheck {
    $dir = Join-Path $env:TEMP 'vd-clip-check'
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    New-Item -ItemType Directory -Path $dir | Out-Null
    try {
        $src = Join-Path $dir 'src.mp4'
        $out = Join-Path $dir 'out.mp4'
        $make = @(
            '-y', '-hide_banner', '-loglevel', 'error',
            '-f', 'lavfi', '-i', 'color=c=black:s=160x120:r=25:d=4',
            '-f', 'lavfi', '-i', 'sine=f=440:d=4',
            '-shortest', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-g', '25', '-keyint_min', '25',
            '-c:a', 'aac', $src
        )
        $made = Invoke-Tool $script:Ffmpeg $make
        Assert-True ($made.Code -eq 0 -and (Test-Path -LiteralPath $src)) ("Could not make a sample video for the clip cut: " + $made.Err)
        $cutArgs = Get-ClipCutArguments -InputPath $src -OutputPath $out -StartSeconds 1 -EndSeconds 3
        $cut = Invoke-Tool $script:Ffmpeg $cutArgs
        Assert-True ($cut.Code -eq 0 -and (Test-Path -LiteralPath $out)) ("The sample clip was not cut: " + $cut.Err)
        $probe = Join-Path $script:ToolsDir 'ffprobe.exe'
        $info = Invoke-Tool $probe @('-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', $out)
        $durText = $info.Out.Trim()
        $dur = 0.0
        $parsed = [double]::TryParse($durText, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$dur)
        Assert-True ($parsed -and $dur -gt 1.85 -and $dur -lt 2.2) "Clip duration was $durText"
    } finally {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-SelfCheck {
    $missing = @(Get-MissingTools)
    Assert-True ($missing.Count -eq 0) ("Missing tools: " + ($missing -join ', '))

    $cases = @(
        @('https://www.youtube.com/watch?v=abc', $false, 'video'),
        @('https://youtu.be/abc', $false, 'video'),
        @('https://www.youtube.com/watch?v=abc&list=PL0123456789', $false, 'video'),
        @('https://www.youtube.com/watch?v=abc&list=PL0123456789', $true, 'playlist'),
        @('https://www.youtube.com/playlist?list=PL0123456789', $false, 'playlist'),
        @('https://www.youtube.com/@SomeChannel', $false, 'channel'),
        @('https://www.youtube.com/@SomeChannel/videos', $false, 'channel'),
        @('https://www.youtube.com/shorts/abc123', $false, 'video'),
        @('https://www.youtube.com/@SomeChannel/shorts', $false, 'channel'),
        @('https://www.youtube.com/channel/UCxxxxxxxx', $false, 'channel'),
        @('https://vimeo.com/123456', $false, 'open'),
        @('https://m.youtube.com/watch?v=abc', $false, 'video'),
        @('https://notyoutube.com/watch?v=abc', $false, 'open')
    )
    foreach ($case in $cases) {
        $got = Get-LinkKind $case[0] ([bool]$case[1])
        Assert-True ($got -eq $case[2]) ("Kind for $($case[0]) expand=$($case[1]) was $got, expected $($case[2])")
    }

    $quoted = ConvertTo-Arg 'E:\Youtube Downloads\tools'
    Assert-True ($quoted -eq '"E:\Youtube Downloads\tools"') "Bad quote: $quoted"
    Assert-True ((ConvertTo-Arg '--newline') -eq '--newline') 'Simple arg was quoted'

    $videoArgs = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\download-history.txt' -BatchFile 'C:\temp\list.txt'
    Assert-True ($videoArgs -contains '--no-playlist') 'Video args missing --no-playlist'
    Assert-True ($videoArgs -contains '--ignore-config') 'Missing --ignore-config'
    Assert-True ($videoArgs -contains '-t') 'Missing mp4 preset'
    Assert-True (-not ($videoArgs -contains '--yes-playlist')) 'Video args forced a playlist'
    $videoLine = ConvertTo-CommandLine $videoArgs
    Assert-True ($videoLine.Contains('"E:\Youtube Downloads\downloads"')) "Path was not quoted: $videoLine"
    Assert-True (-not ($videoArgs -contains '-f')) 'Best resolution should not add a format filter'
    Assert-True ($videoArgs -contains '--download-archive') 'Skip existing did not use the history'
    $clipArgs = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\download-history.txt' -BatchFile 'C:\temp\list.txt' -ClipStamp '1m30s-3m00s'
    Assert-True (-not ($clipArgs -contains '--download-sections')) 'A clip asked yt-dlp to cut during the download'
    Assert-True (-not ($clipArgs -contains '--force-keyframes-at-cuts')) 'A clip asked ffmpeg to re-encode the download'
    Assert-True (-not ($clipArgs -contains '--download-archive')) 'A clip used the full-video history'
    Assert-True ($clipArgs -contains '--force-overwrites') 'A clip did not replace its own file'
    Assert-True (-not ($clipArgs -contains '--no-continue')) 'The first clip attempt refused to resume'
    $retryArgs = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\download-history.txt' -BatchFile 'C:\temp\list.txt' -ClipStamp '1m30s-3m00s' -NoContinue
    Assert-True ($retryArgs -contains '--no-continue') 'A refused download did not start over'
    $clipTemplate = $clipArgs[[array]::IndexOf($clipArgs, '-o') + 1]
    Assert-True ($clipTemplate -match '1m30s-3m00s') "Clip file name was $clipTemplate"
    $fromStart = Get-ClipCutArguments -InputPath 'C:\clip-in.mp4' -OutputPath 'C:\clip-out.mp4' -StartSeconds 0 -EndSeconds 120
    Assert-True (-not ($fromStart -contains '-ss')) 'A clip that starts at the beginning still seeked'
    Assert-True ($fromStart[[array]::IndexOf($fromStart, '-t') + 1] -eq '120') 'A clip from the start used the wrong length'
    $midCut = Get-ClipCutArguments -InputPath 'C:\clip-in.mp4' -OutputPath 'C:\clip-out.mp4' -StartSeconds 90 -EndSeconds 180
    Assert-True ($midCut[[array]::IndexOf($midCut, '-ss') + 1] -eq '90') 'A clip seeked to the wrong time'
    Assert-True ($midCut[[array]::IndexOf($midCut, '-t') + 1] -eq '90') 'A clip kept the wrong length'
    Assert-True ($midCut -contains 'libx264') 'A clip cut did not re-encode the picture'
    Assert-True ($midCut -contains 'pipe:1') 'A clip cut did not report progress'
    $openEnd = Get-ClipCutArguments -InputPath 'C:\clip-in.mp3' -OutputPath 'C:\clip-out.mp3' -StartSeconds 15 -EndSeconds $null
    Assert-True ($openEnd -contains '-ss' -and -not ($openEnd -contains '-t')) 'An open-ended clip was given a length'
    Assert-True ($openEnd -contains 'libmp3lame') 'An MP3 clip did not re-encode the audio'
    Assert-True (-not ($openEnd -contains '+faststart')) 'An MP3 clip asked for an MP4 flag'
    Invoke-ClipCutCheck
    Assert-True ((ConvertTo-ClipSeconds '1:30') -eq 90) 'm:ss was not read as seconds'
    Assert-True ((ConvertTo-ClipSeconds '1:02:05') -eq 3725) 'h:mm:ss was not read'
    Assert-True ((ConvertTo-ClipSeconds '90') -eq 90) 'Plain seconds were not read'
    $blockList = @('youtube.com', 'youtu.be', 'netflix.com')
    Assert-True (Test-BlockedUrl 'https://www.youtube.com/watch?v=abc' $blockList) 'youtube.com was not blocked'
    Assert-True (Test-BlockedUrl 'https://music.youtube.com/watch?v=abc' $blockList) 'A youtube subdomain was not blocked'
    Assert-True (Test-BlockedUrl 'https://youtu.be/abc' $blockList) 'youtu.be was not blocked'
    Assert-True (-not (Test-BlockedUrl 'https://example.com/video/1' $blockList)) 'An unlisted site was blocked'
    $liveSites = @(Get-BlockedSites)
    Assert-True (-not (Test-BlockedUrl 'https://www.youtube.com/watch?v=abc' @())) 'An empty block list blocked YouTube'
    if ($liveSites.Count -eq 0) {
        Assert-True (-not (Test-BlockedUrl 'https://www.youtube.com/watch?v=abc' $liveSites)) 'The empty blocked-sites.md blocked YouTube'
    }
    Assert-True (Test-BlockedUrl 'https://music.youtube.com/watch?v=abc' @('youtube.com')) 'A youtube subdomain was not blocked'
    Assert-True ($script:BlockedButton.Text -eq 'Blocked sites') 'Blocked sites button was missing'
    Assert-True ((ConvertTo-ClipSeconds '1:60') -eq -1) 'An invalid minute was accepted'
    $openClip = Get-ClipRequest
    Assert-True ($openClip.Ok -and -not $openClip.Active) 'Empty clip boxes were treated as a clip'
    Assert-True ($videoLine.Contains('deno:' + $script:Deno)) "Deno was not added: $videoLine"

    $capped = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\download-history.txt' -BatchFile 'C:\temp\list.txt' -Resolution '720'
    $formatIndex = [array]::IndexOf($capped, '-f')
    Assert-True ($formatIndex -ge 0 -and $capped[$formatIndex + 1] -match 'height<=720') '720p did not cap the picture size'
    $audioArgs = Get-YtArguments -Key 'video' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\audio-history.txt' -BatchFile 'C:\temp\list.txt' -AudioOnly $true
    Assert-True ($audioArgs -contains 'mp3') 'Audio mode missing mp3'
    Assert-True (-not ($audioArgs -contains 'mp4')) 'Audio mode still requested an MP4'
    Assert-True ($audioArgs -contains '--audio-quality') 'Audio mode missing quality'
    Assert-True ((Resolve-DownloadsFolder '') -eq $script:DefaultDownloadsDir) 'Empty save folder should stay the default'
    Assert-True ((Resolve-DownloadsFolder 'D:\Video Beam') -eq 'D:\Video Beam') 'A chosen folder was not kept'
    Assert-True ((Resolve-DownloadsFolder $script:YtDlp) -eq $script:DefaultDownloadsDir) 'A file was accepted as a save folder'

    $collectionArgs = Get-YtArguments -Key 'collection' -PlaylistFolders $true -SkipExisting $true -Destination 'E:\Youtube Downloads\downloads' -ArchiveFile 'E:\Youtube Downloads\app\download-history.txt' -BatchFile 'C:\temp\list.txt'
    Assert-True ($collectionArgs -contains '--yes-playlist') 'Playlist args missing --yes-playlist'
    Assert-True (-not ($collectionArgs -contains '--no-playlist')) 'Playlist args blocked the playlist'
    $templateIndex = [array]::IndexOf($collectionArgs, '-o')
    Assert-True ($collectionArgs[$templateIndex + 1] -match 'playlist') 'Playlist template missing folder'

    $sample = "https://www.youtube.com/watch?v=abc`r`n`r`n# comment`r`nhttps://www.youtube.com/playlist?list=PLabcdefghij`r`nnot a link`r`nhttps://www.youtube.com/watch?v=abc`r`nhttps://youtu.be/zzz`r`nwww.youtube.com/watch?v=bare`r`nhttps://www.youtube.com/watch?v=abc&list=PLzzzzzzzzz`r`nhttps://www.youtube.com/@ExampleChannel"
    $parsed = Get-LinksFromText $sample $false
    $videos = @($parsed.Items | Where-Object { $_.Kind -eq 'video' })
    $playlists = @($parsed.Items | Where-Object { $_.Kind -eq 'playlist' })
    $channels = @($parsed.Items | Where-Object { $_.Kind -eq 'channel' })
    Assert-True ($videos.Count -eq 4) "Expected 4 videos, got $($videos.Count)"
    Assert-True ($playlists.Count -eq 1) "Expected 1 playlist, got $($playlists.Count)"
    Assert-True ($channels.Count -eq 1) "Expected 1 channel, got $($channels.Count)"
    Assert-True ($parsed.Invalid.Count -eq 1) "Expected 1 invalid line, got $($parsed.Invalid.Count)"
    Assert-True ($parsed.DuplicateCount -eq 1) "Expected 1 duplicate, got $($parsed.DuplicateCount)"
    $expanded = Get-LinksFromText 'https://www.youtube.com/watch?v=abc&list=PLzzzzzzzzz' $true
    Assert-True ($expanded.Items[0].Kind -eq 'playlist') 'Attached playlist was not expanded'

    foreach ($entry in $script:TipMap.GetEnumerator()) {
        $gotTip = $script:Tips.GetToolTip($entry.Key)
        Assert-True (-not [string]::IsNullOrWhiteSpace($gotTip)) 'A control is missing its tooltip'
    }
    Assert-True ($script:TipMap.Count -ge 14) "Expected tooltips on the main controls, found $($script:TipMap.Count)"

    Add-PendingLine 'queue-one'
    Add-PendingLine 'queue-two'
    $drained = Read-PendingLines
    $onePlaylist = New-Object 'System.Collections.Generic.List[object]'
    $onePlaylist.Add([pscustomobject]@{ Url = 'https://www.youtube.com/playlist?list=PLtest'; Kind = 'playlist' })
    $built = Build-Jobs $onePlaylist
    Assert-True (@($built).Count -eq 1) 'One playlist did not produce one download job'
    Assert-True ($built[0].Key -eq 'collection') 'Playlist job was not a collection'
    Assert-True ($built[0].Urls.Count -eq 1) 'Playlist job lost its link'
    Assert-True ($drained.Count -eq 2) ("Drained $($drained.Count) lines: " + ($drained -join ' | '))
    Assert-True ([string]$drained[0] -eq 'queue-one') "First queued line was $($drained[0])"
    Assert-True ([string]$drained[1] -eq 'queue-two') "Second queued line was $($drained[1])"

    Ensure-OutputHandlers
    [VideoDownloader.YtLinePump]::BeginJob()
    $pumpCmd = Join-Path $env:TEMP 'vd-pump-test.cmd'
    $pumpText = "@echo off`r`necho [download]  12.5%% of 1MiB at 1MiB/s ETA 00:01`r`necho WARNING: sample`r`necho YD_SAVED:C:\temp\clip.mp4`r`n"
    [System.IO.File]::WriteAllText($pumpCmd, $pumpText)
    $pumpPsi = New-Object System.Diagnostics.ProcessStartInfo
    $pumpPsi.FileName = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $pumpPsi.Arguments = '/c "' + $pumpCmd + '"'
    $pumpPsi.UseShellExecute = $false
    $pumpPsi.CreateNoWindow = $true
    $pumpPsi.RedirectStandardOutput = $true
    $pumpPsi.RedirectStandardError = $true
    $pumpProc = New-Object System.Diagnostics.Process
    $pumpProc.StartInfo = $pumpPsi
    $pumpProc.EnableRaisingEvents = $true
    $pumpProc.add_OutputDataReceived($script:DataHandler)
    $pumpProc.add_ErrorDataReceived($script:DataHandler)
    $pumpProc.add_Exited($script:ExitHandler)
    [void]$pumpProc.Start()
    $pumpProc.BeginOutputReadLine()
    $pumpProc.BeginErrorReadLine()
    $pumpDeadline = [DateTime]::UtcNow.AddSeconds(8)
    while (-not [VideoDownloader.YtLinePump]::Exited -and [DateTime]::UtcNow -lt $pumpDeadline) {
        Start-Sleep -Milliseconds 50
    }
    $pumpProc.Dispose()
    Remove-Item -LiteralPath $pumpCmd -Force -ErrorAction SilentlyContinue
    Assert-True ([bool][VideoDownloader.YtLinePump]::Exited) 'The download listener did not see the process finish'
    $pumped = Read-PendingLines
    $pumpedText = $pumped -join "`n"
    Assert-True ($pumpedText -match 'YD_SAVED:') "Listener missed the saved file line: $pumpedText"
    Assert-True ($pumpedText -match 'WARNING:') "Listener missed the warning: $pumpedText"
    Assert-True ([math]::Abs([double][VideoDownloader.YtLinePump]::LivePercent - 12.5) -lt 0.01) 'Listener missed the progress percent'
}

function Save-FormImage($targetForm, [string]$path) {
    $wasTop = $targetForm.TopMost
    $targetForm.TopMost = $true
    $targetForm.BringToFront()
    $targetForm.Activate()
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 250
    [Windows.Forms.Application]::DoEvents()
    $bounds = $targetForm.Bounds
    $bmp = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
    $g.Dispose()
    $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $targetForm.TopMost = $wasTop
}

function Invoke-SmokeTest {
    Invoke-SelfCheck
    $script:Form.Show()
    Update-ChromeLayout
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 200
    [Windows.Forms.Application]::DoEvents()
    Save-FormImage $script:Form (Join-Path $env:TEMP 'vd-main.png')
    $script:Form.ClientSize = New-Object Drawing.Size(860, 680)
    Update-ChromeLayout
    [Windows.Forms.Application]::DoEvents()
    Save-FormImage $script:Form (Join-Path $env:TEMP 'vd-main-narrow.png')
    Assert-True ($script:TitleLabel.Right -le $script:CheckUpdateButton.Left) 'The title overlaps Check for updates in the narrow window'
    Assert-True ($script:UpdateButton.Right -le ($script:Header.ClientSize.Width - 8)) 'Update sits outside the narrow window'
    $script:Form.ClientSize = New-Object Drawing.Size($wantW, $wantH)
    Show-Help
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 200
    Save-FormImage $script:HelpForm (Join-Path $env:TEMP 'vd-help.png')
    if ($script:HelpBox) {
        [IO.File]::WriteAllText((Join-Path $env:TEMP 'vd-help.txt'), $script:HelpBox.Text)
    }
    [IO.File]::WriteAllText((Join-Path $env:TEMP 'vd-log.txt'), $script:Log.Text)
    Assert-True ($script:Log.Text -match 'Paste a video or playlist link') 'Startup instructions were not in the activity box'
    Assert-True ($script:HelpBox.Text -match 'Where the files go') 'The guide was missing its folder section'
    Assert-True ($script:HelpBox.Text -match 'full video downloads first') 'The guide still described the old clip download'
    Assert-True ($script:HelpBox.Text -match 'Check for updates') 'The guide was missing updates'
    Assert-True ($script:CheckUpdateButton.Text -eq 'Check for updates') 'Check for updates was missing'
    Assert-True (-not $script:UpdateButton.Enabled) 'Update started enabled'
    Assert-True ((Get-AppVersion) -eq '1.0.4') 'Version file was not 1.0.4'
    Assert-True ($script:VersionLabel.Text -eq '1.0.4') 'The version was not shown'
    Assert-True ($script:DonateButton.Text -eq 'Donate') 'Donate was missing'
    Assert-True ($script:ReportBugButton.Text -eq 'Report a bug') 'Report a bug was missing'
    Assert-True ($script:DonateButton.Parent -eq $script:Header) 'Donate is not in the header'
    Assert-True ($script:Tips.GetToolTip($script:DonateButton) -eq 'Free forever. Tips of $5 or more can include a feature suggestion.') 'Donate tooltip'
    $bugUrl = Get-BugReportUrl 'saved one file'
    Assert-True ($bugUrl.StartsWith('https://github.com/philipvern-dot/video_beam/issues/new?template=bug_report.yml&')) 'Bug report link was not the GitHub form'
    Assert-True ($bugUrl -match 'activity=') 'Bug report link dropped the activity'
    Assert-True ($null -ne $script:Form.Icon) 'The window has no icon'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $script:Root 'Video Beam.lnk'))
    Assert-True ($shortcut.IconLocation -match 'vb-icon\.ico') 'The shortcut icon was not vb-icon.ico'
    Assert-True ($script:VersionLabel.Parent -eq $script:StatusPanel) 'The version is not in the status bar'
    Assert-True ($script:SubtitleLabel.Text -match [regex]::Escape((Get-SaveFolderName))) 'The header did not name the save folder'
    $script:LinkBox.Text = "https://www.youtube.com/watch?v=abc`r`nhttps://youtu.be/zzz"
    Update-LinkHint
    Assert-True ($script:LinkHint.Text -match '2 links') 'The link count was missing'
    $script:LinkBox.Clear()
    $script:ClipStartBox.Text = '1:30'
    $script:ClipEndBox.Text = '3:00'
    $readyClip = Get-ClipRequest
    Assert-True ($readyClip.Active -and $readyClip.Section -eq '*0:01:30-0:03:00') ("Clip section was $($readyClip.Section)")
    Assert-True ($readyClip.StartSeconds -eq 90 -and $readyClip.EndSeconds -eq 180) ("Clip seconds were $($readyClip.StartSeconds)-$($readyClip.EndSeconds)")
    $script:ClipStartBox.Text = ''
    $script:ClipEndBox.Text = ''
    Assert-True (-not [string]::IsNullOrWhiteSpace($script:Tips.GetToolTip($script:VersionLabel))) 'Version tooltip was missing'
    Assert-True (-not [string]::IsNullOrWhiteSpace($script:Tips.GetToolTip($script:ClipStartBox))) 'Clip start tooltip was missing'
    Assert-True (-not [string]::IsNullOrWhiteSpace($script:Tips.GetToolTip($script:CheckUpdateButton))) 'Check for updates tooltip was missing'
    Assert-True ((Compare-AppVersion '1.0.0' '1.0.1') -eq -1) 'An older version compared as newer'
    Assert-True ($null -eq (Compare-AppVersion 'video_downloader' '1.0.1')) 'A name was treated as a version'
    $sameOffer = Get-UpdateOffer ([pscustomobject]@{
        tag_name = 'v1.0.1'
        assets = @([pscustomobject]@{ name = 'video_downloader.exe'; browser_download_url = 'https://github.com/philipvern-dot/video_beam/releases/download/v1.0.1/video_downloader.exe'; size = 12 })
    })
    Assert-True (-not $sameOffer.Newer) 'The current version was offered as an update'
    $offer = Get-UpdateOffer ([pscustomobject]@{
        tag_name = 'v9.9.9'
        assets = @([pscustomobject]@{ name = 'video_downloader.exe'; browser_download_url = 'https://github.com/philipvern-dot/video_beam/releases/download/v9.9.9/video_downloader.exe'; size = 12 })
    })
    Assert-True ($offer.Newer) 'A newer release was not offered'
    Apply-UpdateOffer $offer
    Assert-True ($script:UpdateButton.Enabled) 'Update stayed disabled after a newer release'
    Set-Busy $true
    Assert-True ((-not $script:CheckUpdateButton.Enabled) -and (-not $script:UpdateButton.Enabled)) 'Update buttons stayed enabled during a download'
    $script:UpdateOffer = $null
    Set-Busy $false
    Assert-True ($script:CheckUpdateButton.Enabled -and -not $script:UpdateButton.Enabled) 'Update buttons did not return to normal after the download'
    Assert-True ($script:TitleLabel.Right -le $script:CheckUpdateButton.Left) 'The title overlaps Check for updates'
    Assert-True ($script:UpdateButton.Right -le ($script:Header.ClientSize.Width - 8)) 'Update sits outside the header'
    Assert-True ($script:ReportBugButton.Right -le ($script:Header.ClientSize.Width - 8)) 'Report a bug sits outside the header'
    Assert-True ($script:DonateButton.Right -le ($script:ReportBugButton.Left + 1)) 'Donate overlaps Report a bug'
    Assert-True ($script:DonateButton.Top -ge $script:UpdateButton.Bottom) 'Donate overlaps the update buttons'
    Assert-True ($script:TitleLabel.Right -le $script:DonateButton.Left) 'The title overlaps Donate'
    $script:Running = $true
    Set-Busy $true
    Assert-True ($script:DonateButton.Enabled -and $script:ReportBugButton.Enabled) 'Donate and Report a bug were disabled during a download'
    Set-Busy $false
    $script:Saved = 0
    $script:Skipped = 0
    $script:Failed = 0
    $script:DetailedCheck.Checked = $false
    Receive-Line '[download] Destination: E:\Youtube Downloads\downloads\Me at the zoo [jNQXAC9IVRw].mp4'
    Receive-Line 'YD_SAVED:E:\Youtube Downloads\downloads\Me at the zoo [jNQXAC9IVRw].mp4'
    Receive-Line '[youtube] abc123: has already been recorded in the archive'
    Receive-Line 'ERROR: [youtube] xyz: Video unavailable'
    Receive-Line '[download] Downloading item 2 of 10'
    Add-PendingLine '[download]  45.2% of  10.00MiB at  1.50MiB/s ETA 00:03'
    Assert-True ($script:Saved -eq 1) "Parser saved $($script:Saved)"
    Assert-True ($script:Skipped -eq 1) "Parser skipped $($script:Skipped)"
    Assert-True ($script:Failed -eq 1) "Parser failed $($script:Failed)"
    Assert-True ($script:ItemIndex -eq 2 -and $script:ItemCount -eq 10) 'Parser item counter'
    Assert-True ([math]::Abs($script:LivePercent - 45.2) -lt 0.01) "Parser percent $($script:LivePercent)"
    $script:ClipPhase = 'cut'
    $script:ClipDuration = 10
    $script:ItemCount = 0
    $script:CurrentName = 'clip.mp4'
    $script:DetailedCheck.Checked = $true
    $script:Running = $true
    $cutLog = $script:Log.Text
    Receive-Line 'stream_0_0_q=24.0'
    Receive-Line 'frame=120'
    Receive-Line 'out_time_us=5000000'
    Receive-Line 'speed=3.50x'
    Assert-True ($script:Log.Text -eq $cutLog) 'Ffmpeg progress was written to the activity'
    Assert-True ([math]::Abs($script:LivePercent - 50) -lt 0.01) "Cut percent was $($script:LivePercent)"
    Update-LiveProgress
    Assert-True ($script:StatusLabel.Text -eq 'Cutting video   50%') "Cut status was $($script:StatusLabel.Text)"
    Assert-True ([math]::Abs($script:ProgressValue - 50) -lt 0.01) "Cut bar was $($script:ProgressValue)"
    $script:ClipPhase = ''
    $script:Running = $false
    $script:DetailedCheck.Checked = $false
    $script:RecentRaw = New-Object System.Collections.Generic.List[string]
    $script:RecentRaw.Add('ERROR: unable to download video data: HTTP Error 403: Forbidden')
    Assert-True (Test-DownloadRefused) 'A 403 was not treated as a refusal'
    $script:RecentRaw.Clear()
    Assert-True (-not (Test-DownloadRefused)) 'An empty log was treated as a refusal'
    if ($script:HelpForm) { $script:HelpForm.Close() }
    $script:Form.Close()
    Write-Output 'SMOKE OK'
}

try {
    if ($script:SmokeTest) {
        Invoke-SmokeTest
        exit 0
    }
    [void][System.Windows.Forms.Application]::Run($script:Form)
} catch {
    $msg = $_.Exception.ToString()
    if ($script:SmokeTest) {
        Write-Output ("SMOKE FAIL: " + $msg)
        Write-Output $_.ScriptStackTrace
        Write-Output $_.InvocationInfo.PositionMessage
        exit 1
    }
    try {
        [Windows.Forms.MessageBox]::Show($msg, 'Video Beam', 'OK', 'Error') | Out-Null
    } catch { }
    exit 1
}
