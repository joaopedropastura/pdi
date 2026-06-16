clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
gray = rgb2gray(img);
ink  = ~imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');  % traco = true
[h,w] = size(ink);

% deskew: angulo que mais "alinha" as linhas da grade
ang = -5:0.25:5; score = zeros(size(ang));
for k = 1:numel(ang)
    r = imrotate(ink, ang(k), 'nearest', 'crop');
    score(k) = var(sum(r,1)) + var(sum(r,2)');
end
[~,kb] = max(score); a = ang(kb);

R = imrotate(ink, a, 'nearest', 'crop');

% grade = linhas longas horizontais e verticais
Lx = round(0.20*w);  Ly = round(0.20*h);
gridM = imopen(R, strel('line', Ly, 90)) | imopen(R, strel('line', Lx, 0));
gridM = imdilate(gridM, strel('square', 3));

clean = R & ~gridM;
clean = imclose(clean, strel('disk', 4));   % suaviza micro-cortes p/ visual
clean = bwareaopen(clean, 400);             % tira tracejados/pontos
clean = imrotate(clean, -a, 'nearest', 'crop');

% visual: traco PRETO em fundo BRANCO (como a comparacao original)
blk = @(b) repmat(uint8(~b)*255, 1, 1, 3);

% recorte central FULL-RES p/ avaliar honestamente (sem reduzir a imagem)
rr = round(h*0.28):round(h*0.64);
cc = round(w*0.20):round(w*0.80);
imwrite(cat(2, blk(ink(rr,cc)), blk(clean(rr,cc))), "remove_grid_crop.png");
disp("ok");
