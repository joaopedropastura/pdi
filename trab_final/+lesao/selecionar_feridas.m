function feridas = selecionar_feridas(comps, sz, px_por_cm, saida)

if nargin < 4, saida = ''; end
ppc = px_por_cm; H = sz(1); W = sz(2);
feridas = struct('classe',{}, 'area_cm2',{}, 'usou_hull',{}, ...
    'centroid',{}, 'mask',{}, 'hull_cm2',{});
if isempty(comps), return; end

% mantem feridas reais; rejeita grade, texto e lixo periferico
keep = false(1, numel(comps));
for k = 1:numel(comps)
    c = comps(k);
    if strcmp(c.classe, 'aberta')
        keep(k) = true; continue;
    end
    eh_grande = c.hull_cm2 >= 12 && c.dist_origem_cm <= 9.0;   % hull grande = ferida
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

% ordena por posicao: cima->baixo, depois esq->dir
if ~isempty(feridas)
    C = reshape([feridas.centroid], 2, [])';
    yband = round(C(:,2) / (2*ppc));
    [~, ord] = sortrows([yband, C(:,1)]);
    feridas = feridas(ord);
end

if ~isempty(saida)
    for k = 1:numel(feridas)
        lesao.salvar(feridas(k).mask, saida, ...
            sprintf('27_ferida_%02d_%s.png', k, feridas(k).classe));
    end
end
end

function [sol, wcm, hcm] = forma(mask, ppc)
rp = regionprops(mask, 'Area', 'Solidity', 'BoundingBox');
if isempty(rp), sol = 0; wcm = 0; hcm = 0; return; end
[~, b] = max([rp.Area]); rp = rp(b);
sol = rp.Solidity;
wcm = rp.BoundingBox(3) / ppc;
hcm = rp.BoundingBox(4) / ppc;
end

function [a_cm2, mask] = medir_fechada(px, H, W, ppc, hull_cm2)
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
