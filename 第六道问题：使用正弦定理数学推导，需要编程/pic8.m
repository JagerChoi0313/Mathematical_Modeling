clc; clear; close all;

% =========================================================
% 图3：第三种大类情况示意图
% 与前面图1、图2保持统一风格，但不是原图复刻
% =========================================================

figure('Color','w','Position',[100 120 1100 360]);
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

% ---------- 统一风格 ----------
circleColor = [0.16 0.38 0.34];   % 墨绿色圆
lineColor   = [0.25 0.25 0.25];   % 深灰色线段
arcColor    = [0.55 0.20 0.18];   % 暗红色角弧
pointColor  = [0 0 0];

lwCircle = 1.45;
lwLine   = 0.95;
lwArc    = 1.00;
fontName = 'Times New Roman';

draw_case3_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case3_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case3_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);

% 高清导出
exportgraphics(gcf,'third_type_three_cases_modified.png','Resolution',600);


%% =========================================================
% 图3(a)
% =========================================================
function draw_case3_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [0,0];

% 点位：k 在左上，j 在上方，i 在右上
Pk = point_on_circle(R, 122);
Pj = point_on_circle(R, 72);
Pi = point_on_circle(R, 35);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pk,Pj,lineColor,lwLine);
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pk,pointColor);
draw_point(Pj,pointColor);
draw_point(Pi,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pk(1)-0.07,Pk(2)+0.14,'k', ...
    'FontName',fontName,'FontSize',15);

text(Pj(1)-0.02,Pj(2)+0.14,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pi(1)+0.08,Pi(2)-0.02,'i', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.03,O(2)-0.12,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧：以 k 为顶点
draw_angle_arc(Pk,O, Pj,0.20,arcColor,lwArc);   % alpha1
draw_angle_arc(Pk,Pj,Pi,0.28,arcColor,lwArc);   % alpha2
draw_angle_arc(Pk,O, Pi,0.38,arcColor,lwArc);   % alpha3

% 角标注
text(Pk(1)+0.10,Pk(2)-0.17,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.27,Pk(2)-0.05,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.34,Pk(2)-0.28,'\alpha_3', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

% 子图编号
text(0,-1.32,'(a)', ...
    'FontName',fontName,'FontSize',16, ...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.22]);

end


%% =========================================================
% 图3(b)
% =========================================================
function draw_case3_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [0,0];

% 点位：j 在左上，k 在下方，i 在右上
Pj = point_on_circle(R, 116);
Pk = point_on_circle(R, 260);
Pi = point_on_circle(R, 36);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pk,Pj,lineColor,lwLine);
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(Pi,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pj(1)-0.10,Pj(2)+0.08,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pk(1)-0.02,Pk(2)-0.16,'k', ...
    'FontName',fontName,'FontSize',15);

text(Pi(1)+0.08,Pi(2)-0.02,'i', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.08,O(2)-0.02,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧：以 k 为顶点
draw_angle_arc(Pk,Pj,O, 0.20,arcColor,lwArc);   % alpha3
draw_angle_arc(Pk,O, Pi,0.28,arcColor,lwArc);   % alpha2
draw_angle_arc(Pk,Pj,Pi,0.40,arcColor,lwArc);   % alpha1

% 角标注
text(Pk(1)+0.02,Pk(2)+0.34,'\alpha_3', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.13,Pk(2)+0.49,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.23,Pk(2)+0.22,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

% 子图编号
text(0,-1.32,'(b)', ...
    'FontName',fontName,'FontSize',16, ...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.22]);

end


%% =========================================================
% 图3(c)
% =========================================================
function draw_case3_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [0,0];

% 点位：j 在上方，i 在右上，k 在右下
Pj = point_on_circle(R, 82);
Pi = point_on_circle(R, 35);
Pk = point_on_circle(R, 318);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pk,Pj,lineColor,lwLine);
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pj,pointColor);
draw_point(Pi,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pj(1)-0.04,Pj(2)+0.14,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pi(1)+0.07,Pi(2)+0.02,'i', ...
    'FontName',fontName,'FontSize',15);

text(Pk(1)+0.05,Pk(2)-0.13,'k', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.08,O(2)-0.02,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧：以 k 为顶点
draw_angle_arc(Pk,O, Pj,0.23,arcColor,lwArc);   % alpha1
draw_angle_arc(Pk,Pi,O,0.31,arcColor,lwArc);    % alpha2
draw_angle_arc(Pk,O, Pi,0.39,arcColor,lwArc);   % alpha3

% 角标注
text(Pk(1)-0.22,Pk(2)+0.48,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)-0.05,Pk(2)+0.34,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)-0.28,Pk(2)+0.22,'\alpha_3', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

% 子图编号
text(0,-1.32,'(c)', ...
    'FontName',fontName,'FontSize',16, ...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.22]);

end


%% =========================================================
% 工具函数：圆上一点
% =========================================================
function P = point_on_circle(R,theta)
P = R * [cosd(theta), sind(theta)];
end


%% =========================================================
% 工具函数：画圆
% =========================================================
function draw_circle(R,color,lw)
t = linspace(0,2*pi,800);
plot(R*cos(t),R*sin(t),'Color',color,'LineWidth',lw);
end


%% =========================================================
% 工具函数：画线段
% =========================================================
function draw_seg(P1,P2,color,lw)
plot([P1(1),P2(1)],[P1(2),P2(2)], ...
    'Color',color,'LineWidth',lw);
end


%% =========================================================
% 工具函数：画点
% =========================================================
function draw_point(P,color)
plot(P(1),P(2),'.','Color',color,'MarkerSize',14);
end


%% =========================================================
% 工具函数：画角弧
% V 为角顶点，A、B 为两条边上的点
% =========================================================
function draw_angle_arc(V,A,B,r,color,lw)

ang1 = atan2d(A(2)-V(2), A(1)-V(1));
ang2 = atan2d(B(2)-V(2), B(1)-V(1));

% 取较小夹角方向
d = mod(ang2-ang1+180,360)-180;
ang = linspace(ang1,ang1+d,100);

x = V(1) + r*cosd(ang);
y = V(2) + r*sind(ang);

plot(x,y,'Color',color,'LineWidth',lw);

end