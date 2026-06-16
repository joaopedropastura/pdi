clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
gray = rgb2gray(img);
[h,w] = size(gray);

rr = round(h*0.30):round(h*0.60);
cc = round(w*0.25):round(w*0.75);
toRGB = @(b) repmat(uint8(b)*255,1,1,3);
crop = @(b) toRGB(b(rr,cc));

T = 0.45;
b0 = gray < T*255;                         % so o escuro (caneta)
b1 = imclose(b0, strel('disk',3));         % fecha pequenas falhas do traco
b2 = bwareaopen(b1, 200);                  % remove restos de grade/numeros
% maior componente conectado = contorno da ferida
cc_lbl = bwconncomp(b2);
np = cellfun(@numel, cc_lbl.PixelIdxList);
[~,imax] = max(np);
b3 = false(size(b2));
b3(cc_lbl.PixelIdxList{imax}) = true;

imwrite(cat(2, crop(b0), crop(b2), crop(b3)), "diag_pipe.png");
disp("ok");
