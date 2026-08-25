clear;
clc;
close all;

%% =========================================================
% 第二问：基于问题一厚度公式 + 双角度反演折射率公式
%
% 核心公式：
%
% (1) 问题一厚度模型
%
%          N
% d = -------------------------------
%     2*sqrt(n^2-sin^2(alpha))*
%       (sigma_(m+N)-sigma_m)
%
%
% (2) 利用同一晶圆在 10°、15° 下的平均条纹周期反演 n
%
%             Delta10^2*sin^2(10°)-Delta15^2*sin^2(15°)
% n = sqrt( ------------------------------------------------ )
%                     Delta10^2-Delta15^2
%
%
% 程序流程：
% 1. 读取附件1、附件2
% 2. 数据清洗
% 3. 截取 1500~4000 cm^-1 候选稳定干涉波段
% 4. 自定义 SG 平滑（不依赖工具箱）
% 5. 自动识别干涉峰、干涉谷
% 6. 峰、谷分别线性拟合条纹周期
% 7. 峰谷共同斜率拟合，得到每个角度的平均条纹周期
% 8. 由 10°、15° 平均条纹周期反演等效折射率 n
% 9. 代回问题一厚度公式计算 d
% 10. 利用逐周期厚度、跨 N 周期厚度进行稳定性分析
%
% 不需要 Signal Processing Toolbox
%
% 请将本程序与：
%   附件1.xlsx
%   附件2.xlsx
% 放在同一文件夹中运行。
%% =========================================================


%% 1. 参数设置

sigma_min = 1500;          % 分析波段下限，cm^-1
sigma_max = 4000;          % 分析波段上限，cm^-1

smooth_window = 61;        % SG平滑窗口，必须为奇数
sgolay_order  = 3;         % 局部多项式阶数

min_peak_distance   = 180; % 最小峰间距离，cm^-1
min_peak_prominence = 0.25;% 最小峰显著度，%


%% 2. 读取数据

data1 = readmatrix('附件1.xlsx');
data2 = readmatrix('附件2.xlsx');

sigma1 = data1(:,1);
R1     = data1(:,2);

sigma2 = data2(:,1);
R2     = data2(:,2);


%% 3. 数据清洗

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

% 波数升序排列
[sigma1,idx1] = sort(sigma1);
R1 = R1(idx1);

[sigma2,idx2] = sort(sigma2);
R2 = R2(idx2);


%% 4. 截取候选稳定干涉区间

band1 = sigma1 >= sigma_min & sigma1 <= sigma_max;
band2 = sigma2 >= sigma_min & sigma2 <= sigma_max;

sigma_band1 = sigma1(band1);
R_band1     = R1(band1);

sigma_band2 = sigma2(band2);
R_band2     = R2(band2);


%% 5. 自定义 SG 平滑

R_smooth1 = my_sgolay(R_band1,smooth_window,sgolay_order);
R_smooth2 = my_sgolay(R_band2,smooth_window,sgolay_order);


%% 6. 峰谷检测：附件1（10°）

[peak_R1,peak_sigma1] = my_findpeaks(...
    sigma_band1,R_smooth1,...
    min_peak_distance,min_peak_prominence);

[neg_trough_R1,trough_sigma1] = my_findpeaks(...
    sigma_band1,-R_smooth1,...
    min_peak_distance,min_peak_prominence);

trough_R1 = -neg_trough_R1;


%% 7. 峰谷检测：附件2（15°）

[peak_R2,peak_sigma2] = my_findpeaks(...
    sigma_band2,R_smooth2,...
    min_peak_distance,min_peak_prominence);

[neg_trough_R2,trough_sigma2] = my_findpeaks(...
    sigma_band2,-R_smooth2,...
    min_peak_distance,min_peak_prominence);

trough_R2 = -neg_trough_R2;


%% 8. 计算峰、谷各自的平均条纹周期
%
% 对同类型极值建立：
%
% sigma_k = Delta_sigma * k + b
%
% 斜率 Delta_sigma 即平均完整干涉周期。
%
% 这种方法使用全部峰（或全部谷），比直接平均相邻差值
% 对单个峰位置误差更稳健。

[Delta_peak_10,R2_peak_10] = period_fit(peak_sigma1);
[Delta_trough_10,R2_trough_10] = period_fit(trough_sigma1);

[Delta_peak_15,R2_peak_15] = period_fit(peak_sigma2);
[Delta_trough_15,R2_trough_15] = period_fit(trough_sigma2);


%% 9. 峰谷共同斜率拟合平均条纹周期
%
% 峰和谷属于同一完整周期体系，但相位不同，因此：
%
% 峰：sigma_p(k) = Delta_sigma*k + b_p
% 谷：sigma_v(k) = Delta_sigma*k + b_v
%
% 两者共享同一个 Delta_sigma，而允许不同截距。
%
% 最终使用该共同斜率作为该入射角下的平均条纹周期。

[Delta_10,R2_joint_10] = common_period_fit(...
    peak_sigma1,trough_sigma1);

[Delta_15,R2_joint_15] = common_period_fit(...
    peak_sigma2,trough_sigma2);


%% 10. 根据双角度公式反演等效折射率 n

[n_eff,ratio_n,den_n] = inverse_n_from_two_angles(...
    Delta_10,Delta_15);


%% 11. 将 n 代回问题一厚度公式
%
% 对平均周期而言：
%
% Delta_sigma = (sigma_(m+N)-sigma_m)/N
%
% 因此问题一公式可等价写为：
%
% d = 1/[2*sqrt(n^2-sin^2(alpha))*Delta_sigma]

d10_um = thickness_from_period(Delta_10,n_eff,10);
d15_um = thickness_from_period(Delta_15,n_eff,15);

d_final_um = (d10_um+d15_um)/2;


%% 12. 分别用"峰周期"和"谷周期"独立反演，用于可靠性检查

[n_peak,~,~] = inverse_n_from_two_angles(...
    Delta_peak_10,Delta_peak_15);

d_peak_10 = thickness_from_period(...
    Delta_peak_10,n_peak,10);

d_peak_15 = thickness_from_period(...
    Delta_peak_15,n_peak,15);


[n_trough,~,~] = inverse_n_from_two_angles(...
    Delta_trough_10,Delta_trough_15);

d_trough_10 = thickness_from_period(...
    Delta_trough_10,n_trough,10);

d_trough_15 = thickness_from_period(...
    Delta_trough_15,n_trough,15);


%% 13. 按问题一原式，跨 N 个周期直接计算厚度
%
% 峰序列：
% N = 峰个数-1
% sigma_(m+N)-sigma_m = 最后一个峰 - 第一个峰
%
% 谷序列同理。

N_peak_10 = length(peak_sigma1)-1;
N_trough_10 = length(trough_sigma1)-1;

N_peak_15 = length(peak_sigma2)-1;
N_trough_15 = length(trough_sigma2)-1;

dN_peak_10 = thickness_from_N(...
    N_peak_10,...
    peak_sigma1(1),peak_sigma1(end),...
    n_eff,10);

dN_trough_10 = thickness_from_N(...
    N_trough_10,...
    trough_sigma1(1),trough_sigma1(end),...
    n_eff,10);

dN_peak_15 = thickness_from_N(...
    N_peak_15,...
    peak_sigma2(1),peak_sigma2(end),...
    n_eff,15);

dN_trough_15 = thickness_from_N(...
    N_trough_15,...
    trough_sigma2(1),trough_sigma2(end),...
    n_eff,15);


%% 14. 逐个相邻周期计算厚度，用于稳定性分析

delta_peak_10   = diff(peak_sigma1);
delta_trough_10 = diff(trough_sigma1);

delta_peak_15   = diff(peak_sigma2);
delta_trough_15 = diff(trough_sigma2);

d_each_peak_10 = thickness_from_period(...
    delta_peak_10,n_eff,10);

d_each_trough_10 = thickness_from_period(...
    delta_trough_10,n_eff,10);

d_each_peak_15 = thickness_from_period(...
    delta_peak_15,n_eff,15);

d_each_trough_15 = thickness_from_period(...
    delta_trough_15,n_eff,15);


%% 15. 输出峰谷位置

fprintf('\n');
fprintf('==========================================================\n');
fprintf('                 第二问计算结果\n');
fprintf('==========================================================\n');

fprintf('\n【附件1：10°】\n');
fprintf('检测峰数 = %d\n',length(peak_sigma1));
fprintf('检测谷数 = %d\n',length(trough_sigma1));

disp('峰值波数 / cm^-1：');
disp(peak_sigma1');

disp('谷值波数 / cm^-1：');
disp(trough_sigma1');


fprintf('\n【附件2：15°】\n');
fprintf('检测峰数 = %d\n',length(peak_sigma2));
fprintf('检测谷数 = %d\n',length(trough_sigma2));

disp('峰值波数 / cm^-1：');
disp(peak_sigma2');

disp('谷值波数 / cm^-1：');
disp(trough_sigma2');


%% 16. 输出周期拟合结果

fprintf('\n');
fprintf('==========================================================\n');
fprintf('                  条纹周期拟合\n');
fprintf('==========================================================\n');

fprintf('\n10°：\n');
fprintf('峰值拟合周期 Delta_peak_10   = %.8f cm^-1\n',...
    Delta_peak_10);
fprintf('峰值周期拟合 R^2             = %.10f\n',...
    R2_peak_10);

fprintf('谷值拟合周期 Delta_trough_10 = %.8f cm^-1\n',...
    Delta_trough_10);
fprintf('谷值周期拟合 R^2             = %.10f\n',...
    R2_trough_10);

fprintf('峰谷共同周期 Delta_10        = %.8f cm^-1\n',...
    Delta_10);
fprintf('峰谷共同拟合 R^2             = %.10f\n',...
    R2_joint_10);


fprintf('\n15°：\n');
fprintf('峰值拟合周期 Delta_peak_15   = %.8f cm^-1\n',...
    Delta_peak_15);
fprintf('峰值周期拟合 R^2             = %.10f\n',...
    R2_peak_15);

fprintf('谷值拟合周期 Delta_trough_15 = %.8f cm^-1\n',...
    Delta_trough_15);
fprintf('谷值周期拟合 R^2             = %.10f\n',...
    R2_trough_15);

fprintf('峰谷共同周期 Delta_15        = %.8f cm^-1\n',...
    Delta_15);
fprintf('峰谷共同拟合 R^2             = %.10f\n',...
    R2_joint_15);


%% 17. 输出 n 与最终厚度

fprintf('\n');
fprintf('==========================================================\n');
fprintf('               双角度反演 n 与厚度\n');
fprintf('==========================================================\n');

fprintf('共同周期 Delta_10 = %.8f cm^-1\n',Delta_10);
fprintf('共同周期 Delta_15 = %.8f cm^-1\n',Delta_15);

fprintf('\n反演等效折射率 n = %.10f\n',n_eff);

fprintf('由10°数据计算厚度 d10 = %.10f um\n',d10_um);
fprintf('由15°数据计算厚度 d15 = %.10f um\n',d15_um);
fprintf('最终平均厚度 d          = %.10f um\n',d_final_um);

fprintf('\n折射率公式中：\n');
fprintf('分母 Delta10^2-Delta15^2 = %.10f\n',den_n);
fprintf('根号内比值                 = %.10f\n',ratio_n);


%% 18. 峰、谷独立反演结果

fprintf('\n');
fprintf('==========================================================\n');
fprintf('                  峰谷独立反演检查\n');
fprintf('==========================================================\n');

fprintf('仅使用峰：\n');
fprintf('n_peak     = %.10f\n',n_peak);
fprintf('d_peak_10  = %.10f um\n',d_peak_10);
fprintf('d_peak_15  = %.10f um\n',d_peak_15);

fprintf('\n仅使用谷：\n');
fprintf('n_trough    = %.10f\n',n_trough);
fprintf('d_trough_10 = %.10f um\n',d_trough_10);
fprintf('d_trough_15 = %.10f um\n',d_trough_15);


%% 19. 跨 N 周期厚度结果

fprintf('\n');
fprintf('==========================================================\n');
fprintf('              按问题一跨 N 周期公式计算\n');
fprintf('==========================================================\n');

fprintf('10°峰：N=%d，d = %.10f um\n',...
    N_peak_10,dN_peak_10);

fprintf('10°谷：N=%d，d = %.10f um\n',...
    N_trough_10,dN_trough_10);

fprintf('15°峰：N=%d，d = %.10f um\n',...
    N_peak_15,dN_peak_15);

fprintf('15°谷：N=%d，d = %.10f um\n',...
    N_trough_15,dN_trough_15);


%% 20. 逐周期厚度稳定性

fprintf('\n');
fprintf('==========================================================\n');
fprintf('                   逐周期厚度稳定性\n');
fprintf('==========================================================\n');

print_stats('10°峰周期',d_each_peak_10);
print_stats('10°谷周期',d_each_trough_10);
print_stats('15°峰周期',d_each_peak_15);
print_stats('15°谷周期',d_each_trough_15);

all_d = [
    d_each_peak_10(:)
    d_each_trough_10(:)
    d_each_peak_15(:)
    d_each_trough_15(:)
    ];

fprintf('\n全部逐周期厚度：\n');
fprintf('平均值 = %.10f um\n',mean(all_d));
fprintf('标准差 = %.10f um\n',std(all_d));
fprintf('CV     = %.6f %%\n',...
    std(all_d)/mean(all_d)*100);

fprintf('==========================================================\n');


%% 21. 数值敏感性提醒
%
% 双角度 n 公式的分母为 Delta10^2-Delta15^2。
% 当 Delta10 和 Delta15 很接近时，n 对条纹周期误差较敏感。

relative_den = abs(den_n) / ...
    ((Delta_10^2+Delta_15^2)/2);

if relative_den < 0.02

    warning(['10°与15°条纹周期较接近，',...
        '反演折射率 n 对峰谷位置误差较敏感。',...
        '请在论文可靠性分析中说明这一点。']);

end


%% =========================================================
% 22. 绘制峰谷识别图
%% =========================================================

figure('Position',[200 100 1100 600]);

plot(sigma_band1,R_band1,'LineWidth',0.8);
hold on;

plot(sigma_band1,R_smooth1,'LineWidth',1.4);

scatter(peak_sigma1,peak_R1,55,'o','filled');
scatter(trough_sigma1,trough_R1,55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件1：10°入射角干涉峰谷识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    '平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;
print(gcf,'附件1_10度_峰谷识别','-dpng','-r300');

hold off;


figure('Position',[200 100 1100 600]);

plot(sigma_band2,R_band2,'LineWidth',0.8);
hold on;

plot(sigma_band2,R_smooth2,'LineWidth',1.4);

scatter(peak_sigma2,peak_R2,55,'o','filled');
scatter(trough_sigma2,trough_R2,55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件2：15°入射角干涉峰谷识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    '平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;
print(gcf,'附件2_15度_峰谷识别','-dpng','-r300');

hold off;


%% =========================================================
% 23. 绘制同类型极值线性拟合图
%% =========================================================

plot_period_fit(...
    peak_sigma1,trough_sigma1,...
    Delta_10,...
    '附件1：10°峰谷共同周期拟合',...
    '附件1_10度_共同周期拟合');

plot_period_fit(...
    peak_sigma2,trough_sigma2,...
    Delta_15,...
    '附件2：15°峰谷共同周期拟合',...
    '附件2_15度_共同周期拟合');


%% =========================================================
% 函数1：双角度公式反演等效折射率 n
%% =========================================================

function [n,ratio,den] = inverse_n_from_two_angles(Delta10,Delta15)

    s10 = sind(10);
    s15 = sind(15);

    numerator = ...
        Delta10^2*s10^2 - ...
        Delta15^2*s15^2;

    den = Delta10^2 - Delta15^2;

    if abs(den) < 1e-12
        error(['Delta_10 与 Delta_15 过于接近，',...
            '折射率反演公式分母接近0，无法稳定求解。']);
    end

    ratio = numerator/den;

    if ratio <= 0
        error(['反演得到 n^2 <= 0，',...
            '请检查峰谷识别结果或分析波段。']);
    end

    n = sqrt(ratio);

    if n <= 1
        warning(['反演得到 n <= 1。',...
            '请检查条纹周期、分析波段及模型适用性。']);
    end

end


%% =========================================================
% 函数2：由平均条纹周期计算厚度
%% =========================================================

function d_um = thickness_from_period(Delta_sigma,n,alpha_deg)

    value = n^2-sind(alpha_deg)^2;

    if value <= 0
        error('n^2-sin^2(alpha) <= 0，无法计算厚度。');
    end

    d_cm = 1 ./ ...
        (2*sqrt(value).*Delta_sigma);

    d_um = d_cm*1e4;

end


%% =========================================================
% 函数3：直接使用问题一跨 N 周期公式
%% =========================================================

function d_um = thickness_from_N(...
    N,sigma_m,sigma_mN,n,alpha_deg)

    if N <= 0
        error('N 必须为正整数。');
    end

    delta_sigma = sigma_mN-sigma_m;

    if delta_sigma <= 0
        error('sigma_(m+N) 必须大于 sigma_m。');
    end

    value = n^2-sind(alpha_deg)^2;

    d_cm = N / ...
        (2*sqrt(value)*delta_sigma);

    d_um = d_cm*1e4;

end


%% =========================================================
% 函数4：单独峰序列或谷序列的周期线性拟合
%% =========================================================

function [Delta,R2] = period_fit(sigma_extrema)

    sigma_extrema = sigma_extrema(:);

    if length(sigma_extrema) < 2
        error('至少需要两个同类型干涉极值。');
    end

    k = (0:length(sigma_extrema)-1)';

    p = polyfit(k,sigma_extrema,1);

    Delta = p(1);

    sigma_fit = polyval(p,k);

    SSE = sum(...
        (sigma_extrema-sigma_fit).^2);

    SST = sum(...
        (sigma_extrema-mean(sigma_extrema)).^2);

    if SST > 0
        R2 = 1-SSE/SST;
    else
        R2 = 1;
    end

end


%% =========================================================
% 函数5：峰谷共同斜率拟合
%
% 峰：sigma_p = Delta*k + b_p
% 谷：sigma_v = Delta*k + b_v
%% =========================================================

function [Delta,R2] = common_period_fit(...
    peak_sigma,trough_sigma)

    peak_sigma   = peak_sigma(:);
    trough_sigma = trough_sigma(:);

    kp = (0:length(peak_sigma)-1)';
    kv = (0:length(trough_sigma)-1)';

    % 参数 beta：
    % beta(1) = 共同周期 Delta
    % beta(2) = 峰截距
    % beta(3) = 谷截距

    A_peak = [
        kp,...
        ones(length(kp),1),...
        zeros(length(kp),1)
        ];

    A_trough = [
        kv,...
        zeros(length(kv),1),...
        ones(length(kv),1)
        ];

    A = [A_peak;A_trough];

    y = [peak_sigma;trough_sigma];

    beta = A\y;

    Delta = beta(1);

    y_fit = A*beta;

    SSE = sum((y-y_fit).^2);
    SST = sum((y-mean(y)).^2);

    R2 = 1-SSE/SST;

end


%% =========================================================
% 函数6：自定义 Savitzky-Golay 平滑
%% =========================================================

function y_smooth = my_sgolay(y,window,order)

    y = y(:);

    if mod(window,2) == 0
        error('SG 平滑窗口长度必须为奇数。');
    end

    if order >= window
        error('多项式阶数必须小于平滑窗口长度。');
    end

    if length(y) < window
        error('数据长度必须大于平滑窗口长度。');
    end

    half_window = (window-1)/2;

    x = (-half_window:half_window)';

    A = zeros(window,order+1);

    for k = 0:order
        A(:,k+1) = x.^k;
    end

    G = (A'*A)\A';

    h = G(1,:);

    % 镜像扩展，减弱端点失真
    y_left = flipud(...
        y(2:half_window+1));

    y_right = flipud(...
        y(end-half_window:end-1));

    y_extend = [
        y_left
        y
        y_right
        ];

    y_smooth = conv(...
        y_extend,h,'valid');

end


%% =========================================================
% 函数7：自定义峰值检测
%% =========================================================

function [peak_y,peak_x] = my_findpeaks(...
    x,y,min_distance,min_prominence)

    x = x(:);
    y = y(:);

    candidate = find(...
        y(2:end-1) > y(1:end-2) & ...
        y(2:end-1) >= y(3:end)) + 1;

    if isempty(candidate)
        peak_y = [];
        peak_x = [];
        return;
    end

    dx = median(diff(x));

    window_points = round(...
        min_distance/dx);

    window_points = max(...
        window_points,1);

    prominence = zeros(size(candidate));

    for i = 1:length(candidate)

        idx = candidate(i);

        left = max(...
            1,idx-window_points);

        right = min(...
            length(y),idx+window_points);

        left_min = min(y(left:idx));
        right_min = min(y(idx:right));

        baseline = max(...
            left_min,right_min);

        prominence(i) = ...
            y(idx)-baseline;

    end

    valid = prominence >= ...
        min_prominence;

    candidate = candidate(valid);
    prominence = prominence(valid);

    if isempty(candidate)
        peak_y = [];
        peak_x = [];
        return;
    end

    [~,order] = sort(x(candidate));

    candidate = candidate(order);
    prominence = prominence(order);

    selected = candidate(1);
    selected_prominence = prominence(1);

    for i = 2:length(candidate)

        current = candidate(i);

        if x(current)-x(selected(end)) >= ...
                min_distance

            selected(end+1,1) = current;
            selected_prominence(end+1,1) = ...
                prominence(i);

        else

            if prominence(i) > ...
                    selected_prominence(end)

                selected(end) = current;
                selected_prominence(end) = ...
                    prominence(i);

            end

        end

    end

    peak_x = x(selected);
    peak_y = y(selected);

end


%% =========================================================
% 函数8：输出统计量
%% =========================================================

function print_stats(name,d)

    d = d(:);

    fprintf('\n%s：\n',name);

    disp(d');

    fprintf('平均厚度 = %.10f um\n',mean(d));
    fprintf('标准差   = %.10f um\n',std(d));

    if mean(d) ~= 0
        fprintf('CV       = %.6f %%\n',...
            std(d)/mean(d)*100);
    end

end


%% =========================================================
% 函数9：绘制共同周期拟合图
%% =========================================================

function plot_period_fit(...
    peak_sigma,trough_sigma,Delta,...
    title_text,file_name)

    peak_sigma = peak_sigma(:);
    trough_sigma = trough_sigma(:);

    kp = (0:length(peak_sigma)-1)';
    kv = (0:length(trough_sigma)-1)';

    % 在固定共同斜率下计算最优截距
    bp = mean(peak_sigma-Delta*kp);
    bv = mean(trough_sigma-Delta*kv);

    fit_peak = Delta*kp+bp;
    fit_trough = Delta*kv+bv;

    figure('Position',[200 100 900 580]);

    scatter(kp,peak_sigma,50,'o','filled');
    hold on;

    plot(kp,fit_peak,'LineWidth',1.5);

    scatter(kv,trough_sigma,50,'v','filled');

    plot(kv,fit_trough,'LineWidth',1.5);

    xlabel('同类型干涉极值相对级次','FontSize',12);
    ylabel('波数 \sigma / cm^{-1}','FontSize',12);

    title(title_text,'FontSize',13);

    legend(...
        '峰值数据',...
        '峰值拟合',...
        '谷值数据',...
        '谷值拟合',...
        'Location','best');

    grid on;
    box on;
    set(gca,'FontSize',11);

    try
        ax = gca;
        tb = axtoolbar(ax);
        tb.Visible = 'off';
    catch
    end

    drawnow;

    print(gcf,file_name,'-dpng','-r300');

    hold off;

end
