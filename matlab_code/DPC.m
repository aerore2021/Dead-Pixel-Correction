function image_dpc = DPC(image_in, AllDP_Lis)
    MeanWindow_size = 3; % 均值滤波窗口大小
    [h, w] = size(image_in);
    image_dpc = image_in; 
    pad_size_stg1 = floor(MeanWindow_size / 2);
    padded_image_in = padarray(image_in, [pad_size_stg1, pad_size_stg1], 'replicate');
    
    for i = 1:h
        for j = 1:w
            % 检查当前像素是否在坏点列表中
            if ismember([i, j], AllDP_Lis, 'rows')
                valid_cnt = 0;
                valid_sum = 0;
                % 获取3x3邻域
                row_start = i - pad_size_stg1;
                row_end = i + pad_size_stg1;
                col_start = j - pad_size_stg1;
                col_end = j + pad_size_stg1;
                for ii = row_start:row_end
                    for jj = col_start:col_end
                        if (ismember([ii, jj], AllDP_Lis, 'rows'))
                            continue; % 跳过坏点
                        end
                        valid_cnt = valid_cnt + 1;
                        valid_sum = valid_sum + double(padded_image_in(ii+pad_size_stg1, jj+pad_size_stg1));
                    end
                end
                
                % 计算均值
                mean_val = valid_sum / valid_cnt;
                
                % 替换坏点像素值
                image_dpc(i, j) = uint16(mean_val);
            end
        end
    end
    % stage 2: 5 x 5 Median Filter
    MedianWindow_size = 5; % 中值滤波窗口大小
    pad_size_stg2 = floor(MedianWindow_size / 2);
    window_num = MedianWindow_size * MedianWindow_size - 1;
    padded_image_stg2 = padarray(image_dpc, [pad_size_stg2, pad_size_stg2], 'replicate');
    for i = 1:h
        for j = 1:w
            window_5x5 = padded_image_stg2(i:i+MedianWindow_size-1, j:j+MedianWindow_size-1);
            window_5x5_1d = reshape(window_5x5, [], 1);
            center_i = i + pad_size_stg2;
            center_j = j + pad_size_stg2;
            cnt = zeros(1, window_num);
            idx = 1;
            % 分别计算周围的24个像素的位次
            for ii = - pad_size_stg2:pad_size_stg2
                for jj = - pad_size_stg2:pad_size_stg2
                    window_pixel = padded_image_stg2(center_i + ii, center_j + jj);
                    cnt(1, idx) = sum(window_pixel < window_5x5_1d);
                    idx = idx + 1;
                end
            end
            % 取十二, 十三位次的像素和原始坐标的换算
            cnt_12_idx = find(cnt == 12);
            cnt_13_idx = find(cnt == 13);
            median_val_12 = window_5x5_1d(find(cnt == 12));
            median_val_13 = window_5x5_1d(find(cnt == 13));
            if (cnt_12_idx >= 20)
                x_idx_12_re = 5;
                y_idx_12_re = cnt_12_idx - 19;
            elseif (cnt_12_idx >= 15)
                x_idx_12_re = 4;
                y_idx_12_re = cnt_12_idx - 14;
            elseif (cnt_12_idx >= 13)
                x_idx_12_re = 3;
                y_idx_12_re = cnt_12_idx - 9;
            elseif (cnt_12_idx >= 11)
                x_idx_12_re = 3;
                y_idx_12_re = cnt_12_idx - 10;
            elseif (cnt_12_idx >= 6)
                x_idx_12_re = 2;
                y_idx_12_re = cnt_12_idx - 5;
            else
                x_idx_12_re = 1;
                y_idx_12_re = cnt_12_idx;
            end
            
            if (cnt_13_idx >= 20)
                x_idx_13_re = 5;
                y_idx_13_re = cnt_13_idx - 19;
            elseif (cnt_13_idx >= 15)
                x_idx_13_re = 4;
                y_idx_13_re = cnt_13_idx - 14;
            elseif (cnt_13_idx >= 13)
                x_idx_13_re = 3;
                y_idx_13_re = cnt_13_idx - 9;
            elseif (cnt_13_idx >= 11)
                x_idx_13_re = 3;
                y_idx_13_re = cnt_13_idx - 10;
            elseif (cnt_13_idx >= 6)
                x_idx_13_re = 2;
                y_idx_13_re = cnt_13_idx - 5;
            else
                x_idx_13_re = 1;
                y_idx_13_re = cnt_13_idx;
            end
            x_idx_12 = center_i - pad_size_stg2 - 1 + x_idx_12_re;
            y_idx_12 = center_j - pad_size_stg2 - 1 + y_idx_12_re;
            x_idx_13 = center_i - pad_size_stg2 - 1 + x_idx_13_re;
            y_idx_13 = center_j - pad_size_stg2 - 1 + y_idx_13_re;
            % 优先选非坏点的值
            if (ismember([center_i - pad_size_stg2, center_j - pad_size_stg2], AllDP_Lis, 'rows'))
                if (ismember([x_idx_12 - pad_size_stg2, y_idx_12 - pad_size_stg2], AllDP_Lis, 'rows') == 0)
                    image_dpc(i, j) = median_val_12; % 优先选非坏点的值
                else
                    image_dpc(i, j) = median_val_13; % 如果12位次是坏点，则选13位次
                end
            end
        end
    end
end