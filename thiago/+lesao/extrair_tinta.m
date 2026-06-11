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

    % 3. Remover a grade com SE de linha (horizontal e vertical).
    len_linha = round(0.6 * ppc);          % < 1 cm, > maior trecho reto do traco
    grade_h = imopen(bw, strel('line', len_linha, 0));
    grade_v = imopen(bw, strel('line', len_linha, 90));
    bw_grade = grade_h | grade_v;

    % 4. So o traco da ferida; reconecta onde a grade cruzava; tira ruido.
    bw_tinta = bw & ~bw_grade;
    bw_tinta = imclose(bw_tinta, strel('disk', max(6, round(0.06 * ppc))));
    bw_tinta = bwareaopen(bw_tinta, round(0.01 * ppc^2));
end
