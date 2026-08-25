# R36S Toolbox

O R36S Toolbox é uma coleção de ferramentas de diagnóstico e manutenção para R36S, dArkOS, ArkOS e variantes compatíveis. A arquitetura foi inspirada no launcher `YouTube.sh` enviado pelo usuário e nas estruturas observadas em dArkOS, ArkOS4Clone e projetos de informações de sistema para ArkOS.

A primeira versão foi desenhada para funcionar em userspace, sem substituir kernel, DTB, U-Boot, ROMs ou BIOS. Como cada R36S/clonagem pode usar painel, device tree, kernel e mapeamento de controles diferentes, todos os módulos detectam caminhos disponíveis e exibem `N/A` quando um recurso não existe.

> **Estado do projeto:** protótipo funcional em shell, com módulos seguros e um módulo experimental de frequência protegido. Os autotestes passam no sandbox, mas nenhum script pode ser considerado validado no R36S físico sem execução no aparelho do usuário.
>
> **Download para o console:** [baixar o ZIP PortMaster na Release](https://github.com/davizerascript/r36s-toolbox/releases/latest). Extraia-o em `/roms/ports` para que o launcher fique em `/roms/ports/r36stoolbox/R36S Toolbox.sh`.

## Relação com o pacote YouTube

O pacote enviado contém um launcher e dois binários AArch64. O launcher prepara `control.txt`, `LD_LIBRARY_PATH`, SDL e o terminal; o executável principal usa SDL2, pesquisa com `yt-dlp` e reproduz por `mpv`, `ffplay` ou `mplayer`. O Toolbox reutiliza a mesma ideia de launcher relocável, execução em primeiro plano, logs e integração com o ambiente do PortMaster, mas não modifica os binários do YouTube.

## Módulos

| Módulo | Comando | Função | Alteração no sistema |
|---|---|---|---|
| Diagnóstico | `diagnostic` | Modelo, DTB, CPU, governor, frequência, temperatura, GPU, memória, bateria, tela, rede e software. | Somente leitura; grava relatório. |
| Controles | `controls` | Lista dispositivos SDL/evdev/joystick e captura eventos quando `evtest` ou `jstest` existem. | Somente leitura. |
| Telemetria | `monitor` | Registra temperatura, frequência, carga e memória em CSV durante um intervalo. | Somente leitura; grava CSV. |
| Perfis de CPU | `profile` | Desempenho, equilibrado, economia e restauração. | Altera apenas o governor exposto pelo kernel. |
| Backup | `backup` | Salva saves, estados e configurações conhecidas; verifica e restaura archives. | Cria arquivos no diretório do Toolbox. |
| Rede | `network` | Interface, SSID, IP, rotas, DNS e ping. | Somente leitura; realiza ping. |
| Manutenção | `maintenance` | Espaço, maiores arquivos, limpeza de caches conhecidos e reset do estado do Toolbox. | Não toca em ROMs/saves; limpeza é confirmada. |
| Ports | `ports` | Verifica scripts, permissões, sintaxe, manifestos, imagens e arquitetura aparente dos binários. | Não executa ports. |
| CPU experimental | `cpu-experimental` | Descobre frequências e pode alterar temporariamente o teto para um valor exposto pelo kernel. | Protegido; desabilitado por padrão. |

## Download e instalação no dArkOS

Baixe o arquivo `r36stoolbox-v0.1.0.zip` na página de [Releases](https://github.com/davizerascript/r36s-toolbox/releases/latest). Esse é o pacote pronto para a aba **Ports**; o arquivo `.tar.gz` é destinado ao código completo e desenvolvimento.

## Instalação no dArkOS

Copie a pasta para o R36S e execute o instalador pelo SSH ou por um terminal local:

```bash
cd /caminho/r36s-toolbox
./install.sh
```

O destino padrão é `/roms/ports/r36stoolbox`, e o launcher é instalado como `/roms/ports/r36stoolbox/R36S Toolbox.sh`. Assim, o item aparece na coleção **Ports** após reiniciar ou atualizar o EmulationStation. Se `/roms/ports` não for gravável pelo usuário atual, use o método de elevação de privilégio disponível na sua imagem, sem substituir a partição de boot.

Para instalar em uma árvore de teste ou em outro ponto montado:

```bash
R36S_TOOLBOX_INSTALL_ROOT=/caminho/de/teste/ports ./install.sh
```

Para abrir um módulo diretamente:

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" diagnostic
"/roms/ports/r36stoolbox/R36S Toolbox.sh" controls
"/roms/ports/r36stoolbox/R36S Toolbox.sh" monitor
"/roms/ports/r36stoolbox/R36S Toolbox.sh" profile status
"/roms/ports/r36stoolbox/R36S Toolbox.sh" backup
"/roms/ports/r36stoolbox/R36S Toolbox.sh" network
"/roms/ports/r36stoolbox/R36S Toolbox.sh" maintenance
"/roms/ports/r36stoolbox/R36S Toolbox.sh" ports
"/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental status
```

Dentro do menu principal, `0` é **Sair para o menu Ports**. O botão B cancela a tela atual e, no menu principal, também retorna ao Ports. O launcher encerra o gptokeyb criado pelo port, chama `pm_finish` quando disponível, tenta restaurar `oga_events` no ArkOS e limpa o terminal.

## Perfis de CPU

Os perfis usam somente arquivos `cpufreq` existentes. O modo desempenho prefere `performance`; o modo equilibrado prefere `schedutil` ou `ondemand`; o modo economia prefere `powersave` ou `conservative`. Se o governor preferido não existir, o módulo tenta uma alternativa disponível.

O estado original é guardado em `state/cpufreq-previous.tsv` antes da primeira alteração. O comando de restauração tenta devolver governor, frequência mínima e frequência máxima anteriores. A alteração não é permanente por design e pode desaparecer no reboot.

## CPU experimental

O módulo experimental começa em modo de descoberta e não altera nada. Para aplicar um valor, ele exige a variável de ambiente `R36S_TOOLBOX_EXPERIMENTAL=1`, confirmação interativa e um valor presente em `scaling_available_frequencies`.

Exemplo conceitual, somente depois de confirmar a lista no seu aparelho:

```bash
R36S_TOOLBOX_EXPERIMENTAL=1 \
  "/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental apply 1296000
```

O valor acima é apenas um exemplo de formato; não deve ser copiado sem aparecer na lista de frequências expostas pelo kernel do aparelho. O módulo não altera voltagem, não escreve DTB, não altera U-Boot, não inventa frequência e não cria uma entrada nova no kernel. Para restaurar:

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental restore
```

Um overclock real também depende de temperatura, estabilidade do SoC, memória, kernel, regulador e device tree. O Toolbox não promete que um valor exposto seja estável em todos os lotes.

## Backup

O backup procura saves e estados comuns, como `.sav`, `.srm`, `.state`, `.rtc`, `.mcr`, `.mcd`, `.eep`, `.fla`, `.hi` e alguns JSON de save. Ele também inclui arquivos de estado pequenos do próprio Toolbox e configurações conhecidas, quando existem.

O arquivo é armazenado em `/roms/ports/r36stoolbox/r36stoolbox/conf/backups`. A restauração rejeita nomes absolutos e caminhos com traversal, como `../arquivo`, antes da extração. Mesmo assim, recomenda-se manter uma cópia do cartão microSD antes de testar alterações de firmware ou DTB.

## Testes no sandbox

O projeto inclui `tests/self-test.sh`. Ele verifica a sintaxe dos scripts, garante que o launcher não depende do YouTube, cria um port mock para o verificador e testa a rejeição de um archive inseguro.

```bash
./tests/self-test.sh
```

O resultado validado no ambiente de desenvolvimento foi:

```text
Resultado: 0 falha(s)
```

O sandbox não reproduz a variante física do R36S. A etapa obrigatória no aparelho é conferir modelo, kernel, arquitetura, DTB, paths de `cpufreq`, temperatura, bateria, tela, controles e permissões antes de habilitar qualquer módulo que escreva configurações.

## Diagnóstico de uma instalação real

Execute primeiro:

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" diagnostic
"/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental status
"/roms/ports/r36stoolbox/R36S Toolbox.sh" ports
```

Depois envie os relatórios gerados em `/roms/ports/r36stoolbox/r36stoolbox/conf/reports` para ajustar caminhos específicos da sua placa. Não envie credenciais, chaves Wi-Fi, tokens ou dados pessoais; o relatório de rede pode conter SSID e endereço IP.

## Próximos incrementos possíveis

A arquitetura permite adicionar um OSD de temperatura/FPS, teste visual de pixels e brilho, suporte a diferentes layouts de controle, sincronização de backup via SSH/Samba habilitado temporariamente, histórico de benchmarks, perfis por jogo, player multimídia local e uma interface SDL2 nativa semelhante à do YouTube.

A integração com ArkOS4Clone deve permanecer em userspace. O seletor de DTB e a customização de painel/controles pertencem ao firmware e não devem ser automatizados pelo Toolbox sem uma identificação explícita da variante e um mecanismo de recuperação.

## Referências técnicas

- [dArkOS Wiki](https://github.com/christianhaitian/dArkOS/wiki)
- [ArkOS4Clone](https://github.com/lcdyk0517/arkos4clone)
- [dArkOSRE-R36](https://github.com/southoz/dArkOSRE-R36)
- [PortMaster — Porting](https://portmaster.games/porting.html)
- [ArkOS System Information](https://github.com/ryanmaule/arkos-systeminfo)
