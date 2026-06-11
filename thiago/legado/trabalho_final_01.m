% Thiago dos Santos Marcelino
% Trabalho final - Segmentacao dos contornos das feridas e medida das areas
% Cada quadradinho do grid = 1 cm^2. Processa todas as imagens da pasta,
% mede a area de cada ferida em cm^2 e salva overlays + tabela de resultados.

clear; clc; close all;

%% Parametros (mesmos validados em teste_grid.m)

pasta    = 'Imagens_GridLesoes_noname';
saidas   = 'saidas';                    % pasta p/ salvar os overlays
thTraco  = 140;    % limiar (0-255): pixels mais escuros = traco a caneta
pMin     = 60;     % periodo minimo do grid (px)
pMax     = 180;    % periodo maximo do grid (px) - evita harmonico (~253)
fatorR   = 0.30;   % raio de fechamento = fatorR * periodo
areaMinC = 1.0;    % area minima de uma ferida (cm^2)
fillRMin = 2.5;    % razao area_preenchida / tinta original (laco fechado)
solMin   = 0.30;   % solidez minima (descarta linhas/textos muito alongados)

if ~exist(saidas, 'dir'); mkdir(saidas); end

%% Lista de imagens

files = dir(fullfile(pasta, '*.jpg'));
n     = numel(files);

% Tabela de resultados (uma linha por ferida)
arquivo  = strings(0,1);
feridaId = [];
areaCm2  = [];
perXcol  = [];
perYcol  = [];

%% Processamento

for i = 1:n
    nome = files(i).name;
    img  = imread(fullfile(pasta, nome));

    [areas, cents, perX, perY, maskFill] = mede_feridas(img, ...
        thTraco, pMin, pMax, fatorR, areaMinC, fillRMin, solMin);

    nFer = numel(areas);
    fprintf('[%2d/%2d] %-14s  perX=%.0f perY=%.0f  feridas=%d\n', ...
        i, n, nome, perX, perY, nFer);

    % --- overlay: contorno vermelho + area anotada ---
    perim = bwperim(maskFill, 8);
    over  = img;
    oR = over(:,:,1); oG = over(:,:,2); oB = over(:,:,3);
    oR(perim) = 255; oG(perim) = 0; oB(perim) = 0;
    over = cat(3, oR, oG, oB);

    fig = figure('Visible','off');
    imshow(over)
    for k = 1:nFer
        fprintf('        ferida %d: %.2f cm^2\n', k, areas(k));
        text(cents(k,1), cents(k,2), sprintf('%.1f cm^2', areas(k)), ...
            'Color','yellow', 'FontSize',12, 'FontWeight','bold', ...
            'HorizontalAlignment','center')
        arquivo(end+1,1)  = string(nome); %#ok<SAGROW>
        feridaId(end+1,1) = k;            %#ok<SAGROW>
        areaCm2(end+1,1)  = areas(k);     %#ok<SAGROW>
        perXcol(end+1,1)  = perX;         %#ok<SAGROW>
        perYcol(end+1,1)  = perY;         %#ok<SAGROW>
    end
    title(sprintf('%s  -  %d ferida(s)', nome, nFer), 'Interpreter','none')
    [~, base] = fileparts(nome);
    exportgraphics(fig, fullfile(saidas, [base '.png']), 'Resolution', 120);
    close(fig)

    if nFer == 0   % registra imagens sem deteccao p/ revisao
        arquivo(end+1,1)  = string(nome); %#ok<SAGROW>
        feridaId(end+1,1) = 0;            %#ok<SAGROW>
        areaCm2(end+1,1)  = NaN;          %#ok<SAGROW>
        perXcol(end+1,1)  = perX;         %#ok<SAGROW>
        perYcol(end+1,1)  = perY;         %#ok<SAGROW>
    end
end

%% Salva tabela de resultados

T = table(arquivo, feridaId, areaCm2, perXcol, perYcol, ...
    'VariableNames', {'arquivo','ferida','area_cm2','perX_px','perY_px'});
writetable(T, 'resultados.csv');
fprintf('\nResultados salvos em resultados.csv e overlays na pasta "%s".\n', saidas);
disp(T)

%% ====================== funcoes locais ======================

function [areas, cents, perX, perY, maskFill] = mede_feridas(img, ...
        thTraco, pMin, pMax, fatorR, areaMinC, fillRMin, solMin)
% Segmenta as feridas desenhadas e mede suas areas em cm^2.

    gray = rgb2gray(img);

    % --- Escala: periodo do grid pela "escuridao" (grid > papel) ---
    dark  = 255 - double(gray);
    perX  = periodo_dominante(mean(dark, 1),  pMin, pMax);
    perY  = periodo_dominante(mean(dark, 2)', pMin, pMax);
    pxCm2 = perX * perY;

    % --- Tinta da caneta (traco grosso); abertura remove o grid fino ---
    bwInk = imopen(gray < thTraco, strel('disk', 3));
    bwInk = imclearborder(bwInk);
    bwInk = bwareaopen(bwInk, round(0.03 * pxCm2));

    % --- Remove a cruz de referencia central (segmentos retos numa ROI) ---
    % A cruz fica perto do centro da pagina; seus bracos sao retos (~0.5 cm),
    % ao contrario do contorno curvo da ferida.
    [Hh, Ww] = size(gray);
    win = round(2.0 * max(perX, perY));
    roi = false(Hh, Ww);
    roi(max(1,round(Hh/2)-win):min(Hh,round(Hh/2)+win), ...
        max(1,round(Ww/2)-win):min(Ww,round(Ww/2)+win)) = true;
    Lc   = round(0.4 * max(perX, perY));
    reto = imopen(bwInk, strel('line', Lc, 0)) | imopen(bwInk, strel('line', Lc, 90));
    bwInk(roi & reto) = false;

    % --- Fecha o contorno (mesmo fragmentado/aberto) e preenche ---
    % A dilatacao reconecta arcos do traco e ponteia a abertura; o preenchimento
    % marca o interior; a erosao devolve a borda externa ao tamanho original.
    R      = round(fatorR * max(perX, perY));
    se     = strel('disk', R);
    bwFech = imerode(imfill(imdilate(bwInk, se), 'holes'), se);

    % --- Seleciona feridas: blobs grandes, convexos e "ocos" ---
    [Lf, nLf] = bwlabel(bwFech, 8);
    props = regionprops(Lf, 'Area', 'Solidity', 'Centroid', 'PixelIdxList');

    areaMin  = areaMinC * pxCm2;
    maskFill = false(size(bwFech));
    areas = []; cents = [];
    for k = 1:nLf
        tinta = nnz(bwInk(props(k).PixelIdxList));
        ratio = props(k).Area / max(tinta, 1);
        if props(k).Area > areaMin && ratio > fillRMin && props(k).Solidity > solMin
            maskFill(props(k).PixelIdxList) = true;
            areas(end+1,1) = props(k).Area / pxCm2;       %#ok<AGROW>
            cents(end+1,:) = props(k).Centroid;           %#ok<AGROW>
        end
    end
end

function p = periodo_dominante(sig, pMin, pMax)
% Periodo dominante (em amostras) via autocorrelacao (robusto a harmonicos).
    sig = double(sig(:));
    sig = sig - mean(sig);
    N   = numel(sig);
    w   = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));   % janela de Hann (sem toolbox)
    F   = fft(sig .* w, 2*N);
    ac  = real(ifft(abs(F).^2));
    ac  = ac(1:N);
    lags   = max(2,round(pMin)):min(N-1,round(pMax));
    [~, i] = max(ac(lags + 1));
    p = lags(i);
end
