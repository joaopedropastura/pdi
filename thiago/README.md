# Segmentação e medida de feridas em papel quadriculado

Mede a área (em cm²) de feridas desenhadas à mão sobre papel quadriculado, onde
**cada quadrado do grid = 1 cm²**. O pipeline identifica feridas **fechadas** e
**abertas** (estas fechadas por *convex hull*), e trata o caso difícil das
feridas **pequenas** (< 1 cm²), facilmente confundíveis com a cruz de referência,
texto e ruído.

> Visão geral da estratégia e das etapas: ver [`PLANO.md`](PLANO.md).

## Requisitos

- **MATLAB R2025b** (ou compatível) com **Image Processing Toolbox**.
- **Não** precisa da Signal Processing Toolbox (a janela de Hann e a
  autocorrelação são implementadas manualmente).

## Estrutura

```
+lesao/                  Pacote com uma função por etapa do pipeline
  calibrar_grid.m        E1 — escala (px/cm) por autocorrelação do grid
  extrair_tinta.m        E2 — isola o traço da caneta (remove grid/fundo)
  achar_origem_roi.m     E3 — acha o plano (ROI) + a cruz central e a remove
  classificar_ferida.m   E4 — classifica cada traço em aberta × fechada
  fechar_e_medir.m       E5+E6 — fecha (convex hull) e mede a área em cm²
testes/                  Scripts de teste/validação por etapa
  t1_calibracao.m        valida E1 (escala de todas as imagens)
  t2_tinta.m             valida E2 (máscara de tinta por imagem)
  t3_origem.m            valida E3 (ROI + origem + remoção da cruz)
  t4_classificacao.m     valida E4 (aberta × fechada vs gabarito)
  t5_area.m              valida E5/E6 (área medida vs gabarito)
  diag_e4.m              diagnóstico p/ calibrar os limiares da E4
  bench_tempo.m          mede tempo por estágio + for × parfor
  prof_e4.m              profiling interno da E4 por componente
Imagens_GridLesoes_noname/   Imagens de entrada (.jpg)
rotulos.csv              Gabarito manual (classe/área por ferida) p/ validação
saidas/                  Saídas geradas pelos testes (ignorada pelo git)
legado/                  Versão monolítica antiga (referência; não usada)
PLANO.md                 Plano de ação detalhado (etapas E1..E8)
OTIMIZACAO.md            Investigação de desempenho da E4 + datastore/parfor
```

> Desempenho: a E4 foi otimizada de ~280 s para ~3,4 s por imagem; a análise
> completa (e por que `datastore`/`parfor` rendem pouco) está em
> [`OTIMIZACAO.md`](OTIMIZACAO.md).

A pipeline é **modular e testável por etapa**: cada estágio é uma função em
`+lesao/` com um script de teste correspondente em `testes/`, que gera painéis
visuais em `saidas/` para inspeção.

## Como rodar os testes

Os comandos abaixo rodam **headless** (sem abrir a interface) a partir da **raiz
do projeto**.

**Linux/macOS (ou se `matlab` está no PATH):**

```bash
matlab -batch "addpath('testes'); t1_calibracao"   # E1
matlab -batch "addpath('testes'); t2_tinta"        # E2
matlab -batch "addpath('testes'); t3_origem"       # E3
matlab -batch "addpath('testes'); t4_classificacao"  # E4
```

**Windows (PowerShell), apontando o executável:**

```powershell
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath('testes'); t1_calibracao"
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath('testes'); t2_tinta"
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath('testes'); t3_origem"
& "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" -batch "addpath('testes'); t4_classificacao"
```

### O que cada teste produz e como conferir

| Teste | Saída | O que olhar |
|-------|-------|-------------|
| `t1_calibracao` | `saidas/t1_calibracao.csv` + tabela no console | perX≈120, perY≈127 px/cm, consistente; sem outliers (>15% da mediana) |
| `t2_tinta` | `saidas/tinta/<img>.png` (original \| grade \| traço) | o traço da ferida sobrevive inteiro? sobrou grade/texto? |
| `t3_origem` | `saidas/origem/<img>.png` (original+ROI+origem \| tinta \| limpa) | a cruz (+ vermelho) caiu na origem? a ROI cobre o plano sem cortar a ferida? os eixos sumiram sem comer o traço? |
| `t4_classificacao` | `saidas/t4_classificacao.csv` + `saidas/classe/<img>.png` (contorno **vermelho**=fechada, **verde**=aberta+hull) e tabela com acurácia | a classe prevista bate com o gabarito? as abertas (`7_c1`) viraram verde? alguma fechada virou aberta (falso positivo)? |

Acurácia atual da E4: **50/51 (98%)**, **sem falsos positivos**. O único erro é
`7_c2` (aberta): a E2/E3 captura só ~7 dos 88 cm² do contorno real dela, ficando
indistinguível de uma ferida pequena fechada — limitação de **extração**, não de
classificação. Para recalibrar os limiares, use `diag_e4` (imprime a razão
preenchido/hull em vários raios de fechamento nos casos críticos).

Casos críticos para inspecionar nos painéis: `2_c1`, `4_c1`, `12_c2` (ferida
pequena sobre a cruz), `7_c1`/`7_c2` (feridas abertas), `3_c1`/`6b` (feridas
grandes), `5a`/`5b` (múltiplas feridas + texto).

## Chamando as funções diretamente

```matlab
addpath(pwd);                       % p/ enxergar o pacote +lesao
img = imread('Imagens_GridLesoes_noname/1_c1_nn.jpg');

[px_por_cm, perX, perY]      = lesao.calibrar_grid(img);          % E1
[bw_tinta, bw_grade]         = lesao.extrair_tinta(img, px_por_cm); % E2
[bw_limpa, origem, roi, info]= lesao.achar_origem_roi(bw_tinta, bw_grade, px_por_cm); % E3
[classe, comps]              = lesao.classificar_ferida(bw_limpa, origem, px_por_cm); % E4
```

> Escala: `px_por_cm` é linear; para área use `px_por_cm^2` (= perX·perY), pois
> 1 cm² corresponde a perX·perY pixels.

## Gabarito (`rotulos.csv`)

Verdade de referência, **uma linha por ferida**, usada para medir a qualidade de
cada etapa. Colunas: `arquivo, ferida_id, classe, n_feridas, area_cm2_aprox, obs`.

- `classe` ∈ `{fechada, aberta, nenhuma}`
- imagem sem ferida → uma linha com `ferida_id = 0`, `classe = nenhuma`
- feridas < 1 cm² recebem a área estimada (ex.: `0,5`) e `obs = pequena`
- decimais em formato brasileiro (vírgula); os testes convertem ao ler

## Status

- [x] **E1** — calibração (escala do grid)
- [x] **E2** — extração da tinta
- [x] **E3** — origem (cruz) + ROI + remoção da cruz
- [x] **E4** — classificação aberta × fechada (50/51 ≈ 98%, sem falsos positivos)
- [ ] **E5** — fechamento de feridas abertas (convex hull)
- [ ] **E6** — medida da área (cm²)
- [ ] **E7** — tratamento de feridas pequenas
- [ ] **E8** — pipeline completo + relatório (CSV + overlays)
