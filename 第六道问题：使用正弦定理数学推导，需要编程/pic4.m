clc; clear; close all;

% =========================================================
%  第一种大类情况示意图：分别绘制(a)(b)(c)
% =========================================================

lineColor = [0.30 0.35 0.48];   % 蓝灰色线条，接近原图
lwCircle  = 1.15;
lwLine    = 0.75;
fontName  = 'Times New Roman';

draw_case_a(lineColor, lwCircle, lwLine, fontName);
draw_case_b(lineColor, lwCircle, lwLine, fontName);
draw_case_c(lineColor, lwCircle, lwLine, fontName);


% =========================================================
%  图(a)
% =========================================================
function draw_case_a(lineColor, lwCircle, lwLine, fontName)

figure('Color','w','Position',[200 200 420 360]);
hold on; axis equal; axis off;

R = 1;
O = [0, 0];

% 圆上点位置
P_i = point_on_circle(R, 78);
P_j = point_on_circle(R, 188);
P_k = point_on_circle(R, 20);

% 画圆
draw_circle(O, R, lineColor, lwCircle);

% 画线段
draw_seg(P_i, P_k, lineColor, lwLine);
draw_seg(P_j, P_k, lineColor, lwLine);
draw_seg(O,   P_k, lineColor, lwLine);
draw_seg(O,   P_i, lineColor, lwLine);

% 画点
draw_point(O);
draw_point(P_i);
draw_point(P_j);
draw_point(P_k);

% 点标注
text(P_i(1)-0.02, P_i(2)+0.12, 'i', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(P_j(1)-0.10, P_j(2)-0.02, 'j', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(P_k(1)+0.08, P_k(2)+0.02, 'k', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(O(1)-0.02, O(2)-0.10, 'o', ...
    'FontName',fontName,'FontSize',13,'HorizontalAlignment','center');

% 角度弧线
draw_angle_arc(P_k, P_j, P_i, 0.22, lineColor, lwLine);
draw_angle_arc(P_k, P_i, O,   0.28, lineColor, lwLine);
draw_angle_arc(P_k, O,   P_j, 0.16, lineColor, lwLine);

% 角度文字
text(P_k(1)-0.31, P_k(2)+0.00, '$\alpha_1$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

text(P_k(1)-0.21, P_k(2)+0.13, '$\alpha_2$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

text(P_k(1)-0.18, P_k(2)-0.10, '$\alpha_3$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

% 子图编号
text(0, -1.35, '(a)', ...
    'FontName',fontName,'FontSize',13,'HorizontalAlignment','center');

xlim([-1.35 1.35]);
ylim([-1.45 1.25]);

end


% =========================================================
%  图(b) 优化版
% =========================================================
function draw_case_b(lineColor, lwCircle, lwLine, fontName)

figure('Color','w','Position',[650 200 420 360]);
hold on; axis equal; axis off;

R = 1;
O = [0, 0];

% 圆上点位置：调整后更接近原图(b)
P_i = point_on_circle(R, 142);
P_j = point_on_circle(R, 232);
P_k = point_on_circle(R, 22);

% 画圆
draw_circle(O, R, lineColor, lwCircle);

% 画线段
draw_seg(P_i, P_k, lineColor, lwLine);
draw_seg(P_j, P_k, lineColor, lwLine);
draw_seg(O,   P_k, lineColor, lwLine);

% 画点
draw_point(O);
draw_point(P_i);
draw_point(P_j);
draw_point(P_k);

% 点标注
text(P_i(1)-0.10, P_i(2)+0.08, 'i', ...
    'FontName',fontName,'FontSize',15,'HorizontalAlignment','center');

text(P_j(1)-0.07, P_j(2)-0.11, 'j', ...
    'FontName',fontName,'FontSize',15,'HorizontalAlignment','center');

text(P_k(1)+0.09, P_k(2)+0.02, 'k', ...
    'FontName',fontName,'FontSize',15,'HorizontalAlignment','center');

text(O(1)-0.06, O(2)-0.11, 'o', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

% 角度弧线：在 k 点处画两个小角
draw_angle_arc2(P_k, P_i, O,   0.28, lineColor, lwLine);
draw_angle_arc2(P_k, O,   P_j, 0.22, lineColor, lwLine);

% α 标注：重新放到角内部，避免跑偏
text(P_k(1)-0.32, P_k(2)-0.23, '$\alpha_1$', ...
    'Interpreter','latex','FontSize',13,'FontName',fontName);

text(P_k(1)-0.48, P_k(2)-0.48, '$\alpha_2$', ...
    'Interpreter','latex','FontSize',13,'FontName',fontName);

% 子图编号
text(0, -1.33, '(b)', ...
    'FontName',fontName,'FontSize',15,'HorizontalAlignment','center');

% 控制画面留白
xlim([-1.28 1.28]);
ylim([-1.40 1.22]);

end


% =========================================================
%  优化后的角度弧线函数
%  V 是角顶点，A、B 是两条边上的点
% =========================================================
function draw_angle_arc2(V, A, B, r, color, lw)

ang1 = atan2d(A(2)-V(2), A(1)-V(1));
ang2 = atan2d(B(2)-V(2), B(1)-V(1));

% 保证画较小夹角
d = mod(ang2 - ang1 + 180, 360) - 180;
ang = linspace(ang1, ang1 + d, 80);

x = V(1) + r*cosd(ang);
y = V(2) + r*sind(ang);

plot(x, y, 'Color', color, 'LineWidth', lw);

end

% =========================================================
%  图(c)
% =========================================================
function draw_case_c(lineColor, lwCircle, lwLine, fontName)

figure('Color','w','Position',[1100 200 420 360]);
hold on; axis equal; axis off;

R = 1;
O = [0, 0];

% 圆上点位置
P_i = point_on_circle(R, 230);
P_j = point_on_circle(R, 290);
P_k = point_on_circle(R, 38);

% 画圆
draw_circle(O, R, lineColor, lwCircle);

% 画线段
draw_seg(P_i, P_k, lineColor, lwLine);
draw_seg(P_j, P_k, lineColor, lwLine);
draw_seg(O,   P_k, lineColor, lwLine);

% 画点
draw_point(O);
draw_point(P_i);
draw_point(P_j);
draw_point(P_k);

% 点标注
text(P_i(1)-0.10, P_i(2)-0.04, 'i', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(P_j(1)+0.07, P_j(2)-0.08, 'j', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(P_k(1)+0.07, P_k(2)+0.05, 'k', ...
    'FontName',fontName,'FontSize',14,'HorizontalAlignment','center');

text(O(1)-0.04, O(2)-0.10, 'o', ...
    'FontName',fontName,'FontSize',13,'HorizontalAlignment','center');

% 角度弧线
draw_angle_arc(P_k, P_i, O,   0.25, lineColor, lwLine);
draw_angle_arc(P_k, O,   P_j, 0.20, lineColor, lwLine);
draw_angle_arc(P_k, P_i, P_j, 0.36, lineColor, lwLine);

% 角度文字
text(P_k(1)-0.34, P_k(2)-0.18, '$\alpha_1$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

text(P_k(1)-0.17, P_k(2)-0.22, '$\alpha_2$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

text(P_k(1)-0.50, P_k(2)-0.52, '$\alpha_3$', ...
    'Interpreter','latex','FontSize',12,'FontName',fontName);

% 子图编号
text(0, -1.35, '(c)', ...
    'FontName',fontName,'FontSize',13,'HorizontalAlignment','center');

xlim([-1.35 1.35]);
ylim([-1.45 1.25]);

end


% =========================================================
%  工具函数：圆上一点
% =========================================================
function P = point_on_circle(R, theta_deg)
P = [R*cosd(theta_deg), R*sind(theta_deg)];
end


% =========================================================
%  工具函数：画圆
% =========================================================
function draw_circle(O, R, color, lw)

theta = linspace(0, 2*pi, 600);
x = O(1) + R*cos(theta);
y = O(2) + R*sin(theta);

plot(x, y, 'Color', color, 'LineWidth', lw);

end


% =========================================================
%  工具函数：画线段
% =========================================================
function draw_seg(P1, P2, color, lw)

plot([P1(1), P2(1)], [P1(2), P2(2)], ...
    'Color', color, 'LineWidth', lw);

end


% =========================================================
%  工具函数：画点
% =========================================================
function draw_point(P)

plot(P(1), P(2), 'k.', 'MarkerSize', 9);

end


% =========================================================
%  工具函数：画角度弧线
%  V 是角的顶点，A、B 分别是两条射线上的点
% =========================================================
function draw_angle_arc(V, A, B, r, color, lw)

ang1 = atan2d(A(2)-V(2), A(1)-V(1));
ang2 = atan2d(B(2)-V(2), B(1)-V(1));

% 取较小夹角方向
d = mod(ang2 - ang1 + 180, 360) - 180;
ang = linspace(ang1, ang1 + d, 80);

x = V(1) + r*cosd(ang);
y = V(2) + r*sind(ang);

plot(x, y, 'Color', color, 'LineWidth', lw);

end