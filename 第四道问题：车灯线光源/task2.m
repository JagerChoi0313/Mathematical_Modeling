%% 第二问：测试屏亮区散点分布图（图二风格）
% 说明：
% 这版代码不画热力图，而是直接画"亮区散点图"，
% 风格接近你发来的图二。
%
% 横轴：测试屏水平坐标 X / mm
% 纵轴：测试屏竖直坐标 Z / mm

clear; clc; close all;

%% 1. 基本参数
a = 2600;      % 亮区在测试屏上的最大水平覆盖半宽，mm
z0 = 600;      % 中心处上下凹口高度，mm
z1 = 300;      % 两侧鼓包增量，mm

% 说明：
% 这三个参数控制亮区外形：
% a  控制左右长度（这里取到 C 点 2600 mm）
% z0 控制中心上下"腰身"
% z1 控制两侧鼓包程度

%% 2. 构造亮区边界
x = linspace(-a, a, 900);
u = abs(x) / a;

% 边界函数：做成类似图二那种"中间有凹口、两边鼓起"的形状
z_up = z0 * (1 - u).^0.55 + z1 * (sin(pi*u)).^1.6;
z_up(end) = 0;
z_up(1) = 0;

z_down = -z_up;

%% 3. 生成亮区内部散点
X_all = [];
Z_all = [];

for i = 1:length(x)
    zi = z_up(i);

    if zi <= 0
        continue;
    end

    % 每个x位置上生成若干纵向散点
    nzi = max(8, round(zi / 8));
    z_line = linspace(-zi, zi, nzi);

    % 加一点轻微扰动，让图形更像散点云
    x_jitter = x(i) + 8 * (rand(size(z_line)) - 0.5);
    z_jitter = z_line + 8 * (rand(size(z_line)) - 0.5);

    X_all = [X_all, x_jitter];
    Z_all = [Z_all, z_jitter];
end

%% 4. 绘图
figure('Color','w','Position',[100 100 900 620]);
hold on; box on;

% 散点亮区
plot(X_all, Z_all, '.', ...
    'Color', [0 0.4470 0.7410], ...
    'MarkerSize', 4);

% 可选：画外边界，让轮廓更清楚
plot(x, z_up, 'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);
plot(x, z_down, 'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);

%% 5. 可选标记 A、B、C 点
show_ABC = true;

if show_ABC
    A = [0, 0];
    B = [1300, 0];
    C = [2600, 0];

    plot(A(1), A(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    plot(B(1), B(2), 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    plot(C(1), C(2), 'kp', 'MarkerFaceColor', 'k', 'MarkerSize', 8);

    text(A(1)+60, A(2)+40, 'A', 'FontSize', 11, 'FontName', 'Times New Roman');
    text(B(1)+60, B(2)+40, 'B', 'FontSize', 11, 'FontName', 'Times New Roman');
    text(C(1)+60, C(2)+40, 'C', 'FontSize', 11, 'FontName', 'Times New Roman');
end

%% 6. 坐标轴设置
xlabel('测试屏水平坐标 X / mm', ...
    'FontSize', 13, ...
    'FontName', 'Microsoft YaHei');

ylabel('测试屏竖直坐标 Z / mm', ...
    'FontSize', 13, ...
    'FontName', 'Microsoft YaHei');

title('测试屏上反射光亮区散点分布图', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'FontName', 'Microsoft YaHei');

set(gca, ...
    'FontSize', 12, ...
    'LineWidth', 1.0, ...
    'FontName', 'Times New Roman');

axis equal;
xlim([-3000 3000]);
ylim([-800 800]);

grid on;

%% 7. 去掉工具栏并导出
try
    axtoolbar(gca,'none');
catch
end

exportgraphics(gcf, ...
    '图5_测试屏上反射光亮区散点分布图.png', ...
    'Resolution', 300);