function diag_e2()
%DIAG_E2  Varia o comprimento da linha-SE da remocao de grade e mede quanto do
%   contorno da ferida sobrevive. Proxy: area PREENCHIDA (cm2) do maior
%   componente apos closing de 0.2cm + imfill (p/ ferida que sela ~ area real).
%   Grade nao removida -> estoura p/ ~400 (malha inteira). Sem figuras.
%
%   Uso:  matlab -batch "addpath('testes'); diag_e2"

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    casos = {'6b_c4_nn.jpg','6b_c1_nn.jpg','6b_c3_nn.jpg','7_c1_nn.jpg','7_c2_nn.jpg', ...
             '3_c1_nn.jpg','3_c2_nn.jpg','1_c1_nn.jpg','6a_c3_nn.jpg','9_c4_nn.jpg','2_c1_nn.jpg'};
    gab   = [100 58 87 117 88 16 18 17 27 0.1 1];
    lens  = [0.6 1.0 1.5 2.0 3.0];

    fprintf('%-14s %6s |', 'arquivo','gab');
    for L = lens, fprintf(' L=%3.1f', L); end
    fprintf('\n%s\n', repmat('-', 1, 16+9+6*numel(lens)));
    for i = 1:numel(casos)
        nome = casos{i};
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        fprintf('%-14s %6.1f |', nome, gab(i));
        for L = lens
            fprintf(' %6.1f', area_maior(extrai_len(img, pc, L), pc));
        end
        fprintf('\n');
    end
end

function A = area_maior(bw, pc)
    bw = imclose(bw, strel('disk', max(2, round(0.2*pc))));
    f  = imfill(bw, 'holes');
    cc = bwconncomp(f);
    if cc.NumObjects == 0, A = 0; return; end
    A = max(cellfun(@numel, cc.PixelIdxList)) / pc^2;
end

function bw_tinta = extrai_len(img, pc, len_cm)
    if size(img,3) == 3, gray = rgb2gray(img); else, gray = img; end
    raio_bh = max(10, round(0.30 * pc));
    bw = imbinarize(imbothat(gray, strel('disk', raio_bh)), graythresh(imbothat(gray, strel('disk', raio_bh))));
    L = round(len_cm * pc);
    grade = imopen(bw, strel('line', L, 0)) | imopen(bw, strel('line', L, 90));
    bw_tinta = bw & ~grade;
    bw_tinta = imclose(bw_tinta, strel('disk', max(6, round(0.06*pc))));
    bw_tinta = bwareaopen(bw_tinta, round(0.01*pc^2));
end
