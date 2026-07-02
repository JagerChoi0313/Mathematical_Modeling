%% 抛物面反射光路示意图
% 用于论文图：反射点处法线与反射光线几何关系图
% 图中展示：
% P：线光源上的一点
% M：抛物面反射点
% D：P 到法线的垂足
% Q：P 关于法线的对称点
% PM：入射光线
% MQ：反射光线
% n：反射点处法线方向

clear; clc; close all;

%% ===================== 1. 基本参数 =====================
R = 36;              % 车灯开口半径，mm
h = 21.6;            % 车灯深度，mm
f = R^2/(4*h);       % 焦距，f=15mm
L = 3.12;            % 线光源长度，mm

% 抛物面方程：
% y^2 + z^2 = 4fx = 60x

%% ===================== 2. 绘制旋转抛物面 =====================
theta = linspace(0, 2*pi, 120);
x = linspace(0, h, 80);
[Theta, X] = meshgrid(theta, x);

rho = sqrt(4*f*X);
Y = rho .* cos(Theta);
Z = rho .* sin(Theta);

figure('Color','w');

hSurface = surf(X, Y, Z);
set(hSurface, ...
    'FaceAlpha', 0.28, ...
    'EdgeColor', [0.45 0.45 0.90], ...
    'FaceColor', [0.75 0.85 1]);

hold on;

%% ===================== 3. 绘制抛物面开口边界 =====================
theta2 = linspace(0, 2*pi, 300);
Xrim = h * ones(size(theta2));
Yrim = R * cos(theta2);
Zrim = R * sin(theta2);

hRim = plot3(Xrim, Yrim, Zrim, 'b', 'LineWidth', 1.8);

%% ===================== 4. 设置线光源点 P 和反射点 M =====================
% 线光源位于 x=f, z=0，沿 y 轴方向
% 这里取线光源右端附近一点作为示意点 P
x2 = f;
y2 = L/2;
z2 = 0;
P = [x2, y2, z2];

% 取抛物面上的一个反射点 M，要求 y0^2+z0^2 <= R^2
y0 = 24;
z0 = 12;
x0 = (y0^2 + z0^2) / (4*f);
M = [x0, y0, z0];

%% ===================== 5. 计算法线、垂足 D 和对称点 Q =====================
% 抛物面隐函数：
% Phi(x,y,z)=y^2+z^2-60x=0
% 法向量：
n = [-60, 2*y0, 2*z0];
n_unit = n / norm(n);

% 法线方程：
% (x-x0)/(-60) = (y-y0)/(2y0) = (z-z0)/(2z0) = lambda
%
% 根据 PD 与法线垂直，可得 lambda
lambda = (y0*y2 + z0*z2 + 30*x0 - 30*x2 - y0^2 - z0^2) ...
         / (1800 + 2*y0^2 + 2*z0^2);

% 垂足 D
xD = x0 - 60*lambda;
yD = (2*lambda + 1)*y0;
zD = (2*lambda + 1)*z0;
D = [xD, yD, zD];

% P 关于法线的对称点 Q
x3 = 2*x0 - 120*lambda - x2;
y3 = 2*(2*lambda + 1)*y0 - y2;
z3 = 2*(2*lambda + 1)*z0 - z2;
Q = [x3, y3, z3];

%% ===================== 6. 绘制线光源 =====================
y_source = linspace(-L/2, L/2, 100);
x_source = f * ones(size(y_source));
z_source = zeros(size(y_source));

hSource = plot3(x_source, y_source, z_source, 'r', 'LineWidth', 4);

plot3(P(1), P(2), P(3), 'ro', ...
    'MarkerFaceColor', 'r', 'MarkerSize', 8);
text(P(1), P(2), P(3), '  P', ...
    'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');

%% ===================== 7. 绘制反射点 M、垂足 D、对称点 Q =====================
plot3(M(1), M(2), M(3), 'ko', ...
    'MarkerFaceColor', 'k', 'MarkerSize', 8);
text(M(1), M(2), M(3), '  M', ...
    'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold');

plot3(D(1), D(2), D(3), 'mo', ...
    'MarkerFaceColor', 'm', 'MarkerSize', 7);
text(D(1), D(2), D(3), '  D', ...
    'FontSize', 12, 'Color', 'm', 'FontWeight', 'bold');

plot3(Q(1), Q(2), Q(3), 'go', ...
    'MarkerFaceColor', 'g', 'MarkerSize', 8);
text(Q(1), Q(2), Q(3), '  Q', ...
    'FontSize', 12, 'Color', 'g', 'FontWeight', 'bold');

%% ===================== 8. 绘制入射光线 PM =====================
hIncident = plot3([P(1), M(1)], [P(2), M(2)], [P(3), M(3)], ...
    'r-', 'LineWidth', 2.2);

% 入射方向箭头
v_in = M - P;
quiver3(P(1), P(2), P(3), ...
    0.75*v_in(1), 0.75*v_in(2), 0.75*v_in(3), ...
    0, 'r', 'LineWidth', 1.8, 'MaxHeadSize', 0.6);

text((P(1)+M(1))/2, (P(2)+M(2))/2, (P(3)+M(3))/2, ...
    '  入射光线', 'FontSize', 11, 'Color', 'r');

%% ===================== 9. 绘制反射光线 MQ =====================
% 为了示意清楚，将反射光线沿 MQ 方向延长
v_ref = Q - M;
Q_extend = M + 2.4 * v_ref;

hReflect = plot3([M(1), Q_extend(1)], ...
                 [M(2), Q_extend(2)], ...
                 [M(3), Q_extend(3)], ...
                 'Color', [1.00 0.45 0.00], ...
                 'LineWidth', 2.5);

quiver3(M(1), M(2), M(3), ...
    1.5*v_ref(1), 1.5*v_ref(2), 1.5*v_ref(3), ...
    0, 'Color', [1.00 0.45 0.00], ...
    'LineWidth', 1.8, 'MaxHeadSize', 0.6);

text(M(1)+0.8*v_ref(1), M(2)+0.8*v_ref(2), M(3)+0.8*v_ref(3), ...
    '  反射光线', 'FontSize', 11, 'Color', [1.00 0.35 0.00]);

%% ===================== 10. 绘制法线 =====================
normal_len = 35;
N1 = M - normal_len * n_unit;
N2 = M + normal_len * n_unit;

hNormal = plot3([N1(1), N2(1)], ...
                [N1(2), N2(2)], ...
                [N1(3), N2(3)], ...
                'm--', 'LineWidth', 2);

quiver3(M(1), M(2), M(3), ...
    18*n_unit(1), 18*n_unit(2), 18*n_unit(3), ...
    0, 'm', 'LineWidth', 1.8, 'MaxHeadSize', 0.7);

text(M(1)+18*n_unit(1), M(2)+18*n_unit(2), M(3)+18*n_unit(3), ...
    '  法线 n', 'FontSize', 11, 'Color', 'm');

%% ===================== 11. 绘制 PD 和 DQ 辅助线 =====================
plot3([P(1), D(1)], [P(2), D(2)], [P(3), D(3)], ...
    'k:', 'LineWidth', 1.5);

plot3([D(1), Q(1)], [D(2), Q(2)], [D(3), Q(3)], ...
    'k:', 'LineWidth', 1.5);

text(D(1), D(2)-4, D(3), ...
    'P、Q 关于法线对称', 'FontSize', 10, 'Color', 'k');

%% ===================== 12. 绘制测试屏示意平面 =====================
% 这里只是示意反射光线向前传播，测试屏位置非真实比例
screen_x_show = 90;

y_plane = linspace(-10, 75, 2);
z_plane = linspace(-20, 55, 2);
[Yp, Zp] = meshgrid(y_plane, z_plane);
Xp = screen_x_show * ones(size(Yp));

hScreen = surf(Xp, Yp, Zp);
set(hScreen, ...
    'FaceAlpha', 0.15, ...
    'EdgeColor', [0.2 0.7 0.2], ...
    'FaceColor', [0.6 1 0.6]);

% 求反射光线与示意测试屏的交点 G
mu_show = (screen_x_show - M(1)) / (Q(1) - M(1));
G = M + mu_show * (Q - M);

plot3(G(1), G(2), G(3), 'bs', ...
    'MarkerFaceColor', 'b', 'MarkerSize', 7);
text(G(1), G(2), G(3), '  G', ...
    'FontSize', 12, 'Color', 'b', 'FontWeight', 'bold');

plot3([M(1), G(1)], [M(2), G(2)], [M(3), G(3)], ...
    'Color', [1.00 0.45 0.00], ...
    'LineWidth', 1.8);

text(screen_x_show, -8, 48, '测试屏示意', ...
    'FontSize', 11, 'Color', [0 0.5 0]);

%% ===================== 13. 坐标轴与文字标注 =====================
axis_len_x = 105;
axis_len_y = 75;
axis_len_z = 55;

quiver3(0,0,0, axis_len_x,0,0, 0, ...
    'k', 'LineWidth', 1.6, 'MaxHeadSize', 0.3);
quiver3(0,0,0, 0,axis_len_y,0, 0, ...
    'k', 'LineWidth', 1.6, 'MaxHeadSize', 0.3);
quiver3(0,0,0, 0,0,axis_len_z, 0, ...
    'k', 'LineWidth', 1.6, 'MaxHeadSize', 0.3);

text(axis_len_x, 0, 0, '  x', ...
    'FontSize', 12, 'FontWeight', 'bold');
text(0, axis_len_y, 0, '  y', ...
    'FontSize', 12, 'FontWeight', 'bold');
text(0, 0, axis_len_z, '  z', ...
    'FontSize', 12, 'FontWeight', 'bold');

text(5, -30, 43, '旋转抛物面：y^2+z^2=60x', ...
    'FontSize', 11, 'Color', [0 0 0.8]);

text(f, -6, 2, '线光源', ...
    'FontSize', 11, 'Color', 'r');

%% ===================== 14. 图形美化 =====================
xlabel('x / mm');
ylabel('y / mm');
zlabel('z / mm');

title('反射点处法线与反射光线几何关系示意图');

grid on;
axis equal;
box on;

xlim([-5, 110]);
ylim([-45, 80]);
zlim([-30, 60]);

view(38, 24);

legend([hSurface, hRim, hSource, hIncident, hReflect, hNormal, hScreen], ...
    {'旋转抛物面', '开口边界', '线光源', '入射光线 PM', ...
     '反射光线 MQ', '法线', '测试屏示意'}, ...
     'Location', 'northeastoutside');

%% ===================== 15. 保存图片 =====================
% 需要保存时取消下面两行注释
% set(gcf, 'PaperPositionMode', 'auto');
% print(gcf, '抛物面反射光路示意图', '-dpng', '-r600');