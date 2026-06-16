function validar_feridas()
%VALIDAR_FERIDAS  Roda o pipeline COMPLETO (E1..E7) e compara com o gabarito:
%   - n de feridas detectadas vs esperado
%   - area total medida (cm2) vs esperado (com parser correto p/ "8,5")
%   Imprime por imagem (com flush em saidas/progresso.log) e estatisticas.
%
%   Uso (headless):  matlab -batch "addpath('testes'); validar_feridas"

    raiz   = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta  = fullfile(raiz, 'imagens');
    saidas = fullfile(raiz, 'saidas');
    if ~exist(saidas, 'dir'); mkdir(saidas); end
    logf = fullfile(saidas, 'progresso.log');
    fid = fopen(logf, 'w'); fclose(fid);

    [area_gab, n_gab] = ler_gabarito(fullfile(raiz, 'rotulos.csv'));

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    plog(logf, sprintf('=== Validacao E1..E7 de %d imagens ===\n', n));
    plog(logf, sprintf('%-14s %4s %4s | %7s %7s %6s | %s\n', ...
        'imagem','nF','gnF','medido','gabar','err%','feridas(classe:area)'));
    plog(logf, sprintf('%s\n', repmat('-',1,90)));

    rows = {}; erros_pct = []; erros_abs = []; nfok = 0;
    t0 = tic;
    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        pc             = lesao.calibrar_grid(img);
        [bw_t, bw_g]   = lesao.extrair_tinta(img, pc);
        [bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [~, comps]     = lesao.classificar_ferida(bw_l, origem, pc);
        feridas        = lesao.selecionar_feridas(comps, size(bw_l), pc);

        total = sum([feridas.area_cm2]); if isempty(feridas), total = 0; end
        nf    = numel(feridas);
        gabv  = 0;  if isKey(area_gab, nome), gabv = area_gab(nome); end
        gnf   = 0;  if isKey(n_gab,   nome), gnf  = n_gab(nome);    end
        dif   = total - gabv; ep = 100*abs(dif)/max(gabv, eps);
        erros_pct(end+1) = ep; erros_abs(end+1) = abs(dif); %#ok<AGROW>
        nfok = nfok + (nf == gnf);
        rows(end+1,:) = {nome, nf, gnf, total, gabv, dif, ep}; %#ok<AGROW>

        descr = strjoin(arrayfun(@(f) sprintf('%s:%.1f', f.classe(1), f.area_cm2), ...
                        feridas, 'UniformOutput', false), ' ');
        el = toc(t0); eta = el/i*(n-i);
        plog(logf, sprintf('[%2d/%d] %-14s %4d %4d | %7.1f %7.1f %5.0f%% | %s  (ETA %.0fs)\n', ...
            i, n, nome, nf, gnf, total, gabv, ep, descr, eta));
    end

    plog(logf, sprintf('%s\n', repmat('-',1,90)));
    plog(logf, sprintf('Nº de feridas correto: %d/%d = %.0f%%\n', nfok, n, 100*nfok/n));
    plog(logf, sprintf('Area erro abs: mediana %.1f cm2 | medio %.1f cm2\n', ...
        median(erros_abs), mean(erros_abs)));
    plog(logf, sprintf('Area erro rel: mediana %.0f%% | medio %.0f%%\n', ...
        median(erros_pct), mean(erros_pct)));
    plog(logf, sprintf('Imagens com erro<=25%%: %.0f%% | <=40%%: %.0f%%\n', ...
        100*mean(erros_pct<=25), 100*mean(erros_pct<=40)));

    T = cell2table(rows, 'VariableNames', ...
        {'arquivo','n_med','n_gab','area_med','area_gab','dif','err_pct'});
    writetable(T, fullfile(saidas, 'validar_feridas.csv'));
    plog(logf, sprintf('CSV: %s\n', fullfile(saidas, 'validar_feridas.csv')));
end

function [area_gab, n_gab] = ler_gabarito(file)
%LER_GABARITO  Le rotulos.csv com parser robusto (%q lida com "8,5") e devolve
%   mapas arquivo->area total esperada e arquivo->n de feridas.
    T = readtable(file, 'Delimiter', ',', 'Format', '%q%q%q%q%q%q', ...
                  'TextType', 'string');
    arquivo = T.(1); area = str2double(strrep(T.(5), ',', '.'));
    area(isnan(area)) = 0;
    area_gab = containers.Map('KeyType','char','ValueType','double');
    n_gab    = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(arquivo)
        a = char(arquivo(i));
        if isKey(area_gab, a)
            area_gab(a) = area_gab(a) + area(i);  n_gab(a) = n_gab(a) + 1;
        else
            area_gab(a) = area(i);                n_gab(a) = 1;
        end
    end
end

function plog(logf, msg)
    fprintf('%s', msg);
    fid = fopen(logf, 'a'); fprintf(fid, '%s', msg); fclose(fid);
end
