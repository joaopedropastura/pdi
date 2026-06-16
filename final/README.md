# Medição de área de feridas em papel quadriculado

Mede a área (em **cm²**) de cada ferida desenhada sobre papel quadriculado, usando
o **grid do fundo como referência de escala** (cada quadrado = 1 cm²). Feridas de
contorno **fechado** têm a área pelo preenchimento do laço; feridas **abertas** são
fechadas por **convex hull**. A saída é impressa no console: nome da imagem, id da
ferida (1, 2, 3… quando há mais de uma) e área.

## Como rodar

Headless (R2025b):

```
matlab -batch "principal"
```

Ou, no MATLAB, abra a pasta e rode `principal`. As imagens ficam em `imagens/`.

Saída (exemplo):

```
imagem            id  classe     area_cm2
------------------------------------------
1_c3_nn.jpg        1  fechada        21.6
                   2  fechada         1.4
7_c1_nn.jpg        1  aberta        154.8   *hull (aberta)
```

Os ids são numerados por **posição**: de cima para baixo e, no mesmo nível, da
esquerda para a direita. `*hull` marca feridas abertas (área estimada pelo hull).

## Pipeline (`+lesao/`)

Cada etapa é uma função independente do pacote `lesao`:

| Etapa | Arquivo | O que faz |
|------|---------|-----------|
| **E1** | `calibrar_grid.m` | Acha o período do grid por **autocorrelação** das projeções → `px_por_cm` (1 cm² = `px_por_cm²` pixels). |
| **E2** | `extrair_tinta.m` | Isola o traço da caneta: *black top-hat* + Otsu; remove a grade com **abertura por linha** (detecção 0,6 cm; remoção 1,5 cm para preservar arcos longos de feridas grandes). |
| **E3** | `achar_origem_roi.m` | Acha o plano cartesiano (ROI), a origem (cruz central) e apaga os eixos retos. |
| **E4** | `classificar_ferida.m` | Para cada componente, classifica **fechada × aberta**: tenta fechar o laço com *closing* crescente; se mesmo a ~2 cm não preenche e o traço é longo, é **aberta**. |
| **E5/E6** | `fechar_e_medir.m` | Conversão de pixels para cm² (hull nas abertas, preenchimento nas fechadas). |
| **E7** | `selecionar_feridas.m` | **Filtro de ruído + medida por ferida.** Descarta texto/marca d'água/dígitos/células de grade e mede cada ferida real; ordena por posição. |

`principal.m` encadeia E1→E2→E3→E4→E7 e imprime o resultado.

### Como o E7 separa ferida de ruído

Uma imagem gera ~60-120 componentes (a ferida + muito lixo impresso). Mantém-se
um componente como ferida se:

- é **aberta** (a E4 já é conservadora), **ou**
- tem **hull ≥ 12 cm²** (ruído nunca é tão grande), **ou**
- **encerra área de forma compacta**: `fill ≥ 1,2 cm²`, solidez ≥ 0,30, menor lado
  do bounding box ≥ 0,6 cm (descarta faixas finas de texto) e perto da origem.

A área de cada ferida fechada usa o preenchimento quando o laço sela; se o laço
está muito quebrado, usa o convex hull (melhor que um preenchimento que vazou).

## Validação

`testes/validar_feridas.m` roda o pipeline completo nas 51 imagens e compara com o
gabarito `rotulos.csv` (classe, nº de feridas e área aproximada por imagem).
Grava progresso em `saidas/progresso.log` e o detalhe em `saidas/validar_feridas.csv`.

```
matlab -batch "addpath('testes'); validar_feridas"
```

Resultado atual:

- **Classificação aberta/fechada: 98 %** (50/51).
- **Nº de feridas correto: 75 %** (38/51).
- **Erro de área: mediana absoluta ~2,3 cm²**; ~40 % das imagens com erro ≤ 40 %.

### Limitações conhecidas

- **Feridas < 1 cm²** (grupos 8, 9, 11, 12): detectadas, mas a área é aproximada —
  o raio de fechamento e as células do grid têm o tamanho da própria ferida, então
  é difícil distinguir/medir. O **erro absoluto é pequeno** (~0,1-2 cm²), o relativo é alto.
- Algumas feridas grandes de peça única se partem em 2 componentes e são somadas,
  super-medindo a área (ex.: `6b_c1`, `6b_c3`).
- `7_c2` é a única classificação errada (a extração perde quase todo o contorno).

## Estrutura

```
trab_final/
  principal.m              # entrega: mede e imprime no console
  +lesao/                  # pipeline (E1-E7)
  testes/
    t1_calibracao.m  t2_tinta.m  t3_origem.m
    t4_classificacao.m  t5_area.m  validar_feridas.m
  rotulos.csv              # gabarito manual (classe / nº feridas / área aprox.)
  imagens/                 # 51 imagens de entrada
  docs/                    # material da aula de segmentação
  saidas/                  # CSVs e logs gerados
  legado/                  # tentativa anterior (scripts soltos) — referência
```
