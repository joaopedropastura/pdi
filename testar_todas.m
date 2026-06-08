function testar_todas()
%TESTAR_TODAS  Roda medir_area_fn em todas as imagens e valida os resultados.
%   Uso (batch):  matlab -batch "testar_todas"
%
%   Dois níveis de teste automático:
%     (A) Por imagem  — calibração/área plausível, sem fallback de hull.
%     (B) Por grupo   — c1..cN do mesmo paciente são a MESMA lesão, então
%                       as áreas devem concordar (coef. de variação baixo).

    script_dir = fileparts(mfilename('fullpath'));
    img_dir = fullfile(script_dir, 'images');
    arquivos = dir(fullfile(img_dir, '*.jpg'));
    [~, ord] = sort({arquivos.name});
    arquivos = arquivos(ord);

    fprintf('\n%-16s %8s %8s %7s %7s %5s  %s\n', ...
            'imagem','area','hull','solidez','px/cm','linha','status');
    fprintf('%s\n', repmat('-', 1, 72));

    nomes = {}; grupos = {}; areas = []; status_ok = [];
    for i = 1:numel(arquivos)
        nome = arquivos(i).name;
        try
            R = medir_area_fn(fullfile(img_dir, nome));
        catch ME
            R = struct('area_cm2',NaN,'area_hull',NaN,'solidez',NaN, ...
                       'pixels_por_cm',NaN,'n_linhas',0,'usou_hull',false, ...
                       'ok',false,'msg',['ERRO: ' ME.message]);
        end
        marca = '  '; if ~R.ok, marca = '!!'; end
        fprintf('%-16s %8.2f %8.2f %7.2f %7.1f %5d  %s %s\n', ...
                nome, R.area_cm2, R.area_hull, R.solidez, ...
                R.pixels_por_cm, R.n_linhas, R.msg, marca);

        % grupo = prefixo antes de "_c"
        g = regexp(nome, '^(.*?)_c?\d', 'tokens', 'once');
        if isempty(g), g = {nome}; end
        nomes{end+1}     = nome;        %#ok<AGROW>
        grupos{end+1}    = g{1};        %#ok<AGROW>
        areas(end+1)     = R.area_cm2;  %#ok<AGROW>
        status_ok(end+1) = R.ok;        %#ok<AGROW>
    end

    %% (A) Resumo por imagem
    n_total = numel(areas);
    n_ok    = sum(status_ok);
    fprintf('\n=== RESUMO POR IMAGEM ===\n');
    fprintf('%d/%d passaram nas validações individuais.\n', n_ok, n_total);

    %% (B) Consistência por grupo (mesma lesão -> áreas próximas)
    fprintf('\n=== CONSISTÊNCIA POR GRUPO (mesma lesão, c1..cN) ===\n');
    fprintf('%-10s %4s %8s %8s %7s  %s\n', 'grupo','n','média','desv','CV%','status');
    fprintf('%s\n', repmat('-', 1, 50));
    [grupos_u, ~, gidx] = unique(grupos, 'stable');
    n_grupos_ok = 0;
    for k = 1:numel(grupos_u)
        a = areas(gidx == k);
        a = a(~isnan(a));
        if numel(a) < 2
            fprintf('%-10s %4d %8.2f %8s %7s  (grupo de 1)\n', ...
                    grupos_u{k}, numel(a), mean(a), '-', '-');
            continue;
        end
        m = mean(a); s = std(a); cv = 100 * s / m;
        % CV < 25% = boa concordância entre observadores
        st = 'OK'; if cv > 25, st = '!! alta variância'; else, n_grupos_ok = n_grupos_ok + 1; end
        fprintf('%-10s %4d %8.2f %8.2f %6.1f%%  %s\n', ...
                grupos_u{k}, numel(a), m, s, cv, st);
    end

    fprintf('\nGrupos com boa concordância (CV<25%%): %d/%d\n', ...
            n_grupos_ok, numel(grupos_u));
end
