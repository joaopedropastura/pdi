function principal()
%PRINCIPAL  Mede a area (cm2) de cada ferida em todas as imagens e imprime no
%   console: nome da imagem, id da ferida e area. Quando a imagem tem mais de
%   uma ferida, os ids sao 1,2,3... ordenados por posicao (cima->baixo, depois
%   esquerda->direita). Feridas ABERTAS sao fechadas por convex hull (marcadas
%   com '*hull'). Base de medida: o grid do fundo (cada quadrado = 1 cm2).
%
%   Uso (headless):  matlab -batch "principal"

    raiz  = fileparts(mfilename('fullpath'));
    addpath(raiz);
    pasta = fullfile(raiz, 'imagens');

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);
    n = numel(files);

    fprintf('\n%-16s %3s  %-8s %10s\n', 'imagem', 'id', 'classe', 'area_cm2');
    fprintf('%s\n', repmat('-', 1, 42));

    for i = 1:n
        nome = files(i).name;
        fprintf(2, '  [%d/%d] %s ...\r', i, n, nome);  % progresso no stderr (nao
        img  = imread(fullfile(pasta, nome));          % suja a tabela no stdout)

        pc             = lesao.calibrar_grid(img);
        [bw_t, bw_g]   = lesao.extrair_tinta(img, pc);
        [bw_l, origem] = lesao.achar_origem_roi(bw_t, bw_g, pc);
        [~, comps]     = lesao.classificar_ferida(bw_l, origem, pc);
        feridas        = lesao.selecionar_feridas(comps, size(bw_l), pc);

        if isempty(feridas)
            fprintf('%-16s %3s  %s\n', nome, '-', '(nenhuma ferida detectada)');
        else
            for k = 1:numel(feridas)
                f = feridas(k);
                marca = ''; if f.usou_hull, marca = '  *hull (aberta)'; end
                rotulo = nome; if k > 1, rotulo = ''; end
                fprintf('%-16s %3d  %-8s %10.1f%s\n', rotulo, k, f.classe, f.area_cm2, marca);
            end
        end
    end
    fprintf('%s\n', repmat('-', 1, 42));
    fprintf('* hull = ferida aberta, area estimada pelo convex hull\n');
end
