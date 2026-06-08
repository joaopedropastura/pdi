%% medir_area.m
% Driver interativo: mede a área de UMA imagem e mostra as figuras de diagnóstico.
% O algoritmo em si vive em medir_area_fn.m (fonte única, também usada nos testes).

clear; close all; clc;

script_dir = fileparts(mfilename('fullpath'));
IMAGEM = fullfile(script_dir, 'images', '7_c3_nn.jpg');

R = medir_area_fn(IMAGEM, true);   % true = mostra figuras

fprintf('\n=== %s ===\n', IMAGEM);
fprintf('Calibração:        %.1f px/cm  (%d linhas de grade)\n', R.pixels_por_cm, R.n_linhas);
fprintf('Área (preenchida): %.2f cm²\n', R.area_cm2);
fprintf('Área (convex hull):%.2f cm²  (limite superior)\n', R.area_hull);
fprintf('Solidez:           %.2f\n', R.solidez);
fprintf('Status:            %s\n', R.msg);
