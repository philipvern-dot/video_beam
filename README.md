# Video Beam

Version 1.0.3

A Windows program that downloads videos and playlists as MP4 files, or audio only as MP3.

Double-click **Video Beam** in this folder. If that shortcut does nothing, open `app\launch.vbs` once. That starts the program and repairs the shortcut.

Paste one link, several links, or a playlist. New files go in the `downloads` folder next to the program until you choose another folder. That choice is saved for the next run.

Check for updates looks for a newer version on GitHub. The program also checks when it opens. Update downloads that version and opens the setup program. The setup replaces the installed copy and keeps your settings. The version is shown at the bottom right.

Clip start and Clip end save part of one video. Leave the start blank to begin at the beginning, or the end blank to continue through the end. A playlist or several links are saved in full. The header names the folder new files go to, and the link box shows how many links are ready.

## What's new in 1.0.2

The version appears at the bottom right. The program checks for updates when it opens, and asks once when a newer version is published. Donate opens a tip page. Report a bug opens a GitHub page and does not send the report.

Clip start and Clip end download one section of a single video, as MP4 or MP3. The file name includes the times.

The header names the save folder. The line under the links counts how many links are ready.

`app\blocked-sites.md` installs with the program. A site listed there is not downloaded. The setup can add a Start menu shortcut and a desktop shortcut. Windows can uninstall Video Beam from Apps & features.

## Tools

The program looks for these files in `tools\`:

- `yt-dlp.exe`
- `ffmpeg.exe`
- `ffprobe.exe`
- `deno.exe`

They are not in this repository. The FFmpeg programs are each larger than GitHub allows. Copy them into `tools\` yourself, or run the Windows setup program `video_beam.exe`, which installs this program and those tools for the current user, adds a Start menu entry, and registers an uninstall entry.

Where each tool comes from, its license, and the bundled version are listed in [`tools/SOURCES.txt`](tools/SOURCES.txt). License texts:

- yt-dlp: [`tools/yt-dlp-LICENSE.txt`](tools/yt-dlp-LICENSE.txt) (Unlicense)
- FFmpeg and ffprobe: [`tools/FFmpeg-LICENSE.txt`](tools/FFmpeg-LICENSE.txt) (GPL-3.0)
- Deno: [`tools/Deno-LICENSE.txt`](tools/Deno-LICENSE.txt) (MIT)

## License

This program is released under the MIT License. See [LICENSE](LICENSE).

yt-dlp, FFmpeg, and Deno are separate programs and keep their own licenses. FFmpeg is GPL-3.0.

Do not download copyrighted material!
