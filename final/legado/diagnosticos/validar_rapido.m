function validar_rapido()
%VALIDAR_RAPIDO  Roda o pipeline completo E1..E6 em todas as imagens, SEM salvar
%   paineis (que travam em headless), e compara com o gabarito (rotulos.csv):
%     - classe prevista (aberta/fechada) vs gabarito  -> acuracia
%     - area total medida (cm2) vs gabarito            -> erro abs/rel
%
%   Progresso e gravado a cada imagem em saidas/progresso.log (com flush real,
%   via fopen/fprintf/fclose), entao da pra acompanhar ao vivo lendo esse arquivo.
%
%   Uso (headless):  matlab -batch "addpath('testes'); validar_rapido"

    raiz   = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta  = fullfile(raiz, 'imagens');
    saidas = fullfile(raiz, 'saidas');
    if ~exist(saidas, 'dir'); mkdir(saidas); end
    logf = fullfile(saidas, 'progresso.log');
    fid = fopen(logf, 'w'); fclose(fid);            % zera o log

    % --- gabarito: classe e area total esperada por imagem ---
    gab = readtable(fullfile(raiz, 'rotulos.csv'), 'TextType','string', 'Delimiter',',');
    esperado = containers.Map('KeyType','char','ValueType','char');
    area_gab = containers.Map('KeyType','char','ValueType','double');
    for i = 1:height(gab)
        arq = char(gab.arquivo(i));
        cls = char(gab.classe(i));
        a   = str2double(strrep(string(gab.area_cm2_aprox(i)), ',', '.'));
        if isnan(a), a = 0; end
        if ~isKey(esperado, arq),        esperado(arq) = cls;
        elseif strcmp(cls, 'aberta'),    esperado(arq) = 'aberta';
        end
        if isKey(area_gab, arq), area_gab(arq) = area_gab(arq) + a;
        else,                    area_gab(arq) = a;
        end
    end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    plog(logf, sprintf('=== Validacao de %d imagens (E1..E6) ===\n', n));

    acertos = 0; erros_pct = []; erros_abs = [];
    rows = {};
    t0 = tic;
    for i = 1:n
        nome = files(i).name;
        ti = tic;
        img = imread(fullfile(pasta, nome));
        pc            = lesao.calibrar_grid(img);
        [bw_t, bw_g]  = lesao.extrair_tinta(img, pc);
        [bw_l, origem]= lesao.achar_origem_roi(bw_t, bw_g, pc);
        [classe, comps]   = lesao.classificar_ferida(bw_l, origem, pc);
        [feridas, total]  = lesao.fechar_e_medir(comps, pc); %#ok<ASGLU>

        gabc = 'fechada'; if isKey(esperado, nome), gabc = esperado(nome); end
        ok   = strcmp(classe, gabc); acertos = acertos + ok;
        gabv = 0; if isKey(area_gab, nome), gabv = area_gab(nome); end
        dif  = total - gabv; ep = 100*abs(dif)/max(gabv, eps);
        erros_pct(end+1) = ep; erros_abs(end+1) = abs(dif); %#ok<AGROW>
        rows(end+1,:) = {nome, classe, gabc, double(ok), total, gabv, dif, ep, numel(feridas)}; %#ok<AGROW>

        dt = toc(ti); el = toc(t0); eta = el/i*(n-i);
        plog(logf, sprintf('[%2d/%d] %-14s prev=%-7s gab=%-7s%s area=%5.1f gab=%5.1f err=%3.0f%%  | %.1fs  ETA %.0fs\n', ...
            i, n, nome, classe, gabc, tern(ok, ' OK ', ' XX '), total, gabv, ep, dt, eta));
    end

    plog(logf, sprintf('%s\n', repmat('-',1,70)));
    plog(logf, sprintf('Classificacao: %d/%d = %.1f%%\n', acertos, n, 100*acertos/n));
    plog(logf, sprintf('Area erro abs: mediana %.1f cm2 | medio %.1f cm2\n', median(erros_abs), mean(erros_abs)));
    plog(logf, sprintf('Area erro rel: mediana %.0f%% | medio %.0f%%\n', median(erros_pct), mean(erros_pct)));
    plog(logf, sprintf('Imagens com erro<=25%%: %.0f%%\n', 100*mean(erros_pct <= 25)));

    T = cell2table(rows, 'VariableNames', ...
        {'arquivo','previsto','gab_classe','acertou','area_medida','area_gab','dif','err_pct','n_feridas'});
    writetable(T, fullfile(saidas, 'validar_rapido.csv'));
    plog(logf, sprintf('CSV: %s\n', fullfile(saidas, 'validar_rapido.csv')));
end

function plog(logf, msg)
%PLOG  Imprime no stdout E grava no log com flush real (fclose forca a escrita).
    fprintf('%s', msg);
    fid = fopen(logf, 'a'); fprintf(fid, '%s', msg); fclose(fid);
end

function s = tern(c, a, b)
    if c, s = a; else, s = b; end
end
