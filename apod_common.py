"""Funcoes compartilhadas por get_wall_day.py e get_all_walls.py."""
import ctypes
import glob
import json
import os
import re

import requests

from apod_log import (
    DEFAULT_LOG_FILE, EV_NOTHING_TO_APPLY, EV_SUSPICIOUS_FILE, EV_WALLPAPER_ERROR,
    EV_WALLPAPER_SET, ev, log)

BASE_URL = "https://science.nasa.gov/wp-json/wp/v2/apod-basic"
HEADERS = {"User-Agent": "Mozilla/5.0"}
APP_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(APP_DIR, "config.json")

DEFAULTS = {
    "download_dir": "%USERPROFILE%\\Pictures\\nasa",
    "set_wallpaper": True,
    "wallpaper_style": "fill",       # fill | fit | stretch | tile | center | span
    "apply_only_when_new": False,    # True: so troca o papel de parede quando baixar imagem nova
    "image_quality": "hd",           # hd | standard (960 px de largura)
    "video_thumbnail": False,        # True: em dias de video, usa a miniatura do YouTube
    "min_file_size_kb": 10,          # abaixo disso o arquivo e descartado (placeholder/logo)
    "request_timeout_seconds": 60,
    "log_to_event_log": True,        # escreve no Log de Eventos do Windows (Aplicativo)
    "log_file": DEFAULT_LOG_FILE,    # arquivo de log com rotacao; "" desativa
}

# (WallpaperStyle, TileWallpaper) no registro do Windows
WALLPAPER_STYLES = {
    "fill": ("10", "0"), "fit": ("6", "0"), "stretch": ("2", "0"),
    "tile": ("0", "1"), "center": ("0", "0"), "span": ("22", "0"),
}
WALLPAPER_EXTS = (".jpg", ".jpeg", ".png", ".bmp")


class ConfigError(Exception):
    pass


def load_config():
    cfg = dict(DEFAULTS)
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                cfg.update({k: v for k, v in json.load(f).items() if k in DEFAULTS})
        except (OSError, ValueError) as e:
            raise ConfigError(f"Erro ao ler {CONFIG_PATH}: {e}") from e
    if cfg["wallpaper_style"] not in WALLPAPER_STYLES:
        raise ConfigError(f"wallpaper_style inválido: {cfg['wallpaper_style']} (use {', '.join(WALLPAPER_STYLES)})")
    if cfg["image_quality"] not in ("hd", "standard"):
        raise ConfigError("image_quality inválido (use 'hd' ou 'standard')")
    # Expande ~ e variaveis de ambiente; caminhos relativos partem da pasta do projeto
    d = os.path.expanduser(os.path.expandvars(cfg["download_dir"]))
    cfg["download_dir"] = d if os.path.isabs(d) else os.path.join(APP_DIR, d)
    return cfg


def fetch_apod(cfg, date=None):
    """Retorna o dict do APOD (do dia, ou de `date` AAAA-MM-DD). None se nao existir."""
    url = BASE_URL + "?per_page=1" if date is None else f"{BASE_URL}/{date[2:4]}{date[5:7]}{date[8:10]}"
    r = requests.get(url, headers=HEADERS, timeout=cfg["request_timeout_seconds"])
    if r.status_code == 404:
        return None
    r.raise_for_status()
    item = r.json()
    return item[0] if isinstance(item, list) else item


def _image_url(item, cfg):
    """Devolve a URL da imagem a baixar, ou None se o dia nao tem imagem aproveitavel."""
    hd = (item.get("hdurl") or "").split("?")[0]
    if item.get("media_type") == "image" and hd:
        return hd if cfg["image_quality"] == "hd" else hd + "?w=960"
    if item.get("media_type") == "video" and cfg["video_thumbnail"]:
        m = re.search(r"youtube(?:-nocookie)?\.com/embed/([\w-]+)", item.get("basic_html") or "")
        if m:
            q = "maxresdefault" if cfg["image_quality"] == "hd" else "hqdefault"
            return f"https://i.ytimg.com/vi/{m.group(1)}/{q}.jpg"
    return None


def download_apod(item, cfg):
    """Baixa a imagem do item. Retorna (status, caminho):
    status = 'novo', 'existe', 'sem_imagem' ou 'suspeito'."""
    date = item["date"]
    os.makedirs(cfg["download_dir"], exist_ok=True)
    existing = glob.glob(os.path.join(cfg["download_dir"], f"APOD_{date}.*"))
    if existing:
        return "existe", existing[0]
    url = _image_url(item, cfg)
    if not url:
        return "sem_imagem", None
    ext = url.split("?")[0].rsplit(".", 1)[-1].lower()
    r = requests.get(url, headers=HEADERS, timeout=cfg["request_timeout_seconds"] * 2)
    if r.status_code != 200 or len(r.content) < cfg["min_file_size_kb"] * 1024:
        log.warning("%s: arquivo descartado por suspeita de placeholder (HTTP %s, %s bytes): %s",
                    date, r.status_code, len(r.content), url, extra=ev(EV_SUSPICIOUS_FILE))
        return "suspeito", None
    path = os.path.join(cfg["download_dir"], f"APOD_{date}.{ext}")
    with open(path, "wb") as f:
        f.write(r.content)
    return "novo", path


def apply_latest_wallpaper(cfg):
    """Aplica a imagem APOD_* mais recente (pela data no nome) como papel de parede.
    Retorna o nome do arquivo aplicado, ou None."""
    import winreg
    d = cfg["download_dir"]
    files = sorted(
        f for f in os.listdir(d)
        if f.startswith("APOD_") and f.lower().endswith(WALLPAPER_EXTS)
        and os.path.getsize(os.path.join(d, f)) >= cfg["min_file_size_kb"] * 1024
    ) if os.path.isdir(d) else []
    if not files:
        log.warning("Nenhuma imagem APOD válida encontrada em %s para aplicar como papel de parede.",
                    d, extra=ev(EV_NOTHING_TO_APPLY))
        return None
    style, tile = WALLPAPER_STYLES[cfg["wallpaper_style"]]
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\Desktop", 0, winreg.KEY_SET_VALUE) as k:
        winreg.SetValueEx(k, "WallpaperStyle", 0, winreg.REG_SZ, style)
        winreg.SetValueEx(k, "TileWallpaper", 0, winreg.REG_SZ, tile)
    # SPI_SETDESKWALLPAPER = 20; UPDATEINIFILE | SENDCHANGE = 3
    if not ctypes.windll.user32.SystemParametersInfoW(20, 0, os.path.join(d, files[-1]), 3):
        log.error("O Windows recusou aplicar o papel de parede: %s", os.path.join(d, files[-1]),
                  extra=ev(EV_WALLPAPER_ERROR))
        return None
    log.info("Papel de parede aplicado: %s (ajuste: %s)", files[-1], cfg["wallpaper_style"],
             extra=ev(EV_WALLPAPER_SET))
    return files[-1]
