function t3_origem()
%T3_ORIGEM  Roda E1+E2+E3 em todas as imagens e salva um painel por imagem
%   (original + ROI + origem | tinta E2 | tinta limpa E3) p/ validar a E3.
%
%   Uso (headless):  matlab -batch "addpath('testes'); t3_origem"
%   ou, da pasta testes:  matlab -batch "t3_origem"
%
%   Conferir: a origem (+ vermelho) caiu na cruz central? A ROI (caixa amarela)
%   cobre o plano sem cortar a ferida? Os eixos/retos sumiram na 3a imagem SEM
%   comer o traco da ferida? Casos criticos: 2_c1, 4_c1, 12_c2 (ferida sobre a
%   cruz) e 6b_c2 (ferida que foge do plano).
%   Saidas em saidas/origem/<base>.png

    raiz   = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta  = fullfile(raiz, 'Imagens_GridLesoes_noname');
    saidas = fullfile(raiz, 'saidas', 'origem');
    if ~exist(saidas, 'dir'); mkdir(saidas); end

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    for i = 1:n
        nome = files(i).name;
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_tinta, bw_grade]          = lesao.extrair_tinta(img, pc);
        [bw_limpa, origem, ~, info]   = lesao.achar_origem_roi(bw_tinta, bw_grade, pc);

        fig = figure('Visible','off','Position',[0 0 1200 520]);
        tiledlayout(1, 3, 'TileSpacing','compact', 'Padding','compact');

        nexttile; imshow(img); hold on;
        rectangle('Position', info.roi_box, 'EdgeColor','y', 'LineWidth',1.5);
        plot(origem(1), origem(2), 'r+', 'MarkerSize',20, 'LineWidth',2);
        title('Original + ROI + origem')

        nexttile; imshow(bw_tinta); title('Tinta (E2)')

        nexttile; imshow(bw_limpa); hold on;
        plot(origem(1), origem(2), 'r+', 'MarkerSize',20, 'LineWidth',2);
        title('Limpa: sem retos + ROI (E3)')

        sgtitle(sprintf('%s   origem=(%.0f,%.0f)   px/cm=%.0f', ...
                nome, origem(1), origem(2), pc), 'Interpreter','none')

        [~, base] = fileparts(nome);
        exportgraphics(fig, fullfile(saidas, [base '.png']), 'Resolution', 110);
        close(fig)
        fprintf('[%2d/%2d] %-16s origem=(%.0f,%.0f)\n', i, n, nome, origem(1), origem(2));
    end
    fprintf('\nPaineis salvos em %s\n', saidas);
end
