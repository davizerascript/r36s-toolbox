# R36S Toolbox — guia do usuário

## Download

A forma recomendada é abrir a página de [Releases](https://github.com/davizerascript/r36s-toolbox/releases) e baixar o arquivo `r36stoolbox-v0.1.0.zip`. Esse é o pacote pronto para o PortMaster. Não é necessário baixar o arquivo `.tar.gz` de desenvolvimento para usar o Toolbox no console.

## Onde colocar

Extraia o ZIP diretamente na pasta `/roms/ports` do cartão microSD. A estrutura final precisa ficar exatamente assim:

```text
/roms/ports/r36stoolbox/R36S Toolbox.sh
```

Não coloque somente o `.sh` solto em `/roms/ports`; o launcher precisa da pasta interna `r36stoolbox`, das bibliotecas de scripts e do arquivo `toolbox.gptk`.

Pelo computador, a operação é:

```text
abrir o cartão microSD → abrir roms → abrir ports → extrair r36stoolbox-v0.1.0.zip
```

Por SSH, se o ZIP foi enviado para `/tmp`, use:

```bash
unzip -o /tmp/r36stoolbox-v0.1.0.zip -d /roms/ports
chmod +x "/roms/ports/r36stoolbox/R36S Toolbox.sh"
```

Depois reinicie o EmulationStation ou atualize a lista de Ports. O item **R36S Toolbox** aparecerá dentro da aba **Ports**.

## Primeira execução

Antes de alterar perfis ou testar CPU experimental, faça uma cópia do cartão microSD. Abra o Toolbox pela aba Ports e execute nesta ordem:

| Ordem | Função | Motivo |
|---:|---|---|
| 1 | Diagnóstico completo | Confirma variante, kernel, DTB, CPU, temperatura, bateria, tela e rede. |
| 2 | Teste de controles | Mostra dispositivos de entrada, configuração SDL, mapa `.gptk` e captura eventos quando possível. |
| 3 | Verificar ports | Procura erros de sintaxe, permissões, manifestos e arquitetura aparente sem executar jogos. |
| 4 | Backup e restauração | Cria uma cópia de saves e configurações conhecidas. |
| 5 | Telemetria | Registra temperatura, frequência, carga e memória para comparar um jogo ou perfil. |

Os relatórios ficam dentro do próprio port:

```text
/roms/ports/r36stoolbox/r36stoolbox/conf/reports/
```

O log principal fica em:

```text
/roms/ports/r36stoolbox/log.txt
```

## Função de cada opção

### Diagnóstico completo

Coleta informações somente de leitura. Mostra modelo do aparelho, arquitetura, kernel, compatível/device tree, núcleos, governor, frequência atual, frequências disponíveis, temperatura do SoC, GPU quando exposta, memória, swap, espaço em disco, bateria, backlight, interfaces de rede e presença de ferramentas como `dialog`, `gptokeyb`, `mpv` e `iwgetid`.

### Teste de controles

Lista os dispositivos de entrada de `/proc/bus/input/devices`, `/dev/input/event*` e `/dev/input/js*`. Também exibe a configuração SDL recebida pelo `control.txt`, o `SDL_GAMECONTROLLERCONFIG` disponível e o conteúdo do mapa `toolbox.gptk` usado pelo launcher.

Quando `evtest` ou `jstest` existem na imagem, o Toolbox oferece uma captura de eventos por 15 segundos. A captura é somente leitura e serve para confirmar se cada botão chega ao Linux corretamente.

### Monitorar temperatura/CPU/memória

Grava um arquivo CSV com timestamp, temperatura, frequência atual da CPU, carga média e memória disponível. Por padrão, o intervalo é curto para teste rápido. A ferramenta serve para comparar um mesmo jogo em perfis diferentes sem adivinhar se o problema é CPU, aquecimento ou memória.

### Perfis de CPU

O perfil **Desempenho** prefere governor `performance`; **Equilibrado** prefere `schedutil` ou `ondemand`; **Economia** prefere `powersave` ou `conservative`. O Toolbox só escolhe governors que o kernel expõe. Antes de alterar, guarda o estado anterior e oferece restauração.

Os perfis não alteram voltagem, kernel, DTB ou U-Boot. A mudança pode desaparecer no reboot, pois o projeto evita criar uma configuração permanente sem conhecer a variante do console.

### Backup e restauração

Procura saves e estados com extensões comuns, como `.sav`, `.srm`, `.state`, `.rtc`, `.mcr`, `.mcd`, `.eep`, `.fla`, `.hi` e alguns JSON de save. Também inclui algumas configurações conhecidas quando existem.

Os backups ficam em `r36stoolbox/conf/backups`. A restauração valida os nomes internos do archive e rejeita caminhos absolutos ou com `../` antes de extrair.

### Rede e conectividade

Mostra interfaces, estado do Wi‑Fi, SSID quando detectável, IPv4, rota, DNS e resultado de ping. Não configura redes nem envia os relatórios automaticamente.

### Manutenção e armazenamento

Mostra espaço usado, maiores arquivos e caches conhecidos. A limpeza pede confirmação e remove somente conteúdos de cache definidos pelo Toolbox. ROMs, BIOS e saves não fazem parte da limpeza.

### Verificar ports

Examina scripts `.sh` dentro de `/roms/ports`, sem executá-los. Verifica permissão de execução, shebang, sintaxe Bash, `port.json`, `gameinfo.xml`, screenshot e descrição aparente dos binários pelo comando `file` quando disponível.

### CPU experimental

Começa em modo de descoberta e não altera nada. Para aplicar uma frequência, é necessário habilitar explicitamente `R36S_TOOLBOX_EXPERIMENTAL=1`, confirmar a operação e escolher um valor que já esteja em `scaling_available_frequencies`.

Esse módulo não altera voltagem nem inventa frequências. Um valor exposto pelo kernel ainda pode não ser estável no seu lote de aparelho, portanto a função deve ser tratada como teste avançado.

## Controles e saída

| Controle | Ação |
|---|---|
| A | Selecionar/confirmar |
| B | Voltar; no menu principal, sair para a coleção Ports |
| D-pad | Navegar |
| X | Subir página |
| Y | Descer página |
| L1/R1 | Tab/Backspace em telas compatíveis |
| L2/R2 | Home/End em telas compatíveis |
| `0` no menu principal | **Sair para o menu Ports** |
| Start + Select | Encerramento pelo hotkey do gptokeyb/PortMaster, conforme o firmware |

O launcher usa `get_controls` e o `sdl_controllerconfig` do PortMaster. Assim, a configuração do controle não fica presa a um GUID fixo de um único clone. A opção Teste de controles permite conferir qual configuração foi realmente carregada.

## Remoção

Para remover o Toolbox, apague somente:

```text
/roms/ports/r36stoolbox/
```

Se o módulo experimental tiver sido usado, execute primeiro:

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental restore
```

Depois remova a pasta. Não apague `/roms/ports/PortMaster` nem outras pastas de ports.
