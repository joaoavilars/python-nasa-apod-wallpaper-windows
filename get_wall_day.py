"""Baixa o NASA APOD do dia e (opcionalmente) aplica como papel de parede."""
import apod_common as c


def main():
    cfg = c.load_config()
    status = "erro"
    try:
        item = c.fetch_apod(cfg)
        status = c.download_apod(item, cfg)
        print({
            "novo": f"Sucesso: imagem de {item['date']} salva em {cfg['download_dir']}",
            "existe": "A imagem de hoje ja foi baixada.",
            "sem_imagem": f"Hoje o APOD e {item.get('media_type')}, sem imagem. Ignorando...",
            "suspeito": "Download descartado (arquivo suspeito).",
        }[status])
    except Exception as e:
        print(f"Erro ao processar: {e}")

    if cfg["set_wallpaper"] and (status == "novo" or not cfg["apply_only_when_new"]):
        try:
            c.apply_latest_wallpaper(cfg)
        except Exception as e:
            print(f"Erro ao aplicar papel de parede: {e}")


if __name__ == "__main__":
    main()
