clc; clear; close all;

nomes = ["1_c1_nn","4_c2_nn","6a_c3_nn","9_c4_nn","12_3_nn"];

for i = 1:numel(nomes)
    img  = imread(fullfile("imagens", nomes(i)+".jpg"));
    [ferida, contorno] = extrai_ferida(img);

    % overlay: contorno detectado em vermelho sobre o original
    ov = img;
    borda = imdilate(bwperim(ferida), strel('disk',2));
    R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
    R(borda)=255; G(borda)=0; B(borda)=0;
    ov = cat(3,R,G,B);

    % painel: original | so o contorno (preto no branco) | overlay
    soc = repmat(uint8(~contorno)*255,1,1,3);
    imwrite(cat(2, img, soc, ov), "val_"+nomes(i)+".png");
    fprintf("%s ok\n", nomes(i));
end
disp("fim");

function [ferida, contorno] = extrai_ferida(img)
    gray = rgb2gray(img);
    ink  = ~imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');
    [h,w] = size(ink);

    % deskew
    ang = -5:0.25:5; sc = zeros(size(ang));
    for k = 1:numel(ang)
        r = imrotate(ink, ang(k), 'nearest', 'crop');
        sc(k) = var(sum(r,1)) + var(sum(r,2)');
    end
    [~,kb] = max(sc); a = ang(kb);

    R = imrotate(ink, a, 'nearest', 'crop');

    % remove grade (linhas longas h/v)
    Lx = round(0.20*w);  Ly = round(0.20*h);
    gridM = imopen(R, strel('line', Ly, 90)) | imopen(R, strel('line', Lx, 0));
    gridM = imdilate(gridM, strel('square', 3));
    clean = R & ~gridM;
    clean = imclearborder(clean);              % remove quadro/linhas que chegam na borda (preserva oval central)

    % fecha o laco em VARIOS raios e une os componentes com "cara de ferida":
    % raio pequeno pega ferida pequena (antes de grudar nos tracejados),
    % raio maior re-sela ferida grande cortada pelos eixos.
    fer = false(size(R));
    for rclose = [4 8 12]
        filled = imfill(imclose(clean, strel('disk', rclose)), 'holes');
        filled = bwareaopen(filled, 2000);
        st = regionprops(filled, 'Area','Solidity','Eccentricity','PixelIdxList');
        if isempty(st), continue; end
        amax = max([st.Area]);
        for j = 1:numel(st)
            if st(j).Area >= 0.15*amax && st(j).Solidity >= 0.6 && st(j).Eccentricity <= 0.95
                fer(st(j).PixelIdxList) = true;
            end
        end
    end
    fer = imfill(fer, 'holes');
    fer = bwareaopen(fer, 2000);

    % volta rotacao
    ferida   = imrotate(fer, -a, 'nearest', 'crop');
    contorno = imdilate(bwperim(ferida), strel('disk',2));
end
