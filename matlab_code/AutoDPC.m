function [DeadPixel_Lis, StuckPixel_Lis] = AutoDPC(hot_uniform, cold_uniform, hot_temp, cold_temp, thres)

    Dif = double(hot_uniform) - double(cold_uniform);
    Dif_temp = double(hot_temp) - double(cold_temp);
    Dif_temp = 1; % 这里假设Dif_temp为1，实际应用中需要根据具体情况计算
    [h, w] = size(Dif);
    DeadPixel_Lis = []; 
    StuckPixel_Lis = [];

    k = zeros(h, w); % 初始化k矩阵
    k = Dif ./ Dif_temp;

    window_size = 3; 
    pad_size = floor(window_size / 2);
    k_padded = padarray(k, [pad_size, pad_size], 'replicate');

    for i = 1:h
        for j = 1:w
            % 坏点检测
            if Dif(i, j) == 0
                DeadPixel_Lis = [DeadPixel_Lis; [i, j]];
                continue;
            end
            % 盲元检测
            % 计算当前像素点的k值
            if (i > pad_size && j > pad_size)
                if (isempty(DeadPixel_Lis) == 0)
                    if (ismember([i-pad_size, j-pad_size], DeadPixel_Lis, 'rows'))
                        continue;
                    end
                end
                k_this = k_padded(i, j);
                k_vld_vals = [];
                for ii = i - pad_size:i + pad_size
                    for jj = j - pad_size:j + pad_size
                        if (isempty(DeadPixel_Lis) == 0)
                            if (ismember([ii-pad_size, jj-pad_size], DeadPixel_Lis, 'rows'))
                                continue; % 跳过坏点
                            end
                        elseif (isempty(StuckPixel_Lis) == 0)
                            if (ismember([ii-pad_size, jj-pad_size], StuckPixel_Lis, 'rows'))
                                continue; % 跳过盲点
                            end
                        elseif (ii == i && jj == j)
                                continue;
                        end
                        k_vld_vals = [k_vld_vals; k_padded(ii, jj)];
                    end
                end
                k_med = median(k_vld_vals);
                if abs(k_this - k_med) > thres
                    StuckPixel_Lis = [StuckPixel_Lis; [i-pad_size, j-pad_size]];
                end
            end
        end
    end
end