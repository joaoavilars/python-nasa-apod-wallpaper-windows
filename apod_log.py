"""Logging do projeto: console, arquivo com rotação e Log de Eventos do Windows.

Os eventos aparecem no Visualizador de Eventos em Logs do Windows > Aplicativo,
com a origem (source) "NASA-APOD-Wallpaper". Os IDs abaixo identificam cada situação.
"""
import ctypes
import logging
import os
import sys
from ctypes import wintypes
from logging.handlers import RotatingFileHandler

EVENT_SOURCE = "NASA-APOD-Wallpaper"
DEFAULT_LOG_FILE = os.path.join(
    os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "nasa-apod-wallpaper", "apod.log")

# IDs de evento (1-999). Informação: 1xx | Aviso: 2xx | Erro: 3xx
EV_NEW_IMAGE = 101        # imagem do dia baixada
EV_ALREADY_HAVE = 102     # imagem do dia já existia
EV_WALLPAPER_SET = 103    # papel de parede aplicado
EV_NO_IMAGE_TODAY = 200   # APOD do dia não é imagem (vídeo)
EV_SUSPICIOUS_FILE = 201  # arquivo descartado (placeholder/logo)
EV_NOTHING_TO_APPLY = 202 # nenhuma imagem válida para aplicar
EV_API_ERROR = 300        # falha ao consultar a API da NASA
EV_DOWNLOAD_ERROR = 301   # falha ao baixar a imagem
EV_WALLPAPER_ERROR = 302  # falha ao aplicar o papel de parede
EV_CONFIG_ERROR = 303     # config.json inválido
EV_UNEXPECTED = 399       # erro inesperado

log = logging.getLogger("apod")


def ev(event_id):
    """Uso: log.info("mensagem", extra=ev(EV_NEW_IMAGE))"""
    return {"event_id": event_id}


class _DefaultEventId(logging.Filter):
    def filter(self, record):
        if not hasattr(record, "event_id"):
            record.event_id = 100 if record.levelno < logging.WARNING else (
                200 if record.levelno < logging.ERROR else EV_UNEXPECTED)
        return True


class EventLogHandler(logging.Handler):
    """Escreve no Log de Eventos do Windows (Aplicativo) via advapi32, sem dependências."""

    def __init__(self, source=EVENT_SOURCE):
        super().__init__()
        adv = ctypes.windll.advapi32
        adv.RegisterEventSourceW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
        adv.RegisterEventSourceW.restype = wintypes.HANDLE
        adv.ReportEventW.argtypes = [
            wintypes.HANDLE, wintypes.WORD, wintypes.WORD, wintypes.DWORD, ctypes.c_void_p,
            wintypes.WORD, wintypes.DWORD, ctypes.POINTER(wintypes.LPCWSTR), ctypes.c_void_p]
        adv.ReportEventW.restype = wintypes.BOOL
        adv.DeregisterEventSource.argtypes = [wintypes.HANDLE]
        self._adv = adv
        self._handle = adv.RegisterEventSourceW(None, source)
        if not self._handle:
            raise OSError("RegisterEventSourceW falhou")

    def emit(self, record):
        try:
            if record.levelno >= logging.ERROR:
                etype = 1   # EVENTLOG_ERROR_TYPE
            elif record.levelno >= logging.WARNING:
                etype = 2   # EVENTLOG_WARNING_TYPE
            else:
                etype = 4   # EVENTLOG_INFORMATION_TYPE
            strings = (wintypes.LPCWSTR * 1)(self.format(record)[:30000])
            self._adv.ReportEventW(self._handle, etype, 0, int(record.event_id), None, 1, 0, strings, None)
        except Exception:
            pass  # falha de log nunca deve derrubar o script

    def close(self):
        try:
            if self._handle:
                self._adv.DeregisterEventSource(self._handle)
                self._handle = None
        finally:
            super().close()


def setup(cfg=None, events=True):
    """Configura o logger. `events=False` desliga o Log de Eventos (ex.: downloads em lote)."""
    cfg = cfg or {}
    log.setLevel(logging.INFO)
    log.propagate = False
    log.handlers.clear()
    log.filters.clear()
    log.addFilter(_DefaultEventId())
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s [%(event_id)s] %(message)s", "%Y-%m-%d %H:%M:%S")

    if sys.stdout is not None:  # pythonw.exe não tem console
        console = logging.StreamHandler(sys.stdout)
        console.setFormatter(logging.Formatter("%(message)s"))
        log.addHandler(console)

    path = os.path.expandvars(cfg.get("log_file", DEFAULT_LOG_FILE))
    if path:
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            fh = RotatingFileHandler(path, maxBytes=512 * 1024, backupCount=3, encoding="utf-8")
            fh.setFormatter(fmt)
            log.addHandler(fh)
        except OSError as e:
            log.warning("Não foi possível abrir o arquivo de log %s: %s", path, e)

    if events and cfg.get("log_to_event_log", True) and os.name == "nt":
        try:
            eh = EventLogHandler()
            eh.setFormatter(logging.Formatter("%(message)s"))
            log.addHandler(eh)
        except Exception as e:
            log.warning("Log de Eventos do Windows indisponível: %s", e)
