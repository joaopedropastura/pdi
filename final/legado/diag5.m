clc; clear; close all;
img  = imread(fullfile("imagens","4_c2_nn.jpg"));
gray = rgb2gray(img);
ink  = ~imbinarize(gray,'adaptive','ForegroundPolarity','dark');
[h,w] = size(ink);

ang=-5:0.25:5; sc=zeros(size(ang));
for k=1:numel(ang), r=imrotate(ink,ang(k),'nearest','crop'); sc(k)=var(sum(r,1))+var(sum(r,2)'); end
[~,kb]=max(sc); a=ang(kb);
R=imrotate(ink,a,'nearest','crop');
Lx=round(0.20*w); Ly=round(0.20*h);
gridM=imopen(R,strel('line',Ly,90))|imopen(R,strel('line',Lx,0));
gridM=imdilate(gridM,strel('square',3));
clean=R&~gridM;
closed=imclose(clean,strel('disk',8));
filled=imfill(closed,'holes');

blk=@(b) repmat(uint8(~b)*255,1,1,3);
% recorte ao redor do centro (onde esta o oval)
rr=round(h*0.42):round(h*0.66);
cc=round(w*0.30):round(w*0.70);
imwrite(cat(2, blk(ink(rr,cc)), blk(clean(rr,cc)), blk(closed(rr,cc)), blk(filled(rr,cc))), "diag5_4c2.png");
disp("ok");
