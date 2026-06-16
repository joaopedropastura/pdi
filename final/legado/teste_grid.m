clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
gray = rgb2gray(img);

bw = imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');

% Abordagem por ESPESSURA: grade = linhas finas, ferida = traco grosso.
% imopen com disco apaga objetos mais finos que ~2*r.
r2 = imopen(bw, strel('disk', 2));
r3 = imopen(bw, strel('disk', 3));

% Recorte central em resolucao cheia para inspecao honesta
[h,w] = size(bw);
rr = round(h*0.30):round(h*0.55);
cc = round(w*0.30):round(w*0.70);

toRGB = @(b) repmat(uint8(b) * 255, 1, 1, 3);
crop  = @(b) toRGB(b(rr,cc));
out = cat(2, crop(bw), crop(r2), crop(r3));
imwrite(out, "teste_grid_out.png");
disp("ok");
