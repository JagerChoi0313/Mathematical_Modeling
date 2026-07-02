%% 第二问：线光源长度为 3.12mm 时测试屏反射光亮区散点图
% 图中中文标注版
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

% 最优线光源长度
L = 3.12;               % mm

% 测试屏位置
screen_x = p + 25000;   % 焦点正前方 25m，即 25000mm

% 测试屏上 A、B、C 点坐标
A = [screen_x, 0, 0];
B = [screen_x, 1300, 0];
C = [screen_x, 2600, 0];

% B、C 点附近接收圆半径
r_receive = 10;         % mm

% 离散步长
dy_source = 0.1;        % 线光源离散步长，mm
d_surface = 1;          % 抛物面离散步长，mm

% 中文字体设置
fontName = 'Microsoft YaHei';   % 如果显示乱码，可改为 'SimHei' 或 '宋体'

fprintf('===================== 参数设置 =====================\n');
fprintf('线光源长度 L = %.2f mm\n', L);
fprintf('抛物面焦距 p = %.2f mm\n', p);
fprintf('测试屏平面 x = %.2f mm\n', screen_x);
fprintf('A 点坐标：A = (%.2f, %.2f, %.2f)\n', A(1), A(2), A(3));
fprintf('B 点坐标：B = (%.2f, %.2f, %.2f)\n', B(1), B(2), B(3));
fprintf('C 点坐标：C = (%.2f, %.2f, %.2f)\n', C(1), C(2), C(3));
fprintf('====================================================\n\n');

%% ===================== 2. 抛物面离散化 =====================

[y_grid, z_grid] = meshgrid(-R:d_surface:R, -R:d_surface:R);

% 只保留圆形开口范围内的点
surface_mask = (y_grid.^2 + z_grid.^2 <= R^2);

y0 = y_grid(surface_mask);
z0 = z_grid(surface_mask);

% 由抛物面方程 y^2 + z^2 = 60x 求 x0
x0 = (y0.^2 + z0.^2) / (4*p);

fprintf('抛物面离散点数量：%d\n', length(x0));

%% ===================== 3. 计算测试屏上的全部落点 =====================

[yG_all, zG_all, NB, NC] = get_screen_points_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive);

fprintf('测试屏落点总数：%d\n', length(yG_all));
fprintf('B 点附近接收圆内光线数量 NB = %d\n', NB);
fprintf('C 点附近接收圆内光线数量 NC = %d\n', NC);

%% ===================== 4. 绘制测试屏反射光亮区散点图 =====================

figure('Color','w');

% 绘制全部反射光落点
plot(yG_all, zG_all, '.', ...
    'MarkerSize', 3, ...
    'Color', [0.10, 0.45, 0.85]);
hold on;

% 绘制 A、B、C 点
plot(A(2), A(3), 'ko', ...
    'MarkerFaceColor', 'k', ...
    'MarkerSize', 7);

plot(B(2), B(3), 'ro', ...
    'MarkerFaceColor', 'r', ...
    'MarkerSize', 7);

plot(C(2), C(3), 'go', ...
    'MarkerFaceColor', 'g', ...
    'MarkerSize', 7);

% 绘制 B、C 点附近接收圆
theta = linspace(0, 2*pi, 400);

plot(B(2) + r_receive*cos(theta), ...
     B(3) + r_receive*sin(theta), ...
     'r--', 'LineWidth', 1.5);

plot(C(2) + r_receive*cos(theta), ...
     C(3) + r_receive*sin(theta), ...
     'g--', 'LineWidth', 1.5);

% 绘制坐标轴辅助线
xline(0, 'k-', 'LineWidth', 0.8);
yline(0, 'k-', 'LineWidth', 0.8);

% 标注 A、B、C 点
text(A(2)+40, A(3)+45, 'A 点（0,0）', ...
    'FontName', fontName, ...
    'FontSize', 11, ...
    'Color', 'k');

text(B(2)+40, B(3)+45, 'B 点（1300,0）', ...
    'FontName', fontName, ...
    'FontSize', 11, ...
    'Color', 'r');

text(C(2)-330, C(3)+45, 'C 点（2600,0）', ...
    'FontName', fontName, ...
    'FontSize', 11, ...
    'Color', 'g');

% 标注统计结果
text(-2650, -700, ...
    ['B 点附近光线数量 N_B = ', num2str(NB), ...
     '，C 点附近光线数量 N_C = ', num2str(NC)], ...
    'FontName', fontName, ...
    'FontSize', 11, ...
    'Color', 'k');

% 坐标轴与标题
xlabel('测试屏水平方向 y / mm', ...
    'FontName', fontName, ...
    'FontSize', 12);

ylabel('测试屏竖直方向 z / mm', ...
    'FontName', fontName, ...
    'FontSize', 12);

title('线光源长度为 3.12mm 时测试屏反射光亮区散点图', ...
    'FontName', fontName, ...
    'FontSize', 14, ...
    'FontWeight', 'bold');

% 图例
legend({'反射光落点', 'A 点', 'B 点', 'C 点', ...
        'B 点接收圆', 'C 点接收圆'}, ...
        'FontName', fontName, ...
        'FontSize', 10, ...
        'Location', 'northeast');

grid on;
box on;
axis equal;

% 显示范围，可根据论文排版调整
xlim([-2800, 2800]);
ylim([-900, 900]);

% 坐标轴字体
set(gca, ...
    'FontName', fontName, ...
    'FontSize', 11, ...
    'LineWidth', 1);

%% ===================== 5. 保存图片 =====================
% 运行后会在当前文件夹保存高清图片
set(gcf, 'PaperPositionMode', 'auto');
print(gcf, '测试屏反射光亮区散点图_中文标注版', '-dpng', '-r600');

fprintf('\n图片已保存为：测试屏反射光亮区散点图_中文标注版.png\n');

%% ===================== 6. 局部函数 =====================

function [yG_all, zG_all, NB, NC] = get_screen_points_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive)

    % 线光源离散化
    num_source = round(L / dy_source) + 1;
    y_source = linspace(-L/2, L/2, num_source);

    % 线光源点 P 的 x、z 坐标固定
    x2 = p;
    z2 = 0;

    % 初始化
    yG_all = [];
    zG_all = [];
    NB = 0;
    NC = 0;

    for i = 1:length(y_source)

        y2 = y_source(i);

        %% ---------- 1. 计算法线参数 lambda ----------
        % 抛物面方程：y^2 + z^2 = 60x
        % 法向量：n = (-60, 2y0, 2z0)
        % 根据 P 关于法线的对称关系计算 lambda

        lambda = (y0.*y2 + z0.*z2 + 30*x0 - 30*x2 - y0.^2 - z0.^2) ...
                 ./ (1800 + 2*y0.^2 + 2*z0.^2);

        %% ---------- 2. 计算入射点关于法线的对称点 Q ----------
        x3 = 2*x0 - 120*lambda - x2;
        y3 = 2*(2*lambda + 1).*y0 - y2;
        z3 = 2*(2*lambda + 1).*z0 - z2;

        %% ---------- 3. 计算反射光线与测试屏交点 ----------
        denominator = x3 - x0;

        % 避免分母为 0
        valid = abs(denominator) > 1e-12;

        mu = zeros(size(x0));
        mu(valid) = (screen_x - x0(valid)) ./ denominator(valid);

        % 只保留向测试屏方向传播的反射光线
        valid = valid & (mu > 0);

        yG = y0(valid) + mu(valid).*(y3(valid) - y0(valid));
        zG = z0(valid) + mu(valid).*(z3(valid) - z0(valid));

        yG_all = [yG_all; yG(:)];
        zG_all = [zG_all; zG(:)];

        %% ---------- 4. 统计 B、C 点附近接收圆内落点数量 ----------
        dist_B_square = (yG - B(2)).^2 + (zG - B(3)).^2;
        dist_C_square = (yG - C(2)).^2 + (zG - C(3)).^2;

        NB = NB + sum(dist_B_square <= r_receive^2);
        NC = NC + sum(dist_C_square <= r_receive^2);
    end
end