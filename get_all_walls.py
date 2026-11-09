"""Baixa um periodo do NASA APOD (completa a colecao). Nao troca o papel de parede.

Uso: python get_all_walls.py [data_inicio] [data_fim]   (AAAA-MM-DD)
Padrao: de 2026-01-01 ate hoje. O APOD comecou em 1995-06-16 (milhares de imagens!).
Registra em console e arquivo de log; nao escreve no Log de Eventos (evita centenas de eventos).
"""
import datetime as dt
import sys
import time

import apod_common as c
import apod_log as L
from apod_log import log


def main():
    try:
        cfg = c.load_config()
    except c.ConfigError as e:
        L.setup(events=False)
        log.error("%s", e)
        return 1
    L.setup(cfg, events=False)

    dia = dt.date.fromisoformat(sys.argv[1] if len(sys.argv) > 1 else "2026-01-01")
    fim = dt.date.fromisoformat(sys.argv[2] if len(sys.argv) > 2 else dt.date.today().isoformat())
    falhas = 0

    while dia <= fim:
        ds = dia.isoformat()
        dia += dt.timedelta(days=1)
        try:
            item = c.fetch_apod(cfg, ds)
            if item is None:
                log.info("%s: não encontrado", ds)
                continue
            status, _ = c.download_apod(item, cfg)
            log.info("%s: %s", ds, status)
            if status == "novo":
                time.sleep(0.5)  # nao sobrecarregar o servidor
        except Exception as e:
            falhas += 1
            log.error("%s: falha (%s)", ds, e)
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
