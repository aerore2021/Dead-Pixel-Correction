function [DeadPixel_Lis, StuckPixel_Lis] = AutoDPC(hot_uniform, cold_uniform, hot_temp, cold_temp, thres)
    % 暂时先假定hot_uniform和cold_uniform是可以用来判断坏点的，即为软核中的sub_value_max, sub_value_min
    
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
            k_this = k(i, j);
            k_sum = sum(k_padded(i:i + window_size - 1, j:j + window_size - 1), 'all') - k_this;
            k_mean = k_sum / (window_size^2 - 1);
            if abs(k_this - k_mean) > thres
                StuckPixel_Lis = [StuckPixel_Lis; [i, j]];
            end
        end
    end
end