function salvar(im, pasta, nome)

if isempty(pasta), return; end
if islogical(im), im = im2uint8(im); end
imwrite(im, fullfile(pasta, nome));

end
