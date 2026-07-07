clc; clear; close all;

% =========================================================
% 三种情况示意图：相同几何含义，但更换视觉风格，避免与原图过于相似
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

draw_case_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);
draw_case_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName);

% 总图导出
exportgraphics(gcf,'three_cases_modified.png','Resolution',600);


%% =========================================================
% 图(a)
% =========================================================
function draw_case_a(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [-0.03, -0.02];

% 点位略微调整，不照搬原图
Pi = point_on_circle(R, 80);
Pj = point_on_circle(R, 190);
Pk = point_on_circle(R, 24);

draw_circle(R,circleColor,lwCircle);

% 弦线和半径线
draw_seg(Pi,Pk,lineColor,lwLine);
draw_seg(Pj,Pk,lineColor,lwLine);
draw_seg(O,Pk,lineColor,lwLine);
draw_seg(O,Pi,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 标注
text(Pi(1)-0.03,Pi(2)+0.12,'i','FontName',fontName,'FontSize',15);
text(Pj(1)-0.12,Pj(2)-0.02,'j','FontName',fontName,'FontSize',15);
text(Pk(1)+0.07,Pk(2)+0.02,'k','FontName',fontName,'FontSize',15);
text(O(1)-0.03,O(2)-0.11,'o','FontName',fontName,'FontSize',14);

% 角弧
draw_angle_arc(Pk,Pj,Pi,0.24,arcColor,lwArc);
draw_angle_arc(Pk,Pi,O, 0.31,arcColor,lwArc);
draw_angle_arc(Pk,O,Pj, 0.17,arcColor,lwArc);

% 角标注
text(Pk(1)-0.34,Pk(2)+0.00,'\alpha_1', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(Pk(1)-0.23,Pk(2)+0.15,'\alpha_2', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(Pk(1)-0.21,Pk(2)-0.13,'\alpha_3', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(0,-1.32,'(a)','FontName',fontName,'FontSize',16,...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.18]);

end


%% =========================================================
% 图(b)
% =========================================================
function draw_case_b(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [-0.05, -0.04];

% 点位相似但不完全相同
Pi = point_on_circle(R, 130);
Pj = point_on_circle(R, 230);
Pk = point_on_circle(R, 20);

draw_circle(R,circleColor,lwCircle);

% 弦线和半径线
draw_seg(Pi,Pk,lineColor,lwLine);
draw_seg(Pj,Pk,lineColor,lwLine);
draw_seg(O,Pk,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 标注
text(Pi(1)-0.08,Pi(2)+0.10,'i','FontName',fontName,'FontSize',15);
text(Pj(1)-0.08,Pj(2)-0.13,'j','FontName',fontName,'FontSize',15);
text(Pk(1)+0.07,Pk(2)+0.02,'k','FontName',fontName,'FontSize',15);
text(O(1)-0.05,O(2)-0.11,'o','FontName',fontName,'FontSize',14);

% 角弧
draw_angle_arc(Pk,Pi,O,0.28,arcColor,lwArc);
draw_angle_arc(Pk,O,Pj,0.20,arcColor,lwArc);

% 角标注
text(Pk(1)-0.31,Pk(2)-0.08,'\alpha_1', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(Pk(1)-0.43,Pk(2)-0.26,'\alpha_2', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(0,-1.32,'(b)','FontName',fontName,'FontSize',16,...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.18]);

end


%% =========================================================
% 图(c)
% =========================================================
function draw_case_c(circleColor,lineColor,arcColor,pointColor,lwCircle,lwLine,lwArc,fontName)

nexttile;
hold on; axis equal; axis off;

R = 1;
O = [-0.04, -0.02];

% 点位略微调整
Pi = point_on_circle(R, 226);
Pj = point_on_circle(R, 292);
Pk = point_on_circle(R, 42);

draw_circle(R,circleColor,lwCircle);

% 弦线和半径线
draw_seg(Pi,Pk,lineColor,lwLine);
draw_seg(Pj,Pk,lineColor,lwLine);
draw_seg(O,Pk,lineColor,lwLine);

% 点
draw_point(Pi,pointColor);
draw_point(Pj,pointColor);
draw_point(Pk,pointColor);
draw_point(O, pointColor);

% 标注
text(Pi(1)-0.10,Pi(2)-0.04,'i','FontName',fontName,'FontSize',15);
text(Pj(1)+0.05,Pj(2)-0.11,'j','FontName',fontName,'FontSize',15);
text(Pk(1)+0.06,Pk(2)+0.04,'k','FontName',fontName,'FontSize',15);
text(O(1)-0.05,O(2)-0.11,'o','FontName',fontName,'FontSize',14);

% 角弧
draw_angle_arc(Pk,Pi,O,0.26,arcColor,lwArc);
draw_angle_arc(Pk,O,Pj,0.20,arcColor,lwArc);
draw_angle_arc(Pk,Pi,Pj,0.38,arcColor,lwArc);

% 角标注
text(Pk(1)-0.35,Pk(2)-0.17,'\alpha_1', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(Pk(1)-0.18,Pk(2)-0.22,'\alpha_2', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(Pk(1)-0.51,Pk(2)-0.53,'\alpha_3', ...
    'FontName',fontName,'FontSize',13,'Color',arcColor);

text(0,-1.32,'(c)','FontName',fontName,'FontSize',16,...
    'HorizontalAlignment','center');

xlim([-1.25 1.25]);
ylim([-1.38 1.18]);

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
plot([P1(1),P2(1)],[P1(2),P2(2)],...
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

% 取较小夹角
d = mod(ang2-ang1+180,360)-180;
ang = linspace(ang1,ang1+d,100);

x = V(1) + r*cosd(ang);
y = V(2) + r*sind(ang);

plot(x,y,'Color',color,'LineWidth',lw);

end