function auditar_visual()
%AUDITAR_VISUAL  Sobrepõe o contorno detectado em cada imagem e monta painéis
%   por paciente, para inspeção visual da qualidade da segmentação.
%   Salva audit_<grupo>.png, recortando uma janela ao redor da lesão.

    d = fileparts(mfilename('fullpath'));
    arq = dir(fullfile(d,'images','*.jpg'));
    [~,o] = sort({arq.name}); arq = arq(o);

    % agrupar por prefixo antes de "_c"
    grupos = containers.Map('KeyType','char','ValueType','any');
    for i = 1:numel(arq)
        g = regexp(arq(i).name, '^(.*?)_c?\d', 'tokens', 'once');
        if isempty(g), g = {arq(i).name}; end
        if ~isKey(grupos, g{1}), grupos(g{1}) = {}; end
        grupos(g{1}) = [grupos(g{1}), arq(i).name];
    end

    chaves = keys(grupos);
    for k = 1:numel(chaves)
        nomes = grupos(chaves{k});
        n = numel(nomes);
        f = figure('Visible','off','Position',[0 0 320*n 360]);
        for j = 1:n
            caminho = fullfile(d,'images',nomes{j});
            R = medir_area_fn(caminho, false);
            img = imread(caminho);
            ppc = R.pixels_por_cm; if isnan(ppc), ppc = 120; end

            subplot(1,n,j);
            st = regionprops(R.mask, 'BoundingBox');
            if ~isempty(st)
                bb = st(1).BoundingBox; m = round(2*ppc);
                x0 = max(1,floor(bb(1))-m); y0 = max(1,floor(bb(2))-m);
                x1 = min(size(img,2),ceil(bb(1)+bb(3))+m);
                y1 = min(size(img,1),ceil(bb(2)+bb(4))+m);
                imshow(img(y0:y1,x0:x1,:)); hold on;
                b = bwboundaries(R.mask(y0:y1,x0:x1));
                for q = 1:numel(b), plot(b{q}(:,2),b{q}(:,1),'r-','LineWidth',2); end
            else
                imshow(img);
            end
            title(sprintf('%s\nn=%d  %.2f cm² (sol %.2f)', nomes{j}, R.n_lesoes, R.area_cm2, R.solidez), ...
                  'Interpreter','none','FontSize',9);
        end
        exportgraphics(f, fullfile(d, sprintf('audit_%s.png', chaves{k})));
        close(f);
        fprintf('grupo %s ok\n', chaves{k});
    end
end
