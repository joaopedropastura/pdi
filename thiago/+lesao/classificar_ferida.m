function [classe_img, comps, info] = classificar_ferida(bw_limpa, origem, px_por_cm)
%CLASSIFICAR_FERIDA  Classifica cada traco da mascara limpa (E3) em
%   FECHADA (laco que encerra area) ou ABERTA (contorno longo com vao),
%   descartando ruido. E o requisito #1 do projeto.
%
%   [CLASSE_IMG, COMPS, INFO] = CLASSIFICAR_FERIDA(BW_LIMPA, ORIGEM, PX_POR_CM)
%
%   Entradas:
%     bw_limpa   mascara do traco da ferida, limpa e restrita a ROI (E3)
%     origem     [x y] da cruz central (E3) — usada so p/ ordenar por proximidade
%     px_por_cm  escala linear (E1)
%
%   Saidas:
%     classe_img classe predominante da imagem: 'aberta' se houver alguma
%                ferida aberta convincente; senao 'fechada'; senao 'nenhuma'
%     comps      struct array (uma entrada por componente classificado), com:
%                  .px            indices dos pixels do traco
%                  .classe        'fechada' | 'aberta'
%                  .area_traco_cm2  area so do traco (sem preencher)
%                  .hull_cm2      area do convex hull
%                  .fill_cm2      area preenchida (laco fechado)
%                  .razao_fill    fill_cm2 / hull_cm2  (alto => fechou)
%                  .esqueleto_cm  comprimento do traco (esqueleto)
%                  .dist_origem_cm distancia do centroide a origem
%                  .mask_fechada  mascara ja fechada (preenchida ou hull) p/ E5/E6
%     info       struct com os parametros usados
%
%   IDEIA (portada do projeto pdi): tenta fechar o laco com closing crescente
%   e preencher. Se a area preenchida e fracao significativa do hull, FECHOU
%   (fechada). Se mesmo assim quase nada preenche E o traco e longo/curvo com
%   hull grande, e um contorno ABERTO. O resto e ruido (texto/cruz/respingo).

    ppc = px_por_cm;
    [H, W] = size(bw_limpa);
    if nargin < 2 || isempty(origem), origem = [W/2, H/2]; end

    % --- parametros ---
    % Estrategia (calibrada no diag_e4): para decidir ABERTA, tenta FECHAR o laco
    % com closing AGRESSIVO (ate ~1.5-2 cm). Uma fechada com laco quebrado pela
    % grade/cruz fecha e preenche (razao sobe); uma ABERTA real tem um vao maior
    % que isso e NAO fecha (razao continua baixa mesmo a 2 cm). Exige tambem traco
    % longo e hull grande p/ nao confundir ferida pequena com aberta.
    A_min_cm2   = 0.06;   % hull abaixo disso = ruido (a menor ferida real ~0.1)
    razao_fech  = 0.20;   % fill/hull >= isso (em rc moderado) => laco fechou
    rc_cm       = [0.15 0.30 0.50 1.0 1.5 2.0];  % raios de closing (cm) testados
    razao_ab15  = 0.18;   % razao a rc=1.5cm abaixo disso => candidato a aberta
    razao_ab20  = 0.30;   % e razao a rc=2.0cm tambem baixa => confirma aberta
    sk_aberta   = 14;     % esqueleto (cm) minimo p/ considerar ABERTA
    hull_aberta = 15;     % hull (cm2) minimo p/ considerar ABERTA

    info = struct('A_min_cm2',A_min_cm2, 'razao_fech',razao_fech, 'rc_cm',rc_cm, ...
                  'razao_ab15',razao_ab15, 'razao_ab20',razao_ab20, ...
                  'sk_aberta',sk_aberta, 'hull_aberta',hull_aberta);

    % une cruzamentos de grade remanescentes sem fundir feridas distintas
    bw = imclose(bw_limpa, strel('disk', max(2, round(0.06 * ppc))));
    cc = bwconncomp(bw);

    comps = struct('px',{}, 'classe',{}, 'area_traco_cm2',{}, 'hull_cm2',{}, ...
                   'fill_cm2',{}, 'razao_fill',{}, 'esqueleto_cm',{}, ...
                   'dist_origem_cm',{}, 'mask_fechada',{});

    % Caminhos separados por tamanho (otimizacao critica): havia ~100 componentes
    % de ruido por imagem. So um componente com hull >= hull_aberta pode ser
    % ABERTA, entao o teste caro (closings de 1-2cm + esqueleto + margem grande)
    % roda SO para esses 1-2 candidatos. O ruido (hull pequeno) so leva closings
    % pequenos num recorte justo, sem bwskel.
    mg_peq = round(0.7 * ppc);              % margem p/ closings <= 0.5 cm
    mg_big = round((max(rc_cm) + 0.2)*ppc); % margem p/ closings ate 2.0 cm
    rc_peq = rc_cm(rc_cm <= 0.5);
    rc_big = rc_cm(rc_cm >  0.5);

    k = 0;
    for i = 1:cc.NumObjects
        px = cc.PixelIdxList{i};
        [ry, rx] = ind2sub([H, W], px);

        % recorte justo p/ a maioria (ruido + feridas pequenas)
        [subp, rp0, cp0] = recorta(ry, rx, mg_peq, H, W);
        A_hull = sum(sum(bwconvhull(subp)));
        if A_hull < A_min_cm2 * ppc^2, continue; end   % ruido: hull minusculo

        A_traco = numel(px);

        % closings PEQUENOS: fecham o laco de feridas normais/pequenas (p/ area).
        filled = []; r0s = rp0; c0s = cp0; razao_peq = 0;
        for rc = rc_peq
            se = strel('disk', max(1, round(rc * ppc)));
            f  = imfill(imclose(subp, se), 'holes');
            rz = sum(f(:)) / max(A_hull, 1);
            razao_peq = max(razao_peq, rz);
            if isempty(filled) && rz >= razao_fech, filled = f; end
        end

        % So candidatos GRANDES (hull >= hull_aberta) levam o teste caro de aberta.
        razao_15 = NaN; razao_20 = NaN; sk_cm = NaN; eh_aberta = false;
        hull_big = []; rb0 = rp0; cb0 = cp0;
        if A_hull >= hull_aberta * ppc^2
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
                sk_cm = sum(sum(bwskel(subb))) / ppc;   % so aqui (caro)
                eh_aberta = sk_cm >= sk_aberta;
            end
            hull_big = bwconvhull(subb);
        end

        % fechada que nunca atingiu razao_fech: usa o melhor preench. disponivel
        if isempty(filled)
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
            classe = 'fechada';  mask_sub = filled;     % E6 mede pelo preenchimento
        end

        % remonta a mascara no quadro cheio (downstream usa tamanho HxW)
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

    % ordena por hull decrescente (ferida principal primeiro)
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
end

function [sub, r0, c0] = recorta(ry, rx, mg, H, W)
%RECORTA  Recorta a bounding box dos pixels (ry,rx) + margem mg, devolvendo a
%   mascara logica do recorte e o offset (r0,c0) p/ remontar no quadro cheio.
    r0 = max(1, min(ry) - mg); r1 = min(H, max(ry) + mg);
    c0 = max(1, min(rx) - mg); c1 = min(W, max(rx) + mg);
    sub = false(r1 - r0 + 1, c1 - c0 + 1);
    sub(sub2ind(size(sub), ry - r0 + 1, rx - c0 + 1)) = true;
end
