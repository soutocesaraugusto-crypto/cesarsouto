# 💎 Sua Assistente Prisma — comece aqui

Esta pasta instala a **sua própria assistente de IA** (apelidada de **Prisma**), que conversa com você pelo **Telegram** e/ou **WhatsApp**, lembra das suas conversas e te ajuda no dia a dia.

Ela roda com a **sua assinatura do Claude** — o cérebro é o Claude Code.

---

## O que você vai precisar

1. **Claude Code instalado e logado** na sua máquina/servidor.
   (Se ainda não tem: https://docs.anthropic.com/en/docs/claude-code)
2. **Onde ela vai morar** — escolha um:
   - **Servidor Linux (VPS)** — fica ligada 24h. Recomendado se você quer ela sempre online.
   - **Seu computador** — funciona enquanto o PC está ligado.
     - **Mac:** funciona direto.
     - **Windows:** precisa do **WSL** (Linux dentro do Windows). O instalador te ajuda.
3. **Telegram** (recomendado pra começar): você cria um bot em 2 minutos. O instalador guia.
4. **WhatsApp** (opcional): você conecta lendo um **QR Code** com o celular (igual ao WhatsApp Web). Recomendado usar um **número dedicado** para a assistente. O instalador explica se você escolher essa opção. Não precisa de nenhum serviço pago extra.

---

## Como instalar

Abra o terminal nesta pasta e rode:

```bash
bash instalar.sh
```

O instalador vai te perguntar:
- O **nome** da sua assistente (padrão: Prisma)
- O **seu nome** (pra ela saber quem é o dono)
- Qual **canal** você quer (Telegram, WhatsApp ou os dois)
- O **token** do canal escolhido (ele te ensina como pegar)

No fim, sua assistente sobe e te manda um "online e pronta" no app que você escolheu. 🎉

---

## Depois de instalada

- **Conversar:** é só mandar mensagem pra ela no Telegram/WhatsApp.
- **Lembretes:** peça que ela te lembre de coisas ("me lembra amanhã às 15h de ligar pro cliente", "todo dia às 8h me manda minha lista"). Veja exemplos em [`docs/lembretes.md`](docs/lembretes.md).
- **Personalizar:** edite os arquivos da sua assistente pra ensinar a sua rotina e seu jeito (o instalador mostra onde ficam).
- **Desligar/ligar:** comandos simples que o instalador mostra no fim.

Qualquer dúvida, fale com o suporte da Aliança de Ouro.
