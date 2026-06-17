function [bw_tinta, bw_grade] = extrair_tinta(img, ppc, saida)

if nargin < 3, saida = ''; end

raio_bh = max(10, round(0.30 * ppc));
gray_bh = imbothat(img, strel('disk', raio_bh));
lesao.salvar(gray_bh, saida, '03_bothat.png');

bw = imbinarize(gray_bh, graythresh(gray_bh));
lesao.salvar(bw, saida, '04_otsu.png');

len_grade = round(0.8 * ppc);
grade_h = imopen(bw, strel('line', len_grade, 0));
grade_v = imopen(bw, strel('line', len_grade, 90));
bw_grade = grade_h | grade_v;
lesao.salvar(grade_h,  saida, '05_grade_h.png');
lesao.salvar(grade_v,  saida, '06_grade_v.png');
lesao.salvar(bw_grade, saida, '07_bw_grade.png');

len_rem = round(1.2 * ppc);
rem = imopen(bw, strel('line', len_rem, 0)) | imopen(bw, strel('line', len_rem, 90));
lesao.salvar(rem, saida, '08_linhas_remover.png');

bw_tinta = bw & ~rem;
lesao.salvar(bw_tinta, saida, '09_tinta_bruta.png');
bw_tinta = imclose(bw_tinta, strel('disk', max(6, round(0.06 * ppc))));
lesao.salvar(bw_tinta, saida, '10_tinta_close.png');
bw_tinta = bwareaopen(bw_tinta, round(0.01 * ppc^2));
lesao.salvar(bw_tinta, saida, '11_bw_tinta.png');

end
