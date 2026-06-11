function prof_e4()
%PROF_E4  Profila as operacoes internas da E4 por imagem p/ achar o gargalo:
%   recorte, bwconvhull, cada closing+fill por raio, e bwskel.

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'Imagens_GridLesoes_noname');
    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    casos = files([1, 13, 44, 41]);   % 10_c1, 1_c1, 7_c1, 6b_c2
    rc_cm = [0.15 0.30 0.50 1.0 1.5 2.0];

    for i = 1:numel(casos)
        nome = casos(i).name;
        img  = imread(fullfile(pasta, nome));
        pc   = lesao.calibrar_grid(img);
        [bt,bg] = lesao.extrair_tinta(img, pc);
        [bl,~]  = lesao.achar_origem_roi(bt, bg, pc);
        bw = imclose(bl, strel('disk', max(2, round(0.06*pc))));
        cc = bwconncomp(bw);
        [H,W] = size(bw);
        mg = round((max(rc_cm)+0.2)*pc);

        fprintf('\n%s  (%d componentes, ppc=%.0f)\n', nome, cc.NumObjects, pc);
        for ci = 1:cc.NumObjects
            px = cc.PixelIdxList{ci};
            [ry,rx] = ind2sub([H,W], px);
            r0=max(1,min(ry)-mg); r1=min(H,max(ry)+mg);
            c0=max(1,min(rx)-mg); c1=min(W,max(rx)+mg);
            sub = false(r1-r0+1, c1-c0+1);
            sub(sub2ind(size(sub), ry-r0+1, rx-c0+1)) = true;

            t=tic; hull=bwconvhull(sub); A_hull=sum(hull(:)); th=toc(t);
            if A_hull < 0.06*pc^2, continue; end

            tc = zeros(1,numel(rc_cm));
            for j=1:numel(rc_cm)
                t=tic;
                se=strel('disk', max(1,round(rc_cm(j)*pc)));
                imfill(imclose(sub,se),'holes');
                tc(j)=toc(t);
            end
            t=tic; bwskel(sub); ts=toc(t);

            fprintf('  comp%d %dx%d hull=%.1fcm2 | hull=%.1fs close=[%s]s skel=%.1fs\n', ...
                ci, size(sub,1), size(sub,2), A_hull/pc^2, th, ...
                sprintf('%.1f ', tc), ts);
        end
    end
end
