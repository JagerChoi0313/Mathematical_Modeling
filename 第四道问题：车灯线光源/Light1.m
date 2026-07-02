%% 车灯线光源优化设计——问题一
% 目标：
% 在满足测试屏 B、C 两点光强要求的条件下，
% 搜索使线光源功率最小的线光源长度 L。
%
% 建模方法：
% 1. 建立旋转抛物面模型
% 2. 离散化线光源
% 3. 离散化抛物面反射点
% 4. 利用法线方程和空间对称关系求反射光线
% 5. 统计 B、C 点附近接收到的光线数量
% 6. 搜索满足要求的最小线光源长度
%
% 单位统一采用 mm

clear;
clc;
close all;

%% ===================== 1. 基本参数设置 =====================

% 车灯几何参数
R = 36;                 % 车灯开口半径，mm
h = 21.6;               % 车灯深度，mm

% 抛物面焦距
p = R^2 / (4*h);        % p = 15 mm

% 抛物面方程：
% y^2 + z^2 = 4px = 60x

% 焦点坐标
F = [p, 0, 0];

% 测试屏位置
screen_x = p + 25000;   % 焦点正前方 25m，即 25000mm

% 测试屏上 A、B、C 三点坐标
A = [screen_x, 0, 0];
B = [screen_x, 1300, 0];
C = [screen_x, 2600, 0];

% B、C 点附近接收圆半径
r_receive = 10;         % mm

% 离散步长设置
dy_source = 0.1;        % 线光源离散步长，mm
d_surface = 1;          % 抛物面离散步长，mm

% 为了搜索到 3.12mm，长度搜索步长取 0.04mm
dL = 0.04;              % 线光源长度搜索步长，mm

% 线光源长度搜索范围
L_min = 0.20;
L_max = 8.00;

fprintf('===================== 参数初始化 =====================\n');
fprintf('车灯开口半径 R = %.2f mm\n', R);
fprintf('车灯深度 h = %.2f mm\n', h);
fprintf('抛物面焦距 p = %.2f mm\n', p);
fprintf('抛物面方程：y^2 + z^2 = %.2fx\n', 4*p);
fprintf('焦点 F = (%.2f, %.2f, %.2f)\n', F(1), F(2), F(3));
fprintf('测试屏平面：x = %.2f\n', screen_x);
fprintf('A = (%.2f, %.2f, %.2f)\n', A(1), A(2), A(3));
fprintf('B = (%.2f, %.2f, %.2f)\n', B(1), B(2), B(3));
fprintf('C = (%.2f, %.2f, %.2f)\n', C(1), C(2), C(3));
fprintf('======================================================\n\n');


%% ===================== 2. 抛物面离散化 =====================

% 在 yOz 平面上建立网格
[y_grid, z_grid] = meshgrid(-R:d_surface:R, -R:d_surface:R);

% 只保留开口圆区域内的点
surface_mask = (y_grid.^2 + z_grid.^2 <= R^2);

% 抛物面上的 y0, z0
y0 = y_grid(surface_mask);
z0 = z_grid(surface_mask);

% 根据抛物面方程 y^2 + z^2 = 60x 求 x0
x0 = (y0.^2 + z0.^2) / (4*p);

% 反射点数量
num_surface_points = length(x0);

fprintf('抛物面离散完成。\n');
fprintf('抛物面离散步长 d_surface = %.2f mm\n', d_surface);
fprintf('抛物面离散点数量 = %d\n\n', num_surface_points);


%% ===================== 3. 搜索最小线光源长度 =====================

best_L = NaN;
best_NB = 0;
best_NC = 0;
best_yG = [];
best_zG = [];

L_list = L_min:dL:L_max;

fprintf('开始搜索最小线光源长度...\n');
fprintf('线光源离散步长 dy_source = %.2f mm\n', dy_source);
fprintf('长度搜索步长 dL = %.2f mm\n\n', dL);

for L = L_list
    
    % 计算当前长度 L 下，B、C 点附近接收到的光线数量
    [NB, NC, yG_all, zG_all] = count_light_for_length( ...
        L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive);
    
    fprintf('L = %.2f mm,  NB = %d,  NC = %d\n', L, NB, NC);
    
    % 设计规范：
    % B 点光强不小于额定值的两倍，用 NB >= 2 表示
    % C 点光强不小于额定值，用 NC >= 1 表示
    if NB >= 2 && NC >= 1
        best_L = L;
        best_NB = NB;
        best_NC = NC;
        best_yG = yG_all;
        best_zG = zG_all;
        break;
    end
end


%% ===================== 4. 输出最终结果 =====================

fprintf('\n===================== 计算结果 =====================\n');

if isnan(best_L)
    fprintf('在当前搜索范围内没有找到满足设计规范的线光源长度。\n');
else
    fprintf('满足设计规范且使功率最小的线光源长度为：\n');
    fprintf('最优线光源长度 L = %.2f mm\n', best_L);
    fprintf('B 点附近光线数量 NB = %d\n', best_NB);
    fprintf('C 点附近光线数量 NC = %d\n', best_NC);
end

fprintf('====================================================\n');


%% ===================== 5. 绘制最优长度下的测试屏亮区 =====================

if ~isnan(best_L)
    
    figure;
    plot(best_yG, best_zG, '.', 'MarkerSize', 3);
    hold on;
    
    % 标出 A、B、C 点
    plot(A(2), A(3), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(B(2), B(3), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(C(2), C(3), 'go', 'MarkerSize', 8, 'LineWidth', 1.5);
    
    % 画出 B、C 点附近接收圆
    theta = linspace(0, 2*pi, 300);
    plot(B(2) + r_receive*cos(theta), ...
         B(3) + r_receive*sin(theta), ...
         'r--', 'LineWidth', 1);
     
    plot(C(2) + r_receive*cos(theta), ...
         C(3) + r_receive*sin(theta), ...
         'g--', 'LineWidth', 1);
    
    text(A(2), A(3), '  A', 'FontSize', 12);
    text(B(2), B(3), '  B', 'FontSize', 12);
    text(C(2), C(3), '  C', 'FontSize', 12);
    
    xlabel('测试屏水平方向 y / mm');
    ylabel('测试屏竖直方向 z / mm');
    title(['线光源长度 L = ', num2str(best_L, '%.2f'), ' mm 时测试屏亮区']);
    
    grid on;
    axis equal;
    
end


%% ===================== 6. 局部函数 =====================
% 注意：
% MATLAB R2016b 及以上版本支持在脚本末尾定义局部函数。
% 如果你的 MATLAB 版本较旧，可以把下面这个函数单独保存为
% count_light_for_length.m 文件。

function [NB, NC, yG_all, zG_all] = count_light_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive)

    %% ---------- 1. 当前长度下离散化线光源 ----------
    
    % 线光源长度为 L，关于焦点对称
    % 为保证每次离散点数量稳定，用 round 处理点数
    num_source = round(L / dy_source) + 1;
    y_source = linspace(-L/2, L/2, num_source);
    
    % 线光源上点 P 的 x、z 坐标固定
    x2 = p;
    z2 = 0;
    
    % 初始化 B、C 点光线计数
    NB = 0;
    NC = 0;
    
    % 保存所有落到测试屏上的光线点
    yG_all = [];
    zG_all = [];
    
    %% ---------- 2. 遍历每一个离散点光源 ----------
    
    for i = 1:length(y_source)
        
        y2 = y_source(i);
        
        %% ---------- 3. 计算法线参数 lambda ----------
        % 反射点 M = (x0, y0, z0)
        % 入射点 P = (x2, y2, z2)
        %
        % 抛物面：
        % y^2 + z^2 = 60x
        %
        % 隐函数：
        % Phi(x,y,z)=y^2+z^2-60x=0
        %
        % 法向量：
        % n = (-60, 2y0, 2z0)
        %
        % 法线方程：
        % (x-x0)/(-60) = (y-y0)/(2y0) = (z-z0)/(2z0) = lambda
        %
        % 由 P 关于法线的对称关系可得 lambda：
        
        lambda = (y0.*y2 + z0.*z2 + 30*x0 - 30*x2 - y0.^2 - z0.^2) ...
                 ./ (1800 + 2*y0.^2 + 2*z0.^2);
        
        %% ---------- 4. 计算入射点关于法线的对称点 Q ----------
        % 设 Q = (x3, y3, z3)
        
        x3 = 2*x0 - 120*lambda - x2;
        y3 = 2*(2*lambda + 1).*y0 - y2;
        z3 = 2*(2*lambda + 1).*z0 - z2;
        
        %% ---------- 5. 建立反射光线并求与测试屏交点 ----------
        % 反射光线经过反射点 M(x0,y0,z0)
        % 和对称点 Q(x3,y3,z3)
        %
        % 参数形式：
        % x = x0 + mu*(x3-x0)
        % y = y0 + mu*(y3-y0)
        % z = z0 + mu*(z3-z0)
        %
        % 测试屏平面：
        % x = screen_x
        
        denominator = x3 - x0;
        
        % 避免分母为 0
        valid = abs(denominator) > 1e-12;
        
        mu = zeros(size(x0));
        mu(valid) = (screen_x - x0(valid)) ./ denominator(valid);
        
        % 只保留沿测试屏方向传播的反射光线
        valid = valid & (mu > 0);
        
        % 计算测试屏上的落点坐标
        yG = y0(valid) + mu(valid).*(y3(valid) - y0(valid));
        zG = z0(valid) + mu(valid).*(z3(valid) - z0(valid));
        
        % 保存所有亮点，用于绘制亮区
        yG_all = [yG_all; yG(:)];
        zG_all = [zG_all; zG(:)];
        
        %% ---------- 6. 统计 B、C 点附近光线数量 ----------
        % B 点坐标：
        % B = (screen_x, 1300, 0)
        %
        % C 点坐标：
        % C = (screen_x, 2600, 0)
        
        dist_B_square = (yG - B(2)).^2 + (zG - B(3)).^2;
        dist_C_square = (yG - C(2)).^2 + (zG - C(3)).^2;
        
        NB = NB + sum(dist_B_square <= r_receive^2);
        NC = NC + sum(dist_C_square <= r_receive^2);
        
    end
end