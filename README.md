# NASA APOD as Wallpaper (Windows)

[🇧🇷 Português](README.pt-BR.md) | 🇺🇸 English

Downloads the [NASA Astronomy Picture of the Day](https://science.nasa.gov/apod/) and sets it as
your **Windows** wallpaper.

## Reference

This project was inspired by the GNOME extension
[NASA APOD Wallpaper Changer](https://github.com/Elinvention/gnome-shell-extension-nasa-apod)
(`nasa_apod@elinvention.ovh`) by Elinvention, and follows the same approach: the current NASA endpoint
and options such as image quality and video thumbnails. If you use Linux with GNOME, use the original extension.

## Quick install

Requires Windows and [Python 3](https://www.python.org/downloads/). In PowerShell, from the project folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer finds Python, installs the dependencies, creates `config.json`, **asks where to save the
images** (suggesting your Pictures folder, e.g. `C:\Users\you\Pictures\nasa`; press Enter to accept),
registers the Windows Event Log source (one UAC prompt, only for this step), and creates the scheduled
task (daily at 09:00 and 1 minute after logon, running windowless). The task points to the folder where the
project currently is, so if you move the project, run `install.ps1 -Force` again. Useful options:

| Option | Effect |
|---|---|
| `-DownloadDir D:\Pictures\NASA` | Images folder, without being asked. |
| `-Yes` | Accepts the suggested values without prompting. |
| `-Time 07:30` | Daily run time (default `09:00`). |
| `-RunNow` | Runs the task once at the end. |
| `-Force` | Replaces the task if it already exists. |
| `-TaskName "..."` | Custom task name. |
| `-PythonPath C:\...\python.exe` | Use a specific Python. |
| `-NoEventLog` | Skips the Event Log registration (no UAC prompt). |
| `-DryRun` | Shows what would be done without changing anything. |

To remove it: `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1` (add `-RemoveEventSource` to also
remove the Event Log source). Your images, `config.json` and logs are kept.

Advanced users who prefer to configure everything by hand can follow [Manual setup](#manual-setup-advanced-users) below. The installer is the recommended path.

## Files

| File | Purpose |
|---|---|
| `install.ps1` / `uninstall.ps1` | One-command install and removal (see above). |
| `apod_log.py` | Logging: console, rotating log file and Windows Event Log. |
| `EventViewer_NASA_APOD.xml` | Event Viewer custom view that filters this project's events. |
| `get_wall_day.py` | Downloads today's APOD, saves it to the configured folder (default: `Pictures\nasa` in your user profile) as `APOD_YYYY-MM-DD.ext`, and sets the most recent image as wallpaper. |
| `get_all_walls.py` | Downloads a date range (to complete your collection). Usage: `python get_all_walls.py [start] [end]` (YYYY-MM-DD). Does not change the wallpaper. |
| `apod_common.py` | Shared code (config loading, download, wallpaper setting). |
| `config.json` | Your local settings (not tracked by Git). Created from `config.example.json`. |
| `config.example.json` | Settings template with the default values. |
| `run_daily.bat` | Runs `get_wall_day.py` from its own folder. This is what the scheduled task executes. |
| `Download_NASA_APOD.xml` | Scheduled task template for [manual setup](#manual-setup-advanced-users) (advanced users); contains a path placeholder you must edit. The installer does not use it. |

## Configuration (`config.json`)

Copy `config.example.json` to `config.json` and edit what you need. Omitted options use their defaults.
If the file does not exist, all defaults are used.

| Option | Default | Description |
|---|---|---|
| `download_dir` | `%USERPROFILE%\Pictures\nasa` | Folder where images are saved. Accepts environment variables (`%USERPROFILE%`), `~`, and relative paths (relative to the project folder). Use `\\` or `/` in JSON. |
| `set_wallpaper` | `true` | If `false`, only downloads images and leaves the wallpaper alone. |
| `wallpaper_style` | `"fill"` | Fit mode: `fill`, `fit`, `stretch`, `tile`, `center`, or `span` (across multiple monitors). |
| `apply_only_when_new` | `false` | If `true`, the wallpaper changes only when a new image was downloaded, so a manual change is not undone by later runs on the same day. |
| `image_quality` | `"hd"` | `hd` (original) or `standard` (960 px wide, like the GNOME extension on metered connections). |
| `video_thumbnail` | `false` | If `true`, on video days the YouTube thumbnail is used instead of skipping the day. |
| `min_file_size_kb` | `10` | Files smaller than this are discarded (placeholders, the NASA logo). |
| `request_timeout_seconds` | `60` | Maximum wait per request. |
| `log_to_event_log` | `true` | Write events to the Windows Event Log (Application). |
| `log_file` | `%LOCALAPPDATA%\nasa-apod-wallpaper\apod.log` | Rotating log file (512 KB x 3 backups). Use `""` to disable. |

Example storing images on another drive:

```json
{ "download_dir": "D:/Pictures/NASA", "apply_only_when_new": true }
```

## Data source

NASA changed its API. The scripts use the current endpoint, with **no API key**:

- Latest: `https://science.nasa.gov/wp-json/wp/v2/apod-basic?per_page=1`
- Specific day: `https://science.nasa.gov/wp-json/wp/v2/apod-basic/YYMMDD` (e.g. `/261108`)

Things worth knowing:

- The list endpoint only returns the ~25 most recent items; longer ranges are fetched day by day.
- The `url` field is the article page. The image is in `hdurl`, which comes with a query string
  (`?w=0&h=0&...`); the scripts strip everything after the `?`.
- Videos are skipped (or use the thumbnail, with `video_thumbnail`). Files smaller than
  `min_file_size_kb` are discarded (placeholders / NASA logo).

## Requirements

- Python 3 on the PATH (`python --version`)
- Dependencies: `pip install -r requirements.txt` (just `requests`)
- Images folder is set in `config.json`. In `Download_NASA_APOD.xml`, replace `C:\PATH\TO\PROJECT`
  with the folder where you saved this project (in both `Command` and `WorkingDirectory`).

## Manual test

```powershell
cd C:\PATH\TO\PROJECT
python get_wall_day.py
```

The script's messages are in Portuguese. Expected output: `Imagem de ... baixada: ...` (or
`A imagem de ... já havia sido baixada: ...`) followed by `Papel de parede aplicado: APOD_....jpg`.

## Logs and Windows events

Every run is recorded in two places (plus the console when run manually):

- **Windows Event Log:** Event Viewer > Windows Logs > **Application**, source **`NASA-APOD-Wallpaper`**.
  The installer also adds a custom view: Event Viewer > Custom Views > **NASA APOD Wallpaper**.
  (Without the installer, import `EventViewer_NASA_APOD.xml` via *Action > Import Custom View*.)
- **Log file:** `%LOCALAPPDATA%\nasa-apod-wallpaper\apod.log`, with rotation.

The script exits with code `1` when there was an error, so Task Scheduler's **Last Run Result** also
shows failures. Event messages are in Portuguese.

| ID | Level | Meaning |
|---|---|---|
| 101 | Information | Today's image downloaded |
| 102 | Information | Today's image was already downloaded |
| 103 | Information | Wallpaper applied |
| 200 | Warning | Today's APOD is not an image (video); last image kept |
| 201 | Warning | File discarded as a suspected placeholder (too small) |
| 202 | Warning | No valid image found to set as wallpaper |
| 300 | Error | Failed to query the NASA API (network, HTTP error, bad response) |
| 301 | Error | Failed to download or save the image |
| 302 | Error | Failed to set the wallpaper |
| 303 | Error | Invalid `config.json` |
| 399 | Error | Unexpected error (the message includes the traceback) |

To list only errors in PowerShell:

```powershell
Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='NASA-APOD-Wallpaper'] and (Level=2)]]"
```

If the event source is not registered, events are still written, but Event Viewer shows them without
formatted text. Run `install.ps1` (or register the source as administrator) to fix that.
`get_all_walls.py` logs to the console and file only, to avoid hundreds of events.

## Manual setup (advanced users)

> **Recommended: use [`install.ps1`](#quick-install).** This section is for advanced users who want full
> control and are comfortable editing paths and using Task Scheduler. Doing it by hand, you take care of
> what the installer does for you:
>
> - Install the dependencies (`pip install -r requirements.txt`) and create `config.json` from `config.example.json`
>   (including choosing `download_dir`).
> - Edit `Download_NASA_APOD.xml`: replace every `C:\PATH\TO\PROJECT` with the real project folder
>   (`Command` and `WorkingDirectory`). Keep a personal copy; don't commit your paths.
> - The XML runs `run_daily.bat`, which calls `python` from your `PATH` (a console window may flash).
>   The installer instead runs `pythonw.exe` windowless, with its full path.
> - Optionally register the Event Log source as administrator (see [Logs and Windows events](#logs-and-windows-events)),
>   otherwise events show up without formatted text.
> - If you move the project, update the task paths yourself.

### Option A: import the XML (GUI)

1. Open **Task Scheduler** (`taskschd.msc`).
2. **Action > Import Task...** and select `Download_NASA_APOD.xml`.
3. On the **General** tab, check that the user is you and that **Run only when user is logged on**
   is selected (required to change the wallpaper).
4. On the **Actions** tab, check the path to `run_daily.bat`.
5. Click **OK**.

If a task named `Download NASA APOD` already exists, delete it first or rename the new one.

### Option B: import from the terminal

```powershell
schtasks /Create /TN "Download NASA APOD" /XML "C:\PATH\TO\PROJECT\Download_NASA_APOD.xml"
```

To run it right away: `schtasks /Run /TN "Download NASA APOD"`

### When the task runs

- Every day at 09:00.
- 1 minute after logon.
- If the PC was off at the scheduled time, it runs as soon as possible (`StartWhenAvailable`).
- Only when a network is available.

To change the time, edit `<StartBoundary>` in the XML (or change the trigger in Task Scheduler).

## Wallpaper behavior

- Every run sets the **most recent** `APOD_*` image (by the date in the filename), using `wallpaper_style`.
- A manual change (Personalize > Background) **lasts only until the next run** of the task.
  To keep it, use `"apply_only_when_new": true` (the task only changes the wallpaper when a new image
  arrives) or temporarily disable the task.
- Setting a fixed image turns off the Windows slideshow. If you turn the slideshow back on, the
  next run of the script overrides it again.
- Supported formats for setting as wallpaper: jpg, jpeg, png, bmp. GIF and TIFF stay in the folder but are not applied.

## License

[MIT](LICENSE). Downloaded images belong to their respective authors; check the credits on the
[NASA APOD](https://science.nasa.gov/apod/) site before redistributing them.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Event 200 / `é do tipo 'video'` | Today's APOD is a video; the last image is kept. |
| Event 201 / `arquivo descartado` | NASA returned a placeholder; nothing is saved. |
| Event 303 / `Erro ao ler config.json` | Invalid JSON (single `\` backslashes, trailing comma). Use `\\` or `/`. |
| Event 300 | No network or NASA API unavailable; the next scheduled run tries again. |
| Scheduled task shows result `1` | Look at the Event Log or `apod.log` for the error event (3xx). |
| Wallpaper does not change from the task | Task set to run without a logged-in session; use "Run only when user is logged on". |
| `ModuleNotFoundError: requests` | `pip install -r requirements.txt`. |
| `python` not found in the task | Use the full path to `python.exe` in `run_daily.bat`. |
