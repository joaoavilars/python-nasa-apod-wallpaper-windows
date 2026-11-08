# NASA APOD como papel de parede (Windows)

🇧🇷 Português | [🇺🇸 English](README.md)

Baixa a imagem do dia do [NASA APOD](https://science.nasa.gov/apod/) e a aplica como papel de parede
no **Windows**.

## Referência

Este projeto foi inspirado na extensão do GNOME
[NASA APOD Wallpaper Changer](https://github.com/Elinvention/gnome-shell-extension-nasa-apod)
(`nasa_apod@elinvention.ovh`), de Elinvention, e segue a mesma abordagem: o endpoint atual da NASA e
opções como qualidade da imagem e miniatura de vídeos. Se você usa Linux com GNOME, use a extensão original.

## Arquivos

| Arquivo | Função |
|---|---|
| `get_wall_day.py` | Baixa o APOD do dia, salva na pasta configurada (padrão: `Imagens\nasa` do seu usuário) como `APOD_AAAA-MM-DD.ext` e aplica a imagem mais recente como papel de parede. |
| `get_all_walls.py` | Baixa um período (completa a coleção). Uso: `python get_all_walls.py [inicio] [fim]` (AAAA-MM-DD). Não troca o papel de parede. |
| `apod_common.py` | Código compartilhado (leitura da configuração, download, aplicação do papel de parede). |
| `config.json` | Sua configuração local (não vai para o Git). Criada a partir de `config.example.json`. |
| `config.example.json` | Modelo de configuração com os valores padrão. |
| `run_daily.bat` | Chama o `get_wall_day.py` a partir da própria pasta. É o que a tarefa agendada executa. |
| `Download_NASA_APOD.xml` | Definição da tarefa agendada para importar no Agendador de Tarefas. |

## Configuração (`config.json`)

Copie `config.example.json` para `config.json` e edite o que quiser. Opções omitidas usam o padrão.
Se o arquivo não existir, os padrões são usados.

| Opção | Padrão | Descrição |
|---|---|---|
| `download_dir` | `%USERPROFILE%\Pictures\nasa` | Pasta onde as imagens são salvas. Aceita variáveis (`%USERPROFILE%`), `~` e caminho relativo (a partir da pasta do projeto). Use `\\` ou `/` no JSON. |
| `set_wallpaper` | `true` | Se `false`, só baixa as imagens e não mexe no papel de parede. |
| `wallpaper_style` | `"fill"` | Ajuste: `fill` (preencher), `fit` (ajustar), `stretch` (esticar), `tile` (lado a lado), `center` (centralizar), `span` (estender em vários monitores). |
| `apply_only_when_new` | `false` | Se `true`, só troca o papel de parede quando baixa uma imagem nova. Assim uma troca manual sua não é desfeita nas outras execuções do dia. |
| `image_quality` | `"hd"` | `hd` (original) ou `standard` (960 px de largura, como a extensão do GNOME em conexão limitada). |
| `video_thumbnail` | `false` | Se `true`, em dias de vídeo usa a miniatura do YouTube em vez de pular o dia. |
| `min_file_size_kb` | `10` | Arquivos menores que isso são descartados (placeholders, logo da NASA). |
| `request_timeout_seconds` | `60` | Tempo máximo de espera por requisição. |

Exemplo para guardar em outro disco:

```json
{ "download_dir": "D:/Imagens/NASA", "apply_only_when_new": true }
```

## Fonte dos dados

A NASA trocou a API. O script usa o endpoint atual, **sem API key**:

- Dia atual: `https://science.nasa.gov/wp-json/wp/v2/apod-basic?per_page=1`
- Dia específico: `https://science.nasa.gov/wp-json/wp/v2/apod-basic/AAMMDD` (ex.: `/261108`)

Detalhes importantes:

- A listagem só devolve os ~25 itens mais recentes; períodos maiores são consultados dia a dia.
- O campo `url` é a página do artigo. A imagem está em `hdurl`, que vem com query string
  (`?w=0&h=0&...`); os scripts removem tudo depois do `?`.
- Vídeos são ignorados (ou usam a miniatura, com `video_thumbnail`). Arquivos menores que
  `min_file_size_kb` são descartados (placeholders / logo da NASA).

## Requisitos

- Python 3 no PATH (`python --version`)
- Dependências: `pip install -r requirements.txt` (apenas `requests`)
- A pasta das imagens fica no `config.json`. No `Download_NASA_APOD.xml`, troque `C:\CAMINHO\DO\PROJETO`
  pela pasta onde você salvou este projeto (nos campos `Command` e `WorkingDirectory`).

## Teste manual

```powershell
cd C:\CAMINHO\DO\PROJETO
python get_wall_day.py
```

Saída esperada: `Sucesso: APOD_... salvo` (ou `A imagem de hoje ja foi baixada.`) e
`Papel de parede aplicado: APOD_....jpg`.

## Agendar a execução diária

### Opção A: importar o XML (interface gráfica)

1. Abra o **Agendador de Tarefas** (`taskschd.msc`).
2. **Ação > Importar Tarefa...** e selecione `Download_NASA_APOD.xml`.
3. Na aba **Geral**, confira que o usuário é o seu e que está marcado
   **Executar somente quando o usuário estiver conectado** (necessário para trocar o papel de parede).
4. Na aba **Ações**, confira o caminho do `run_daily.bat`.
5. Clique **OK**.

Se já existir uma tarefa chamada `Download NASA APOD`, exclua-a antes ou renomeie a nova.

### Opção B: importar pelo terminal

```powershell
schtasks /Create /TN "Download NASA APOD" /XML "C:\CAMINHO\DO\PROJETO\Download_NASA_APOD.xml"
```

Para executar na hora: `schtasks /Run /TN "Download NASA APOD"`

### Quando a tarefa dispara

- Todos os dias às 09:00.
- 1 minuto após o logon.
- Se o PC estava desligado no horário, roda assim que possível (`StartWhenAvailable`).
- Só roda com rede disponível.

Para mudar o horário, edite `<StartBoundary>` no XML (ou altere o gatilho no Agendador).

## Comportamento do papel de parede

- Toda execução aplica a imagem `APOD_*` **mais recente** (pela data no nome), no ajuste de `wallpaper_style`.
- Uma troca manual (Personalizar > Plano de fundo) **vale só até a próxima execução** da tarefa.
  Para mantê-la, use `"apply_only_when_new": true` (a tarefa só troca quando sai imagem nova)
  ou desative a tarefa temporariamente.
- Aplicar uma imagem fixa desliga o slideshow do Windows. Se você religar o slideshow, a
  próxima execução do script volta a sobrescrevê-lo.
- Formatos aceitos para aplicar: jpg, jpeg, png, bmp. Gif e tif ficam na pasta, mas não são aplicados.

## Licença

[MIT](LICENSE). As imagens baixadas pertencem aos seus respectivos autores; consulte os créditos
no site do [NASA APOD](https://science.nasa.gov/apod/) antes de redistribuí-las.

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `Hoje o APOD e video` | O APOD do dia é vídeo; mantém a última imagem. |
| `arquivo suspeito (... bytes)` | A NASA devolveu um placeholder; nada é salvo. |
| `Erro ao ler config.json` | JSON inválido (barras `\` simples, vírgula sobrando). Use `\\` ou `/`. |
| Papel de parede não muda pela tarefa | Tarefa configurada para rodar sem sessão aberta; use "somente quando o usuário estiver conectado". |
| `ModuleNotFoundError: requests` | `pip install -r requirements.txt`. |
| `Python` não encontrado na tarefa | Use o caminho completo do `python.exe` em `run_daily.bat`. |
