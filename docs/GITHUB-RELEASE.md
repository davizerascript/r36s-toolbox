# R36S Toolbox v0.1.0

Primeira versão do R36S Toolbox como port para a aba **Ports** do dArkOS/ArkOS.

## Download recomendado

Baixe `r36stoolbox-v0.1.0.zip` nesta Release. Extraia o ZIP em `/roms/ports` do cartão microSD. O caminho final obrigatório é:

```text
/roms/ports/r36stoolbox/R36S Toolbox.sh
```

Depois reinicie ou atualize a lista de Ports no EmulationStation.

## O que a ferramenta faz

| Opção | Função |
|---|---|
| Diagnóstico completo | Lê modelo, arquitetura, DTB, kernel, CPU, frequência, governor, temperatura, GPU, memória, bateria, tela, rede e software. |
| Teste de controles | Lista entrada, mostra SDL e o mapa `.gptk`, e captura eventos se `evtest` ou `jstest` estiverem disponíveis. |
| Telemetria | Registra temperatura, frequência, carga e memória em CSV. |
| Perfis de CPU | Aplica desempenho, equilibrado ou economia usando somente governors expostos pelo kernel; guarda restauração. |
| Backup e restauração | Salva saves/configurações conhecidas e verifica archives antes de extrair. |
| Rede | Mostra interface, Wi-Fi, SSID, IP, rota, DNS e ping. |
| Manutenção | Analisa espaço e limpa somente caches conhecidos após confirmação. |
| Verificar ports | Examina scripts, permissões, sintaxe, manifestos e arquitetura sem executar jogos. |
| CPU experimental | Descobre e, se explicitamente habilitada, testa somente frequências expostas pelo kernel. Não altera voltagem, DTB ou U-Boot. |

## Controles e saída

A seleciona, B volta e sai do menu principal, D-pad navega, X sobe página, Y desce página, L1/R1 usam Tab/Backspace e L2/R2 usam Home/End em telas compatíveis. A opção `0 — Sair para o menu Ports` fecha o Toolbox. Start+Select usa o hotkey de saída do gptokeyb/PortMaster conforme o firmware.

O launcher chama `get_controls`, usa a configuração SDL do `control.txt`, inicia o gptokeyb sem duplicar processos e chama `pm_finish` ao terminar quando disponível.

## Estado do projeto

O código passou em ShellCheck, autotestes e execução mock do launcher PortMaster. O diagnóstico do aparelho real ainda deve ser executado no R36S do usuário antes de testar perfis ou frequência experimental.
