function bench_tempo()
%BENCH_TEMPO  Responde 2 perguntas: (1) o Parallel Computing Toolbox esta
%   INSTALADO? (2) usar parfor acelera o pipeline real? Mede tempo por estagio,
%   depois compara o batch sequencial (for) vs paralelo (parfor).

    raiz  = fileparts(fileparts(mfilename('fullpath')));
    addpath(raiz);
    pasta = fullfile(raiz, 'Imagens_GridLesoes_noname');

    % --- (1) toolbox instalado? ---
    v = ver;
    nomes = {v.Name};
    tem_pct = any(contains(nomes, 'Parallel Computing'));
    fprintf('=== Parallel Computing Toolbox INSTALADO: %d ===\n', tem_pct);
    if tem_pct
        idx = find(contains(nomes,'Parallel Computing'),1);
        fprintf('    %s %s\n', v(idx).Name, v(idx).Version);
    end
    fprintf('    Nucleos fisicos: %d\n\n', feature('numcores'));

    files = dir(fullfile(pasta, '*.jpg'));
    [~, ord] = sort({files.name}); files = files(ord);

    % --- per-estagio em 4 imagens (sem salvar png) ---
    casos = files([1, 13, 44, 41]);
    acc = zeros(1,5);
    for i = 1:numel(casos)
        cam = fullfile(pasta, casos(i).name);
        t=tic; img=imread(cam);                                a1=toc(t);
        t=tic; pc=lesao.calibrar_grid(img);                    a2=toc(t);
        t=tic; [bt,bg]=lesao.extrair_tinta(img,pc);            a3=toc(t);
        t=tic; [bl,og]=lesao.achar_origem_roi(bt,bg,pc);       a4=toc(t);
        t=tic; [~,~]=lesao.classificar_ferida(bl,og,pc);       a5=toc(t);
        acc = acc + [a1 a2 a3 a4 a5];
    end
    acc = acc/numel(casos);
    fprintf('Tempo medio/imagem: read=%.2f E1=%.2f E2=%.2f E3=%.2f E4=%.2f s\n', acc);
    fprintf('  -> calculo total ~%.2f s/img\n\n', sum(acc(2:5)));

    % --- (2) for vs parfor no batch (12 imagens) ---
    sub = files(1:min(12,numel(files)));
    cams = arrayfun(@(f) fullfile(pasta, f.name), sub, 'UniformOutput', false);
    N = numel(cams);

    t=tic;
    for i = 1:N, processa(cams{i}); end
    t_seq = toc(t);
    fprintf('SEQUENCIAL (for)   %2d imgs: %.1f s  (%.2f s/img)\n', N, t_seq, t_seq/N);

    if tem_pct
        t=tic; p = gcp('nocreate'); if isempty(p), p = parpool('Processes'); end
        t_pool = toc(t);
        fprintf('PARPOOL start (1x):        %.1f s  (%d workers)\n', t_pool, p.NumWorkers);
        t=tic;
        parfor i = 1:N, processa(cams{i}); end
        t_par = toc(t);
        fprintf('PARALELO (parfor)  %2d imgs: %.1f s  (%.2f s/img)  speedup=%.1fx\n', ...
                N, t_par, t_par/N, t_seq/t_par);
    end
end

function processa(cam)
    img = imread(cam);
    pc  = lesao.calibrar_grid(img);
    [bt,bg] = lesao.extrair_tinta(img,pc);
    [bl,og] = lesao.achar_origem_roi(bt,bg,pc);
    lesao.classificar_ferida(bl,og,pc);
end
