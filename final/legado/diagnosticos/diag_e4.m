function diag_e4()
%DIAG_E4  Diagnostico p/ calibrar E4: roda E1-E3 nos casos criticos e, para o
%   componente de maior hull, imprime a razao fill/hull em VARIOS raios de
%   closing + nº de extremidades do esqueleto. Objetivo: achar a regra que
%   separa abertas reais (7_c1, 7_c2) das fechadas com laco quebrado.

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    casos = {'7_c1_nn.jpg','7_c2_nn.jpg', ...           % abertas reais
             '7_c3_nn.jpg','1_c1_nn.jpg','6a_c4_nn.jpg','6b_c2_nn.jpg', ... % falsas abertas
             '1_c2_nn.jpg','3_c3_nn.jpg','6b_c1_nn.jpg'};   % fechadas faceis (controle)
    rc_cm = [0.3 0.6 1.0 1.5 2.0];

    fprintf('%-14s %6s %5s | %s | %4s %4s\n', 'arquivo','hull','skel', ...
            sprintf('razao fill/hull @rc=%s', mat2str(rc_cm)), 'end','gap');
    fprintf('%s\n', repmat('-',1,92));

    for i = 1:numel(casos)
        nome = casos{i};
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bw_t, bw_g]   = lesao.extrair_tinta(img, pc);
        [bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc); %#ok<ASGLU>

        bw = imclose(bw_l, strel('disk', max(2, round(0.06*pc))));
        cc = bwconncomp(bw);
        if cc.NumObjects == 0, fprintf('%-14s (vazio)\n', nome); continue; end
        [~, im] = max(cellfun(@numel, cc.PixelIdxList));
        comp = false(size(bw)); comp(cc.PixelIdxList{im}) = true;

        hull = bwconvhull(comp); A_hull = sum(hull(:));
        sk   = bwskel(comp);
        skcm = sum(sk(:))/pc;
        ends = sum(sum(bwmorph(sk,'endpoints')));

        razoes = zeros(1,numel(rc_cm));
        for j = 1:numel(rc_cm)
            se = strel('disk', max(1, round(rc_cm(j)*pc)));
            f  = imfill(imclose(comp, se), 'holes');
            razoes(j) = sum(f(:))/max(A_hull,1);
        end

        % "gap" estimado: maior distancia entre extremidades do esqueleto (cm)
        [ey, ex] = find(bwmorph(sk,'endpoints'));
        gap = 0;
        if numel(ex) >= 2
            D = hypot(ex - ex', ey - ey'); gap = max(D(:))/pc;
        end

        fprintf('%-14s %6.1f %5.1f | %s | %4d %4.1f\n', nome, A_hull/pc^2, skcm, ...
            sprintf('%5.2f', razoes), ends, gap);
    end
end
