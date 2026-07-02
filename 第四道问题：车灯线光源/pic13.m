% 清理环境变量
clear; clc; close all;

% 创建图形窗口
figure('Color', 'w', 'Position', [100, 100, 900, 700]);
hold on; grid off; axis off;
axis equal;

%% 1. 定义参数
a = 0.1; % 抛物面方程参数: x = a*(y^2 + z^2)
R_max = 5; % 抛物面最大半径
x_screen = 12; % 测试屏所在的 X 坐标

%% 2. 绘制 3D 坐标轴 (O-XYZ)
axis_len = 8;
% X轴
quiver3(0, 0, 0, axis_len, 0, 0, 'b', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
text(axis_len+0.5, 0, 0, 'X', 'FontSize', 12, 'Color', 'b', 'HorizontalAlignment', 'center');
% Y轴
quiver3(0, 0, 0, 0, axis_len, 0, 'b', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
text(0, axis_len+0.5, 0, 'Y', 'FontSize', 12, 'Color', 'b', 'HorizontalAlignment', 'center');
% Z轴
quiver3(0, 0, 0, 0, 0, axis_len, 'b', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
text(0, 0, axis_len+0.5, 'Z', 'FontSize', 12, 'Color', 'b', 'HorizontalAlignment', 'center');
% 原点 O
text(-0.5, -0.5, 0, 'O', 'FontSize', 12, 'Color', 'b');

%% 3. 绘制旋转抛物面 (反射镜)
[Theta, R] = meshgrid(linspace(0, 2*pi, 40), linspace(0, R_max, 20));
Y_surf = R .* cos(Theta);
Z_surf = R .* sin(Theta);
X_surf = a * (Y_surf.^2 + Z_surf.^2);

% 只画一半或者让其半透明以体现立体感
surf(X_surf, Y_surf, Z_surf, 'FaceColor', 'none', 'EdgeColor', [0.2 0.4 0.8], 'EdgeAlpha', 0.5);

% 绘制抛物面开口处的灰色底面 (体现截面)
fill3(a*R_max^2 * ones(size(Theta(1,:))), R_max*cos(Theta(1,:)), R_max*sin(Theta(1,:)), ...
    [0.8 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'k', 'LineStyle', '--');

%% 4. 定义入射点和光线追踪
% 选择抛物面上的一个点 P
y_p = 2.5; z_p = 2.5;
x_p = a * (y_p^2 + z_p^2);
P = [x_p, y_p, z_p];

% 计算该点指向外部(凸面侧)的法向量，用于计算反射
% 曲面 F(x,y,z) = x - a*y^2 - a*z^2 = 0
% 梯度(法向量) = [1, -2*a*y, -2*a*z]
normal_out = [1, -2*a*y_p, -2*a*z_p]; 
% 因为光从内部射来，我们取指向抛物面内部的法线用于计算
normal_in = [-1, 2*a*y_p, 2*a*z_p];
normal_in = normal_in / norm(normal_in);

% 定义入射光向量 (假设从坐标系某处射向点 P)
% 设定一个起始点
P_start = [5, -2, 5]; 
V_in = P - P_start;
V_in = V_in / norm(V_in); % 归一化入射向量

% 计算反射光向量 (反射定律: R = I - 2*(I·N)*N)
V_out = V_in - 2 * dot(V_in, normal_in) * normal_in;
V_out = V_out / norm(V_out);

% 计算反射光与测试屏的交点
% 直线方程: P_screen = P + t * V_out; 其中 P_screen(1) = x_screen
t = (x_screen - P(1)) / V_out(1);
P_intersect = P + t * V_out;

%% 5. 绘制光线和法线
% 绘制入射光
quiver3(P_start(1), P_start(2), P_start(3), V_in(1)*norm(P-P_start), V_in(2)*norm(P-P_start), V_in(3)*norm(P-P_start), ...
    0, 'Color', [0.2 0.4 0.8], 'LineWidth', 1.5, 'MaxHeadSize', 0.1);
text(P_start(1)+1, P_start(2)+2, P_start(3)-1, '入射光', 'Color', [0.2 0.4 0.8], 'FontSize', 11);

% 绘制法线 (虚线)
N_len = 6;
P_normal_end = P - normal_in * N_len; % 向内延伸
plot3([P(1), P_normal_end(1)], [P(2), P_normal_end(2)], [P(3), P_normal_end(3)], '--', 'Color', [0.2 0.4 0.8], 'LineWidth', 1.5);
text(P_normal_end(1)+1, P_normal_end(2), P_normal_end(3), '法线', 'Color', [0.2 0.4 0.8], 'FontSize', 11);

% 绘制反射光
quiver3(P(1), P(2), P(3), V_out(1)*t, V_out(2)*t, V_out(3)*t, ...
    0, 'Color', [0.2 0.4 0.8], 'LineWidth', 1.5, 'MaxHeadSize', 0.1);
text(P(1)+3, P(2)+1, P(3)-1, '反射光', 'Color', [0.2 0.4 0.8], 'FontSize', 11);

% 在入射点 P 绘制一个小圆点和切线辅助线
plot3(P(1), P(2), P(3), '.', 'MarkerSize', 15, 'Color', [0.2 0.4 0.8]);
% 简单的切线示意
plot3([P(1)-1, P(1)+1], [P(2)-0.5, P(2)+0.5], [P(3)-1, P(3)+1], 'Color', [0.2 0.4 0.8], 'LineWidth', 1);
plot3([P(1)-1, P(1)+1], [P(2)+1, P(2)-1], [P(3), P(3)], 'Color', [0.2 0.4 0.8], 'LineWidth', 1);

%% 6. 绘制测试屏
screen_width = 8;
screen_height = 10;
% 屏幕的四个顶点
screen_V = [x_screen, -screen_width/2, -screen_height/2;
            x_screen, screen_width/2,  -screen_height/2;
            x_screen, screen_width/2,  screen_height/2;
            x_screen, -screen_width/2, screen_height/2];
patch('Vertices', screen_V, 'Faces', [1 2 3 4], 'FaceColor', 'none', 'EdgeColor', [0 0.4 0.7], 'LineWidth', 1.5);
% 为了体现厚度，再画一层
patch('Vertices', screen_V+[0.5,0,0], 'Faces', [1 2 3 4], 'FaceColor', 'none', 'EdgeColor', [0 0.4 0.7], 'LineWidth', 1.5);
plot3([x_screen, x_screen+0.5], [-screen_width/2, -screen_width/2], [screen_height/2, screen_height/2], 'Color', [0 0.4 0.7], 'LineWidth', 1.5);
plot3([x_screen, x_screen+0.5], [screen_width/2, screen_width/2], [screen_height/2, screen_height/2], 'Color', [0 0.4 0.7], 'LineWidth', 1.5);
plot3([x_screen, x_screen+0.5], [screen_width/2, screen_width/2], [-screen_height/2, -screen_height/2], 'Color', [0 0.4 0.7], 'LineWidth', 1.5);

text(x_screen, 0, screen_height/2 + 2, '测试屏', 'Color', [0 0.4 0.7], 'FontSize', 12, 'Rotation', -15);

%% 7. 绘制屏幕上的点
% 绘制反射光打在屏幕上的蓝灰点
plot3(P_intersect(1), P_intersect(2), P_intersect(3), '.', 'MarkerSize', 20, 'Color', [0.5 0.6 0.7]);

% 绘制参考红点 A, B, C
P_A = P_intersect + [0, 1.5, -1];
P_B = P_intersect + [0, 1.5, 0];
P_C = P_intersect + [0, 1.5, 1];
plot3(P_A(1), P_A(2), P_A(3), 'r.', 'MarkerSize', 20); text(P_A(1), P_A(2), P_A(3)-0.8, 'A', 'Color', [0.2 0.4 0.8]);
plot3(P_B(1), P_B(2), P_B(3), 'r.', 'MarkerSize', 20); text(P_B(1), P_B(2), P_B(3)-0.8, 'B', 'Color', [0.2 0.4 0.8]);
plot3(P_C(1), P_C(2), P_C(3), 'r.', 'MarkerSize', 20); text(P_C(1), P_C(2), P_C(3)-0.8, 'C', 'Color', [0.2 0.4 0.8]);

%% 8. 调整视角和标题
view(40, 20); % 调整 3D 视角以匹配原图的透视关系
title('图 2：反射光照射情景图', 'Position', [x_screen/2, -screen_width, -screen_height], 'FontSize', 14, 'FontWeight', 'normal');

% 调整坐标轴显示范围
xlim([-2, x_screen+2]);
ylim([-6, 6]);
zlim([-6, 6]);