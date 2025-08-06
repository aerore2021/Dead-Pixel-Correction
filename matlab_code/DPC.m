function image_dpc = DPC(image_in, AllDP_Lis)
    MeanWindow_size = 3; % 均值滤波窗口大小
    [h, w] = size(image_in);
    image_dpc = image_in; 
    pad_size = floor(MeanWindow_size / 2);
    padded_image_in = padarray(image_in, [pad_size, pad_size], 'replicate');
    
    for i = 1:h
        for j = 1:w
            % 检查当前像素是否在坏点列表中
            if ismember([i, j], AllDP_Lis, 'rows')
                valid_cnt = 0;
                valid_sum = 0;
                % 获取3x3邻域
                row_start = i - pad_size;
                row_end = i + pad_size;
                col_start = j - pad_size;
                col_end = j + pad_size;
                for ii = row_start:row_end
                    for jj = col_start:col_end
                        if (ismember([ii, jj], AllDP_Lis, 'rows'))
                            continue; % 跳过坏点
                        end
                        valid_cnt = valid_cnt + 1;
                        valid_sum = valid_sum + double(padded_image_in(ii+pad_size, jj+pad_size));
                    end
                end
                
                % 计算均值
                mean_val = valid_sum / valid_cnt;
                
                % 替换坏点像素值
                image_dpc(i, j) = uint16(mean_val);
            end
        end
    end
end