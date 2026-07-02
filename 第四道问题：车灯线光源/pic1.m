%% 图1 车灯线光源与测试屏空间位置示意图
% 坐标系：
% x轴：水平方向，线光源方向
% y轴：车灯对称轴，指向正前方
% z轴：竖直方向

clear; clc; close all;

%% 1. 基本参数
R = 36;              % 车灯开口半径，单位：mm
d = 21.6;            % 车灯深度，单位：mm
f = R^2/(4*d);       % 焦距，单位：mm
L = 8;               % 线光源长度，单位：mm，可改为第一问求得的最优长度

% 实际测试屏位置
screen_y_real = f + 25000;     % 实际测试屏 y 坐标，单位：mm

% 为了便于作图，对测试屏位置进行示意压缩
screen_y_show = 170;           % 图中显示的测试屏位置，非真实比例
screen_x_scale = 0.035;        % A、B、C 水平距离显示比例

% A、B、C 点实际横向距离
AB_real = 1300;                % mm
AC_real = 2600;                % mm

% A、B、C 点在图中的显示坐标
A_show = [0, screen_y_show, 0];
B_show = [AB_real*screen_x_scale, screen_y_show, 0];
C_show = [AC_real*screen_x_scale, screen_y_show, 0];

%% 2. 绘制旋转抛物面 x^2 + z^2 = 60y
theta = linspace(0, 2*pi, 120);
r = linspace(0, R, 60);
[Theta, RR] = meshgrid(theta, r);

X = RR .* cos(Theta);
Z = RR .* sin(Theta);
Y = RR.^2 / (4*f);

figure('Color','w','Position',[100 100 1000 720]);
hold on; grid on; box on;

surf(X, Y, Z, ...
    'FaceColor',[0.70 0.85 1.00], ...
    'EdgeColor',[0.55 0.65 0.75], ...
    'FaceAlpha',0.55, ...
    'LineWidth',0.25);

%% 3. 绘制开口圆边界
theta_rim = linspace(0, 2*pi, 300);
x_rim = R*cos(theta_rim);
z_rim = R*sin(theta_rim);
y_rim = d*ones(size(theta_rim));

plot3(x_rim, y_rim, z_rim, ...
    'Color',[0.15 0.25 0.45], ...
    'LineWidth',1.8);

%% 4. 绘制焦点 F 和线光源
F = [0, f, 0];

plot3(F(1), F(2), F(3), ...
    'ko', 'MarkerSize',7, 'MarkerFaceColor','k');

text(F(1)+2, F(2)+4, F(3)+3, ...
    'F(0,15,0)', ...
    'FontSize',11, 'FontName','Microsoft YaHei');

% 线光源沿 x 轴放置
x_source = linspace(-L/2, L/2, 100);
y_source = f * ones(size(x_source));
z_source = zeros(size(x_source));

plot3(x_source, y_source, z_source, ...
    'r-', 'LineWidth',5);

plot3([-L/2, L/2], [f, f], [0, 0], ...
    'ro', 'MarkerSize',5, 'MarkerFaceColor','r');

text(0, f-10, -8, ...
    '线光源', ...
    'Color','r', ...
    'FontSize',11, 'FontName','Microsoft YaHei', ...
    'HorizontalAlignment','center');

%% 5. 绘制车灯对称轴
plot3([0,0], [0,screen_y_show+20], [0,0], ...
    'k--', 'LineWidth',1.4);

text(3, 90, 4, ...
    '车灯对称轴', ...
    'FontSize',10, 'FontName','Microsoft YaHei');

%% 6. 绘制测试屏
screen_x_min = -25;
screen_x_max = C_show(1) + 25;
screen_z_min = -45;
screen_z_max = 45;

screen_X = [screen_x_min screen_x_max screen_x_max screen_x_min];
screen_Y = screen_y_show * ones(1,4);
screen_Z = [screen_z_min screen_z_min screen_z_max screen_z_max];

patch(screen_X, screen_Y, screen_Z, ...
    [0.92 0.92 0.92], ...
    'FaceAlpha',0.40, ...
    'EdgeColor',[0.35 0.35 0.35], ...
    'LineWidth',1.2);

text(screen_x_min+5, screen_y_show+4, screen_z_max+5, ...
    '测试屏 y=25015 mm（示意压缩显示）', ...
    'FontSize',10, 'FontName','Microsoft YaHei');

%% 7. 绘制 A、B、C 三点
plot3(A_show(1), A_show(2), A_show(3), ...
    'ko', 'MarkerSize',7, 'MarkerFaceColor','k');
plot3(B_show(1), B_show(2), B_show(3), ...
    'bo', 'MarkerSize',7, 'MarkerFaceColor','b');
plot3(C_show(1), C_show(2), C_show(3), ...
    'mo', 'MarkerSize',7, 'MarkerFaceColor','m');

% A、B、C 所在水平线
plot3([A_show(1), C_show(1)], ...
      [screen_y_show, screen_y_show], ...
      [0, 0], ...
      'k-', 'LineWidth',1.2);

text(A_show(1)-6, A_show(2)+2, A_show(3)-6, ...
    'A', 'FontSize',12, 'FontWeight','bold', 'FontName','Microsoft YaHei');

text(B_show(1)-2, B_show(2)+2, B_show(3)-6, ...
    'B', 'FontSize',12, 'FontWeight','bold', 'Color','b', 'FontName','Microsoft YaHei');

text(C_show(1)-2, C_show(2)+2, C_show(3)-6, ...
    'C', 'FontSize',12, 'FontWeight','bold', 'Color','m', 'FontName','Microsoft YaHei');

text((A_show(1)+B_show(1))/2-4, screen_y_show+2, 6, ...
    'AB=1.3 m', ...
    'FontSize',9, 'FontName','Microsoft YaHei');

text((B_show(1)+C_show(1))/2-4, screen_y_show+2, 6, ...
    'BC=1.3 m', ...
    'FontSize',9, 'FontName','Microsoft YaHei');

%% 8. 绘制 F 到 A 的示意距离线
plot3([F(1), A_show(1)], [F(2), A_show(2)], [F(3), A_show(3)], ...
    'Color',[0.25 0.25 0.25], ...
    'LineStyle','-.', ...
    'LineWidth',1.2);

text(6, (F(2)+screen_y_show)/2, 8, ...
    'FA=25 m', ...
    'FontSize',10, 'FontName','Microsoft YaHei');

%% 9. 绘制坐标轴箭头
axis_len_x = 80;
axis_len_y = screen_y_show + 40;
axis_len_z = 65;

quiver3(0,0,0, axis_len_x,0,0, ...
    'Color',[0.1 0.1 0.1], 'LineWidth',1.8, 'MaxHeadSize',0.08);
quiver3(0,0,0, 0,axis_len_y,0, ...
    'Color',[0.1 0.1 0.1], 'LineWidth',1.8, 'MaxHeadSize',0.08);
quiver3(0,0,0, 0,0,axis_len_z, ...
    'Color',[0.1 0.1 0.1], 'LineWidth',1.8, 'MaxHeadSize',0.08);

text(axis_len_x+4, 0, 0, ...
    'x 线光源方向', ...
    'FontSize',11, 'FontName','Microsoft YaHei');

text(0, axis_len_y+5, 0, ...
    'y 车灯正前方', ...
    'FontSize',11, 'FontName','Microsoft YaHei');

text(0, 0, axis_len_z+4, ...
    'z 竖直方向', ...
    'FontSize',11, 'FontName','Microsoft YaHei');

%% 10. 图形美化
xlabel('x / mm', 'FontSize',12, 'FontName','Times New Roman');
ylabel('y / mm', 'FontSize',12, 'FontName','Times New Roman');
zlabel('z / mm', 'FontSize',12, 'FontName','Times New Roman');

title('车灯线光源与测试屏空间位置示意图', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'FontName','Microsoft YaHei');

axis equal;
xlim([-60, C_show(1)+40]);
ylim([-10, screen_y_show+45]);
zlim([-55, 75]);

view(38, 24);

set(gca, ...
    'FontSize',11, ...
    'LineWidth',1.0, ...
    'GridLineStyle','--', ...
    'GridAlpha',0.25, ...
    'FontName','Times New Roman');

legend({'抛物面反光面','开口边界','焦点 F','线光源','车灯对称轴','测试屏'}, ...
    'Location','northeastoutside', ...
    'FontName','Microsoft YaHei', ...
    'FontSize',9);

%% 11. 保存图片
exportgraphics(gcf, '图1_车灯线光源与测试屏空间位置示意图.png', 'Resolution', 300);