raiz  = fileparts(mfilename('fullpath'));
addpath(raiz);
pasta = fullfile(raiz, 'imagens');

nome = '6a_c3_nn.jpg';
% nome = '10_c1_nn.jpg';
% nome = '9_c3_nn.jpg';
% nome = '3_c1_nn.jpg';

[~, base] = fileparts(nome);
saida = fullfile(raiz, 'passos', base);
if ~exist(saida, 'dir'), mkdir(saida); end

img  = imread(fullfile(pasta, nome));
gray = rgb2gray(img);
lesao.salvar(img,  saida, '00_original.jpg');
lesao.salvar(gray, saida, '01_cinza.png');

pc             = lesao.calibrar_grid(gray, saida);
[bw_t, bw_g]   = lesao.extrair_tinta(gray, pc, saida);
[bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc, saida);
[~, comps]     = lesao.classificar_ferida(bw_l, origem, pc, saida);
feridas        = lesao.selecionar_feridas(comps, size(bw_l), pc, saida);

over = img;
for k = 1:numel(feridas)
    over = sobrepor(over, feridas(k).mask, [255 0 0], 0.45);
end
lesao.salvar(over, saida, '28_feridas_overlay.jpg');

if isempty(feridas)
    fprintf('(nenhuma ferida detectada)\n');
else
    for k = 1:numel(feridas)
        fprintf('ferida %d: %.1f cm2\n', k, feridas(k).area_cm2);
    end
end

function out = sobrepor(img, mask, cor, alpha)

out = img;
b   = bwperim(mask);
for ch = 1:3
    plano = out(:,:,ch);
    plano(mask) = uint8((1-alpha)*double(plano(mask)) + alpha*cor(ch));
    plano(b)    = cor(ch);
    out(:,:,ch) = plano;
end

end
