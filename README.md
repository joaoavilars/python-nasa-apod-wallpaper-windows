# NASA APOD as Wallpaper (Windows)

[🇧🇷 Português](README.pt-BR.md) | 🇺🇸 English

Downloads the [NASA Astronomy Picture of the Day](https://science.nasa.gov/apod/) and sets it as
your **Windows** wallpaper.

## Reference

This project was inspired by the GNOME extension
[NASA APOD Wallpaper Changer](https://github.com/Elinvention/gnome-shell-extension-nasa-apod)
(`nasa_apod@elinvention.ovh`) by Elinvention, and follows the same approach: the current NASA endpoint
and options such as image quality and video thumbnails. If you use Linux with GNOME, use the original extension.

## Files

| File | Purpose |
|---|---|
| `get_wall_day.py` | Downloads today's APOD, saves it to the configured folder (default: `Pictures\nasa` in your user profile) as `APOD_YYYY-MM-DD.ext`, and sets the most recent image as wallpaper. |
| `get_all_walls.py` | Downloads a date range (to complete your collection). Usage: `python get_all_walls.py [start] [end]` (YYYY-MM-DD). Does not change the wallpaper. |
| `apod_common.py` | Shared code (config loading, download, wallpaper setting). |
| `config.json` | Your local settings (not tracked by Git). Created from `config.example.json`. |
| `config.example.json` | Settings template with the default values. |
| `run_daily.bat` | Runs `get_wall_day.py` from its own folder. This is what the scheduled task executes. |
| `Download_NASA_APOD.xml` | Scheduled task definition to import into Task Scheduler. |

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

The script's messages are in Portuguese. Expected output: `Sucesso: imagem de ... salva em ...`
(or `A imagem de hoje ja foi baixada.`) followed by `Papel de parede aplicado: APOD_....jpg`.

## Schedule the daily run

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
| `Hoje o APOD e video` | Today's APOD is a video; the last image is kept. |
| `arquivo suspeito (... bytes)` | NASA returned a placeholder; nothing is saved. |
| `Erro ao ler config.json` | Invalid JSON (single `\` backslashes, trailing comma). Use `\\` or `/`. |
| Wallpaper does not change from the task | Task set to run without a logged-in session; use "Run only when user is logged on". |
| `ModuleNotFoundError: requests` | `pip install -r requirements.txt`. |
| `python` not found in the task | Use the full path to `python.exe` in `run_daily.bat`. |
