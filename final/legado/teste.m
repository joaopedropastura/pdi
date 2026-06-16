clc; clear; close all;

ds      = datastore("imagens");
images  = readall(ds);
n       = length(images);

folder = "comparacao";

if ~exist(folder,  "dir"), mkdir(folder); end

for i = 1:n
    img  = images{i};
    gray       = rgb2gray(img);

    bw = imbinarize(gray, 'adaptive', 'ForegroundPolarity', 'dark');

    [~, name, ext] = fileparts(ds.Files{i});

    toRGB = @(bw) repmat(uint8(bw) * 255, 1, 1, 3);

    imwrite(cat(2, img,  toRGB(bw)), fullfile(folder, [name, ext]));
end