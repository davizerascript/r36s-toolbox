# R36S Toolbox v0.1.0 — notas de entrega

## O que foi implementado

Esta versão entrega um Toolbox independente do aplicativo YouTube, mas inspirado no seu launcher SDL2/PortMaster. O projeto contém diagnóstico de hardware e firmware, teste de controles, telemetria em CSV, perfis reversíveis de governor, backup/restauração de saves e configurações, diagnóstico de rede, manutenção conservadora, verificador de ports e módulo experimental de frequência de CPU.

## Segurança de alterações

Os módulos de diagnóstico, controle, telemetria, rede e verificação de ports são somente leitura, além de gerarem relatórios. A manutenção limpa apenas caches conhecidos e pede confirmação. Os perfis alteram apenas o governor exposto pelo kernel e guardam o estado anterior. O módulo experimental vem bloqueado, exige `R36S_TOOLBOX_EXPERIMENTAL=1`, confirmação e uma frequência já exposta em `scaling_available_frequencies`; ele não altera voltagem, DTB, U-Boot ou kernel.

## Testes executados

O projeto passou na verificação de sintaxe com Bash e no ShellCheck sem avisos. O autoteste passou com 0 falhas. A validação funcional em uma árvore temporária passou para diagnóstico, rede, monitor, verificador de ports, criação de backup, restauração de conteúdo, perfis em modo de status e descoberta do módulo experimental. A instalação e o desinstalador também foram testados em uma árvore temporária.

Esses testes não substituem a execução em um R36S real. O dispositivo deve ser testado com a sua própria variante, painel, DTB, kernel, cartão e adaptador de rede.

## Instalação

Extraia o pacote no computador, copie a pasta para o R36S e execute:

```bash
cd /caminho/r36s-toolbox
./install.sh
```

O instalador coloca o port em `/roms/ports/r36stoolbox` e o launcher em `/roms/ports/r36stoolbox/R36S Toolbox.sh`. Para gerar o primeiro diagnóstico:

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" diagnostic
```

Os relatórios ficam em `/roms/ports/r36stoolbox/r36stoolbox/conf/reports`. O arquivo de log fica em `/roms/ports/r36stoolbox/log.txt`.

## Primeiro teste recomendado no aparelho

Execute diagnóstico, status do CPU experimental, teste de controles e verificação de ports nessa ordem. Só depois experimente perfis. Não habilite o módulo experimental antes de guardar uma cópia do cartão e confirmar as frequências disponíveis no relatório.

```bash
"/roms/ports/r36stoolbox/R36S Toolbox.sh" diagnostic
"/roms/ports/r36stoolbox/R36S Toolbox.sh" cpu-experimental status
"/roms/ports/r36stoolbox/R36S Toolbox.sh" controls
"/roms/ports/r36stoolbox/R36S Toolbox.sh" ports
```

## Próxima etapa

Depois de receber os relatórios do seu aparelho, a próxima versão pode ajustar os caminhos específicos de bateria, backlight, GPU, cpufreq e DTB da sua variante. Também será possível adicionar perfis por jogo, OSD de temperatura/FPS, teste visual da tela, integração de backup via SSH/Samba e uma central multimídia local inspirada no projeto YouTube.
