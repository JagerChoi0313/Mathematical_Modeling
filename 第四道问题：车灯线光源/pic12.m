%% 反射光照射情景图
% 类似论文中的"反射光照射情景图"
% 包含：旋转抛物面、入射光、反射光、法线、测试屏、A/B/C 点、坐标轴

clear; clc; close all;

%% 基本参数
R = 36;              % 开口半径 mm
h = 21.6;            % 深度 mm
f = R^2/(4*h);       % 焦距 f=15mm
L = 3.12;            % 线光源长度 mm

blue = [0.10 0.38 0.85];

%% 绘制抛物面
theta = linspace(0,2*pi,100);
x = linspace(0,h,80);
[Theta,X] = meshgrid(theta,x);

rho = sqrt(4*f*X);
Y = rho.*cos(Theta);
Z = rho.*sin(Theta);

figure('Color','w');
surf(X,Y,Z, ...
    'FaceAlpha',0.25, ...
    'FaceColor',[0.80 0.86 0.95], ...
    'EdgeColor',[0.45 0.55 0.85]);
hold on;

%% 开口边界
theta2 = linspace(0,2*pi,300);
plot3(h*ones(size(theta2)), ...
      R*cos(theta2), ...
      R*sin(theta2), ...
      'Color',blue,'LineWidth',2);

%% 坐标轴
quiver3(0,0,0,75,0,0,0,'Color',blue,'LineWidth',1.8,'MaxHeadSize',0.3);
quiver3(0,0,0,0,65,0,0,'Color',blue,'LineWidth',1.8,'MaxHeadSize',0.3);
quiver3(0,0,0,0,0,-55,0,'Color',blue,'LineWidth',1.8,'MaxHeadSize',0.3);

text(76,0,0,'X','Color',blue,'FontSize',14,'FontWeight','bold');
text(0,66,0,'Y','Color',blue,'FontSize',14,'FontWeight','bold');
text(0,0,-57,'Z','Color',blue,'FontSize',14,'FontWeight','bold');
text(0,-4,0,'O','Color',blue,'FontSize',12);

%% 线光源
ys = linspace(-L/2,L/2,80);
plot3(f*ones(size(ys)),ys,zeros(size(ys)), ...
    'r','LineWidth',4);
text(f,-8,2,'线光源','Color','r','FontSize',11);

%% 选取一个反射点 M 和光源点 P
P = [f, -L/2, 0];          % 线光源上一点
y0 = 20;
z0 = 18;
x0 = (y0^2+z0^2)/(4*f);
M = [x0,y0,z0];

%% 法向量
n = [-60,2*y0,2*z0];
n = n/norm(n);

%% 为了示意，构造入射光和反射光方向
% 入射光线 P -> M
v_in = M - P;

% 用向量反射公式得到反射方向
n_raw = [-60,2*y0,2*z0];
v_ref = v_in - 2*dot(v_in,n_raw)/dot(n_raw,n_raw)*n_raw;
v_ref = v_ref/norm(v_ref);

% 反射光终点，向测试屏方向延长
G_show = M + 85*v_ref;

%% 绘制入射光
plot3([P(1),M(1)], [P(2),M(2)], [P(3),M(3)], ...
    'Color',blue,'LineWidth',2);

quiver3(P(1),P(2),P(3), ...
    0.75*v_in(1),0.75*v_in(2),0.75*v_in(3), ...
    0,'Color',blue,'LineWidth',1.6,'MaxHeadSize',0.5);

text((P(1)+M(1))/2-5, ...
     (P(2)+M(2))/2-8, ...
     (P(3)+M(3))/2, ...
     '入射光','Color',blue,'FontSize',11);

%% 绘制反射光
plot3([M(1),G_show(1)], [M(2),G_show(2)], [M(3),G_show(3)], ...
    'Color',blue,'LineWidth',2);

quiver3(M(1),M(2),M(3), ...
    45*v_ref(1),45*v_ref(2),45*v_ref(3), ...
    0,'Color',blue,'LineWidth',1.6,'MaxHeadSize',0.5);

text(M(1)+35*v_ref(1), ...
     M(2)+35*v_ref(2)+4, ...
     M(3)+35*v_ref(3), ...
     '反射光','Color',blue,'FontSize',11);

%% 绘制法线
normal_len = 35;
N1 = M - normal_len*n;
N2 = M + normal_len*n;

plot3([N1(1),N2(1)], [N1(2),N2(2)], [N1(3),N2(3)], ...
    '--','Color',blue,'LineWidth',1.5);

text(N2(1)+2,N2(2),N2(3),'法线','Color',blue,'FontSize',11);

%% 标出反射点
plot3(M(1),M(2),M(3),'o','MarkerFaceColor',blue, ...
    'MarkerEdgeColor',blue,'MarkerSize',6);

%% 测试屏示意
screen_x = 95;
y_screen = [-30 45];
z_screen = [-40 45];

% 测试屏四个角
P1 = [screen_x,y_screen(1),z_screen(1)];
P2 = [screen_x,y_screen(2),z_screen(1)];
P3 = [screen_x,y_screen(2),z_screen(2)];
P4 = [screen_x,y_screen(1),z_screen(2)];

screen_pts = [P1;P2;P3;P4;P1];

plot3(screen_pts(:,1),screen_pts(:,2),screen_pts(:,3), ...
    'Color',[0 0.45 0.9],'LineWidth',2);

patch(screen_pts(1:4,1),screen_pts(1:4,2),screen_pts(1:4,3), ...
    [0.80 0.93 1.00], ...
    'FaceAlpha',0.15, ...
    'EdgeColor',[0 0.45 0.9]);

text(screen_x,y_screen(2)-4,z_screen(2)+4, ...
    '测试屏','Color',[0 0.45 0.9], ...
    'FontSize',12,'Rotation',-25);

%% A、B、C 点示意
% 为了图形美观，采用示意比例，不按真实 1300mm、2600mm 绘制
A_show = [screen_x, 18, 0];
B_show = [screen_x, 12, 5];
C_show = [screen_x, 6, 10];

plot3(A_show(1),A_show(2),A_show(3),'ro','MarkerFaceColor','r','MarkerSize',7);
plot3(B_show(1),B_show(2),B_show(3),'ro','MarkerFaceColor','r','MarkerSize',7);
plot3(C_show(1),C_show(2),C_show(3),'ro','MarkerFaceColor','r','MarkerSize',7);

text(A_show(1),A_show(2)+2,A_show(3),'A','Color',blue,'FontSize',11);
text(B_show(1),B_show(2)+2,B_show(3),'B','Color',blue,'FontSize',11);
text(C_show(1),C_show(2)+2,C_show(3),'C','Color',blue,'FontSize',11);

%% 反射光与测试屏交点示意
plot3(G_show(1),G_show(2),G_show(3),'o', ...
    'MarkerFaceColor',[0.45 0.65 0.95], ...
    'MarkerEdgeColor',[0.45 0.65 0.95], ...
    'MarkerSize',7);

%% 图形美化
xlabel('x');
ylabel('y');
zlabel('z');

title('反射光照射情景图','FontSize',14,'FontWeight','bold');

axis equal;
grid off;
box off;

xlim([-5 115]);
ylim([-45 70]);
zlim([-60 55]);

view(36,22);

set(gca,'XColor','none','YColor','none','ZColor','none');

%% 保存图片
set(gcf,'PaperPositionMode','auto');
print(gcf,'反射光照射情景图_MATLAB生成','-dpng','-r600');