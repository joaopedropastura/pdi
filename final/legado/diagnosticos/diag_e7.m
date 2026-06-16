function diag_e7()
%DIAG_E7  Dumpa as metricas de TODOS os componentes (top por hull) de algumas
%   imagens representativas, p/ desenhar o filtro de ruido E7: o que separa a(s)
%   ferida(s) real(is) dos ~80 fragmentos de lixo (texto, digitos, grade, cruz).
%
%   Colunas:
%     hull  area do convex hull (cm2)
%     fill  area preenchida do laco fechado (cm2)  <- o que a E6 mede
%     traco area so do traco/tinta (cm2)
%     f/h   fill/hull  (compacidade do preenchimento)
%     f/tr  fill/traco (ALTO p/ contorno que encerra area; ~1 p/ risco solido/letra)
%     dorig distancia do centroide a origem (cm)
%
%   Uso:  matlab -batch "addpath('testes'); diag_e7"

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    % representativos: media/grande, pequena na cruz, 2 feridas, aberta, 3 feridas, minuscula
    casos = {'1_c1_nn.jpg','2_c1_nn.jpg','6a_c3_nn.jpg','7_c1_nn.jpg','5b_c1_nn.jpg','9_c4_nn.jpg'};
    gabtxt = {'1 fechada ~17','1 fechada ~1 (na cruz)','2 fechadas 21+6','1 aberta ~117', ...
              '3 fechadas 2+6+7','1 fechada ~0.1'};

    for i = 1:numel(casos)
        nome = casos{i};
        fprintf('\n[%d/%d] processando %s ...\n', i, numel(casos), nome);
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_t, bw_g]   = lesao.extrair_tinta(img, pc);
        [bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [classe, comps]= lesao.classificar_ferida(bw_l, origem, pc);

        fprintf('==== %-13s px/cm=%.0f  classe=%-7s  n_comp=%-3d  gab: %s ====\n', ...
                nome, pc, classe, numel(comps), gabtxt{i});
        fprintf('%3s %7s %7s %7s %6s %6s %7s %-7s\n', ...
                '#','hull','fill','traco','f/h','f/tr','dorig','classe');
        fprintf('%s\n', repmat('-',1,62));
        m = min(15, numel(comps));
        for k = 1:m
            c = comps(k);
            fprintf('%3d %7.2f %7.2f %7.3f %6.2f %6.1f %7.1f %-7s\n', k, ...
                c.hull_cm2, c.fill_cm2, c.area_traco_cm2, c.razao_fill, ...
                c.fill_cm2/max(c.area_traco_cm2,eps), c.dist_origem_cm, c.classe);
        end
        fprintf('   soma fill de TODOS os %d comps = %.1f cm2\n', ...
                numel(comps), sum([comps.fill_cm2]));
    end
    fprintf('\nfim diag_e7\n');
end
