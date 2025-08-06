function ManualPixel_Lis = MedForDPC(window, thres_Med, AutoDPC_Lis)
    ManualPixel_Lis = [];
    MedWindow_size = 3;
    Padded_size = floor(MedWindow_size / 2);
    DeadPixel_Lis = AutoDPC_Lis;
    [h, w] = size(window);
    window_padded = padarray(window, [Padded_size, Padded_size], 'replicate');  

    for i=1+Padded_size:h+Padded_size
        for j=1+Padded_size:w+Padded_size
            if (~isempty(DeadPixel_Lis))
                if ismember([i-Padded_size, j-Padded_size], DeadPixel_Lis, 'rows')
                    continue; % 如果已经判定为坏点，跳过
                end
            end
            % 获取当前3x3窗口
            MedPixel_Vals = [];
            for ii = i-Padded_size:i+Padded_size
                for jj = j-Padded_size:j+Padded_size
                    % 避免与原有的坐标重复
                    if (~isempty(DeadPixel_Lis) && ii-Padded_size >= 1 && jj-Padded_size >= 1)
                        if ((ismember([ii-Padded_size, jj-Padded_size], DeadPixel_Lis, 'rows')) )
                            continue;
                        end
                    end
                    if ((ii == i && jj == j))
                        continue;
                    end
                    MedPixel_Vals = [MedPixel_Vals; window_padded(ii, jj)];
                end
            end
            MedPixel_Val = median(MedPixel_Vals);
            if abs(window_padded(i, j) - MedPixel_Val) > thres_Med
                DeadPixel_Lis = [DeadPixel_Lis; [i-Padded_size, j-Padded_size]];
                ManualPixel_Lis = [ManualPixel_Lis; [i-Padded_size, j-Padded_size]];
            end
        end
    end
end