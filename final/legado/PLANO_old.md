# Plano de ação — Segmentação e medida de feridas em papel quadriculado

## Contexto / pontos de partida

**`trabalho_final` (este projeto)** — pipeline limpo e didático: calibração do grid por
autocorrelação → máscara de tinta (threshold `<140` + abertura) → `dilata→preenche→erode`
para fechar contorno → seleção por área/ratio/solidez → CSV + overlays.
*Limitação:* só fecha laços quase-fechados. Metade das imagens deu `NaN` no `resultados.csv`,
incluindo as feridas **abertas** (`7_c1`, `7_c2`). Não tem convex hull.

**`D:\projects\pdi` (`medir_area_fn.m`)** — versão muito mais robusta, que já resolve quase
tudo: black top-hat + Otsu, remoção de grid com SE de linha, detecção da origem (cruz) e ROI
do plano cartesiano, sweep multi-escala, **detecção de ferida aberta por esqueleto + convex
hull**, lógica de resgate e score de confiança por cobertura de borda, testes de consistência
por grupo. *Problema:* é um monólito de ~340 linhas — ótimo resultado, difícil de testar
parte-por-parte.

**Estratégia:** aproveitar a lógica robusta do `pdi`, mas refatorar em estágios independentes,
cada um com seu script de teste e visualização.

## Casos-chave (confirmados nas imagens)

| imagem | caso                         | o que precisa                          |
|--------|------------------------------|----------------------------------------|
| `1_c1` | fechada grande (~17 cm²)     | medir direto                           |
| `7_c1` | aberta (vão grande no topo)  | detectar que é aberta → convex hull    |
| `2_c1` | pequena (~1 cm²) sobre a cruz| distinguir de cruz/texto/dígitos       |

## Estrutura proposta

```
trabalho_final/
  +lesao/                  % pacote de funções (uma por estágio)
    calibrar_grid.m        % E1
    extrair_tinta.m        % E2
    achar_origem_roi.m     % E3
    classificar_ferida.m   % E4  (aberta vs fechada)
    fechar_e_medir.m       % E5+E6 (convex hull + área)
  testes/
    t1_calibracao.m        % roda E1 em todas, imprime px/cm
    t2_tinta.m             % salva máscara de tinta de cada imagem
    t3_origem.m            % overlay ROI + cruz detectada
    t4_classificacao.m     % rótulo aberta/fechada vs gabarito
    t5_area.m              % área + consistência por grupo
  rotulos.csv              % GABARITO manual (preencher uma vez)
  principal.m              % pipeline completo + CSV + overlays
```

## Estágios

### E1 — Calibração (grid → cm²)
Consolidar a calibração (autocorrelação) num `calibrar_grid.m` → `px_por_cm` (perX/perY).
- **Teste t1:** imprime px/cm das 50 imagens. Esperado ~120 px/cm consistente. Sinaliza outliers.

### E2 — Extração da tinta
Adotar **black top-hat + Otsu + remoção de grid com SE de linha** do `pdi` (melhor que o
threshold fixo atual).
- **Teste t2:** salva PNG com só o traço da ferida isolado por imagem. Conferir resíduo de
  grid/texto ou traço apagado.

### E3 — Origem (cruz) + ROI do plano
Restringe ao plano cartesiano, acha a cruz central, remove os braços retos, janela ao redor.
- **Teste t3:** overlay com retângulo da ROI e marcador na origem. Caso crítico: `2_c1`.

### E4 — Classificação Aberta vs Fechada  ⭐ (requisito #1)  ✅ FEITO
Para cada componente de traço na ROI, tenta fechar o laço com closing de raio
**crescente até ~2 cm** e mede `razão = área_preenchida / área_hull`:
- **FECHADA:** o laço fecha — mesmo quebrado pela grade/cruz, com closing agressivo
  a razão sobe (preenche bem).
- **ABERTA:** a razão continua **baixa a 1,5 cm (< 0.18) e a 2,0 cm (< 0.30)** — o
  vão é maior que o fechamento — **e** o traço é longo (esqueleto ≥ 14 cm) com hull
  grande (≥ 15 cm²). Mede-se pelo convex hull (E5).
- Caso contrário → fechada pequena (default conservador; E7 refina) ou ruído.

**Resultado (t4 vs gabarito): 50/51 ≈ 98%, zero falsos positivos.** Único erro:
`7_c2` (aberta) — a E2/E3 perde quase todo o contorno (capta ~7 de 88 cm²), ficando
indistinguível de fechada pequena. É limitação de **extração**, não da regra. Limiares
calibrados com `diag_e4` (razão preenchido/hull em vários raios nos casos críticos).
- **Teste t4:** classe por imagem vs gabarito + painel colorido (vermelho=fechada,
  verde=aberta+hull).

### E5 — Fechar abertas com Convex Hull (requisito #2)
Classe aberta → área = `bwconvhull`. Fechada → área = preenchimento. Flag `usou_hull` = menor
confiança.
- **Teste:** overlay vermelho (preenchido) vs verde tracejado (hull), tipo `auditar_visual.m`.

### E6 — Medida da área (requisito #3)
`area_cm2 = area_px / px_por_cm²`. Cada quadrado = 1 cm².
- **Teste t5:** área por ferida + consistência por grupo (`c1..cN` mesma ferida → CV < 25%).
  Validação cruzada contando quadrados no overlay.

### E7 — Feridas pequenas (requisito #4)
Regra assimétrica (já existe no `pdi`): candidato pequeno (<1 cm²) só conta com cobertura de
borda alta (traço nítido), proximidade da origem e solidez mínima — cruz/dígitos caem fora.
- **Teste:** focar em `2_c1`, `12_c2`, `5a` (2 feridas + texto).

### E8 — Pipeline + relatório
`principal.m` junta tudo: CSV (`arquivo, ferida, classe, area_cm2, usou_hull, confianca`) +
overlays + painéis por grupo.

## Execução

Cada estágio roda headless: `matlab -batch "testes/tX"` (R2025b, sem Signal Processing Toolbox
— Hann/autocorrelação manuais, como já feito nos dois projetos).

## Primeiro passo recomendado

Criar `rotulos.csv` — gabarito manual por imagem (fechada/aberta/sem ferida, nº de feridas,
área aproximada contando quadrados). Sem ele não há como medir objetivamente o ganho de cada
estágio.
