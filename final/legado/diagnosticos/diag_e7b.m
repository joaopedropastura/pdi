function diag_e7b()
%DIAG_E7B  Dump rico de componentes (apos a E2 atual com L=1.5) p/ achar o
%   separador entre ferida real e residuo de grade. Alem de hull/fill/dorig,
%   mede forma do laco preenchido: extent (fill/bbox), solidez, e dimensoes do
%   bbox em cm (residuo de grade tende a bbox ~Ncm inteiro e/ou extent alto).
%
%   Uso:  matlab -batch "addpath('testes'); diag_e7b"

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    casos  = {'10_c1_nn.jpg','2_c1_nn.jpg','5b_c2_nn.jpg','6a_c3_nn.jpg','9_c4_nn.jpg'};
    gabtxt = {'1 fech ~8.5','1 fech ~1','3 fech 2+6+7','2 fech 21+6','1 fech ~0.1'};

    for i = 1:numel(casos)
        nome = casos{i};
        fprintf('\n[%d/%d] %s ...\n', i, numel(casos), nome);
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_t, bw_g]   = lesao.extrair_tinta(img, pc);
        [bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [~, comps]     = lesao.classificar_ferida(bw_l, origem, pc);

        fprintf('==== %-13s  n=%-3d  gab: %s ====\n', nome, numel(comps), gabtxt{i});
        fprintf('%3s %6s %6s %5s %6s %5s %5s %5s %5s\n', ...
                '#','hull','fill','f/tr','dorig','ext','sol','wcm','hcm');
        fprintf('%s\n', repmat('-',1,54));
        m = min(12, numel(comps));
        for k = 1:m
            c = comps(k);
            ftr = c.fill_cm2 / max(c.area_traco_cm2, eps);
            rp = regionprops(c.mask_fechada, 'Area','BoundingBox','Extent','Solidity');
            if isempty(rp), continue; end
            [~,b] = max([rp.Area]); rp = rp(b);
            wcm = rp.BoundingBox(3)/pc; hcm = rp.BoundingBox(4)/pc;
            fprintf('%3d %6.2f %6.2f %5.1f %6.1f %5.2f %5.2f %5.1f %5.1f\n', ...
                k, c.hull_cm2, c.fill_cm2, ftr, c.dist_origem_cm, ...
                rp.Extent, rp.Solidity, wcm, hcm);
        end
    end
    fprintf('\nfim diag_e7b\n');
end
