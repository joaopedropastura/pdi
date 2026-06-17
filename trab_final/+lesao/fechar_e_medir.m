function [feridas, total_cm2, info] = fechar_e_medir(comps, px_por_cm)

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
