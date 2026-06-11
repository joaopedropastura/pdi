function t5_area()
%T5_AREA  Roda o pipeline E1..E6 em todas as imagens, mede a area (cm2) de cada
%   ferida e compara o TOTAL por imagem com o gabarito (rotulos.csv). Imprime
%   erro por imagem + estatisticas, e salva um overlay por imagem (preenchido
%   em vermelho, convex hull em verde nas abertas).
%
%   Uso (headless):  matlab -batch "addpath('testes'); t5_area"
%
%   Saidas: saidas/t5_area.csv  e  saidas/area/<base>.png

    raiz   = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta  = fullfile(raiz, 'Imagens_GridLesoes_noname');
    saidas = fullfile(raiz, 'saidas', 'area');
    if ~exist(saidas, 'dir'); mkdir(saidas); end

    % --- gabarito: area total esperada por imagem (soma das feridas) ---
    gab = readtable(fullfile(raiz, 'rotulos.csv'), 'TextType','string', ...
                    'Delimiter',',');
    area_gab = containers.Map('KeyType','char','ValueType','double');
    for i = 1:height(gab)
        arq = char(gab.arquivo(i));
        a   = str2double(strrep(string(gab.area_cm2_aprox(i)), ',', '.'));
        if isnan(a), a = 0; end
        if isKey(area_gab, arq), area_gab(arq) = area_gab(arq) + a;
        else,                    area_gab(arq) = a;
        end
    end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    linhas = {}; erros_pct = []; erros_abs = [];

    fprintf('%-16s %7s %7s %7s %6s  %s\n', ...
            'arquivo','medido','gabar','dif','err%','feridas(classe:area)');
    fprintf('%s\n', repmat('-',1,92));

    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_t, bw_g]    = lesao.extrair_tinta(img, pc);
        [bw_l, origem]  = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [~, comps]      = lesao.classificar_ferida(bw_l, origem, pc);
        [feridas, total]= lesao.fechar_e_medir(comps, pc);

        gabv = 0; if isKey(area_gab, nome), gabv = area_gab(nome); end
        dif  = total - gabv;
        ep   = 100 * abs(dif) / max(gabv, eps);
        erros_pct(end+1) = ep;  erros_abs(end+1) = abs(dif); %#ok<AGROW>

        descr = strjoin(arrayfun(@(f) sprintf('%s:%.1f', f.classe(1), f.area_cm2), ...
                        feridas, 'UniformOutput', false), ' ');
        fprintf('%-16s %7.1f %7.1f %7.1f %5.0f%%  %s\n', ...
                nome, total, gabv, dif, ep, descr);

        linhas(end+1,:) = {nome, total, gabv, dif, ep, numel(feridas)}; %#ok<AGROW>
        salvar_overlay(img, feridas, nome, total, gabv, pc, ...
                       fullfile(saidas, [erase(nome,'.jpg') '.png']));
    end

    fprintf('%s\n', repmat('-',1,92));
    fprintf('Erro absoluto: mediana %.1f cm2 | medio %.1f cm2\n', ...
            median(erros_abs), mean(erros_abs));
    fprintf('Erro relativo: mediana %.0f%% | medio %.0f%%\n', ...
            median(erros_pct), mean(erros_pct));
    dentro = 100 * mean(erros_pct <= 25);
    fprintf('Imagens com erro <= 25%%: %.0f%%\n', dentro);

    T = cell2table(linhas, 'VariableNames', ...
        {'arquivo','medido_cm2','gabarito_cm2','dif_cm2','err_pct','n_feridas'});
    writetable(T, fullfile(raiz,'saidas','t5_area.csv'));
    fprintf('\nCSV: %s\nOverlays: %s\n', ...
            fullfile(raiz,'saidas','t5_area.csv'), saidas);
end

function salvar_overlay(img, feridas, nome, total, gabv, pc, destino)
    fig = figure('Visible','off','Position',[0 0 760 720]);
    imshow(img); hold on;
    for j = 1:numel(feridas)
        b = bwboundaries(feridas(j).mask);
        if feridas(j).usou_hull, cor = 'g'; else, cor = 'r'; end
        for k = 1:numel(b), plot(b{k}(:,2), b{k}(:,1), cor, 'LineWidth', 1.8); end
        rp = regionprops(feridas(j).mask, 'Centroid');
        if ~isempty(rp)
            text(rp(1).Centroid(1), rp(1).Centroid(2), ...
                 sprintf('%.1f', feridas(j).area_cm2), 'Color','y', ...
                 'FontWeight','bold', 'HorizontalAlignment','center');
        end
    end
    title(sprintf('%s   medido=%.1f  gabarito=%.1f cm^2  (px/cm=%.0f)', ...
          nome, total, gabv, pc), 'Interpreter','none')
    exportgraphics(fig, destino, 'Resolution', 110);
    close(fig)
end
