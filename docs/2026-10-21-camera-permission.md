# Correção da permissão de câmara, 2026-10-21

Sintoma: macOS permite a câmara nas Definições, mas a app mostra denied.

O target macOS ativava Hardened Runtime sem CODE_SIGN_ENTITLEMENTS. A app existente em DerivedData não tinha entitlements legíveis (confirmado com codesign). Acrescentado com.apple.security.device.camera e ligado o ficheiro a Debug, Release e project.yml, preservando a equipa de assinatura já configurada pelo utilizador.

Validação: plutil e git diff --check passaram; configuração confirmada em ambas as variantes e XcodeGen. scripts/check-camera-entitlement.py falha na app anterior, como esperado. Compilação bloqueada pelas restrições da sessão: caches fora da área permitida e sandbox-exec: sandbox_apply: Operation not permitted durante a resolução do SharedKit. Falta compilar no Xcode, verificar a assinatura com o script e testar Iniciar câmara. Não foi confirmada a resolução em execução.

Os avisos Publishing changes from within view updates não foram reproduzidos nem corrigidos. Não há evidência suficiente para os atribuir à falha de autorização. Os logs DetachedSignatures/store index também não foram tratados como causa comprovada.

Registo preparado localmente porque o vault SecondBrain está fora das raízes de escrita permitidas nesta sessão.


## Atualização: melhorias de estabilidade e usabilidade

### Tarefa
Melhorar o programa, começando pela app macOS que apresentou o erro de câmara. Pergunta opcional sobre prioridades enviada, sem resposta durante a implementação.

### O que foi feito
- Configuração da sessão reutilizada ao reiniciar; validação de entradas e saídas, remoção de entrada se a configuração da saída falhar e verificação de isRunning após startRunning.
- Estado de arranque com progresso e cancelamento. Pedidos repetidos ignorados; respostas de permissão e frames antigos não substituem uma execução mais recente.
- Paragem limpa resultados e reinicia os classificadores na fila de captura. Fechar a vista pede a paragem sem publicar estado durante a atualização SwiftUI.
- Leitura do frame para registo na fila de captura, limpeza de imagens antigas quando o rosto desaparece, nome normalizado e botão desativado sem rosto. Nome mantido para recolher várias amostras.
- Mensagem própria para câmara ausente, botão de definições quando a permissão é recusada e mensagens PT/EN.
- Seletores de idioma/tema publicam mudanças numa tarefa MainActor posterior; o desaparecimento dos avisos originais não foi comprovado com logs.
- README atualizado para a interface unificada. Package.swift de testes macOS e quatro testes do serviço real com autorização injetada, sem abrir a câmara.
- Corrigido o verificador codesign para pedir XML explicitamente.

### Validação
33 testes SharedKit e 4 testes de captura passaram. Código completo macOS compilado e ligado com swiftc (Swift 5, macOS 13) usando SharedKit compilado pelo SwiftPM. Aplicação local de revisão criada em DerivedData/Review/iFaceAIID-Mac.app, assinada ad hoc com Hardened Runtime e entitlement de câmara verificado. Não é uma build de distribuição assinada pela equipa.

Interface inspecionada com computer use: estado inicial, progresso com Cancelar arranque e regresso a idle após cancelar confirmados. O arranque ficou pendente sem mostrar imagem; não foi confirmado acesso real à câmara, reinício com hardware, qualidade dos classificadores nem registo de rosto em execução. Perguntado ao utilizador se apareceu um pedido do sistema, sem resposta durante a verificação. O fluxo habitual xcodebuild continua por validar devido às restrições do ambiente.

### Aprendizados/padrões
Usar um identificador por execução impede que callbacks de permissão e frames atrasados reponham estado após parar ou reiniciar. O frame para registo deve ser lido na mesma fila que o atualiza e invalidado quando a deteção perde o rosto. Em codesign recente, --entitlements - pode produzir formato textual; --xml é necessário para leitura com plistlib.

### Decisões
Melhorias de captura limitadas a macOS; localização e controlos partilhados compilados em SharedKit. Não alterar heurísticas de reconhecimento sem amostras que permitam medir a precisão. Preservar as alterações preexistentes do utilizador ao projeto Xcode.

### Próximos passos
Executar a build assinada pelo Xcode e confirmar a autorização do sistema, imagem real, parar/reiniciar e registo de várias amostras. Verificar se persistem os avisos SwiftUI. Registo mantido no projeto porque o vault está fora das raízes permitidas de escrita.
