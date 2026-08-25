# Pesquisa do R36S Toolbox — achados

## ArkOS4Clone

O repositório `lcdyk0517/arkos4clone` é uma base de porting do kernel dArkOS 4.4 para dispositivos portáteis RK3326 não suportados. O README recomenda uma ferramenta de análise de DTB para identificar o clone e uma ferramenta de customização de DTB para remapear eixos do joystick, botões, capacidade de bateria e taxa de atualização da tela. O repositório também contém scripts de build, seletor de DTB e alterações específicas de kernel/driver; um commit recente menciona mover o tratamento de teclas ADC para o driver de joypad no kernel, reduzindo IPC e sobrecarga do userspace.

O projeto declara que não distribui dados de jogos, apenas ajustes para fazer ports funcionarem. O repositório é público e possui licença MIT. URL: https://github.com/lcdyk0517/arkos4clone

## dArkOSRE-R36

O repositório `southoz/dArkOSRE-R36` é uma build customizada de dArkOS para R36S e clones selecionados. A página lista muitas combinações de placa, variante e painel, indicando que a identificação de hardware/DTB é central. Entre as versões publicadas há R36S V12, V21, V22, V30, R36S Plus, R36XX, G80C/G80CA/G80D e GR36S, com painéis e variantes diferentes. URL: https://github.com/southoz/dArkOSRE-R36

## Implicações para o projeto

O Toolbox não deve gravar diretamente em DTB, kernel, U-Boot ou partições de boot. A primeira versão deve ser uma ferramenta de diagnóstico e configuração em userspace, capaz de detectar variante, painel, kernel, arquitetura, governor, frequências, temperatura, bateria, armazenamento e interfaces disponíveis.

O suporte a bateria, brilho, controles e refresh rate pode variar de acordo com placa, painel e DTB. Por isso, a ferramenta deve detectar caminhos existentes em `/sys`, mostrar o que está disponível e desabilitar ações que não sejam comprovadas no aparelho.

O pacote YouTube enviado pelo usuário contém três arquivos: `YouTube.sh`, `youtube/youtube` e `youtube/yt-dlp`. `youtube` e `yt-dlp` são ELF AArch64 para Linux. O app principal depende dinamicamente de SDL2, SDL2_ttf, SDL2_image, pthread, libm e libc. O programa já usa SDL para tela e controles, chama `yt-dlp`, procura mpv/ffplay/mplayer, usa cache de miniaturas, histórico e favoritos em JSON e possui busca, abas e configurações.

O script do YouTube pode servir como modelo de launcher: localizar PortMaster, carregar `control.txt`, configurar `LD_LIBRARY_PATH`, ajustar SDL e iniciar um binário nativo em primeiro plano com log. Porém, o Toolbox deve ser separado do YouTube, pois os binários estão stripped e não há código-fonte no pacote.

## Fontes

- https://github.com/lcdyk0517/arkos4clone
- https://github.com/southoz/dArkOSRE-R36
- https://github.com/chr15m/web-game-console
- https://portmaster.games/porting.html

## Diagnóstico e display

A wiki atual do dArkOS informa que o sistema é baseado em Debian, mantém userspace 64/32-bit e suporta mais de 800 ports via PortMaster. Também afirma que SSH e Samba ficam desativados por padrão e podem ser habilitados pelo menu Options > Enable Remote Services. URL: https://github.com/christianhaitian/dArkOS/wiki

O projeto comunitário `ryanmaule/arkos-systeminfo` fornece uma referência direta para um utilitário em shell iniciado pelo EmulationStation. Ele coleta modelo via `/proc/device-tree/model`, arquitetura via `uname -m`, CPU e núcleos via `/proc/cpuinfo`, frequência e governor via `/sys/devices/system/cpu/cpu0/cpufreq`, temperatura via `/sys/class/thermal/thermal_zone*/temp`, GPU Mali via `/sys/devices/platform/fde60000.gpu`, memória e swap via `/proc/meminfo`, versão/DTB/kernel, SSID/IP e bateria via `/sys/class/power_supply/battery`. Usa `dialog` e `gptokeyb`, grava relatório em `/roms/tools/system_report.txt` e tem rotina de limpeza. URL: https://github.com/ryanmaule/arkos-systeminfo/blob/main/System%20Info.sh

Esse script é uma boa base de coleta, mas o Toolbox deve melhorar a tolerância: testar cada caminho antes de ler, não matar todos os processos `gptokeyb` indiscriminadamente, preservar configuração anterior e distinguir `N/A` de valor real.

## Estrutura correta para Ports

A documentação oficial do PortMaster exige que um port novo tenha um diretório próprio com `port.json`, `README.md`, `screenshot.png/jpg`, `gameinfo.xml`, um script com nome capitalizado terminado em `.sh` e uma subpasta com o mesmo nome do port. O nome interno do port deve começar com letra minúscula ou número. A configuração de execução deve carregar `control.txt`, chamar `get_controls`, usar `$directory`, `$DEVICE_ARCH`, `$sdl_controllerconfig`, `$GPTOKEYB`, `pm_platform_helper` e `pm_finish` quando disponíveis. URLs: https://portmaster.games/packaging.html e https://github.com/PortsMaster/PortMaster-New/blob/main/README.md

O guia antigo/oficial do PortMaster documenta que o script deve chamar `gptokeyb` para o executável e que `pm_finish`/limpeza do gptokeyb e reinício de `oga_events` ajudam a evitar ghost inputs e preservar hotkeys globais após sair. Também documenta detecção de dispositivos por `/dev/input/by-path/`, configuração de `SDL_GAMECONTROLLERCONFIG`, diferenciação de `roms`/`roms2` e uso de `directory`. URL: https://github.com/christianhaitian/PortMaster/blob/main/docs/packaging.md

Para o Toolbox, o launcher correto deve ficar em uma pasta como `/roms/ports/r36stoolbox/`, ter o arquivo `/roms/ports/r36stoolbox/R36S Toolbox.sh` e a subpasta `/roms/ports/r36stoolbox/r36stoolbox/` contendo o código. O script precisa ser chamado pelo PortMaster, não pelo caminho `/roms/tools`. A saída deve ser explícita pelo item `0 Sair para o menu`, pelo hotkey de `gptokeyb` (normalmente Select+Start conforme o dispositivo) e por `pm_finish`/limpeza final.

## Mapeamento

A documentação do gptokeyb define `.gptk` como pares `botão = tecla`, permite remapear A/B/X/Y, Start, Guide, D-pad, analógicos e deadzone, e fornece modo de kill switch. URL: https://portmaster.games/gptokeyb-documentation.html
