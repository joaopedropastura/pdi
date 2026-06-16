clc; clear; close all;

img  = imread(fullfile("imagens", "1_c1_nn.jpg"));
gray = rgb2gray(img);
ink  = ~imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');  % traco = true
[h,w] = size(ink);
fprintf("mean(ink)=%.3f\n", mean(ink(:)));

% deskew
ang = -5:0.25:5; score = zeros(size(ang));
for k = 1:numel(ang)
    r = imrotate(ink, ang(k), 'nearest', 'crop');
    score(k) = var(sum(r,1)) + var(sum(r,2)');
end
[~,kb] = max(score); a = ang(kb);

R = imrotate(ink, a, 'nearest', 'crop');
Lx = round(0.20*w);  Ly = round(0.20*h);
gridM = imopen(R, strel('line', Ly, 90)) | imopen(R, strel('line', Lx, 0));
gridM = imdilate(gridM, strel('square', 3));
clean = R & ~gridM;
clean = imclose(clean, strel('disk', 6));     % reconecta arcos do contorno cortados pela grade
clean = bwareaopen(clean, 600);
clean = imclearborder(clean);
clean = imrotate(clean, -a, 'nearest', 'crop');

lab = bwconncomp(clean);
np  = sort(cellfun(@numel, lab.PixelIdxList), 'descend');
fprintf("deskew=%.2f  n_comp=%d  top5: ", a, lab.NumObjects);
fprintf("%d ", np(1:min(5,end))); fprintf("\n");

[~,imax] = max(cellfun(@numel, lab.PixelIdxList));
maior = false(size(clean)); maior(lab.PixelIdxList{imax}) = true;

ov = img;
Rc=ov(:,:,1); Gc=ov(:,:,2); Bc=ov(:,:,3);
Rc(maior)=255; Gc(maior)=0; Bc(maior)=0;
imwrite(cat(3,Rc,Gc,Bc), "diag4_overlay.png");
disp("ok");
