function image_dpc = DPC_v2(image_in, AllDP_Lis, thres_dir)
    % AllDP_Lis: nX2数组, 第一列为行, 第二列为列
    % thres_dir: 方向性阈值

    MeanWindow_size = 3; % 均值滤波窗口大小
    [h, w] = size(image_in);
    image_dpc = image_in; 
    pad_size = floor(MeanWindow_size / 2);
    max_iterations = 1; % 最多迭代2轮
    
    % 预先生成坏点 map (logical)，避免在每个像素使用 ismember
    badmap_original = false(h, w);
    if ~isempty(AllDP_Lis)
        if size(AllDP_Lis,2) < 2
            error('AllDP_Lis 必须是 n x 2 的数组 (row, col)');
        end
        rows = round(AllDP_Lis(:,1));
        cols = round(AllDP_Lis(:,2));
        valid = rows >= 1 & rows <= h & cols >= 1 & cols <= w;
        rows = rows(valid);
        cols = cols(valid);
        if ~isempty(rows)
            idx = sub2ind([h, w], rows, cols);
            badmap_original(idx) = true;
        end
    end
    
    % 迭代处理坏点，每次处理有足够有效方向的坏点
    badmap_remaining = badmap_original; % 剩余未处理的坏点
    
    for iter = 1:max_iterations
        if ~any(badmap_remaining(:))
            break; % 所有坏点都已处理
        end
        
        padded_image = padarray(image_dpc, [pad_size, pad_size], 'replicate');
        processed_this_iter = false(h, w); % 本次迭代处理的坏点
        
        for i = 1:h
            for j = 1:w
                % 只处理剩余的坏点
                if ~badmap_remaining(i, j)
                    continue;
                end
                
                % 获取3x3邻域
                window = double(padded_image(i:i+2*pad_size, j:j+2*pad_size));
                
                % 构建坏点窗口（基于原始坏点map，不包括本轮已修复的）
                window_dp = false(3, 3);
                for wi = 1:3
                    for wj = 1:3
                        img_i = i + wi - 2;
                        img_j = j + wj - 2;
                        if img_i >= 1 && img_i <= h && img_j >= 1 && img_j <= w
                            % 如果是原始坏点且本轮还未处理，则标记为坏点
                            window_dp(wi, wj) = badmap_remaining(img_i, img_j);
                        end
                    end
                end
                
                % 检查4个基本方向的有效性
                % 水平方向: 左(2,1)和右(2,3)
                valid_h = ~window_dp(2,1) && ~window_dp(2,3);
                % 垂直方向: 上(1,2)和下(3,2)
                valid_v = ~window_dp(1,2) && ~window_dp(3,2);
                % 对角线1: 左上(1,1)和右下(3,3)
                valid_d1 = ~window_dp(1,1) && ~window_dp(3,3);
                % 对角线2: 右上(1,3)和左下(3,1)
                valid_d2 = ~window_dp(1,3) && ~window_dp(3,1);
                
                % 计算基本方向的 dif 和 mean
                difs = [];
                means = [];
                dir_types = []; % 记录每个方向的类型: 1-4基本方向, 5-12额外方向
                
                if valid_h
                    difs = [difs, abs(window(2,3) - window(2,1))];
                    means = [means, (window(2,1) + window(2,3))/2];
                    dir_types = [dir_types, 1];
                end
                if valid_v
                    difs = [difs, abs(window(3,2) - window(1,2))];
                    means = [means, (window(1,2) + window(3,2))/2];
                    dir_types = [dir_types, 2];
                end
                if valid_d1
                    difs = [difs, abs(window(3,3) - window(1,1))];
                    means = [means, (window(1,1) + window(3,3))/2];
                    dir_types = [dir_types, 3];
                end
                if valid_d2
                    difs = [difs, abs(window(1,3) - window(3,1))];
                    means = [means, (window(1,3) + window(3,1))/2];
                    dir_types = [dir_types, 4];
                end
                
                % 只有当基本4个方向的有效数量 < 2 时，才考虑额外方向作为补充
                num_basic_directions = length(difs);
                if num_basic_directions < 2
                    % 检查中心点的4个直接邻居中是否有坏点
                    has_adjacent_badpixel = window_dp(1,2) || window_dp(2,1) || window_dp(2,3) || window_dp(3,2);
                    
                    if has_adjacent_badpixel
                        % 同行/同列的对角+邻居组合（不穿过中心坏点）
                        % 第1行组合
                        if ~window_dp(1,1) && ~window_dp(1,2) && ~window_dp(2,1) % 左上+上,且左可用
                            difs = [difs, abs(window(1,1) - window(1,2))];
                            means = [means, (window(1,1) + window(1,2))/2];
                            dir_types = [dir_types, 5];
                        end
                        if ~window_dp(1,3) && ~window_dp(1,2) && ~window_dp(2,3) % 右上+上,且右可用
                            difs = [difs, abs(window(1,3) - window(1,2))];
                            means = [means, (window(1,3) + window(1,2))/2];
                            dir_types = [dir_types, 6];
                        end
                        % 第3行组合
                        if ~window_dp(3,1) && ~window_dp(3,2) && ~window_dp(2,1) % 左下+下,且左可用
                            difs = [difs, abs(window(3,1) - window(3,2))];
                            means = [means, (window(3,1) + window(3,2))/2];
                            dir_types = [dir_types, 7];
                        end
                        if ~window_dp(3,3) && ~window_dp(3,2) && ~window_dp(2,3) % 右下+下,且右可用
                            difs = [difs, abs(window(3,3) - window(3,2))];
                            means = [means, (window(3,3) + window(3,2))/2];
                            dir_types = [dir_types, 8];
                        end
                        % 第1列组合
                        if ~window_dp(1,1) && ~window_dp(2,1) && ~window_dp(1,2) % 左上+左,且上可用
                            difs = [difs, abs(window(1,1) - window(2,1))];
                            means = [means, (window(1,1) + window(2,1))/2];
                            dir_types = [dir_types, 9];
                        end
                        if ~window_dp(3,1) && ~window_dp(2,1) && ~window_dp(3,2) % 左下+左,且下可用
                            difs = [difs, abs(window(3,1) - window(2,1))];
                            means = [means, (window(3,1) + window(2,1))/2];
                            dir_types = [dir_types, 10];
                        end
                        % 第3列组合
                        if ~window_dp(1,3) && ~window_dp(2,3) && ~window_dp(1,2) % 右上+右,且上可用
                            difs = [difs, abs(window(1,3) - window(2,3))];
                            means = [means, (window(1,3) + window(2,3))/2];
                            dir_types = [dir_types, 11];
                        end
                        if ~window_dp(3,3) && ~window_dp(2,3) && ~window_dp(3,2) % 右下+右,且下可用
                            difs = [difs, abs(window(3,3) - window(2,3))];
                            means = [means, (window(3,3) + window(2,3))/2];
                            dir_types = [dir_types, 12];
                        end
                    end
                end
                
                % 只要有至少1个有效方向就进行方向性判断
                if ~isempty(difs)
                    edge_flag = any(difs > thres_dir);
                    if edge_flag
                        % 选择差异最小的方向（最平坦）
                        idx_min = find(difs == min(difs), 1);
                        dir_type = dir_types(idx_min); % 获取该方向的类型
                        
                        if dir_type <= 4
                            % 基本4方向（穿过中心坏点）：直接用该方向两端点的均值
                            mean_val = means(idx_min);
                        else
                            % 额外方向（同行/列组合）：直接使用同侧邻居（已在添加方向时保证可用）
                            if dir_type == 5 % 左上+上 → 用左
                                mean_val = window(2,1);
                            elseif dir_type == 6 % 右上+上 → 用右
                                mean_val = window(2,3);
                            elseif dir_type == 7 % 左下+下 → 用左
                                mean_val = window(2,1);
                            elseif dir_type == 8 % 右下+下 → 用右
                                mean_val = window(2,3);
                            elseif dir_type == 9 % 左上+左 → 用上
                                mean_val = window(1,2);
                            elseif dir_type == 10 % 左下+左 → 用下
                                mean_val = window(3,2);
                            elseif dir_type == 11 % 右上+右 → 用上
                                mean_val = window(1,2);
                            else % dir_type == 12, 右下+右 → 用下
                                mean_val = window(3,2);
                            end
                        end
                    else
                        % 所有有效方向差异都小，使用3x3窗口均值（排除坏点）
                        idx_valid = ~window_dp;
                        valid_pixels = window(idx_valid);
                        if isempty(valid_pixels)
                            mean_val = 0;
                        else
                            mean_val = mean(valid_pixels);
                        end
                    end
                    
                    % 替换坏点像素值
                    image_dpc(i, j) = uint16(mean_val);
                    processed_this_iter(i, j) = true;
                end
            end
        end
        
        % 更新剩余坏点列表
        badmap_remaining = badmap_remaining & ~processed_this_iter;
        
        % 如果本次迭代没有处理任何坏点，说明剩余坏点都方向不足，用3x3均值兜底
        if ~any(processed_this_iter(:))
            padded_image = padarray(image_dpc, [pad_size, pad_size], 'replicate');
            for i = 1:h
                for j = 1:w
                    if badmap_remaining(i, j)
                        window = double(padded_image(i:i+2*pad_size, j:j+2*pad_size));
                        window_dp = false(3, 3);
                        for wi = 1:3
                            for wj = 1:3
                                img_i = i + wi - 2;
                                img_j = j + wj - 2;
                                if img_i >= 1 && img_i <= h && img_j >= 1 && img_j <= w
                                    window_dp(wi, wj) = badmap_original(img_i, img_j);
                                end
                            end
                        end
                        idx_valid = ~window_dp;
                        valid_pixels = window(idx_valid);
                        if isempty(valid_pixels)
                            mean_val = 0;
                        else
                            mean_val = mean(valid_pixels);
                        end
                        image_dpc(i, j) = uint16(mean_val);
                    end
                end
            end
            break; % 剩余坏点已用兜底策略处理
        end
    end
end