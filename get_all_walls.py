"""Baixa um periodo do NASA APOD (completa a colecao). Nao troca o papel de parede.

Uso: python get_all_walls.py [data_inicio] [data_fim]   (AAAA-MM-DD)
Padrao: de 2026-01-01 ate hoje. O APOD comecou em 1995-06-16 (milhares de imagens!).
"""
import datetime as dt
import sys
import time

import apod_common as c


def main():
    cfg = c.load_config()
    dia = dt.date.fromisoformat(sys.argv[1] if len(sys.argv) > 1 else "2026-01-01")
    fim = dt.date.fromisoformat(sys.argv[2] if len(sys.argv) > 2 else dt.date.today().isoformat())

    while dia <= fim:
        ds = dia.isoformat()
        dia += dt.timedelta(days=1)
        try:
            item = c.fetch_apod(cfg, ds)
            if item is None:
                print(f"{ds}: nao encontrado")
                continue
            status = c.download_apod(item, cfg)
            print(f"{ds}: {status}")
            if status == "novo":
                time.sleep(0.5)  # nao sobrecarregar o servidor
        except Exception as e:
            print(f"{ds}: falha ({e})")


if __name__ == "__main__":
    main()
