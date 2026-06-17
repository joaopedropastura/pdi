function px_por_cm = calibrar_grid(img, saida)

if nargin < 2, saida = ''; end

pMin = 60;
pMax = 180;

dark = 255 - double(img); % Inverte as cores da imagem
lesao.salvar(uint8(dark), saida, '02_dark.png');
perX = periodo_dominante(mean(dark, 1),  pMin, pMax);   % linhas verticais
perY = periodo_dominante(mean(dark, 2)', pMin, pMax);   % linhas horizontais

px_por_cm = sqrt(perX * perY);   % escala linear (px_por_cm^2 == perX*perY)

end

function p = periodo_dominante(sig, pMin, pMax)

sig = double(sig(:));
sig = sig - mean(sig);
N   = numel(sig);
w   = hann(N);                  % janela de Hann
ac  = xcorr(sig .* w);          % autocorrelacao linear
ac  = ac(N:end);                % mantem apenas positivos
lags   = max(2,round(pMin)):min(N-1,round(pMax));
[~, i] = max(ac(lags + 1));
p = lags(i);

end
