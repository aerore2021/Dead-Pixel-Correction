function AllDP_Lis = ManualDPC(image_input, ManualPixel_input, thres_Med, AutoDP_Lis)
    [h, w] = size(image_input);
    AllDP_Lis = AutoDP_Lis; % 初始化所有坏点列表
    MedWindow_size = 5;

    for i = 1:h
        for j = 1:w
            % 检查手动标记的像素点是否在自动检测列表中
            if ismember([i, j], AllDP_Lis, 'rows')
                continue; % 如果在已有坏点列表中，则跳过
            end
            
            % 当坐标为手动标记的像素点时，在5乘5邻域作中值滤波判断真实坏点位置
            if ismember([i, j], ManualPixel_input, 'rows')
                % 获取5x5邻域
                row_start = max(1, i - floor(MedWindow_size / 2));
                row_end = min(h, i + floor(MedWindow_size / 2));
                col_start = max(1, j - floor(MedWindow_size / 2));
                col_end = min(w, j + floor(MedWindow_size / 2));
                window = image_input(row_start:row_end, col_start:col_end);
                
                % AllDP_Lis中位于window的值
                AllDP_Lis_obj = [];
                for k = 1:size(AllDP_Lis, 1)
                    if AllDP_Lis(k, 1) >= row_start && AllDP_Lis(k, 1) <= row_end && ...
                       AllDP_Lis(k, 2) >= col_start && AllDP_Lis(k, 2) <= col_end
                        AllDP_Lis_obj = [AllDP_Lis_obj; [AllDP_Lis(k, 1)-row_start+1, AllDP_Lis(k, 2)-col_start+1]];
                    end
                end
                ManualPixel_Lis_obj = MedForDPC(window, thres_Med, AllDP_Lis_obj);
                for m = 1:size(ManualPixel_Lis_obj, 1)
                    AllDP_Lis = [AllDP_Lis; [row_start + ManualPixel_Lis_obj(m, 1) - 1, col_start + ManualPixel_Lis_obj(m, 2) - 1]];
                end
                % 将AllDP_Lis中的坐标从小到大排序
                AllDP_Lis = sortrows(AllDP_Lis);
            end        
        end
    end
end