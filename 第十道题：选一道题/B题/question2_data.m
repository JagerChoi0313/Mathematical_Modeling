clear;
clc;
close all;

%% =========================================================
% 第二问：附件1、附件2红外反射光谱处理与峰谷识别
% 说明：
% 1. 不依赖 Signal Processing Toolbox
% 2. 自定义 Savitzky-Golay 平滑函数 my_sgolay
% 3. 自定义峰值检测函数 my_findpeaks
% 4. 附件1：入射角 10°
% 5. 附件2：入射角 15°
%
% 请将本程序与"附件1.xlsx""附件2.xlsx"放在同一文件夹中运行
%% =========================================================


%% 1. 参数设置

% 候选稳定干涉波段
sigma_min = 1500;
sigma_max = 4000;

% SG 平滑参数
smooth_window = 61;      % 必须为奇数
sgolay_order  = 3;       % 局部多项式阶数

% 峰谷检测参数
min_peak_distance   = 180;   % 相邻峰最小波数距离，单位 cm^-1
min_peak_prominence = 0.25;  % 最小峰显著度，单位 %


%% 2. 读取附件1和附件2

data1 = readmatrix('附件1.xlsx');
data2 = readmatrix('附件2.xlsx');

sigma1 = data1(:,1);
R1     = data1(:,2);

sigma2 = data2(:,1);
R2     = data2(:,2);


%% 3. 数据基础清洗

% 删除 NaN、Inf 等无效数据
valid1 = isfinite(sigma1) & isfinite(R1);
sigma1 = sigma1(valid1);
R1     = R1(valid1);

valid2 = isfinite(sigma2) & isfinite(R2);
sigma2 = sigma2(valid2);
R2     = R2(valid2);

% 删除最前面的孤立零反射率边界点（若存在）
if ~isempty(R1) && R1(1) == 0
    sigma1(1) = [];
    R1(1) = [];
end

if ~isempty(R2) && R2(1) == 0
    sigma2(1) = [];
    R2(1) = [];
end

% 按波数从小到大排序
[sigma1,index1] = sort(sigma1);
R1 = R1(index1);

[sigma2,index2] = sort(sigma2);
R2 = R2(index2);


%% 4. 输出原始数据基本信息

fprintf('==============================================\n');
fprintf('      碳化硅红外反射光谱数据基本信息\n');
fprintf('==============================================\n');

fprintf('\n附件1（入射角10°）：\n');
fprintf('有效数据点数量：%d\n',length(sigma1));
fprintf('波数范围：%.4f ~ %.4f cm^-1\n',min(sigma1),max(sigma1));
fprintf('反射率范围：%.4f ~ %.4f %%\n',min(R1),max(R1));

fprintf('\n附件2（入射角15°）：\n');
fprintf('有效数据点数量：%d\n',length(sigma2));
fprintf('波数范围：%.4f ~ %.4f cm^-1\n',min(sigma2),max(sigma2));
fprintf('反射率范围：%.4f ~ %.4f %%\n',min(R2),max(R2));

fprintf('==============================================\n');


%% 5. 绘制原始光谱：附件1

figure('Position',[200 100 1000 550]);

plot(sigma1,R1,'LineWidth',1.2);

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件1：入射角10°时碳化硅晶圆片红外反射光谱',...
    'FontSize',13);

grid on;
box on;
set(gca,'FontSize',11);
xlim([min(sigma1),max(sigma1)]);

ax = gca;
tb = axtoolbar(ax);
tb.Visible = 'off';
drawnow;

exportgraphics(gcf,...
    '附件1_10度_原始反射光谱.png',...
    'Resolution',300);


%% 6. 绘制原始光谱：附件2

figure('Position',[200 100 1000 550]);

plot(sigma2,R2,'LineWidth',1.2);

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件2：入射角15°时碳化硅晶圆片红外反射光谱',...
    'FontSize',13);

grid on;
box on;
set(gca,'FontSize',11);
xlim([min(sigma2),max(sigma2)]);

ax = gca;
tb = axtoolbar(ax);
tb.Visible = 'off';
drawnow;

exportgraphics(gcf,...
    '附件2_15度_原始反射光谱.png',...
    'Resolution',300);


%% 7. 绘制两组原始光谱对比图

figure('Position',[200 100 1000 550]);

plot(sigma1,R1,'LineWidth',1.2);
hold on;
plot(sigma2,R2,'LineWidth',1.2);

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('不同入射角下碳化硅晶圆片红外反射光谱对比',...
    'FontSize',13);

legend('附件1：10°','附件2：15°','Location','best');

grid on;
box on;
set(gca,'FontSize',11);

xlim([min([sigma1;sigma2]),max([sigma1;sigma2])]);

ax = gca;
tb = axtoolbar(ax);
tb.Visible = 'off';
drawnow;

exportgraphics(gcf,...
    '附件1与附件2_反射光谱对比.png',...
    'Resolution',300);

hold off;


%% ==========================================================
%                  附件1：10°
%% ==========================================================

%% 8. 截取候选稳定干涉区间

index_band1 = sigma1 >= sigma_min & sigma1 <= sigma_max;

sigma_band1 = sigma1(index_band1);
R_band1     = R1(index_band1);


%% 9. 自定义 Savitzky-Golay 平滑

R_smooth1 = my_sgolay(...
    R_band1,...
    smooth_window,...
    sgolay_order);


%% 10. 自动检测反射峰

[peak_R1,peak_sigma1] = my_findpeaks(...
    sigma_band1,...
    R_smooth1,...
    min_peak_distance,...
    min_peak_prominence);


%% 11. 自动检测反射谷
% 将曲线取负以后寻找峰，即得到原曲线的谷

[negative_trough_R1,trough_sigma1] = my_findpeaks(...
    sigma_band1,...
    -R_smooth1,...
    min_peak_distance,...
    min_peak_prominence);

trough_R1 = -negative_trough_R1;


%% 12. 计算附件1相邻峰和谷的波数差

delta_peak1   = diff(peak_sigma1);
delta_trough1 = diff(trough_sigma1);


%% 13. 绘制附件1峰谷识别结果

figure('Position',[200 100 1100 600]);

plot(sigma_band1,R_band1,'LineWidth',0.8);
hold on;

plot(sigma_band1,R_smooth1,'LineWidth',1.5);

scatter(peak_sigma1,peak_R1,55,'o','filled');
scatter(trough_sigma1,trough_R1,55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件1：入射角10°干涉峰谷自动识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    'SG平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

ax = gca;
tb = axtoolbar(ax);
tb.Visible = 'off';
drawnow;

exportgraphics(gcf,...
    '附件1_10度_峰谷识别.png',...
    'Resolution',300);

hold off;


%% ==========================================================
%                  附件2：15°
%% ==========================================================

%% 14. 截取候选稳定干涉区间

index_band2 = sigma2 >= sigma_min & sigma2 <= sigma_max;

sigma_band2 = sigma2(index_band2);
R_band2     = R2(index_band2);


%% 15. 自定义 Savitzky-Golay 平滑

R_smooth2 = my_sgolay(...
    R_band2,...
    smooth_window,...
    sgolay_order);


%% 16. 自动检测反射峰

[peak_R2,peak_sigma2] = my_findpeaks(...
    sigma_band2,...
    R_smooth2,...
    min_peak_distance,...
    min_peak_prominence);


%% 17. 自动检测反射谷

[negative_trough_R2,trough_sigma2] = my_findpeaks(...
    sigma_band2,...
    -R_smooth2,...
    min_peak_distance,...
    min_peak_prominence);

trough_R2 = -negative_trough_R2;


%% 18. 计算附件2相邻峰和谷的波数差

delta_peak2   = diff(peak_sigma2);
delta_trough2 = diff(trough_sigma2);


%% 19. 绘制附件2峰谷识别结果

figure('Position',[200 100 1100 600]);

plot(sigma_band2,R_band2,'LineWidth',0.8);
hold on;

plot(sigma_band2,R_smooth2,'LineWidth',1.5);

scatter(peak_sigma2,peak_R2,55,'o','filled');
scatter(trough_sigma2,trough_R2,55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件2：入射角15°干涉峰谷自动识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    'SG平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

ax = gca;
tb = axtoolbar(ax);
tb.Visible = 'off';
drawnow;

exportgraphics(gcf,...
    '附件2_15度_峰谷识别.png',...
    'Resolution',300);

hold off;


%% ==========================================================
%                     输出峰谷结果
%% ==========================================================

fprintf('\n');
fprintf('========================================================\n');
fprintf('             附件1：入射角10°峰谷检测结果\n');
fprintf('========================================================\n');

peak_number1 = (1:length(peak_sigma1))';

peak_table1 = table(...
    peak_number1,...
    peak_sigma1,...
    peak_R1,...
    'VariableNames',...
    {'序号','峰值波数_cm_1','反射率_percent'});

disp('附件1检测得到的干涉峰：');
disp(peak_table1);

trough_number1 = (1:length(trough_sigma1))';

trough_table1 = table(...
    trough_number1,...
    trough_sigma1,...
    trough_R1,...
    'VariableNames',...
    {'序号','谷值波数_cm_1','反射率_percent'});

disp('附件1检测得到的干涉谷：');
disp(trough_table1);


%% 附件1峰间距统计

fprintf('\n附件1峰间距：\n');
disp(delta_peak1');

if ~isempty(delta_peak1)
    fprintf('峰间距平均值 = %.4f cm^-1\n',mean(delta_peak1));
    fprintf('峰间距标准差 = %.4f cm^-1\n',std(delta_peak1));
    fprintf('峰间距变异系数 CV = %.4f %%\n',...
        std(delta_peak1)/mean(delta_peak1)*100);
end


%% 附件1谷间距统计

fprintf('\n附件1谷间距：\n');
disp(delta_trough1');

if ~isempty(delta_trough1)
    fprintf('谷间距平均值 = %.4f cm^-1\n',mean(delta_trough1));
    fprintf('谷间距标准差 = %.4f cm^-1\n',std(delta_trough1));
    fprintf('谷间距变异系数 CV = %.4f %%\n',...
        std(delta_trough1)/mean(delta_trough1)*100);
end


fprintf('\n');
fprintf('========================================================\n');
fprintf('             附件2：入射角15°峰谷检测结果\n');
fprintf('========================================================\n');

peak_number2 = (1:length(peak_sigma2))';

peak_table2 = table(...
    peak_number2,...
    peak_sigma2,...
    peak_R2,...
    'VariableNames',...
    {'序号','峰值波数_cm_1','反射率_percent'});

disp('附件2检测得到的干涉峰：');
disp(peak_table2);

trough_number2 = (1:length(trough_sigma2))';

trough_table2 = table(...
    trough_number2,...
    trough_sigma2,...
    trough_R2,...
    'VariableNames',...
    {'序号','谷值波数_cm_1','反射率_percent'});

disp('附件2检测得到的干涉谷：');
disp(trough_table2);


%% 附件2峰间距统计

fprintf('\n附件2峰间距：\n');
disp(delta_peak2');

if ~isempty(delta_peak2)
    fprintf('峰间距平均值 = %.4f cm^-1\n',mean(delta_peak2));
    fprintf('峰间距标准差 = %.4f cm^-1\n',std(delta_peak2));
    fprintf('峰间距变异系数 CV = %.4f %%\n',...
        std(delta_peak2)/mean(delta_peak2)*100);
end


%% 附件2谷间距统计

fprintf('\n附件2谷间距：\n');
disp(delta_trough2');

if ~isempty(delta_trough2)
    fprintf('谷间距平均值 = %.4f cm^-1\n',mean(delta_trough2));
    fprintf('谷间距标准差 = %.4f cm^-1\n',std(delta_trough2));
    fprintf('谷间距变异系数 CV = %.4f %%\n',...
        std(delta_trough2)/mean(delta_trough2)*100);
end


%% =========================================================
% 自定义 Savitzky-Golay 平滑函数
% 不需要 Signal Processing Toolbox
%% =========================================================

function y_smooth = my_sgolay(y,window,order)

    y = y(:);

    if mod(window,2) == 0
        error('SG平滑窗口长度必须为奇数');
    end

    if order >= window
        error('多项式阶数必须小于窗口长度');
    end

    if length(y) < window
        error('数据长度必须大于SG平滑窗口长度');
    end

    half_window = (window-1)/2;

    % 构造局部横坐标
    x = (-half_window:half_window)';

    % 构造多项式设计矩阵
    A = zeros(window,order+1);

    for k = 0:order
        A(:,k+1) = x.^k;
    end

    % 最小二乘矩阵
    G = (A'*A)\A';

    % 中心点平滑系数
    h = G(1,:);

    % 两端镜像扩展
    y_left  = flipud(y(2:half_window+1));
    y_right = flipud(y(end-half_window:end-1));

    y_extend = [
        y_left
        y
        y_right
        ];

    % 卷积得到平滑结果
    y_smooth = conv(y_extend,h,'valid');

end


%% =========================================================
% 自定义峰值检测函数
% 不需要 Signal Processing Toolbox
%
% 输入：
% x              横坐标（波数）
% y              信号
% min_distance   相邻峰最小距离
% min_prominence 最小局部显著度
%
% 输出：
% peak_y         峰值高度
% peak_x         峰对应的横坐标
%% =========================================================

function [peak_y,peak_x] = my_findpeaks(...
    x,y,min_distance,min_prominence)

    x = x(:);
    y = y(:);

    % 1. 找所有局部极大值候选点
    candidate = find(...
        y(2:end-1) > y(1:end-2) & ...
        y(2:end-1) >= y(3:end)) + 1;

    if isempty(candidate)
        peak_y = [];
        peak_x = [];
        return;
    end

    % 2. 根据横坐标步长确定局部搜索窗口
    dx = median(diff(x));

    window_points = round(min_distance/dx);
    window_points = max(window_points,1);

    % 3. 计算每一个候选峰的局部显著度
    prominence = zeros(size(candidate));

    for i = 1:length(candidate)

        idx = candidate(i);

        left  = max(1,idx-window_points);
        right = min(length(y),idx+window_points);

        left_min  = min(y(left:idx));
        right_min = min(y(idx:right));

        baseline = max(left_min,right_min);

        prominence(i) = y(idx)-baseline;

    end

    % 4. 删除显著度不足的伪峰
    valid = prominence >= min_prominence;

    candidate  = candidate(valid);
    prominence = prominence(valid);

    if isempty(candidate)
        peak_y = [];
        peak_x = [];
        return;
    end

    % 5. 按横坐标顺序排序
    [~,order] = sort(x(candidate));

    candidate  = candidate(order);
    prominence = prominence(order);

    % 6. 强制满足最小峰间距
    selected = candidate(1);
    selected_prominence = prominence(1);

    for i = 2:length(candidate)

        current = candidate(i);

        if x(current)-x(selected(end)) >= min_distance

            selected(end+1,1) = current;
            selected_prominence(end+1,1) = prominence(i);

        else

            % 两个候选峰过近时保留显著度较大的那个
            if prominence(i) > selected_prominence(end)

                selected(end) = current;
                selected_prominence(end) = prominence(i);

            end

        end

    end

    % 7. 输出最终峰位置和峰值
    peak_x = x(selected);
    peak_y = y(selected);

end
