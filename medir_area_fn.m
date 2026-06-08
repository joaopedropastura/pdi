function R = medir_area_fn(img_path, visualizar)
%MEDIR_AREA_FN  Mede a área de uma forma desenhada à mão em papel quadriculado.
%   R = medir_area_fn(CAMINHO)            -> struct com resultados, sem figuras
%   R = medir_area_fn(CAMINHO, true)      -> também mostra figuras de diagnóstico
%
%   Campos de R:
%     area_cm2      área preenchida (resultado principal)
%     area_hull     área do convex hull (limite superior)
%     solidez       area_cm2 / area_hull  (1 = convexo, baixo = côncavo/incompleto)
%     pixels_por_cm calibração estimada
%     n_linhas      nº de linhas de grade detectadas na calibração
%     usou_hull     true se o resultado veio do fallback de convex hull
%     ok            true se passou em todas as validações
%     msg           mensagem resumida de status

    if nargin < 2, visualizar = false; end

    R = struct('area_cm2',NaN,'area_hull',NaN,'solidez',NaN,'cobertura',NaN, ...
               'n_lesoes',0,'areas_cm2',[], ...
               'pixels_por_cm',NaN,'n_linhas',0,'usou_hull',false, ...
               'ok',false,'msg','','mask',[]);

    %% 1. Leitura
    img = imread(img_path);
    if size(img,3) == 3, gray = rgb2gray(img); else, gray = img; end

    %% 2. Resolução estimada (lado curto ~ 20 cm)
    ppc_rough = min(size(gray)) / 20;

    %% 3. Black top-hat + Otsu  (realça tinta na largura real, ignora a grade)
    raio_bh = max(10, round(0.30 * ppc_rough));
    gray_bh = imbothat(gray, strel('disk', raio_bh));
    bw = imbinarize(gray_bh, graythresh(gray_bh));

    %% 4. Remover a grade com SE de LINHA (não com disco)
    % As linhas da grade são longas, retas e alinhadas aos eixos; o traço da
    % lesão é curvo e nunca tem longos trechos retos. Abertura com SE de linha
    % horizontal/vertical extrai SÓ a grade, preservando o traço fino e curvo.
    len_linha = round(0.6 * ppc_rough);            % < 1 cm, > trecho reto do traço
    grade_h = imopen(bw, strel('line', len_linha, 0));
    grade_v = imopen(bw, strel('line', len_linha, 90));
    bw_grade = grade_h | grade_v;                  % máscara explícita da grade

    bw_open = bw & ~bw_grade;                      % só o traço da lesão
    % Reconectar o traço onde a grade o cruzava (disco > largura da grade ~5-8px)
    bw_open = imclose(bw_open, strel('disk', max(6, round(0.06 * ppc_rough))));
    bw_open = bwareaopen(bw_open, round(0.01 * ppc_rough^2));

    %% 5. Calibração via espaçamento das linhas verticais da grade
    perfil = movmean(sum(double(grade_v), 1), 3);
    limiar = mean(perfil) + std(perfil);
    min_dist = max(10, round(0.5 * ppc_rough));

    x = perfil(:); n = numel(x);
    eh_max = false(n,1);
    eh_max(2:end-1) = (x(2:end-1) > x(1:end-2)) & (x(2:end-1) > x(3:end));
    eh_max = eh_max & (x >= limiar);
    cand = find(eh_max);
    locs = [];
    while ~isempty(cand)
        [~, m] = max(x(cand));
        locs(end+1) = cand(m);                       %#ok<AGROW>
        cand(abs(cand - cand(m)) < min_dist) = [];
    end
    locs = sort(locs);

    if numel(locs) >= 4
        pixels_por_cm = median(diff(locs));
    else
        pg = perfil - mean(perfil);
        xc = real(ifft(abs(fft(pg)).^2));
        xc = xc(1:floor(end/2));
        xc(1:max(5, round(0.3*ppc_rough))) = 0;
        [~, pixels_por_cm] = max(xc);
    end
    R.pixels_por_cm = pixels_por_cm;
    R.n_linhas = numel(locs);

    %% 5b. Restringir ao plano cartesiano (ignorar bordas/margens da folha)
    % As linhas da grade definem o plano; fora dele (moldura, textos, furos,
    % faixa escura da borda) não há lesão e só geram laços falsos.
    % A extensão das linhas (1ª e última coluna/linha com grade densa) dá o
    % retângulo do plano; encolhemos pra dentro pra descartar a própria moldura.
    margem = round(0.4 * pixels_por_cm);
    col_grade = sum(grade_v, 1);  col_tem = col_grade > 0.2 * max(col_grade);
    row_grade = sum(grade_h, 2);  row_tem = row_grade > 0.2 * max(row_grade);
    cmin = find(col_tem, 1, 'first'); cmax = find(col_tem, 1, 'last');
    rmin = find(row_tem, 1, 'first'); rmax = find(row_tem, 1, 'last');
    if ~isempty(cmin) && ~isempty(rmin) && (cmax-cmin) > 2*margem && (rmax-rmin) > 2*margem
        roi = false(size(bw));
        roi(rmin+margem:rmax-margem, cmin+margem:cmax-margem) = true;
        bw_open = bw_open & roi;
    end

    %% 5c. Localizar a ORIGEM (cruz central) pelos eixos em NEGRITO
    % Os eixos X/Y são (a) MUITO LONGOS (~20 cm, atravessam a folha) e (b) mais
    % GROSSOS que a grade comum. Detectar com SE de linha LONGO (3 cm) é crucial:
    % um SE curto deixa segmentos retos da LESÃO sobreviverem e a lateral grossa
    % do contorno rouba a origem (bug visto na 7_c2). Com 3 cm, só eixos/grade
    % sobrevivem; entre eles, a linha/coluna mais grossa (erosão) é o eixo.
    % O eixo verdadeiro ATRAVESSA toda a grade (extensão máxima); a lateral
    % grossa da LESÃO só cobre a altura da lesão. Por isso escolhemos a coluna
    % de MAIOR EXTENSÃO VERTICAL (e a linha de maior extensão horizontal), e não
    % a de mais pixels — assim a lesão não rouba a origem (bug visto na 7_c2).
    esp    = max(4, round(0.06 * pixels_por_cm));
    eixo_h = imerode(grade_h, strel('line', esp, 90));
    eixo_v = imerode(grade_v, strel('line', esp, 0));

    [rv, cv] = find(eixo_v);
    ext_col = zeros(size(bw,2), 1);
    if ~isempty(cv)
        ext_col = accumarray(cv, rv, [size(bw,2),1], @max, 0) ...
                - accumarray(cv, rv, [size(bw,2),1], @min, 0);
    end
    [vx, ox] = max(movmean(ext_col, esp));

    [rh, ch] = find(eixo_h);
    ext_row = zeros(size(bw,1), 1);
    if ~isempty(rh)
        ext_row = accumarray(rh, ch, [size(bw,1),1], @max, 0) ...
                - accumarray(rh, ch, [size(bw,1),1], @min, 0);
    end
    [vy, oy] = max(movmean(ext_row, esp));
    if vy > 0 && vx > 0
        origem = [ox, oy];
    elseif ~isempty(cmin)
        origem = [(cmin+cmax)/2, (rmin+rmax)/2];   % fallback: centro da grade
    else
        origem = [size(bw,2)/2, size(bw,1)/2];
    end

    %% 6. Janela ao redor da origem (cruz central): inclui 2ª ferida a ~6 cm,
    % exclui a seta de orientação (~11 cm) e cantos da folha.
    area_min_px = round(0.2 * pixels_por_cm^2);
    raio_base   = max(6, round(0.10 * pixels_por_cm));
    raio_busca  = 8 * pixels_por_cm;

    [Yg, Xg] = ndgrid(1:size(bw,1), 1:size(bw,2));
    janela = (Xg - origem(1)).^2 + (Yg - origem(2)).^2 <= raio_busca^2;
    bw_jan = bw_open & janela;

    %% 7. Contar e medir TODAS as feridas (laços que encerram área)
    % Coletamos todo laço válido (encerra área, borda de tinta real), cada um na
    % menor escala em que fecha (sem recontar sobreposições).
    % Regra ASSIMÉTRICA contra falsos: a ferida PRINCIPAL (maior, sobre a origem)
    % vale com qualquer tamanho; feridas SECUNDÁRIAS só contam se forem grandes
    % (> area_sec). Furos de dígito/merges (~0.3-0.5 cm²) ficam abaixo disso e
    % são descartados; uma 2ª ferida real (ex.: 6a_c2 "B" ~5 cm²) passa.
    area_sec_px = round(2.5 * pixels_por_cm^2);   % 2ª ferida só conta se substancial
    ink_d = imdilate(bw_open, strel('disk', max(2, round(0.05 * pixels_por_cm))));

    % PARAR DE ESCALAR assim que achar lesão(ões): escala o raio só até a
    % primeira lesão fechar, faz UM passo a mais (pega 2ª ferida próxima) e para.
    % Assim imagens bem desenhadas param cedo (antes de a dilatação FABRICAR
    % enclausuras falsas em raio grande); as mal desenhadas escalam só o
    % necessário para a lesão de falhas largas fechar.
    raio_primaria = 3.5 * pixels_por_cm;   % a lesão PRINCIPAL fica sobre a origem
    sweep = raio_base * [1 2 3 4 6 8];
    cands = {}; cdist = [];
    resc = {}; resc_area = [];             % resgate: laços bons com solidez baixa
    ja_visto = false(size(bw));
    achou_em = -1;
    for ri = 1:numel(sweep)
        r = sweep(ri);
        se_r = strel('disk', r);
        e  = imerode(imfill(imdilate(bw_jan, se_r), 'holes'), se_r);
        e  = bwareaopen(e, area_min_px);
        rp = regionprops(e, 'Area', 'Solidity', 'Centroid', ...
                            'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
        for i = 1:numel(rp)
            px = rp(i).PixelIdxList;
            % rejeitar candidato muito ALONGADO = segmento de linha/eixo, não
            % lesão. Lesão real é roundish (aspect<4); linha tem aspect alto
            % (ex.: 5a/12_c2 pegavam o eixo horizontal, aspect ~9).
            if rp(i).MajorAxisLength / max(rp(i).MinorAxisLength,1) > 4, continue; end
            if rp(i).Area / max(sum(bw_jan(px)),1) <= 1.3, continue; end
            if any(ja_visto(px)), continue; end
            cm = false(size(bw)); cm(px) = true; cp = bwperim(cm);
            cov_i = sum(cp(:) & ink_d(:)) / max(sum(cp(:)),1);
            % candidato PEQUENO (<1 cm²) precisa de cobertura ALTA: lesão pequena
            % real é crisp (cov>0.85); ruído pequeno (ex.: 12_c2, cov 0.58) cai.
            % Candidato GRANDE basta cov>0.5 (o tamanho já o confirma como lesão).
            cov_min = 0.5; if rp(i).Area < 1 * pixels_por_cm^2, cov_min = 0.85; end
            if cov_i < cov_min, continue; end
            if rp(i).Solidity < 0.5
                % Solidez baixa = normalmente fragmentos espalhados (rejeitar).
                % EXCEÇÃO: um laço REAL com traços de eixo colados tem hull
                % inflado e solidez artificialmente baixa (10_c2: sol 0.37,
                % cob 0.99). Se a borda está quase toda sobre tinta (>0.9),
                % guardamos como RESGATE — usado só se a detecção normal falhar,
                % então não interfere em lesões grandes nem em abertas (7_c1).
                if cov_i >= 0.9
                    resc{end+1} = px;                 %#ok<AGROW>
                    resc_area(end+1) = rp(i).Area;    %#ok<AGROW>
                end
                continue;
            end
            ja_visto(px) = true;
            cands{end+1} = px;                        %#ok<AGROW>
            cdist(end+1) = hypot(rp(i).Centroid(1)-origem(1), ...
                                 rp(i).Centroid(2)-origem(2)); %#ok<AGROW>
        end
        if ~isempty(cands)
            if achou_em < 0, achou_em = ri; end
            if ri >= achou_em + 1, break; end        % um passo extra, depois para
        end
    end

    bw_final = [];
    dist_primaria = 0;
    if ~isempty(cands)
        areas = cellfun(@numel, cands);
        [~, ip] = max(areas);                          % principal = maior
        dist_primaria = cdist(ip) / pixels_por_cm;     % p/ flag de confiança
        bw_final = false(size(bw));
        bw_final(cands{ip}) = true;
        for j = 1:numel(cands)                          % secundárias: só se grandes
            if j ~= ip && areas(j) >= area_sec_px
                bw_final(cands{j}) = true;
            end
        end
    end

    %% 7b. LESÃO ABERTA: detecção por COMPRIMENTO do traço (não por bbox).
    % Uma lesão aberta é UM traço de caneta LONGO e CURVO (o contorno em si).
    % Filtro que torna isso evidente, separando de tudo que confunde:
    %   - esqueleto LONGO (>15 cm)  -> não é ruído curto nem lesão pequena
    %   - convex hull de área GRANDE (>10 cm²) -> curva e envolve espaço; um
    %     EIXO é longo mas reto (hull fino), então é descartado aqui
    %   - área já capturada << hull  -> a detecção normal (laço fechado) falhou
    % Quando evidente: fecha a falha do contorno (preciso) ou convex hull (aberto).
    area_atual = 0; if ~isempty(bw_final), area_atual = sum(bw_final(:)); end
    bw_lc = imclose(bw_jan, strel('disk', round(0.15 * pixels_por_cm)));  % une cruzamentos de grade
    cc = bwconncomp(bw_lc);
    melhor = 0; melhor_hull = 0; melhor_px = [];
    for i = 1:cc.NumObjects
        px = cc.PixelIdxList{i};
        comp = false(size(bw)); comp(px) = true;
        if sum(sum(bwskel(comp))) < 15 * pixels_por_cm, continue; end   % traço curto
        ah = sum(sum(bwconvhull(comp)));
        if ah > melhor_hull, melhor_hull = ah; melhor = i; melhor_px = px; end
    end
    % área capturada < 15% do hull = laço fechado falhou de verdade (aberta);
    % lesões médias côncavas capturam bem mais que isso e não disparam.
    if melhor > 0 && melhor_hull > 10 * pixels_por_cm^2 && area_atual < 0.15 * melhor_hull
        comp = false(size(bw)); comp(melhor_px) = true;
        filled = imfill(imclose(comp, strel('disk', round(1.5*pixels_por_cm))), 'holes');
        hull   = bwconvhull(comp);
        % Preferir um LAÇO RESGATADO se ele captura a maior parte da lesão
        % (resc >= 0.5*filled): aí é uma lesão FECHADA cujo hull foi inflado por
        % traços de eixo (10_c2: resc 8.6 vs filled 12.5, razão 0.69 -> usa resc,
        % evita hull 22). Se o resgate é só um fragmento de uma lesão grande
        % ABERTA (6b_c3 0.37, 7_c1 0.36), mantém o 7b (filled/hull).
        if ~isempty(resc) && max(resc_area) >= 0.5 * sum(filled(:))
            [~, ir] = max(resc_area);
            bw_final = false(size(bw)); bw_final(resc{ir}) = true;
        elseif sum(filled(:)) > sum(hull(:)) * 0.75   % fechou bem -> preenchido
            bw_final = filled; R.usou_hull = false;
        else                                       % permanece aberto -> convex hull
            bw_final = hull;   R.usou_hull = true;
        end
    end

    %% 7c. RESGATE quando o 7b não disparou (não há lesão aberta grande): um laço
    % de cobertura altíssima rejeitado só por solidez (hull inflado pelo eixo).
    % Ex. 12_c2: lesão pequena na origem que ia para fallback errado.
    if isempty(bw_final) && ~isempty(resc)
        [~, ir] = max(resc_area);
        bw_final = false(size(bw)); bw_final(resc{ir}) = true;
    end

    %% 8. Fallback NÃO-inflante: preencher o maior fragmento da janela
    if isempty(bw_final)
        cc = bwconncomp(bwareaopen(bw_jan, area_min_px));
        if cc.NumObjects == 0
            R.msg = 'nenhum traço perto da origem'; return;
        end
        [~, im] = max(cellfun(@numel, cc.PixelIdxList));
        m = false(size(bw)); m(cc.PixelIdxList{im}) = true;
        bw_final = imfill(m, 'holes');
        R.usou_hull = true;   % marca baixa confiança (traço não fechou)
    end

    %% 9. Área, convex hull e solidez (somando por ferida; pode haver várias)
    ccL = bwconncomp(bw_final);
    R.n_lesoes = ccL.NumObjects;
    R.areas_cm2 = cellfun(@numel, ccL.PixelIdxList) / pixels_por_cm^2;  % por ferida
    R.area_cm2  = sum(bw_final(:)) / pixels_por_cm^2;                   % total
    % Hull/solidez somados POR ferida (hull único entre lesões separadas seria
    % enorme e enganoso). bw_hull serve só para sobreposição no diagnóstico.
    bw_hull = false(size(bw)); hull_px = 0;
    for i = 1:ccL.NumObjects
        m = false(size(bw)); m(ccL.PixelIdxList{i}) = true;
        h = bwconvhull(m); bw_hull = bw_hull | h; hull_px = hull_px + sum(h(:));
    end
    R.area_hull = hull_px / pixels_por_cm^2;
    R.solidez   = R.area_cm2 / max(R.area_hull, eps);
    R.mask      = bw_final;   % máscara final (para auditoria/sobreposição)

    % Cobertura: fração do PERÍMETRO detectado que coincide com tinta real
    % desenhada (bw_open). Sinal de confiança INDEPENDENTE da seleção: uma
    % lesão real tem traço contínuo na borda (cobertura alta); um laço espúrio
    % costurado de fragmentos/dilatação tem borda majoritariamente "inventada".
    perim = bwperim(bw_final);
    ink_d = imdilate(bw_open, strel('disk', max(2, round(0.05 * pixels_por_cm))));
    R.cobertura = sum(perim(:) & ink_d(:)) / max(sum(perim(:)), 1);

    %% 10. Validação
    R.ok = true; motivos = {};
    if isnan(pixels_por_cm) || pixels_por_cm < 15 || pixels_por_cm > 500
        R.ok = false; motivos{end+1} = 'calibração';
    end
    if R.area_cm2 < 0.3 || R.area_cm2 > 300
        R.ok = false; motivos{end+1} = 'área';
    end
    if R.usou_hull
        R.ok = false; motivos{end+1} = 'fallback-hull';
    end
    if R.cobertura < 0.45   % borda pouco apoiada em traço real = baixa confiança
        R.ok = false; motivos{end+1} = sprintf('cobertura-baixa(%.2f)', R.cobertura);
    end
    if isempty(motivos), R.msg = 'ok'; else, R.msg = strjoin(motivos, ','); end

    %% 11. Figuras (opcional)
    if visualizar
        figure('Name', 'Pipeline', 'Position', [50 50 1200 700]);
        subplot(2,3,1); imshow(gray);        title('1. Original');
        subplot(2,3,2); imshow(gray_bh, []); title('2. Black top-hat');
        subplot(2,3,3); imshow(bw_grade);    title('3. Grade (linha-SE)');
        subplot(2,3,4); imshow(bw_open);     title('4. Traço isolado');
        subplot(2,3,5); imshow(bw_final);    title('5. Lesão (área encerrada)');
        subplot(2,3,6); imshow(img); hold on;
        bf = bwboundaries(bw_final);
        for k = 1:numel(bf), plot(bf{k}(:,2), bf{k}(:,1), 'r-', 'LineWidth', 2); end
        bh = bwboundaries(bw_hull);
        for k = 1:numel(bh), plot(bh{k}(:,2), bh{k}(:,1), 'g--', 'LineWidth', 1.5); end
        title(sprintf('Preench=%.2f | hull=%.2f cm²', R.area_cm2, R.area_hull));
        legend('preenchido','convex hull','Location','south');
    end
end
