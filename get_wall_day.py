"""Baixa o NASA APOD do dia e (opcionalmente) aplica como papel de parede.

Codigo de saida: 0 = ok (avisos incluidos), 1 = houve erro. Isso aparece como
"Resultado da ultima execucao" no Agendador de Tarefas.
"""
import sys

import requests

import apod_common as c
import apod_log as L
from apod_log import ev, log


def run(cfg):
    """Executa o fluxo diario. Retorna True se nao houve erro."""
    ok = True

    try:
        item = c.fetch_apod(cfg)
        if not item or "date" not in item:
            raise ValueError("resposta da API sem o campo 'date'")
    except (requests.RequestException, ValueError) as e:
        log.error("Falha ao consultar a API da NASA (%s): %s", c.BASE_URL, e, extra=ev(L.EV_API_ERROR))
        item = None
        ok = False

    status = None
    if item:
        try:
            status, path = c.download_apod(item, cfg)
        except (requests.RequestException, OSError) as e:
            log.error("Falha ao baixar/salvar a imagem de %s: %s", item["date"], e,
                      extra=ev(L.EV_DOWNLOAD_ERROR))
            ok = False
        else:
            name = path.rsplit("\\", 1)[-1] if path else None
            if status == "novo":
                log.info("Imagem de %s baixada: %s", item["date"], name, extra=ev(L.EV_NEW_IMAGE))
            elif status == "existe":
                log.info("A imagem de %s já havia sido baixada: %s", item["date"], name,
                         extra=ev(L.EV_ALREADY_HAVE))
            elif status == "sem_imagem":
                log.warning("O APOD de %s é do tipo '%s' (sem imagem); mantendo a última imagem. "
                            "Título: %s", item["date"], item.get("media_type"), item.get("title"),
                            extra=ev(L.EV_NO_IMAGE_TODAY))

    if cfg["set_wallpaper"] and (status == "novo" or not cfg["apply_only_when_new"]):
        try:
            c.apply_latest_wallpaper(cfg)
        except Exception:
            log.exception("Erro ao aplicar o papel de parede", extra=ev(L.EV_WALLPAPER_ERROR))
            ok = False
    return ok


def main():
    try:
        cfg = c.load_config()
    except c.ConfigError as e:
        L.setup()
        log.error("%s", e, extra=ev(L.EV_CONFIG_ERROR))
        return 1
    L.setup(cfg)
    try:
        return 0 if run(cfg) else 1
    except Exception:
        log.exception("Erro inesperado", extra=ev(L.EV_UNEXPECTED))
        return 1


if __name__ == "__main__":
    sys.exit(main())
