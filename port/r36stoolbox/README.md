# R36S Toolbox

## Notas

O R36S Toolbox é uma ferramenta de diagnóstico e manutenção para R36S com dArkOS/ArkOS. Ele foi preparado como um port executável pela aba **Ports** e mantém seu estado dentro da própria pasta do port.

O primeiro uso recomendado é executar o diagnóstico e guardar o relatório antes de alterar qualquer perfil. O módulo de CPU experimental permanece protegido e não altera voltagem, kernel, DTB ou U-Boot.

## Controles

| Botão | Ação |
|---|---|
| A | Selecionar/confirmar |
| B | Voltar; no menu principal, sair para o menu Ports |
| D-pad | Navegar |
| X | Subir página |
| Y | Descer página |
| L1/R1 | Tab/retrocesso em telas compatíveis |
| L2/R2 | Início/fim de lista em telas compatíveis |
| Start + Select | Hotkey de encerramento do PortMaster/gptokeyb, conforme a configuração do dispositivo |
| 0 no menu principal | Sair para o menu Ports |

O launcher chama `get_controls` e exporta `SDL_GAMECONTROLLERCONFIG` fornecido pelo `control.txt`. Ele também inicia o gptokeyb com `r36stoolbox/assets/toolbox.gptk` quando o PortMaster oferece `$GPTOKEYB` ou o executável local.

## Dados e relatórios

Os dados do Toolbox são guardados em `r36stoolbox/conf`, dentro do port:

```text
conf/state/
conf/reports/
conf/backups/
conf/cache/
conf/runtime/
```

O `log.txt` fica na raiz do port. O Toolbox não envia relatórios pela rede automaticamente.

## Dependências

O port usa Bash, ferramentas POSIX, SDL/entrada fornecida pelo sistema e utilitários disponíveis na imagem. `dialog`, `gptokeyb`, `ip`, `ping`, `evtest`, `jstest` e `mpv` são detectados quando presentes; quando ausentes, o módulo correspondente informa a limitação em vez de falhar silenciosamente.

## Empacotamento local

A pasta foi montada segundo a estrutura de ports do PortMaster:

```text
r36stoolbox/
├── port.json
├── README.md
├── screenshot.png
├── gameinfo.xml
├── R36S Toolbox.sh
└── r36stoolbox/
    ├── assets/
    ├── bin/
    ├── lib/
    └── modules/
```

Para instalar manualmente sem usar o catálogo do PortMaster, copie `R36S Toolbox.sh` e a pasta `r36stoolbox` para `/roms/ports/r36stoolbox/`.

## Créditos

A arquitetura de launcher segue as convenções documentadas pelo PortMaster. A ideia do relatório de sistema é compatível com utilitários comunitários de informações do ArkOS. O desenho do menu e os scripts deste port foram criados para este projeto.
