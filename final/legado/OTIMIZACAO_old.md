# Otimização de desempenho da E4 e investigação de paralelismo

Documenta a investigação que reduziu o tempo de execução do pipeline em ~82× e a
conclusão sobre o uso de `datastore`/`parfor` (Parallel Computing Toolbox).

**Ambiente da medição:** MATLAB R2025b, Windows 11, 4 núcleos físicos,
Parallel Computing Toolbox 25.2. Imagens ~2500×2200 px (`px/cm ≈ 123`).

## 1. Sintoma

O pipeline estava muito lento nos testes em lote. O perfil por estágio
(`testes/bench_tempo.m`) localizou o gargalo na **E4** (classificação
aberta × fechada):

```
Tempo médio/imagem (versão original):
  read=0.14  E1=0.05  E2=1.12  E3=0.53  E4=280.11 s
```

Ou seja, **~280 s por imagem só na E4** — as outras etapas somavam < 2 s.
Em 50 imagens isso daria ~4 horas.

## 2. Diagnóstico (profiling interno)

`testes/prof_e4.m` cronometrou cada operação interna da E4 por componente.
Descobertas:

1. **Nº de componentes, não custo unitário.** Cada operação isolada era rápida
   (~0,1–0,5 s). O problema é que a máscara limpa da E3 deixa **95–118
   componentes por imagem**: ~1 ferida real e **~100 fragmentos de ruído**
   (resíduo de grade, com *convex hull* de ~0,1 cm²).

2. **Trabalho caro feito em cada ruído.** A E4 rodava, para *cada* componente:
   `bwconvhull` + 6 *closings* (raios de 0,15 a 2,0 cm) + `imfill` + `bwskel`.
   O *closing* de 2,0 cm usa um disco de ~246 px de raio.

3. **Recorte inflado pela margem.** Mesmo após recortar o componente, a margem
   era fixa em ~270 px (para caber o *closing* de 2 cm). Um ruído de 5 px
   recebia um recorte de ~540×540 px → o *closing* grande custava ~0,2 s mesmo
   em um pingo de ruído.

**Conclusão:** o teste caro de "ferida aberta" (*closings* grandes + esqueleto +
margem grande) estava sendo aplicado a ~100 ruídos por imagem, sendo que um
componente **só pode ser aberta se `hull ≥ 15 cm²`**.

## 3. Correções (algorítmicas, sem nenhum toolbox)

Em `+lesao/classificar_ferida.m`:

1. **Recorte na *bounding box*** de cada componente (helper `recorta`): todas as
   operações pesadas rodam no recorte, não na folha inteira (~5,5 MP). Uma
   ferida pequena vira um recorte minúsculo.

2. **Caminhos separados por tamanho:**
   - *Maioria* (ruído + feridas pequenas): só *closings* pequenos (≤ 0,5 cm) em
     recorte justo (margem 0,7 cm), **sem `bwskel`**.
   - *Candidatos a aberta* (`hull ≥ 15 cm²`, 1–2 por imagem): aí sim recorte
     grande, *closings* de 1–2 cm e `bwskel` para decidir aberta × fechada.

A regra de classificação **não mudou** (aberta já exigia `hull ≥ 15 cm²`); apenas
deixou de gastar o caminho caro onde ele nunca mudaria o resultado.

## 4. Resultado

| Versão                                              | E4 por imagem |
|-----------------------------------------------------|---------------|
| Original (folha inteira, todos os componentes)      | **280 s**     |
| + recorte na *bounding box*                         | 34 s          |
| + caminho caro só p/ `hull ≥ 15 cm²`                | **3,4 s**     |

- **~82× mais rápido**, ainda em thread única.
- Pipeline completo: **~5 s/imagem** (`read 0.12 / E1 0.04 / E2 1.04 / E3 0.54 / E4 3.41`).
- **Acurácia preservada:** `t4_classificacao` segue **50/51 (98%)**, mesmo único
  erro (`7_c2`), zero falsos positivos.

## 5. `datastore` e `parfor` — vale a pena?

A pergunta original era se um `datastore`/`parfor` reduziria o tempo. Medido no
pipeline real (`bench_tempo.m`, 12 imagens, após a otimização):

```
SEQUENCIAL (for)    12 imgs: 57.2 s  (4.77 s/img)
PARPOOL start (1x):          19.7 s  (4 workers)   <- custo fixo único
PARALELO (parfor)   12 imgs: 31.8 s  (2.65 s/img)  speedup = 1.8x
```

**Conclusões:**

- **`imageDatastore` não acelera o cálculo** — é só uma abstração de iteração/
  leitura. A leitura do disco é ~0,12 s/imagem (irrelevante aqui). Serve para
  organizar o código e habilitar `parfor`, não para ganhar tempo por si só.

- **`parfor` rende apenas ~1,8×** (não 4×), porque as funções de imagem do MATLAB
  **já são multithread** internamente — sobra pouca folga para paralelismo no
  nível das imagens — e há o custo do pool (~20 s) e desbalanceamento (uma
  imagem grande domina o lote).

- **O ganho real (82×) veio da otimização algorítmica**, não do hardware/toolbox.

**Recomendação:** manter a E4 otimizada; não adotar `datastore` por desempenho;
usar `parfor` apenas como **opção** na rodada completa das 50 imagens (E8,
`principal.m`), onde o custo fixo do pool se dilui.

## 6. Pendência relacionada (E7)

A E4 ainda devolve os ~100 componentes de ruído como feridas pequenas "fechadas".
Isso não afeta a classificação (o teste olha a ferida principal), mas o
`t5_area` **somaria essas áreas espúrias**. A medição de área só fica confiável
após a **E7** (filtro de ruído / validação do que é ferida real).

## 7. Scripts de apoio

- `testes/bench_tempo.m` — tempo por estágio + comparação `for` × `parfor`.
- `testes/prof_e4.m` — profiling interno da E4 por componente.
