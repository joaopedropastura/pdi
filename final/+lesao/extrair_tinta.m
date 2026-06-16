function [bw_tinta, bw_grade] = extrair_tinta(img, px_por_cm)
%EXTRAIR_TINTA  Isola o traco da caneta (ferida), removendo grid, fundo e texto.
%   [BW_TINTA, BW_GRADE] = EXTRAIR_TINTA(IMG, PX_POR_CM)
%
%   Estrategia (mais robusta que threshold fixo):
%     1. Black top-hat realca tinta escura na largura real, ignorando o fundo.
%     2. Otsu binariza.
%     3. O grid e removido com SE de LINHA (linhas longas e retas), nao disco:
%        o traco da ferida e curvo e nunca tem trechos retos longos, entao
%        sobrevive enquanto a grade some.
%     4. Reconecta o traco onde a grade o cruzava e remove residuos pequenos.
%
%   Saidas:
%     bw_tinta  mascara logica so com o traco da ferida
%     bw_grade  mascara da grade detectada (util p/ E3: origem/ROI)

    if size(img,3) == 3, gray = rgb2gray(img); else, gray = img; end
    ppc = px_por_cm;                       % px por cm (linear)

    % 1. Black top-hat: realca estruturas escuras finas/medias sobre fundo claro.
    raio_bh = max(10, round(0.30 * ppc));
    gray_bh = imbothat(gray, strel('disk', raio_bh));

    % 2. Otsu.
    bw = imbinarize(gray_bh, graythresh(gray_bh));

    % 3. DETECTAR a grade com SE de linha curta (0.6 cm). Esta mascara e so
    %    p/ a E3 (achar origem/ROI) e p/ devolver bw_grade.
    len_grade = round(0.6 * ppc);
    grade_h = imopen(bw, strel('line', len_grade, 0));
    grade_v = imopen(bw, strel('line', len_grade, 90));
    bw_grade = grade_h | grade_v;

    % 4. REMOVER a grade da tinta com SE de linha MAIS LONGA (1.5 cm). Linha de
    %    0.6 cm tambem apagava arcos longos e quase-retos de feridas GRANDES
    %    (grupos 6b/7), sub-medindo a area. Linhas de grade sao continuas e bem
    %    mais longas que 1.5 cm, entao continuam removidas; arcos de ferida
    %    retos por 0.6-1.5 cm agora sobrevivem (o E7 filtra o residuo extra).
    len_rem = round(1.5 * ppc);
    rem = imopen(bw, strel('line', len_rem, 0)) | imopen(bw, strel('line', len_rem, 90));
    bw_tinta = bw & ~rem;
    bw_tinta = imclose(bw_tinta, strel('disk', max(6, round(0.06 * ppc))));
    bw_tinta = bwareaopen(bw_tinta, round(0.01 * ppc^2));
end
