clear;
%% 初始化
hot_uniform = imread('D:\feizhileng\Dead-Pixel-Correction\matlab_code\inputs\bendi_gaowen.png');
cold_uniform = imread('D:\feizhileng\Dead-Pixel-Correction\matlab_code\inputs\bendi_diwen.png');
image_input = imread('D:\feizhileng\Dead-Pixel-Correction\matlab_code\inputs\tf.png');
hot_uniform = reshape(hot_uniform, 640, 512)';
cold_uniform = reshape(cold_uniform, 640, 512)';
%image_input = reshape(image_input, 640, 512)';
hot_temp = 30; % 假设热像素温度为30
cold_temp = 20; % 假设冷像素温度为20
thres = 100; 
thres_Med = 30; 
DeadPixel_Lis = [];
StuckPixel_Lis = [];

%% 人工生成1x2，2x1，1x3，3x1，1+2x1，2x2，3x3，1+2x2的坏点
% 1x2
image_input(100, 100:101) = 8192;
hot_uniform(100, 100:101) = 8192;
cold_uniform(100, 100:101) = 8192;
% 2x1
image_input(150:151, 200) = 8192;
hot_uniform(150:151, 200) = 8192;
cold_uniform(150:151, 200) = 8192;
% 1x3
image_input(200, 300:302) = 8192;
hot_uniform(200, 300:302) = 8192;
cold_uniform(200, 300:302) = 8192;
% 3x1
image_input(250:252, 300) = 8192;
hot_uniform(250:252, 300) = 8192;
cold_uniform(250:252, 300) = 8192;
% 1+2x1
image_input(300, 400:401) = 8192;
image_input(301, 400) = 8192;
hot_uniform(300, 400:401) = 8192;
cold_uniform(300, 400:401) = 8192;
hot_uniform(301, 400) = 8192;
cold_uniform(301, 400) = 8192;
% 2x2
image_input(350:351, 400:401) = 8192;
hot_uniform(350:351, 400:401) = 8192;
cold_uniform(350:351, 400:401) = 8192;
% 3x3
image_input(400:402, 400:402) = 8192;
hot_uniform(400:402, 400:402) = 8192;
cold_uniform(400:402, 400:402) = 8192;
% 1+2x2
image_input(450, 399) = 8192;
image_input(451:452, 400:401) = 8192;
hot_uniform(450, 399) = 8192;
cold_uniform(450, 399) = 8192;
hot_uniform(451:452, 400:401) = 8192;
cold_uniform(451:452, 400:401) = 8192;
% 2x3
image_input(500:501, 400:402) = 8192;
hot_uniform(500:501, 400:402) = 8192;
cold_uniform(500:501, 400:402) = 8192;

%% 自动检测坏点和盲元
[DeadPixel_Lis, StuckPixel_Lis] = AutoDPC(hot_uniform, cold_uniform, hot_temp, cold_temp, thres);
AutoDP_Lis = sortrows([DeadPixel_Lis; StuckPixel_Lis]);

%% 手动检测坏点
% 5x5的范围内标记一个坐标就行，让它尽量保持在中心
% AutoDP_Lis = [];
ManualPixel_Lis = [30, 157; 83, 133; 83, 134; 84, 133; 84, 134];

if ~isempty(ManualPixel_Lis)
    % 如果有手动标记的坏点，则进行手动坏点检测
    AllDP_Lis = ManualDPC(image_input, ManualPixel_Lis, thres_Med, AutoDP_Lis);
else
    % 如果没有手动标记的坏点，则直接使用自动检测的坏点列表
    AllDP_Lis = AutoDP_Lis;
end

%% 使用DPC算法修复坏点
AllDP_Lis = ManualPixel_Lis;
img_dpc = DPC_v2(image_input, AllDP_Lis, 50);
figure; imshow(img_dpc,[]);title("去坏点结果");
figure; imshow(image_input, []); title("输入");
% 输出坏点数量    
disp(['坏点数量: ', num2str(size(AllDP_Lis, 1))]);
imwrite(img_dpc, "D:\feizhileng\Dead-Pixel-Correction\matlab_code\inputs\dpc.png");