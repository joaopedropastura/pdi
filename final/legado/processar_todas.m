clc; clear; close all;

pasta_in  = "imagens";
pasta_out = "comparacao";
if ~exist(pasta_out, "dir"), mkdir(pasta_out); end

arqs = dir(fullfile(pasta_in, "*.jpg"));
sem_ferida = strings(0,1);

for i = 1:numel(arqs)
    nome = arqs(i).name;
    img  = imread(fullfile(pasta_in, nome));

    [ferida, contorno, area_px] = extrai_ferida(img);

    if area_px == 0
        sem_ferida(end+1,1) = nome;   %#ok<SAGROW>
    end

    % overlay: contorno detectado em vermelho sobre o original
    ov = img;
    Rc=ov(:,:,1); Gc=ov(:,:,2); Bc=ov(:,:,3);
    Rc(contorno)=255; Gc(contorno)=0; Bc(contorno)=0;
    ov = cat(3,Rc,Gc,Bc);

    soc = repmat(uint8(~contorno)*255, 1, 1, 3);   % so o contorno, preto no branco
    imwrite(cat(2, img, soc, ov), fullfile(pasta_out, nome));
    fprintf("%2d/%d  %-14s area=%d\n", i, numel(arqs), nome, area_px);
end

fprintf("\n=== %d imagens sem ferida detectada (revisar manualmente) ===\n", numel(sem_ferida));
for k = 1:numel(sem_ferida)
    fprintf("   %s\n", sem_ferida(k));
end

% ---------------------------------------------------------------------------
function [ferida, contorno, area_px] = extrai_ferida(img)
    gray = rgb2gray(img);
    ink  = ~imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');  % traco = true
    [h,w] = size(ink);

    % 1) deskew: angulo que melhor alinha a grade aos eixos
    ang = -5:0.25:5; sc = zeros(size(ang));
    for k = 1:numel(ang)
        r = imrotate(ink, ang(k), 'nearest', 'crop');
        sc(k) = var(sum(r,1)) + var(sum(r,2)');
    end
    [~,kb] = max(sc); a = ang(kb);
    R = imrotate(ink, a, 'nearest', 'crop');

    % 2) remove grade: linhas RETAS LONGAS horizontais e verticais
    Lx = round(0.20*w);  Ly = round(0.20*h);
    gridM = imopen(R, strel('line', Ly, 90)) | imopen(R, strel('line', Lx, 0));
    gridM = imdilate(gridM, strel('square', 3));
    clean = R & ~gridM;
    clean = imclearborder(clean);              % quadro da pagina + linhas que vao a borda

    % 3) isola ferida(s): fecha o laco em varios raios e une o que tem cara de ferida
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
    fer = bwareaopen(imfill(fer, 'holes'), 2000);

    % 4) volta rotacao
    ferida   = imrotate(fer, -a, 'nearest', 'crop');
    contorno = imdilate(bwperim(ferida), strel('disk', 2));
    area_px  = nnz(ferida);
end
