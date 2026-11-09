# NASA APOD como papel de parede (Windows)

🇧🇷 Português | [🇺🇸 English](README.md)

Baixa a imagem do dia do [NASA APOD](https://science.nasa.gov/apod/) e a aplica como papel de parede
no **Windows**.

## Referência

Este projeto foi inspirado na extensão do GNOME
[NASA APOD Wallpaper Changer](https://github.com/Elinvention/gnome-shell-extension-nasa-apod)
(`nasa_apod@elinvention.ovh`), de Elinvention, e segue a mesma abordagem: o endpoint atual da NASA e
opções como qualidade da imagem e miniatura de vídeos. Se você usa Linux com GNOME, use a extensão original.

## Instalação rápida

Requer Windows e [Python 3](https://www.python.org/downloads/). No PowerShell, na pasta do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O instalador localiza o Python, instala as dependências, cria o `config.json`, **pergunta onde salvar as
imagens** (sugerindo a sua pasta de Imagens, ex.: `C:\Users\voce\Pictures\nasa`; basta dar Enter para
confirmar), registra a origem no Log de Eventos do Windows (um pedido de UAC, só para esse passo) e cria a
tarefa agendada (todos os dias às 09:00 e 1 minuto após o logon, sem abrir janela). A tarefa aponta para a
pasta onde o projeto está agora; se você mover o projeto, rode `install.ps1 -Force` de novo. Opções úteis:

| Opção | Efeito |
|---|---|
| `-DownloadDir D:\Imagens\NASA` | Pasta das imagens, sem perguntar. |
| `-Yes` | Aceita os valores sugeridos, sem perguntar. |
| `-Time 07:30` | Horário diário (padrão `09:00`). |
| `-NoRun` | Não executa a primeira vez (por padrão a tarefa roda ao final para baixar e aplicar o papel de parede). |
| `-Force` | Substitui a tarefa se ela já existir. |
| `-TaskName "..."` | Nome personalizado da tarefa. |
| `-PythonPath C:\...\python.exe` | Usa um Python específico. |
| `-NoEventLog` | Pula o registro no Log de Eventos (sem pedido de UAC). |
| `-DryRun` | Mostra o que seria feito, sem alterar nada. |

Para remover: `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1` (use `-RemoveEventSource` para
remover também a origem de eventos). Imagens, `config.json` e logs são mantidos.

Usuários avançados que preferem configurar tudo à mão podem seguir a [Configuração manual](#configuração-manual-usuários-avançados) abaixo. O instalador é o caminho recomendado.

## Arquivos

| Arquivo | Função |
|---|---|
| `install.ps1` / `uninstall.ps1` | Instalação e remoção em um comando (veja acima). |
| `apod_log.py` | Logging: console, arquivo com rotação e Log de Eventos do Windows. |
| `EventViewer_NASA_APOD.xml` | Visão personalizada do Visualizador de Eventos que filtra os eventos do projeto. |
| `get_wall_day.py` | Baixa o APOD do dia, salva na pasta configurada (padrão: `Imagens\nasa` do seu usuário) como `APOD_AAAA-MM-DD.ext` e aplica a imagem mais recente como papel de parede. |
| `get_all_walls.py` | Baixa um período (completa a coleção). Uso: `python get_all_walls.py [inicio] [fim]` (AAAA-MM-DD). Não troca o papel de parede. |
| `apod_common.py` | Código compartilhado (leitura da configuração, download, aplicação do papel de parede). |
| `config.json` | Sua configuração local (não vai para o Git). Criada a partir de `config.example.json`. |
| `config.example.json` | Modelo de configuração com os valores padrão. |
| `run_daily.bat` | Chama o `get_wall_day.py` a partir da própria pasta. É o que a tarefa agendada executa. |
| `Download_NASA_APOD.xml` | Modelo de tarefa agendada para a [configuração manual](#configuração-manual-usuários-avançados) (usuários avançados); tem um marcador de caminho que você precisa editar. O instalador não o usa. |

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
| `log_to_event_log` | `true` | Escreve eventos no Log de Eventos do Windows (Aplicativo). |
| `log_file` | `%LOCALAPPDATA%\nasa-apod-wallpaper\apod.log` | Arquivo de log com rotação (512 KB x 3 backups). Use `""` para desativar. |

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

Saída esperada: `Imagem de ... baixada: ...` (ou `A imagem de ... já havia sido baixada: ...`) e
`Papel de parede aplicado: APOD_....jpg`.

## Baixar imagens anteriores manualmente

Para completar a coleção com imagens de dias anteriores, execute o `get_all_walls.py` **no PowerShell**
(a expressão de data abaixo é sintaxe do PowerShell e não funciona no `cmd`). Ele baixa as imagens
sem trocar o papel de parede; as já baixadas são ignoradas.

Últimos 25 dias (hoje e os 24 anteriores):

```powershell
cd C:\CAMINHO\DO\PROJETO
python .\get_all_walls.py (Get-Date).AddDays(-24).ToString('yyyy-MM-dd')
```

Troque `-24` por `-(N-1)` para os últimos N dias. Para um período específico (`AAAA-MM-DD`, data final opcional):

```powershell
python .\get_all_walls.py 2026-01-01 2026-01-31
```

Se o `python` não estiver no PATH da sessão atual, use o caminho completo, ex.:
`& "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe" .\get_all_walls.py ...`.

## Logs e eventos do Windows

Cada execução é registrada em dois lugares (e no console, quando rodada manualmente):

- **Log de Eventos do Windows:** Visualizador de Eventos > Logs do Windows > **Aplicativo**, origem
  **`NASA-APOD-Wallpaper`**. O instalador também cria uma visão personalizada: Visualizador de Eventos >
  Modos de Exibição Personalizados > **NASA APOD Wallpaper**.
  (Sem o instalador, importe `EventViewer_NASA_APOD.xml` em *Ação > Importar Modo de Exibição Personalizado*.)
- **Arquivo de log:** `%LOCALAPPDATA%\nasa-apod-wallpaper\apod.log`, com rotação.

O script termina com código `1` quando houve erro, então o **Resultado da Última Execução** do
Agendador de Tarefas também mostra as falhas.

| ID | Nível | Significado |
|---|---|---|
| 101 | Informação | Imagem do dia baixada |
| 102 | Informação | A imagem do dia já havia sido baixada |
| 103 | Informação | Papel de parede aplicado |
| 200 | Aviso | O APOD do dia não é imagem (vídeo); mantida a última imagem |
| 201 | Aviso | Arquivo descartado por suspeita de placeholder (muito pequeno) |
| 202 | Aviso | Nenhuma imagem válida para aplicar como papel de parede |
| 300 | Erro | Falha ao consultar a API da NASA (rede, erro HTTP, resposta inválida) |
| 301 | Erro | Falha ao baixar ou salvar a imagem |
| 302 | Erro | Falha ao aplicar o papel de parede |
| 303 | Erro | `config.json` inválido |
| 399 | Erro | Erro inesperado (a mensagem inclui o traceback) |

Para listar só os erros no PowerShell:

```powershell
Get-WinEvent -LogName Application -FilterXPath "*[System[Provider[@Name='NASA-APOD-Wallpaper'] and (Level=2)]]"
```

Se a origem de eventos não estiver registrada, os eventos ainda são gravados, mas o Visualizador de Eventos
os mostra sem o texto formatado. Rode o `install.ps1` (ou registre a origem como administrador) para corrigir.
O `get_all_walls.py` registra só no console e no arquivo, para não gerar centenas de eventos.

## Configuração manual (usuários avançados)

> **Recomendado: use o [`install.ps1`](#instalação-rápida).** Esta seção é para usuários avançados que
> querem controle total e se sentem à vontade para editar caminhos e usar o Agendador de Tarefas. Fazendo
> à mão, você cuida do que o instalador faz por você:
>
> - Instalar as dependências (`pip install -r requirements.txt`) e criar o `config.json` a partir do
>   `config.example.json` (incluindo definir o `download_dir`).
> - Editar o `Download_NASA_APOD.xml`: trocar todo `C:\CAMINHO\DO\PROJETO` pela pasta real do projeto
>   (`Command` e `WorkingDirectory`). Mantenha uma cópia pessoal; não faça commit dos seus caminhos.
> - O XML executa o `run_daily.bat`, que chama o `python` do seu `PATH` (uma janela de console pode piscar).
>   O instalador, em vez disso, executa o `pythonw.exe` sem janela e com o caminho completo.
> - Opcionalmente, registrar a origem no Log de Eventos como administrador (veja
>   [Logs e eventos do Windows](#logs-e-eventos-do-windows)); sem isso, os eventos aparecem sem texto formatado.
> - Se você mover o projeto, atualize os caminhos da tarefa por conta própria.

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
| Evento 200 / `é do tipo 'video'` | O APOD do dia é vídeo; mantém a última imagem. |
| Evento 201 / `arquivo descartado` | A NASA devolveu um placeholder; nada é salvo. |
| Evento 303 / `Erro ao ler config.json` | JSON inválido (barras `\` simples, vírgula sobrando). Use `\\` ou `/`. |
| Evento 300 | Sem rede ou API da NASA indisponível; a próxima execução agendada tenta de novo. |
| Tarefa agendada com resultado `1` | Veja o Log de Eventos ou o `apod.log` para o evento de erro (3xx). |
| Papel de parede não muda pela tarefa | Tarefa configurada para rodar sem sessão aberta; use "somente quando o usuário estiver conectado". |
| `ModuleNotFoundError: requests` | `pip install -r requirements.txt`. |
| `Python` não encontrado na tarefa | Use o caminho completo do `python.exe` em `run_daily.bat`. |
