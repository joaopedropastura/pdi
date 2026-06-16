function t2_tinta()
%T2_TINTA  Roda E1+E2 em todas as imagens e salva um painel por imagem
%   (original | grade detectada | traco isolado) p/ inspecao visual da E2.
%
%   Uso (headless):  matlab -batch "addpath('testes'); t2_tinta"
%   ou, da pasta testes:  matlab -batch "t2_tinta"
%
%   Conferir em cada painel: o traco da ferida sobreviveu inteiro? Sobrou
%   grade/texto na mascara de tinta? O grid foi removido na imagem 'grade'?
%   Saidas em saidas/tinta/<base>.png

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');
    saidas = fullfile(raiz, 'saidas', 'tinta');
    if ~exist(saidas, 'dir'); mkdir(saidas); end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        [pc, pX, pY] = lesao.calibrar_grid(img);
        [bw_tinta, bw_grade] = lesao.extrair_tinta(img, pc);

        fig = figure('Visible','off','Position',[0 0 1200 520]);
        tiledlayout(1, 3, 'TileSpacing','compact', 'Padding','compact');
        nexttile, imshow(img),      title('Original')
        nexttile, imshow(bw_grade), title('Grade detectada')
        nexttile, imshow(bw_tinta), title('Traco isolado (tinta)')
        sgtitle(sprintf('%s   px/cm=%.0f (perX=%.0f perY=%.0f)', ...
                nome, pc, pX, pY), 'Interpreter','none')

        [~, base] = fileparts(nome);
        exportgraphics(fig, fullfile(saidas, [base '.png']), 'Resolution', 110);
        close(fig)
        fprintf('[%2d/%2d] %s ok\n', i, n, nome);
    end
    fprintf('\nPaineis salvos em %s\n', saidas);
end
