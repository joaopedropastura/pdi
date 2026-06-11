% Thiago dos Santos Marcelino
% Trabalho final - teste do pipeline de segmentacao de ferida e medida de area

clear; clc; close all;

%% Parametros

arquivo = 'Imagens_GridLesoes_noname/1_c1_nn.jpg';    % imagem de teste
% arquivo = 'Imagens_GridLesoes_noname/5a_c1_nn.jpg'; % 2 feridas + texto
% arquivo = 'Imagens_GridLesoes_noname/2_c1_nn.jpg';  % ferida pequena sobre a cruz

thTraco   = 140;   % limiar (0-255): pixels mais escuros que isso = traco escuro
pMin      = 60;    % periodo minimo do grid em pixels
pMax      = 180;   % periodo maximo do grid em pixels (evita harmonico)

%% 1. Carregar imagem

img  = imread(arquivo);
gray = rgb2gray(img);

R = double(img(:,:,1));
G = double(img(:,:,2));
B = double(img(:,:,3));

%% 2. Escala: periodo do grid pela "escuridao" (grid e mais escuro que o papel)

dark  = 255 - double(gray);
projX = mean(dark, 1);   % perfil ao longo de x -> periodo das linhas verticais
projY = mean(dark, 2)';  % perfil ao longo de y -> periodo das linhas horizontais

perX = periodo_dominante(projX, pMin, pMax);
perY = periodo_dominante(projY, pMin, pMax);

pxPorCm2 = perX * perY;   % pixels que equivalem a 1 cm^2

%% 3. Mascara dos tracos escuros (caneta) e limpeza

bw0 = gray < thTraco;                      % tudo escuro: caneta + grid + texto

% O contorno da caneta e GROSSO (~10 px); as linhas do grid sao FINAS (~2-3 px).
% Uma abertura por disco apaga as linhas finas e preserva o traco grosso.
bwInk = imopen(bw0, strel('disk', 3));
bwInk = imclearborder(bwInk);              % remove bordas/furos/texto de margem
bwInk = bwareaopen(bwInk, round(0.03*pxPorCm2)); % remove residuos pequenos

% Remove a cruz de referencia central: segmentos retos numa ROI central.
% Os bracos da cruz sao retos (~0.5 cm); o contorno da ferida e curvo.
[Hh, Ww] = size(gray);
win = round(2.0 * max(perX, perY));
roi = false(Hh, Ww);
roi(max(1,round(Hh/2)-win):min(Hh,round(Hh/2)+win), ...
    max(1,round(Ww/2)-win):min(Ww,round(Ww/2)+win)) = true;
Lc   = round(0.4 * max(perX, perY));
reto = imopen(bwInk, strel('line', Lc, 0)) | imopen(bwInk, strel('line', Lc, 90));
bwInk(roi & reto) = false;

% Fecha o contorno (mesmo aberto) e preenche: dilata -> preenche -> erode.
% Garante o preenchimento de lacos com aberturas que o imclose nao fecha.
R       = round(0.30 * max(perX, perY));   % raio p/ pontear a abertura do traco
bwFech  = imdilate(bwInk, strel('disk', R));
bwFech  = imfill(bwFech, 'holes');
bwFech  = imerode(bwFech, strel('disk', R));

%% 4. Identificar feridas: blobs preenchidos grandes, convexos e "ocos"

% Para cada blob fechado, compara sua area com a tinta original dentro dele:
% laco fechado (ferida) -> muita area preenchida vs. pouca tinta (ratio alto);
% texto/seta/cruz preenchem pouco -> ratio ~1.
[Lf, nLf] = bwlabel(bwFech, 8);
props = regionprops(Lf, 'Area', 'Solidity', 'Centroid', ...
                        'BoundingBox', 'PixelIdxList');

areaMin  = 1.0 * pxPorCm2;                  % ferida tem ao menos ~1.0 cm^2
fillRMin = 2.5;                             % area preenchida / tinta original
solMin   = 0.30;                            % descarta linhas/textos alongados

ratio   = zeros(1, nLf);
ehFer   = false(1, nLf);
for k = 1:nLf
    tinta    = nnz(bwInk(props(k).PixelIdxList));
    ratio(k) = props(k).Area / max(tinta, 1);
    ehFer(k) = props(k).Area > areaMin & ratio(k) > fillRMin & ...
               props(k).Solidity > solMin;
end

% --- diagnostico: lista todas as regioes ---
fprintf('--- regioes (Area | cm2 | ratio | Solidity | ferida?) ---\n');
for k = 1:nLf
    fprintf('  %2d: %8d | %6.2f | %5.1f | %.2f | %d\n', k, ...
        props(k).Area, props(k).Area/pxPorCm2, ratio(k), ...
        props(k).Solidity, ehFer(k));
end

feridas = props(ehFer);
nFer    = numel(feridas);

%% 5. Mascara preenchida das feridas + areas em cm^2

maskFill = false(size(bwFech));
for i = 1:nFer
    maskFill(feridas(i).PixelIdxList) = true;
end

areasCm2 = zeros(1, nFer);
for i = 1:nFer
    areasCm2(i) = feridas(i).Area / pxPorCm2;
end

%% 6. Overlay: contorno + area anotada

perim = bwperim(maskFill, 8);
over  = img;
oR = over(:,:,1); oG = over(:,:,2); oB = over(:,:,3);
oR(perim) = 255; oG(perim) = 0; oB(perim) = 0;   % contorno vermelho
over = cat(3, oR, oG, oB);

fprintf('Arquivo: %s\n', arquivo);
fprintf('Periodo grid: perX=%.1f px  perY=%.1f px  (1 cm^2 = %.0f px)\n', ...
        perX, perY, pxPorCm2);
fprintf('Feridas detectadas: %d\n', nFer);
for i = 1:nFer
    fprintf('  Ferida %d: %.2f cm^2\n', i, areasCm2(i));
end

%% 7. Figura de etapas

fig = figure('Name', 'Teste grid', 'Visible', 'off', ...
             'Units', 'normalized', 'Position', [0 0 1 1]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact')

nexttile, imshow(img),       title('Original')
nexttile, imshow(bwInk),     title('Tinta (grid removido)')
nexttile, imshow(bwFech),    title('Contorno fechado/preenchido')
nexttile, imshow(maskFill),  title('Feridas selecionadas')
nexttile
plot(projX), hold on, plot(projY), grid on
title(sprintf('Projecoes grid (perX=%.0f perY=%.0f)', perX, perY))
legend('projX', 'projY')
nexttile, imshow(over), title('Contorno + area')
for i = 1:nFer
    c = feridas(i).Centroid;
    text(c(1), c(2), sprintf('%.1f cm^2', areasCm2(i)), ...
        'Color', 'yellow', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center')
end

sgtitle(sprintf('%s  -  %d ferida(s)', arquivo, nFer), 'Interpreter', 'none')

exportgraphics(fig, 'teste_grid_saida.png', 'Resolution', 120)

%% 8. Recorte ampliado da 1a ferida p/ conferir o contorno

if nFer >= 1
    bb = feridas(1).BoundingBox;        % [x y w h]
    m  = 40;                            % margem
    x1 = max(1, floor(bb(1))-m); y1 = max(1, floor(bb(2))-m);
    x2 = min(size(img,2), ceil(bb(1)+bb(3))+m);
    y2 = min(size(img,1), ceil(bb(2)+bb(4))+m);
    fprintf('Ferida 1 bbox = [%.0f %.0f %.0f %.0f]\n', bb);
    figc = figure('Visible','off');
    imshow(over(y1:y2, x1:x2, :))
    title(sprintf('Ferida 1: %.2f cm^2  (perX=%.0f perY=%.0f)', ...
        areasCm2(1), perX, perY))
    exportgraphics(figc, 'teste_grid_crop.png', 'Resolution', 150)
end

%% --- funcao local ---

function p = periodo_dominante(sig, pMin, pMax)
% Acha o periodo dominante (em amostras) de um sinal periodico via
% autocorrelacao (1o pico forte = fundamental, robusto a harmonicos).
    sig = double(sig(:));
    sig = sig - mean(sig);
    N   = numel(sig);
    w   = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));   % janela de Hann (sem toolbox)
    x   = sig .* w;
    F   = fft(x, 2*N);
    ac  = real(ifft(abs(F).^2));                % autocorrelacao linear
    ac  = ac(1:N);

    lagMin = max(2, round(pMin));
    lagMax = min(N-1, round(pMax));
    lags   = lagMin:lagMax;
    [~, i] = max(ac(lags + 1));
    p = lags(i);
end
