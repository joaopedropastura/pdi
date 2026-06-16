clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
img  = im2double(img);
R = img(:,:,1); G = img(:,:,2); B = img(:,:,3);
gray = rgb2gray(img);
hsv  = rgb2hsv(img);
S = hsv(:,:,2);  V = hsv(:,:,3);
[h,w] = size(gray);

rr = round(h*0.30):round(h*0.60);
cc = round(w*0.25):round(w*0.75);
toRGB = @(b) repmat(uint8(b)*255,1,1,3);
crop = @(b) toRGB(b(rr,cc));

% Grade azul = R menor que B (linha absorve vermelho). Caneta preta: R~=B.
% "azulado" = B - R alto.  Caneta = escuro E neutro.
azul   = (B - R) > 0.06;                  % pixels cromaticos (grade)
escuro = gray < 0.55;                      % candidatos escuros
pen    = escuro & ~azul;                    % escuro e NAO azul = caneta

imwrite(cat(2, crop(escuro), crop(azul), crop(pen)), "diag2_out.png");
disp("ok");
