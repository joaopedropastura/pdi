function feridas = selecionar_feridas(comps, sz, px_por_cm)
%SELECIONAR_FERIDAS  (E7) Filtra o ruido e mede cada ferida real em cm2.
%   FERIDAS = SELECIONAR_FERIDAS(COMPS, SZ, PX_POR_CM)
%
%   A E4 devolve ~60-120 componentes por imagem: a(s) ferida(s) + muito lixo
%   (texto impresso, marca d'agua, rotulos "A"/"B", digitos dos eixos, restos
%   de grade/cruz). Somar tudo (como a E5/E6 fazia) inflava a area. Esta etapa
%   mantem so o que tem cara de ferida e mede cada uma escolhendo o melhor
%   estimador de area.
%
%   Criterio de FERIDA (calibrado no diag_e7):
%     - ABERTA  -> sempre ferida (a E4 ja foi conservadora p/ marcar aberta).
%     - FECHADA -> contorno que ENCERRA area perto da regiao do desenho:
%                  hull >= 1 cm2  E  fill/traco >= 1.5 (laco, nao risco solido)
%                  E  dist_origem <= 8 cm (lixo de texto fica na periferia).
%     - Fallback: se nada passou mas ha um componente bem na origem (ferida
%                 pequena desenhada sobre a cruz), mantem o mais proximo.
%
%   Medida de AREA por ferida:
%     - ABERTA  -> convex hull (o vao impede preencher).
%     - FECHADA -> fecha o laco com closing crescente; se selar (fill/hull>=0.6)
%                  usa o preenchimento; se nao selar (laco muito quebrado) usa o
%                  hull, que e melhor que um fill que vazou.
%
%   Saida FERIDAS: struct array (uma por ferida), ordenada por POSICAO
%   (cima->baixo, depois esq->dir), com campos:
%     .classe 'fechada'|'aberta'  .area_cm2  .usou_hull  .centroid [x y]
%     .mask (logica HxW)  .hull_cm2

    ppc = px_por_cm; H = sz(1); W = sz(2);
    feridas = struct('classe',{}, 'area_cm2',{}, 'usou_hull',{}, ...
                     'centroid',{}, 'mask',{}, 'hull_cm2',{});
    if isempty(comps), return; end

    % --- selecao (E7) ---
    % Separadores (calibrados no diag_e7b): ferida real ENCERRA area de forma
    % compacta. Ruido vem em 3 formas, todas rejeitadas:
    %   - fragmento de grade: fill baixo e ESPALHADO (solidez baixa);
    %   - texto/marca d'agua: faixa FININHA (menor lado do bbox < 0.6 cm);
    %   - lixo periferico: longe da origem.
    keep = false(1, numel(comps));
    for k = 1:numel(comps)
        c = comps(k);
        if strcmp(c.classe, 'aberta')
            keep(k) = true; continue;
        end
        % hull grande = ferida por definicao (ruido nunca chega a ~12 cm2);
        % fura o filtro de forma, que senao rejeita ferida GRANDE de laco
        % quebrado (solidez baixa) — ex.: grupos 6b/6a_c4.
        eh_grande = c.hull_cm2 >= 12 && c.dist_origem_cm <= 9.0;
        [sol, wcm, hcm] = forma(c.mask_fechada, ppc);
        eh_formada = c.fill_cm2 >= 1.2 && sol >= 0.30 && ...
                     min(wcm, hcm) >= 0.6 && c.dist_origem_cm <= 9.0;
        keep(k) = eh_grande || eh_formada;
    end
    idx = find(keep);
    if isempty(idx)                          % fallback: ferida pequena na cruz
        cand = find([comps.dist_origem_cm] <= 3.5);
        if ~isempty(cand)
            [~, b] = max([comps(cand).fill_cm2]); idx = cand(b);
        end
    end

    % --- medida por ferida ---
    j = 0;
    for k = idx
        c = comps(k);
        if strcmp(c.classe, 'aberta')
            a = c.hull_cm2; m = c.mask_fechada; uh = true;
        else
            [a, m] = medir_fechada(c.px, H, W, ppc, c.hull_cm2);
            uh = false;
        end
        rp = regionprops(m, 'Centroid');
        if isempty(rp)
            [ry, rx] = ind2sub([H W], c.px); cen = [mean(rx) mean(ry)];
        else
            cen = rp(1).Centroid;
        end
        j = j + 1;
        feridas(j).classe    = c.classe;
        feridas(j).area_cm2  = a;
        feridas(j).usou_hull = uh;
        feridas(j).centroid  = cen;
        feridas(j).mask      = m;
        feridas(j).hull_cm2  = c.hull_cm2;
    end

    % --- ordena por posicao: cima->baixo (banda ~2cm), depois esq->dir ---
    if ~isempty(feridas)
        C = reshape([feridas.centroid], 2, [])';      % colunas [x y]
        yband = round(C(:,2) / (2*ppc));
        [~, ord] = sortrows([yband, C(:,1)]);
        feridas = feridas(ord);
    end
end

function [sol, wcm, hcm] = forma(mask, ppc)
%FORMA  Solidez e dimensoes do bbox (cm) da maior regiao da mascara fechada.
    rp = regionprops(mask, 'Area', 'Solidity', 'BoundingBox');
    if isempty(rp), sol = 0; wcm = 0; hcm = 0; return; end
    [~, b] = max([rp.Area]); rp = rp(b);
    sol = rp.Solidity;
    wcm = rp.BoundingBox(3) / ppc;
    hcm = rp.BoundingBox(4) / ppc;
end

function [a_cm2, mask] = medir_fechada(px, H, W, ppc, hull_cm2)
%MEDIR_FECHADA  Area do laco fechado: fecha com closing crescente; usa o
%   preenchimento se selar, senao o convex hull (laco muito quebrado).
    [ry, rx] = ind2sub([H W], px);
    mg = round(1.3 * ppc);
    r0 = max(1, min(ry)-mg); r1 = min(H, max(ry)+mg);
    c0 = max(1, min(rx)-mg); c1 = min(W, max(rx)+mg);
    sub = false(r1-r0+1, c1-c0+1);
    sub(sub2ind(size(sub), ry-r0+1, rx-c0+1)) = true;

    A_hull = sum(sum(bwconvhull(sub)));
    rcs = [0.15 0.30 0.50 0.80 1.20];
    best_fill = 0; mfill = sub; sealed = false;
    for r = rcs
        f  = imfill(imclose(sub, strel('disk', max(1, round(r*ppc)))), 'holes');
        af = sum(f(:));
        if af / max(A_hull,1) >= 0.6
            mfill = f; best_fill = af; sealed = true; break;
        end
        if af > best_fill, best_fill = af; mfill = f; end
    end

    if sealed
        a_cm2 = best_fill / ppc^2;
    else
        a_cm2 = hull_cm2;                 % laco muito quebrado -> hull
        mfill = bwconvhull(sub);
    end
    mask = false(H, W);
    mask(r0:r0+size(mfill,1)-1, c0:c0+size(mfill,2)-1) = mfill;
end
