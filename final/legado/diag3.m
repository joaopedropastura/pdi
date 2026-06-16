clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
gray = rgb2gray(img);
bw   = imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');
[h,w] = size(bw);

% 1) Estima rotacao: angulo que torna as colunas mais "picadas" (grade vertical alinhada)
ang = -5:0.25:5;
score = zeros(size(ang));
for k = 1:numel(ang)
    r = imrotate(bw, ang(k), 'nearest', 'crop');
    score(k) = var(sum(r,1)) + var(sum(r,2)');
end
[~,kb] = max(score);
a = ang(kb);
fprintf("deskew = %.2f deg\n", a);

R = imrotate(bw, a, 'nearest', 'crop');

% 2) Detecta grade: linhas longas horizontais e verticais (ja alinhadas)
Lx = round(0.20*w);  Ly = round(0.20*h);
gridM = imopen(R, strel('line', Ly, 90)) | imopen(R, strel('line', Lx, 0));
gridM = imdilate(gridM, strel('square', 5));

clean = R & ~gridM;
clean = imclose(clean, strel('disk', 3));        % repara cortes no contorno
clean = bwareaopen(clean, 600);                   % tira tracejados/restos pequenos

% 3) Maior componente conectado = contorno fechado da ferida
lab = bwconncomp(clean);
np  = cellfun(@numel, lab.PixelIdxList);
[~,imax] = max(np);
contorno = false(size(clean));
contorno(lab.PixelIdxList{imax}) = true;

% 4) Preenche para obter a regiao da ferida
ferida = imfill(contorno, 'holes');

% 5) Volta a rotacao original
contorno = imrotate(contorno, -a, 'nearest', 'crop');
ferida   = imrotate(ferida,   -a, 'nearest', 'crop');

toRGB = @(b) repmat(uint8(b)*255,1,1,3);
imwrite(toRGB(contorno), "diag3_contorno.png");
imwrite(toRGB(ferida),   "diag3_ferida.png");
disp("ok");
