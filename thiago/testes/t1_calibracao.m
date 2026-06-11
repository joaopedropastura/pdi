function t1_calibracao()
%T1_CALIBRACAO  Roda E1 (lesao.calibrar_grid) em todas as imagens e imprime a
%   escala estimada. Salva saidas/t1_calibracao.csv.
%
%   Uso (headless):  matlab -batch "addpath('testes'); t1_calibracao"
%   ou, da pasta testes:  matlab -batch "t1_calibracao"
%
%   Esperado: perX ~120 px/cm, perY ~127 px/cm, consistente entre imagens.
%   Outliers (perX/perY muito fora) indicam falha de calibracao p/ investigar.

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'Imagens_GridLesoes_noname');
    saidas = fullfile(raiz, 'saidas');
    if ~exist(saidas, 'dir'); mkdir(saidas); end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    arquivo = strings(n,1);
    perXc = zeros(n,1); perYc = zeros(n,1);
    pxcm  = zeros(n,1); pxcm2 = zeros(n,1);

    fprintf('\n%-16s %7s %7s %9s %12s\n', 'imagem','perX','perY','px/cm','px/cm^2');
    fprintf('%s\n', repmat('-', 1, 56));
    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        [pc, pX, pY] = lesao.calibrar_grid(img);
        arquivo(i) = string(nome);
        perXc(i) = pX; perYc(i) = pY; pxcm(i) = pc; pxcm2(i) = pX*pY;
        fprintf('%-16s %7.0f %7.0f %9.1f %12.0f\n', nome, pX, pY, pc, pX*pY);
    end

    fprintf('%s\n', repmat('-', 1, 56));
    fprintf('mediana   perX=%.0f  perY=%.0f  px/cm=%.1f\n', ...
            median(perXc), median(perYc), median(pxcm));
    % sinaliza outliers: > 15%% de desvio da mediana em qualquer eixo
    mX = median(perXc); mY = median(perYc);
    out = abs(perXc-mX) > 0.15*mX | abs(perYc-mY) > 0.15*mY;
    if any(out)
        fprintf('\nOUTLIERS (>15%% da mediana) -- investigar:\n');
        for i = find(out')
            fprintf('  %-16s perX=%.0f perY=%.0f\n', arquivo(i), perXc(i), perYc(i));
        end
    else
        fprintf('Nenhum outlier (>15%% da mediana). Calibracao consistente.\n');
    end

    T = table(arquivo, perXc, perYc, pxcm, pxcm2, ...
        'VariableNames', {'arquivo','perX_px','perY_px','px_por_cm','px_por_cm2'});
    writetable(T, fullfile(saidas, 't1_calibracao.csv'));
    fprintf('\nSalvo: %s\n', fullfile(saidas, 't1_calibracao.csv'));
end
