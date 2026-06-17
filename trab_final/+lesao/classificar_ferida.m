function [classe_img, comps, info] = classificar_ferida(bw_limpa, origem, ppc, saida)

[H, W] = size(bw_limpa);
if nargin < 2 || isempty(origem), origem = [W/2, H/2]; end
if nargin < 4, saida = ''; end

A_min_cm2   = 0.06;   % hull abaixo disso = ruido
razao_fech  = 0.20;   % fill/hull >= isso => laco fechou
rc_cm       = [0.15 0.30 0.50 1.0 1.5 2.0];  % raios de closing (cm)
razao_ab15  = 0.18;   % razao a rc=1.5cm abaixo disso => candidato a aberta
razao_ab20  = 0.30;   % e a rc=2.0cm tambem baixa => confirma aberta
sk_aberta   = 14;     % esqueleto (cm) minimo p/ aberta
hull_aberta = 15;     % hull (cm2) minimo p/ aberta

info = struct('A_min_cm2',A_min_cm2, 'razao_fech',razao_fech, 'rc_cm',rc_cm, ...
    'razao_ab15',razao_ab15, 'razao_ab20',razao_ab20, ...
    'sk_aberta',sk_aberta, 'hull_aberta',hull_aberta);

bw = imclose(bw_limpa, strel('disk', max(2, round(0.06 * ppc))));
cc = bwconncomp(bw);

comps = struct('px',{}, 'classe',{}, 'area_traco_cm2',{}, 'hull_cm2',{}, ...
    'fill_cm2',{}, 'razao_fill',{}, 'esqueleto_cm',{}, ...
    'dist_origem_cm',{}, 'mask_fechada',{});

mg_peq = round(0.7 * ppc);              % margem p/ closings <= 0.5 cm
mg_big = round((max(rc_cm) + 0.2)*ppc); % margem p/ closings ate 2.0 cm
rc_peq = rc_cm(rc_cm <= 0.5);
rc_big = rc_cm(rc_cm >  0.5);

k = 0;
for i = 1:cc.NumObjects
    px = cc.PixelIdxList{i};
    [ry, rx] = ind2sub([H, W], px);

    [subp, rp0, cp0] = recorta(ry, rx, mg_peq, H, W);
    A_hull = sum(sum(bwconvhull(subp)));
    if A_hull < A_min_cm2 * ppc^2, continue; end

    A_traco = numel(px);

    filled = []; r0s = rp0; c0s = cp0; razao_peq = 0;
    for rc = rc_peq
        se = strel('disk', max(1, round(rc * ppc)));
        f  = imfill(imclose(subp, se), 'holes');
        rz = sum(f(:)) / max(A_hull, 1);
        razao_peq = max(razao_peq, rz);
        if isempty(filled) && rz >= razao_fech, filled = f; end
    end

    razao_15 = NaN; sk_cm = NaN; eh_aberta = false;
    hull_big = []; rb0 = rp0; cb0 = cp0;
    if A_hull >= hull_aberta * ppc^2   % so candidatos grandes levam o teste caro
        [subb, rb0, cb0] = recorta(ry, rx, mg_big, H, W);
        rzb = zeros(1, numel(rc_big));
        for j = 1:numel(rc_big)
            se = strel('disk', max(1, round(rc_big(j) * ppc)));
            f  = imfill(imclose(subb, se), 'holes');
            rzb(j) = sum(f(:)) / max(A_hull, 1);
            if isempty(filled) && rzb(j) >= razao_fech
                filled = f; r0s = rb0; c0s = cb0;
            end
        end
        razao_15 = rzb(rc_big == 1.5);
        razao_20 = rzb(rc_big == 2.0);
        if razao_15 < razao_ab15 && razao_20 < razao_ab20
            sk_cm = sum(sum(bwskel(subb))) / ppc;
            eh_aberta = sk_cm >= sk_aberta;
        end
        hull_big = bwconvhull(subb);
    end

    if isempty(filled)   % nunca fechou: usa o melhor preenchimento disponivel
        if ~isempty(hull_big)
            se = strel('disk', max(1, round(1.0 * ppc)));
            filled = imfill(imclose(subb, se), 'holes'); r0s = rb0; c0s = cb0;
        else
            se = strel('disk', max(1, round(0.5 * ppc)));
            filled = imfill(imclose(subp, se), 'holes'); r0s = rp0; c0s = cp0;
        end
    end

    razao = razao_15; if isnan(razao), razao = razao_peq; end
    if eh_aberta
        classe = 'aberta';   mask_sub = hull_big; r0s = rb0; c0s = cb0;
    else
        classe = 'fechada';  mask_sub = filled;
    end

    mfull = false(H, W);
    mfull(r0s:r0s+size(mask_sub,1)-1, c0s:c0s+size(mask_sub,2)-1) = mask_sub;
    cen     = [mean(rx), mean(ry)];
    dist_cm = hypot(cen(1) - origem(1), cen(2) - origem(2)) / ppc;

    k = k + 1;
    comps(k).px             = px;
    comps(k).classe         = classe;
    comps(k).area_traco_cm2 = A_traco / ppc^2;
    comps(k).hull_cm2       = A_hull  / ppc^2;
    comps(k).fill_cm2       = sum(mask_sub(:)) / ppc^2;
    comps(k).razao_fill     = razao;
    comps(k).esqueleto_cm   = sk_cm;
    comps(k).dist_origem_cm = dist_cm;
    comps(k).mask_fechada   = mfull;
end

if ~isempty(comps)
    [~, ord] = sort([comps.hull_cm2], 'descend');
    comps = comps(ord);
end

classes = {comps.classe};
if any(strcmp(classes, 'aberta'))
    classe_img = 'aberta';
elseif ~isempty(classes)
    classe_img = 'fechada';
else
    classe_img = 'nenhuma';
end

if ~isempty(saida)
    lesao.salvar(uniao_mascaras(comps, [H W]), saida, '25_componentes.png');
    lesao.salvar(rotular(comps, [H W]),        saida, '26_componentes_color.png');
end
end

function u = uniao_mascaras(comps, sz)
u = false(sz);
for k = 1:numel(comps), u = u | comps(k).mask_fechada; end
end

function rgb = rotular(comps, sz)
L = zeros(sz);
for k = 1:numel(comps), L(comps(k).mask_fechada) = k; end
rgb = label2rgb(L, 'jet', 'k', 'shuffle');
end

function [sub, r0, c0] = recorta(ry, rx, mg, H, W)
r0 = max(1, min(ry) - mg); r1 = min(H, max(ry) + mg);
c0 = max(1, min(rx) - mg); c1 = min(W, max(rx) + mg);
sub = false(r1 - r0 + 1, c1 - c0 + 1);
sub(sub2ind(size(sub), ry - r0 + 1, rx - c0 + 1)) = true;
end
