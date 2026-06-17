function [bw_limpa, origem] = achar_origem_roi(bw_tinta, bw_grade, ppc, saida)

if nargin < 4, saida = ''; end

[H, W] = size(bw_tinta);

L = round(0.6 * ppc);
grade_h = imopen(bw_grade, strel('line', L, 0));
grade_v = imopen(bw_grade, strel('line', L, 90));
lesao.salvar(grade_h, saida, '12_grade_h_dir.png');
lesao.salvar(grade_v, saida, '13_grade_v_dir.png');

sv = sum(grade_v, 1); sh = sum(grade_h, 2);
col_tem = sv > 0.2 * max(sv);
row_tem = sh > 0.2 * max(sh);
cmin = find(col_tem, 1, 'first'); cmax = find(col_tem, 1, 'last');
rmin = find(row_tem, 1, 'first'); rmax = find(row_tem, 1, 'last');
if isempty(cmin), cmin = 1; cmax = W; end
if isempty(rmin), rmin = 1; rmax = H; end

% ROI = plano + folga de ~0.6 cm p/ fora
% tolera a ferida que ficam para fora do plano (6b_c2)
folga = round(0.6 * ppc);
r1 = max(1, rmin - folga); r2 = min(H, rmax + folga);
c1 = max(1, cmin - folga); c2 = min(W, cmax + folga);
roi = false(H, W);
roi(r1:r2, c1:c2) = true;
lesao.salvar(roi, saida, '14_roi.png');

% cruz central
esp = max(4, round(0.06 * ppc));
eixo_v = imerode(grade_v, strel('line', esp, 0));    % verticais grossas
eixo_h = imerode(grade_h, strel('line', esp, 90));   % horizontais grossas
lesao.salvar(eixo_v, saida, '15_eixo_v.png');
lesao.salvar(eixo_h, saida, '16_eixo_h.png');

cenx = (cmin + cmax) / 2;  ceny = (rmin + rmax) / 2;
ox = []; oy = [];
[rv, cv] = find(eixo_v);
if ~isempty(cv)
    ext_col = accumarray(cv, rv, [W,1], @max, 0) - accumarray(cv, rv, [W,1], @min, 0);
    [vx, ox] = max(movmean(ext_col, esp));
    if vx <= 0
        ox = [];
    end
end

[rh, ch] = find(eixo_h);
if ~isempty(rh)
    ext_row = accumarray(rh, ch, [H,1], @max, 0) - accumarray(rh, ch, [H,1], @min, 0);
    [vy, oy] = max(movmean(ext_row, esp));
    if vy <= 0
        oy = [];
    end
end

% trava de sanidade: fora de 25% do tamanho do plano -> volta ao centro
if isempty(ox) || abs(ox - cenx) > 0.25 * (cmax - cmin), ox = round(cenx); end
if isempty(oy) || abs(oy - ceny) > 0.25 * (rmax - rmin), oy = round(ceny); end
origem = [ox, oy];
if ~isempty(saida)
    lesao.salvar(marca_origem(bw_tinta, origem, roi, ppc), saida, '17_origem.png');
end

Lc    = round(0.7 * ppc);
banda = round(0.30 * ppc);
faixa = false(H, W);
faixa(:, max(1,ox-banda):min(W,ox+banda)) = true;   % faixa do eixo vertical
faixa(max(1,oy-banda):min(H,oy+banda), :) = true;   % faixa do eixo horizontal
lesao.salvar(faixa, saida, '18_faixa_eixos.png');
reto  = imopen(bw_tinta, strel('line', Lc, 0)) | imopen(bw_tinta, strel('line', Lc, 90));
lesao.salvar(reto, saida, '19_retos.png');
lesao.salvar(reto & faixa, saida, '20_cruz_remover.png');
bw_limpa = bw_tinta & ~(reto & faixa);
lesao.salvar(bw_limpa, saida, '21_sem_cruz.png');

bw_limpa = bw_limpa & roi;                                             % limita à região do plano
lesao.salvar(bw_limpa, saida, '22_restrita_roi.png');
bw_limpa = imclose(bw_limpa, strel('disk', max(3, round(0.1 * ppc)))); % reconecta feridas cortadas pelos eixos
lesao.salvar(bw_limpa, saida, '23_limpa_close.png');
bw_limpa = bwareaopen(bw_limpa, round(0.01 * ppc^2));                  % remove ruídos pequenos
lesao.salvar(bw_limpa, saida, '24_bw_limpa.png');

end

function rgb = marca_origem(bw, origem, roi, ppc)
rgb = repmat(im2uint8(bw), 1, 1, 3);
[H, W, ~] = size(rgb);
ox = round(origem(1)); oy = round(origem(2));
r  = round(1.0 * ppc);
xs = max(1,ox-r):min(W,ox+r);   ys = max(1,oy-r):min(H,oy+r);
rgb = pinta(rgb, oy, xs, [255 0 0]);
rgb = pinta(rgb, ys, ox, [255 0 0]);
b   = bwperim(roi);
R = rgb(:,:,1); G = rgb(:,:,2); B = rgb(:,:,3);
R(b) = 0; G(b) = 255; B(b) = 0;
rgb = cat(3, R, G, B);
end

function rgb = pinta(rgb, rows, cols, cor)
for ch = 1:3
    plano = rgb(:,:,ch);
    plano(rows, cols) = cor(ch);
    rgb(:,:,ch) = plano;
end
end
