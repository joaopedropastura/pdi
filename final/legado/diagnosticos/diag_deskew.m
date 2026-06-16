function diag_deskew()
%DIAG_DESKEW  Testa se alinhar a grade (deskew) antes de remover reduz o residuo
%   de grade com L=1.5. Mede area total de tinta (cm2) e nº de componentes
%   (proxy de residuo: quanto menor, mais limpo). Imprime tb o angulo detectado.
%
%   Uso:  matlab -batch "addpath('testes'); diag_deskew"

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    casos = {'10_c1_nn.jpg','2_c1_nn.jpg','9_c4_nn.jpg','6b_c4_nn.jpg', ...
             '5b_c2_nn.jpg','1_c1_nn.jpg'};

    fprintf('%-14s %5s | %12s | %12s | %12s\n', 'arquivo','ang', ...
            'L0.6 sem(ar/n)','L1.5 sem(ar/n)','L1.5 desk(ar/n)');
    fprintf('%s\n', repmat('-',1,66));
    for i = 1:numel(casos)
        nome = casos{i};
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        if size(img,3)==3, gray = rgb2gray(img); else, gray = img; end

        ang = acha_angulo(gray);
        gray_d = imrotate(gray, ang, 'bilinear', 'crop');

        [a1,n1] = residuo(gray,   pc, 0.6);
        [a2,n2] = residuo(gray,   pc, 1.5);
        [a3,n3] = residuo(gray_d, pc, 1.5);

        fprintf('%-14s %5.1f | %7.1f /%4d | %7.1f /%4d | %7.1f /%4d\n', ...
                nome, ang, a1,n1, a2,n2, a3,n3);
    end
end

function ang = acha_angulo(gray)
%ACHA_ANGULO  Angulo que melhor alinha a grade aos eixos (max variancia das
%   projecoes). A grade domina a tinta, entao a projecao "pulsa" quando alinhada.
    bw = ~imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');
    bw = imresize(bw, 0.25);                 % rapido; angulo nao precisa de full-res
    angs = -5:0.25:5; sc = zeros(size(angs));
    for k = 1:numel(angs)
        r = imrotate(bw, angs(k), 'nearest', 'crop');
        sc(k) = var(sum(r,1)) + var(sum(r,2)');
    end
    [~, kb] = max(sc); ang = angs(kb);
end

function [area_cm2, ncomp] = residuo(gray, pc, len_cm)
    raio_bh = max(10, round(0.30*pc));
    bw = imbinarize(imbothat(gray, strel('disk', raio_bh)), ...
                    graythresh(imbothat(gray, strel('disk', raio_bh))));
    L = round(len_cm*pc);
    rem = imopen(bw, strel('line', L, 0)) | imopen(bw, strel('line', L, 90));
    t = bw & ~rem;
    t = imclose(t, strel('disk', max(6, round(0.06*pc))));
    t = bwareaopen(t, round(0.01*pc^2));
    area_cm2 = nnz(t)/pc^2;
    cc = bwconncomp(t); ncomp = cc.NumObjects;
end
