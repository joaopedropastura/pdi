function [bw_limpa, origem, roi, info] = achar_origem_roi(bw_tinta, bw_grade, px_por_cm)
%ACHAR_ORIGEM_ROI  Acha o plano cartesiano (ROI) e a origem (cruz central), e
%   limpa da mascara de tinta os segmentos RETOS (eixos/grade remanescentes),
%   preservando os tracos curvos das feridas.
%
%   [BW_LIMPA, ORIGEM, ROI, INFO] = ACHAR_ORIGEM_ROI(BW_TINTA, BW_GRADE, PX_POR_CM)
%
%   Entradas (saidas da E2):
%     bw_tinta   mascara do traco da ferida (com restos de eixo/grade)
%     bw_grade   mascara da grade detectada
%     px_por_cm  escala linear (E1)
%
%   Saidas:
%     bw_limpa   tinta restrita a ROI, sem segmentos retos (cruz/eixos/grade)
%     origem     [x y] da cruz central (referencia)
%     roi        mascara logica do plano cartesiano (+ folga)
%     info       struct: cmin/cmax/rmin/rmax (extensao da grade) e roi_box [x y w h]

    ppc = px_por_cm;
    [H, W] = size(bw_tinta);

    % --- grade direcional (a partir da grade combinada da E2) ---
    % Abrir a grade com SE de linha separa as linhas horizontais das verticais.
    L = round(0.6 * ppc);
    grade_h = imopen(bw_grade, strel('line', L, 0));
    grade_v = imopen(bw_grade, strel('line', L, 90));

    % --- extensao do plano cartesiano (retangulo onde ha grade densa) ---
    sv = sum(grade_v, 1); sh = sum(grade_h, 2);
    col_tem = sv > 0.2 * max(sv);
    row_tem = sh > 0.2 * max(sh);
    cmin = find(col_tem, 1, 'first'); cmax = find(col_tem, 1, 'last');
    rmin = find(row_tem, 1, 'first'); rmax = find(row_tem, 1, 'last');
    if isempty(cmin), cmin = 1; cmax = W; end
    if isempty(rmin), rmin = 1; rmax = H; end

    % ROI = plano + folga de ~0.6 cm p/ fora. Folga (em vez de recorte p/ dentro)
    % tolera a ferida que extrapola o plano (ex.: 6b_c2 "foge do cartesiano").
    folga = round(0.6 * ppc);
    r1 = max(1, rmin - folga); r2 = min(H, rmax + folga);
    c1 = max(1, cmin - folga); c2 = min(W, cmax + folga);
    roi = false(H, W); roi(r1:r2, c1:c2) = true;

    % --- origem (cruz central) ---
    % O grid e fino (1-3 px); os eixos da cruz sao mais GROSSOS. Erodir a grade
    % direcional com uma linha perpendicular remove o grid fino e mantem so os
    % eixos grossos. Entre eles, a coluna/linha de MAIOR EXTENSAO (o eixo
    % atravessa o plano) e a origem. Uma trava final joga pro centro do plano
    % quando a estimativa foge demais (ferida grande rouba a origem em 7_c2/5b).
    esp = max(4, round(0.06 * ppc));
    eixo_v = imerode(grade_v, strel('line', esp, 0));    % verticais grossas
    eixo_h = imerode(grade_h, strel('line', esp, 90));   % horizontais grossas

    cenx = (cmin + cmax) / 2;  ceny = (rmin + rmax) / 2;
    ox = []; oy = [];
    [rv, cv] = find(eixo_v);
    if ~isempty(cv)
        ext_col = accumarray(cv, rv, [W,1], @max, 0) - accumarray(cv, rv, [W,1], @min, 0);
        [vx, ox] = max(movmean(ext_col, esp)); if vx <= 0, ox = []; end
    end
    [rh, ch] = find(eixo_h);
    if ~isempty(rh)
        ext_row = accumarray(rh, ch, [H,1], @max, 0) - accumarray(rh, ch, [H,1], @min, 0);
        [vy, oy] = max(movmean(ext_row, esp)); if vy <= 0, oy = []; end
    end
    % trava de sanidade: fora de 25% do tamanho do plano -> volta ao centro.
    if isempty(ox) || abs(ox - cenx) > 0.25 * (cmax - cmin), ox = round(cenx); end
    if isempty(oy) || abs(oy - ceny) > 0.25 * (rmax - rmin), oy = round(ceny); end
    origem = [ox, oy];

    % --- remover a CRUZ central: retos SO na banda dos eixos (pela origem) ---
    % A abertura por linha extrai os segmentos retos (eixo/grade). Mas aplicar
    % isso no quadro inteiro come as laterais localmente retas de feridas grandes
    % (bug visto em 3_c1). Entao subtraimos os retos APENAS dentro da faixa que
    % passa pela origem: isso solta feridas pequenas coladas na cruz (2_c1) e
    % apaga os remanescentes dos eixos, sem tocar no contorno fora dos eixos.
    Lc    = round(0.7 * ppc);
    banda = round(0.30 * ppc);
    faixa = false(H, W);
    faixa(:, max(1,ox-banda):min(W,ox+banda)) = true;   % faixa do eixo vertical
    faixa(max(1,oy-banda):min(H,oy+banda), :) = true;   % faixa do eixo horizontal
    reto  = imopen(bw_tinta, strel('line', Lc, 0)) | imopen(bw_tinta, strel('line', Lc, 90));
    bw_limpa = bw_tinta & ~(reto & faixa);

    % restringe ao plano (+folga); reconecta o que a remocao possa ter cortado
    bw_limpa = bw_limpa & roi;
    bw_limpa = imclose(bw_limpa, strel('disk', max(3, round(0.05 * ppc))));
    bw_limpa = bwareaopen(bw_limpa, round(0.01 * ppc^2));

    info = struct('cmin',cmin, 'cmax',cmax, 'rmin',rmin, 'rmax',rmax, ...
                  'roi_box', [c1 r1 (c2-c1) (r2-r1)]);
end
