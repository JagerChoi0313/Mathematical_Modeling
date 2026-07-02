%% 车灯线光源空间坐标模型图
% 说明：
% 1. 本图用于论文中的"空间坐标模型示意图"
% 2. 为了便于显示，测试屏与 B、C 点位置采用"示意压缩显示"，因此本图为非比例示意图
% 3. 坐标轴定义：
%    x轴——车灯对称轴，指向正前方
%    y轴——水平横向，线光源方向
%    z轴——竖直方向

clear; clc; close all;

%% ===================== 1. 基本参数 =====================
R = 36;              % 车灯开口半径(mm)
h = 21.6;            % 车灯深度(mm)
f = R^2/(4*h);       % 焦距(mm)，应为15
L = 3.12;            % 线光源长度(mm)，可改成其他值

% 焦点
F = [f, 0, 0];

% 实际测试屏位置与点坐标（单位：mm）
screen_x_real = f + 25000;
A_real = [screen_x_real, 0, 0];
B_real = [screen_x_real, 1300, 0];
C_real = [screen_x_real, 2600, 0];

%% ===================== 2. 为绘图做压缩显示 =====================
% 由于 25m 与 36mm 尺度差异太大，直接画图会看不清车灯结构
% 故仅用于示意显示，对测试屏位置和 B、C 点位置做压缩
kx = 100;   % x方向压缩比例
ky = 50;    % y方向压缩比例

screen_x_show = f + 25000/kx;
A_show = [screen_x_show, 0, 0];
B_show = [screen_x_show, 1300/ky, 0];
C_show = [screen_x_show, 2600/ky, 0];

%% ===================== 3. 绘制旋转抛物面 =====================
% 抛物面方程： y^2 + z^2 = 4fx = 60x
theta = linspace(0, 2*pi, 120);
x = linspace(0, h, 80);
[Theta, X] = meshgrid(theta, x);

rho = sqrt(4*f*X);
Y = rho .* cos(Theta);
Z = rho .* sin(Theta);

figure('Color','w');
surf(X, Y, Z, ...
    'FaceAlpha', 0.35, ...
    'EdgeColor', [0.4 0.4 0.9], ...
    'FaceColor', [0.75 0.85 1]);
hold on;

%% ===================== 4. 绘制开口圆 =====================
theta2 = linspace(0, 2*pi, 300);
Yrim = R*cos(theta2);
Zrim = R*sin(theta2);
Xrim = h*ones(size(theta2));
plot3(Xrim, Yrim, Zrim, 'b', 'LineWidth', 1.8);

%% ===================== 5. 绘制线光源 =====================
y_source = linspace(-L/2, L/2, 100);
x_source = f*ones(size(y_source));
z_source = zeros(size(y_source));
plot3(x_source, y_source, z_source, 'r', 'LineWidth', 4);

%% ===================== 6. 绘制焦点与原点 =====================
plot3(0, 0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
text(0, 0, 0, '  O(0,0,0)', 'FontSize', 11, 'Color', 'k');

plot3(F(1), F(2), F(3), 'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 7);
text(F(1), F(2), F(3), '  F(15,0,0)', 'FontSize', 11, 'Color', 'm');

%% ===================== 7. 绘制测试屏 =====================
% 测试屏为平面 x = screen_x_show
y_plane = linspace(-70, 70, 2);
z_plane = linspace(-50, 50, 2);
[Yp, Zp] = meshgrid(y_plane, z_plane);
Xp = screen_x_show * ones(size(Yp));

surf(Xp, Yp, Zp, ...
    'FaceAlpha', 0.15, ...
    'EdgeColor', [0.3 0.7 0.3], ...
    'FaceColor', [0.6 1 0.6]);

%% ===================== 8. 绘制 A、B、C 点 =====================
plot3(A_show(1), A_show(2), A_show(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
text(A_show(1), A_show(2), A_show(3), '  A', 'FontSize', 11, 'Color', 'k');

plot3(B_show(1), B_show(2), B_show(3), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
text(B_show(1), B_show(2), B_show(3), '  B', 'FontSize', 11, 'Color', 'r');

plot3(C_show(1), C_show(2), C_show(3), 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 6);
text(C_show(1), C_show(2), C_show(3), '  C', 'FontSize', 11, 'Color', 'g');

%% ===================== 9. 绘制 FA 方向线 =====================
plot3([F(1), A_show(1)], [F(2), A_show(2)], [F(3), A_show(3)], ...
    '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.2);

%% ===================== 10. 绘制坐标轴 =====================
axis_len_x = screen_x_show + 20;
axis_len_y = 80;
axis_len_z = 60;

quiver3(0,0,0, axis_len_x,0,0, 0, 'k', 'LineWidth', 1.8, 'MaxHeadSize', 0.3);
quiver3(0,0,0, 0,axis_len_y,0, 0, 'k', 'LineWidth', 1.8, 'MaxHeadSize', 0.3);
quiver3(0,0,0, 0,0,axis_len_z, 0, 'k', 'LineWidth', 1.8, 'MaxHeadSize', 0.3);

text(axis_len_x, 0, 0, '  x', 'FontSize', 12, 'FontWeight', 'bold');
text(0, axis_len_y, 0, '  y', 'FontSize', 12, 'FontWeight', 'bold');
text(0, 0, axis_len_z, '  z', 'FontSize', 12, 'FontWeight', 'bold');

%% ===================== 11. 添加辅助标注 =====================
text(f, L/2+2, 0, '线光源', 'Color', 'r', 'FontSize', 11);
text(screen_x_show, -15, 42, '测试屏 x = 25015 mm（压缩示意）', ...
    'Color', [0 0.5 0], 'FontSize', 10);

% 可选：显示抛物面方程
text(5, -55, 45, '旋转抛物面：y^2 + z^2 = 60x', ...
    'FontSize', 11, 'Color', [0 0 0.8]);

%% ===================== 12. 图形美化 =====================
xlabel('x / mm');
ylabel('y / mm');
zlabel('z / mm');

title('车灯线光源空间坐标模型示意图');
grid on;
axis equal;

xlim([-5, screen_x_show + 20]);
ylim([-80, 80]);
zlim([-60, 60]);

view(36, 24);
box on;

legend({'旋转抛物面','开口边界','线光源','焦点F','测试屏','A/B/C点'}, ...
    'Location','northeastoutside');

%% ===================== 13. 保存图片（可选） =====================
% print(gcf,'车灯线光源空间坐标模型图','-dpng','-r600');