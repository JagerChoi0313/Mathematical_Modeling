clc; clear; close all;

% =========================================================
% 图2：第二种大类情况示意图
% 风格与前面三张保持一致，但不完全复刻原图
% =========================================================

figure('Color','w','Position',[100 120 1100 360]);
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

% ---------- 统一绘图风格 ----------
circleColor = [0.16 0.38 0.34];   % 墨绿色圆
lineColor   = [0.25 0.25 0.25];   % 深灰色线段
arcColor    = [0.55 0.20 0.18];   % 暗红色角弧
pointColor  = [0 0 0];

lwCircle = 1.45;
lwLine   = 0.95;
lwArc    = 1.00;
fontName = 'Times New Roman';

draw_case2_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case2_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case2_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);

% 高清导出
exportgraphics(gcf,'second_type_three_cases_modified.png','Resolution',600);


%% =========================================================
% 图2(a)
% =========================================================
function draw_case2_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [0.00, -0.04];

% 点位：保持 k 在上方，i 在右上，j 在左侧
Pi = point_on_circle(R, 35);
Pj = point_on_circle(R, 192);
Pk = point_on_circle(R, 82);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pj,Pk,lineColor,lwLine);
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pi(1)+0.08,Pi(2)-0.02,'i', ...
    'FontName',fontName,'FontSize',15);

text(Pj(1)-0.12,Pj(2)-0.02,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pk(1)+0.02,Pk(2)+0.12,'k', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.04,O(2)-0.12,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧：以 k 为顶点
draw_angle_arc(Pk,Pj,O, 0.23,arcColor,lwArc);   % alpha3
draw_angle_arc(Pk,O, Pi,0.30,arcColor,lwArc);   % alpha1
draw_angle_arc(Pk,Pj,Pi,0.40,arcColor,lwArc);   % alpha2 外侧

% 角标注
text(Pk(1)-0.15,Pk(2)-0.23,'\alpha_3', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.13,Pk(2)-0.25,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.06,Pk(2)-0.48,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

% 子图编号
text(0,-1.32,'(a)', ...
    'FontName',fontName,'FontSize',16, ...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.22]);

end


%% =========================================================
% 图2(b)
% =========================================================
function draw_case2_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [-0.18, -0.02];

% 点位：k 上方，i 右上，j 右下
Pi = point_on_circle(R, 32);
Pj = point_on_circle(R, 286);
Pk = point_on_circle(R, 84);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(Pk,Pj,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pi(1)+0.08,Pi(2)-0.02,'i', ...
    'FontName',fontName,'FontSize',15);

text(Pj(1)-0.02,Pj(2)-0.14,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pk(1)-0.02,Pk(2)+0.12,'k', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.10,O(2)-0.05,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧
draw_angle_arc(Pk,O, Pi,0.24,arcColor,lwArc);   % alpha2
draw_angle_arc(Pk,Pi,Pj,0.34,arcColor,lwArc);   % alpha1
draw_angle_arc(Pk,O, Pj,0.18,arcColor,lwArc);   % alpha3

% 角标注
text(Pk(1)+0.06,Pk(2)-0.19,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.14,Pk(2)-0.50,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)-0.18,Pk(2)-0.37,'\alpha_3', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

% 子图编号
text(0,-1.32,'(b)', ...
    'FontName',fontName,'FontSize',16, ...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.22]);

end


%% =========================================================
% 图2(c)
% =========================================================
function draw_case2_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [-0.02, -0.02];

% 点位：k 左下，j 右下，i 右上
Pk = point_on_circle(R, 220);
Pj = point_on_circle(R, 300);
Pi = point_on_circle(R, 48);

draw_circle(R,circleColor,lwCircle);

% 线段
draw_seg(Pk,Pi,lineColor,lwLine);
draw_seg(Pk,Pj,lineColor,lwLine);
draw_seg(O, Pk,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 点标注
text(Pi(1)+0.08,Pi(2)+0.00,'i', ...
    'FontName',fontName,'FontSize',15);

text(Pj(1)+0.05,Pj(2)-0.12,'j', ...
    'FontName',fontName,'FontSize',15);

text(Pk(1)-0.13,Pk(2)-0.02,'k', ...
    'FontName',fontName,'FontSize',15);

text(O(1)-0.04,O(2)-0.10,'o', ...
    'FontName',fontName,'FontSize',14);

% 角弧：以 k 为顶点
draw_angle_arc(Pk,O, Pi,0.23,arcColor,lwArc);   % alpha1
draw_angle_arc(Pk,O, Pj,0.31,arcColor,lwArc);   % alpha2
draw_angle_arc(Pk,Pi,Pj,0.43,arcColor,lwArc);   % alpha3

% 角标注
text(Pk(1)+0.17,Pk(2)+0.24,'\alpha_1', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.22,Pk(2)+0.03,'\alpha_2', ...
    'FontName',fontName,'FontSize',12,'Color',arcColor);

text(Pk(1)+0.46,Pk(2)+0.20,'\alpha_3', ...
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