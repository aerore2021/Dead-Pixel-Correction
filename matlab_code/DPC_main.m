%% 初始化
hot_uniform = imread();
cold_uniform = imread();
image_input = imread(); 
hot_temp = 30; % 假设热像素温度为30
cold_temp = 20; % 假设冷像素温度为20
thres = 1; 
thres_Med = 30; 
DeadPixel_Lis = [];
StuckPixel_Lis = [];

%% 自动检测坏点和盲元
[DeadPixel_Lis, StuckPixel_Lis] = AutoDPC(hot_uniform, cold_uniform, hot_temp, cold_temp, thres);
AutoDP_Lis = sortrows([DeadPixel_Lis; StuckPixel_Lis]);

%% 手动检测坏点
% 5x5的范围内标记一个坐标就行，让它尽量保持在中心
ManualPixel_Lis = [];

if ~isempty(ManualPixel_Lis)
    % 如果有手动标记的坏点，则进行手动坏点检测
    AllDP_Lis = ManualDPC(image_input, ManualPixel_Lis, thres_Med, AutoDP_Lis);
else
    % 如果没有手动标记的坏点，则直接使用自动检测的坏点列表
    AllDP_Lis = AutoDP_Lis;
end

%% 使用DPC算法修复坏点
img_dpc = DPC(image_input, AllDP_Lis);
figure; imshow(img_dpc);