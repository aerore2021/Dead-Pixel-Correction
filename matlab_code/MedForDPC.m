function ManualPixel_Lis = MedForDPC(window, thres_Med, AutoDPC_Lis)
    MedWindow_size = 3;
    Padded_size = floor(MedWindow_size / 2);
    DeadPixel_Lis = AutoDPC_Lis;
    [h, w] = size(window);

    for i=1+Padded_size:h-Padded_size
        for j=1+Padded_size:w-Padded_size
            if ismember([i, j], DeadPixel_Lis, 'rows')
                continue; % 如果已经判定为坏点，跳过
            end
            % 获取当前3x3窗口
            MedPixel_Vals = [];
            for ii = i-Padded_size:i+Padded_size
                for jj = j-Padded_size:j+Padded_size
                    % 避免与原有的坐标重复
                    if ((ismember([ii, jj], DeadPixel_Lis, 'rows')) || (ii == i && jj == j))
                        continue;
                    end
                    MedPixel_Vals = [MedPixel_Vals; window(ii, jj)];
                end
            end
            MedPixel_Val = median(MedPixel_Vals);
            if abs(window(i, j) - MedPixel_Val) > thres_Med
                DeadPixel_Lis = [DeadPixel_Lis; [i, j]];
                ManualPixel_Lis = [ManualPixel_Lis; [i, j]];
            end
        end
    end
end