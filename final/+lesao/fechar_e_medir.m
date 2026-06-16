function [feridas, total_cm2, info] = fechar_e_medir(comps, px_por_cm)
%FECHAR_E_MEDIR  Fecha cada ferida (E5) e mede sua area em cm2 (E6).
%   [FERIDAS, TOTAL_CM2, INFO] = FECHAR_E_MEDIR(COMPS, PX_POR_CM)
%
%   Recebe os componentes ja classificados pela E4 (cada um com sua mascara
%   fechada: preenchimento p/ FECHADA, convex hull p/ ABERTA) e converte area
%   de pixels para cm2, sabendo que 1 cm2 = px_por_cm^2 pixels.
%
%   Entradas:
%     comps      struct array da E4 (lesao.classificar_ferida)
%     px_por_cm  escala linear (E1)
%
%   Saidas:
%     feridas    struct array, uma por ferida, com:
%                  .classe     'fechada' | 'aberta'
%                  .area_cm2   area medida
%                  .hull_cm2   area do convex hull (limite superior)
%                  .solidez    area_cm2 / hull_cm2 (1=convexo; baixo=concavo)
%                  .usou_hull  true se a area veio do convex hull (aberta) ->
%                              menor confianca
%                  .pequena    true se area < 1 cm2 (alvo da E7)
%                  .mask       mascara logica final da ferida (p/ overlay)
%     total_cm2  soma das areas (cm2)
%     info       struct com px_por_cm e n_feridas

    ppc = px_por_cm;
    feridas = struct('classe',{}, 'area_cm2',{}, 'hull_cm2',{}, 'solidez',{}, ...
                     'usou_hull',{}, 'pequena',{}, 'mask',{});

    for k = 1:numel(comps)
        m  = comps(k).mask_fechada;
        a  = sum(m(:)) / ppc^2;
        h  = bwconvhull(m); ah = sum(h(:)) / ppc^2;   % hull da mascara final

        feridas(k).classe    = comps(k).classe;
        feridas(k).area_cm2  = a;
        feridas(k).hull_cm2  = ah;
        feridas(k).solidez   = a / max(ah, eps);
        feridas(k).usou_hull = strcmp(comps(k).classe, 'aberta');
        feridas(k).pequena   = a < 1;
        feridas(k).mask      = m;
    end

    total_cm2 = sum([feridas.area_cm2]);
    if isempty(feridas), total_cm2 = 0; end
    info = struct('px_por_cm', ppc, 'n_feridas', numel(feridas));
end
