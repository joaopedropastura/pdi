function [px_por_cm, perX, perY] = calibrar_grid(img, pMin, pMax)
%CALIBRAR_GRID  Estima a escala (pixels por cm) a partir do grid do fundo.
%   [PX_POR_CM, PERX, PERY] = CALIBRAR_GRID(IMG) acha o periodo dominante das
%   linhas do grid em X e Y por autocorrelacao (cada quadrado = 1 cm).
%
%   Saidas:
%     px_por_cm  escala LINEAR = sqrt(perX*perY)  -> use ^2 p/ area (1 cm^2 = px_por_cm^2)
%     perX       periodo do grid em x (px por cm na horizontal)
%     perY       periodo do grid em y (px por cm na vertical)
%
%   IMG pode ser RGB ou escala de cinza. PMIN/PMAX limitam a busca do periodo
%   (em px) para evitar harmonicos; padrao 60..180.

    if nargin < 2 || isempty(pMin), pMin = 60;  end
    if nargin < 3 || isempty(pMax), pMax = 180; end

    if size(img,3) == 3, gray = rgb2gray(img); else, gray = img; end

    % O grid e mais ESCURO que o papel; projetar a "escuridao" em cada eixo
    % revela um sinal periodico cujo periodo e o espacamento do grid.
    dark = 255 - double(gray);
    perX = periodo_dominante(mean(dark, 1),  pMin, pMax);   % linhas verticais
    perY = periodo_dominante(mean(dark, 2)', pMin, pMax);   % linhas horizontais

    px_por_cm = sqrt(perX * perY);   % escala linear (px_por_cm^2 == perX*perY)
end

function p = periodo_dominante(sig, pMin, pMax)
%PERIODO_DOMINANTE  Periodo (em amostras) de um sinal periodico via
%   autocorrelacao (1o pico forte = fundamental, robusto a harmonicos).
%   Janela de Hann implementada na mao (sem Signal Processing Toolbox).
    sig = double(sig(:));
    sig = sig - mean(sig);
    N   = numel(sig);
    w   = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));   % janela de Hann
    F   = fft(sig .* w, 2*N);
    ac  = real(ifft(abs(F).^2));                % autocorrelacao linear
    ac  = ac(1:N);
    lags   = max(2,round(pMin)):min(N-1,round(pMax));
    [~, i] = max(ac(lags + 1));
    p = lags(i);
end
