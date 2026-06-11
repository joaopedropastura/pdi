function t4_classificacao()
%T4_CLASSIFICACAO  Roda E1+E2+E3+E4 em todas as imagens, classifica cada uma
%   em aberta/fechada e compara com o gabarito (rotulos.csv). Imprime as
%   metricas por imagem (uteis p/ calibrar limiares) e a acuracia global, e
%   salva um painel por imagem com o contorno colorido pela classe.
%
%   Uso (headless):  matlab -batch "addpath('testes'); t4_classificacao"
%
%   Conferir: as ABERTAS (7_c1, 7_c2) sao detectadas? Alguma fechada virou
%   aberta (falso positivo)? As metricas razao_fill/esqueleto/hull explicam.
%   Saidas: saidas/t4_classificacao.csv  e  saidas/classe/<base>.png

    raiz   = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta  = fullfile(raiz, 'Imagens_GridLesoes_noname');
    saidas = fullfile(raiz, 'saidas', 'classe');
    if ~exist(saidas, 'dir'); mkdir(saidas); end

    % --- gabarito: classe esperada por imagem (aberta se alguma linha aberta) ---
    gab = readtable(fullfile(raiz, 'rotulos.csv'), 'TextType','string', ...
                    'Delimiter',',');
    esperado = containers.Map('KeyType','char','ValueType','char');
    for i = 1:height(gab)
        arq = char(gab.arquivo(i));
        cls = char(gab.classe(i));
        if ~isKey(esperado, arq)
            esperado(arq) = cls;
        elseif strcmp(cls, 'aberta')
            esperado(arq) = 'aberta';   % aberta domina o rotulo da imagem
        end
    end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    linhas = {};   % p/ CSV
    acertos = 0; total = 0;
    fa_pos = {}; fa_neg = {};   % falsos positivos/negativos de "aberta"

    fprintf('%-16s %-8s %-8s %3s | %-22s\n', ...
            'arquivo','prev','gab','OK','principal (hull/fill/razao/skel/dist)');
    fprintf('%s\n', repmat('-',1,90));

    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_t, bw_g]                = lesao.extrair_tinta(img, pc);
        [bw_l, origem]              = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [classe, comps]             = lesao.classificar_ferida(bw_l, origem, pc);

        % classe esperada (default fechada se a imagem nao estiver no gabarito)
        gabc = 'fechada';
        if isKey(esperado, nome), gabc = esperado(nome); end
        ok = strcmp(classe, gabc);
        acertos = acertos + ok; total = total + 1;
        if ~ok
            if strcmp(classe,'aberta'), fa_pos{end+1} = nome; %#ok<AGROW>
            else,                       fa_neg{end+1} = nome; %#ok<AGROW>
            end
        end

        % metricas do componente principal (maior hull)
        if ~isempty(comps)
            c = comps(1);
            descr = sprintf('%-7s h=%.1f f=%.1f r=%.2f sk=%.1f d=%.1f', ...
                c.classe, c.hull_cm2, c.fill_cm2, c.razao_fill, ...
                c.esqueleto_cm, c.dist_origem_cm);
        else
            descr = '(sem componente)';
        end
        fprintf('%-16s %-8s %-8s %3s | %s\n', nome, classe, gabc, ...
                ternario(ok,'ok','XX'), descr);

        linhas(end+1,:) = {nome, classe, gabc, double(ok), numel(comps)}; %#ok<AGROW>

        % painel e opcional: uma falha de renderizacao headless nao deve abortar
        % a validacao (a acuracia e o que importa).
        try
            salvar_painel(img, comps, origem, nome, classe, gabc, pc, ...
                          fullfile(saidas, [erase(nome,'.jpg') '.png']));
        catch ME
            fprintf('  (painel nao salvo p/ %s: %s)\n', nome, ME.message);
        end
    end

    % --- resumo ---
    fprintf('%s\n', repmat('-',1,90));
    fprintf('Acuracia (imagem): %d/%d = %.1f%%\n', acertos, total, 100*acertos/total);
    if ~isempty(fa_pos), fprintf('Falsos ABERTA (fechada->aberta): %s\n', strjoin(fa_pos,', ')); end
    if ~isempty(fa_neg), fprintf('Abertas perdidas (aberta->fechada): %s\n', strjoin(fa_neg,', ')); end

    T = cell2table(linhas, 'VariableNames', ...
        {'arquivo','previsto','gabarito','acertou','n_comp'});
    writetable(T, fullfile(raiz,'saidas','t4_classificacao.csv'));
    fprintf('\nCSV: %s\nPaineis: %s\n', ...
            fullfile(raiz,'saidas','t4_classificacao.csv'), saidas);
end

function salvar_painel(img, comps, origem, nome, classe, gabc, pc, destino)
    fig = figure('Visible','off','Position',[0 0 760 720]);
    imshow(img); hold on;
    for j = 1:numel(comps)
        m = false(size(img,1), size(img,2)); m(comps(j).px) = true;
        b = bwboundaries(m);
        if strcmp(comps(j).classe,'aberta'), cor = 'g'; else, cor = 'r'; end
        for k = 1:numel(b), plot(b{k}(:,2), b{k}(:,1), cor, 'LineWidth', 1.8); end
        % hull tracejado p/ as abertas (o que a E5 vai usar)
        if strcmp(comps(j).classe,'aberta')
            bh = bwboundaries(comps(j).mask_fechada);
            for k = 1:numel(bh), plot(bh{k}(:,2), bh{k}(:,1), 'g--', 'LineWidth', 1.2); end
        end
    end
    plot(origem(1), origem(2), 'y+', 'MarkerSize',16, 'LineWidth',2);
    title(sprintf('%s   prev=%s  gab=%s  (px/cm=%.0f)', nome, classe, gabc, pc), ...
          'Interpreter','none')
    exportgraphics(fig, destino, 'Resolution', 110);
    close(fig)
end

function s = ternario(c, a, b)
    if c, s = a; else, s = b; end
end
