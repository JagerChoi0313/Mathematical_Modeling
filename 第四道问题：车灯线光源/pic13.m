%% 车灯线光源优化设计：三维反射光照射情景图
% 坐标系设定：
% O：旋转抛物面顶点
% X：车灯对称轴，指向正前方
% Y：竖直向上
% Z：水平横向，即线光源方向
%
% 说明：
% 题目中测试屏距离焦点 25 m，远大于车灯尺寸。
% 为了论文插图清晰，测试屏位置采用显示缩放，不按真实比例绘制。

clear; clc; close all;

%% ===================== 1. 基本参数 =====================
R = 36;              % 开口半径，单位 mm
h = 21.6;            % 抛物面深度，单位 mm
f = R^2/(4*h);       % 焦距，f = 15 mm

F = [f, 0, 0];       % 焦点坐标

% 测试屏真实距离为 25 m，这里用显示距离代替
screenX = 115;       % 测试屏在图中的显示位置
screenHalfH = 42;    % 测试屏半高
screenHalfW = 45;    % 测试屏半宽

% B、C 点的显示间距
% 真实关系：AB = 1.3 m，AC = 2.6 m
AB_show = 12;
AC_show = 24;

A = [screenX, 0, 0];
B = [screenX, 0, AB_show];
C = [screenX, 0, AC_show];

%% ===================== 2. 图形风格 =====================
blue = [0.22 0.36 0.72];
deepBlue = [0.10 0.18 0.40];
lightBlue = [0.72 0.80 0.95];
gray = [0.62 0.62 0.62];
red = [0.85 0.22 0.13];

figure('Color','w','Position',[120 80 1100 720]);
hold on;
axis equal;
axis off;
set(gca,'Clipping','off');
set(gcf,'Renderer','opengl');

%% ===================== 3. 绘制旋转抛物面 =====================
% 抛物面方程：
% x = (y^2 + z^2)/(4f)

x = linspace(0, h, 80);
theta = linspace(0, 2*pi, 160);
[X, T] = meshgrid(x, theta);

rho = sqrt(4*f*X);
Y = rho .* sin(T);
Z = rho .* cos(T);

% 为了让图中 Y 轴竖直显示，绘图时采用：
% 显示坐标 = [X, Z, Y]
surf(X, Z, Y, ...
    'FaceColor', lightBlue, ...
    'FaceAlpha', 0.33, ...
    'EdgeColor', 'none');

% 抛物面口径圆
rim = [h*ones(numel(theta),1), ...
       R*sin(theta(:)), ...
       R*cos(theta(:))];
plotL(rim, 'Color', gray, 'LineWidth', 1.6);

% 抛物面几条经线
rhoLine = sqrt(4*f*x(:));
angles = [0, pi/2, pi, 3*pi/2, pi/4, 5*pi/4];

for k = 1:length(angles)
    th = angles(k);
    curve = [x(:), rhoLine*sin(th), rhoLine*cos(th)];
    if k <= 4
        plotL(curve, 'Color', blue, 'LineWidth', 1.25);
    else
        plotL(curve, 'Color', gray, 'LineWidth', 1.0);
    end
end

%% ===================== 4. 绘制坐标轴 =====================
axisX = 82;
axisY = 58;
axisZ = 58;

drawArrowL([0 0 0], [axisX 0 0], blue, 1.7, 0.28);
drawArrowL([0 0 0], [0 axisY 0], blue, 1.7, 0.28);
drawArrowL([0 0 0], [0 0 -axisZ], blue, 1.7, 0.28);

textL([-4 -3 0], 'O', ...
    'Color', blue, 'FontSize', 15, 'FontName', 'Times New Roman');

% 按你的要求修改字母：
% 原 X -> Y
% 原 Y -> Z
% 原 Z -> X
textL([axisX+4 0 0], 'Y', ...
    'Color', blue, 'FontSize', 18, 'FontName', 'Times New Roman');

textL([0 axisY+5 0], 'Z', ...
    'Color', blue, 'FontSize', 18, 'FontName', 'Times New Roman');

textL([0 0 -axisZ-5], 'X', ...
    'Color', blue, 'FontSize', 18, 'FontName', 'Times New Roman');

% 对称轴虚线，延伸到测试屏
plotL([0 0 0; screenX 0 0], ...
    '--', 'Color', [0.45 0.55 0.85], 'LineWidth', 1.0);

%% ===================== 5. 绘制线光源与焦点 =====================
% 线光源沿 Z 方向，经过焦点 F
L_show = 28;
lineSource = [f, 0, -L_show/2;
              f, 0,  L_show/2];

plotL(lineSource, ...
    'Color', blue, 'LineWidth', 3.0);

plotPointL(F, blue, 30);
textL(F + [-5 -6 5], 'F', ...
    'Color', blue, 'FontSize', 13, 'FontName', 'Times New Roman');

%% ===================== 6. 绘制测试屏 =====================
% 测试屏与 FA 垂直，因此测试屏平面为 x = screenX

yMin = -screenHalfH;
yMax =  screenHalfH;
zMin = -screenHalfW;
zMax =  screenHalfW;

screenFront = [screenX yMin zMin;
               screenX yMax zMin;
               screenX yMax zMax;
               screenX yMin zMax;
               screenX yMin zMin];

% 画前矩形边框
plotL(screenFront, 'Color', deepBlue, 'LineWidth', 2.0);

% 画一个很薄的厚度，增强立体感
thick = 5;
screenBack = screenFront;
screenBack(:,1) = screenBack(:,1) + thick;

plotL(screenBack, 'Color', blue, 'LineWidth', 1.2);

for i = 1:4
    plotL([screenFront(i,:); screenBack(i,:)], ...
        'Color', blue, 'LineWidth', 1.1);
end

% 屏上过 A 点的水平线
plotL([screenX 0 zMin; screenX 0 zMax], ...
    ':', 'Color', blue, 'LineWidth', 1.1);

textL([screenX+3, 32, 25], '测试屏', ...
    'Color', blue, 'FontSize', 15, ...
    'FontName', 'SimSun', 'Rotation', -22);

%% ===================== 7. 绘制 A、B、C 三点 =====================
plotPointL(A, red, 55);
plotPointL(B, red, 55);
plotPointL(C, red, 55);

textL(A + [0 -3 -4], 'A', ...
    'Color', blue, 'FontSize', 13, 'FontName', 'Times New Roman');

textL(B + [0 -3 1], 'B', ...
    'Color', blue, 'FontSize', 13, 'FontName', 'Times New Roman');

textL(C + [0 -3 1], 'C', ...
    'Color', blue, 'FontSize', 13, 'FontName', 'Times New Roman');

%% ===================== 8. 绘制入射光、反射光和法线 =====================
% 选取线光源上一点 S 和抛物面上一点 P
S = [f, 0, 8];

Py = 23;
Pz = -16;
Px = (Py^2 + Pz^2)/(4*f);
P = [Px, Py, Pz];

% 抛物面法向量
% 对隐函数 x - (y^2+z^2)/(4f)=0，
% 法向量为 [1, -y/(2f), -z/(2f)]
n = [1, -P(2)/(2*f), -P(3)/(2*f)];
n = n / norm(n);

% 入射方向
vin = P - S;
vin = vin / norm(vin);

% 反射方向
vout = vin - 2 * dot(vin, n) * n;
vout = vout / norm(vout);

% 反射光与测试屏 x = screenX 的交点
t = (screenX - P(1)) / vout(1);
Q = P + t * vout;

% 入射光
drawArrowL(S, P, blue, 1.7, 0.22);
textL([18, 15, -5], '入射光', ...
    'Color', blue, 'FontSize', 14, 'FontName', 'SimSun');

% 反射光
drawArrowL(P, Q, blue, 1.7, 0.22);
textL([63, 12, -28], '反射光', ...
    'Color', blue, 'FontSize', 14, 'FontName', 'SimSun');

% 反射点
plotPointL(P, blue, 22);

% 法线
normalLen1 = 20;
normalLen2 = 24;
N1 = P - normalLen1*n;
N2 = P + normalLen2*n;

plotL([N1; N2], ...
    '--', 'Color', blue, 'LineWidth', 1.3);

textL(P + [12, 4, 2], '法线', ...
    'Color', blue, 'FontSize', 14, 'FontName', 'SimSun');

%% ===================== 9. 增加一条辅助虚线，使反射关系更清楚 =====================
auxEnd = P + 40 * vout;
plotL([P; auxEnd], ...
    ':', 'Color', [0.45 0.55 0.85], 'LineWidth', 1.0);

%% ===================== 10. 视角与导出 =====================
view(38, 20);
camproj perspective;
camlight headlight;
lighting gouraud;

xlim([-14, 132]);
ylim([-68, 68]);
zlim([-50, 68]);

% 导出图片
try
    exportgraphics(gcf, '反射光照射情景图_改进版.png', 'Resolution', 300);
catch
    print(gcf, '反射光照射情景图_改进版.png', '-dpng', '-r300');
end

%% ===================== 局部函数 =====================
function Q = mapXYZ(P)
    % 逻辑坐标 [X,Y,Z] 映射为显示坐标 [X,Z,Y]
    % 这样可以让论文中的 Y 轴在图中竖直向上
    if isrow(P)
        Q = [P(1), P(3), P(2)];
    else
        Q = [P(:,1), P(:,3), P(:,2)];
    end
end

function plotL(P, varargin)
    Q = mapXYZ(P);
    plot3(Q(:,1), Q(:,2), Q(:,3), varargin{:});
end

function drawArrowL(P1, P2, colorValue, lineWidthValue, headSizeValue)
    Q1 = mapXYZ(P1);
    Q2 = mapXYZ(P2);
    V = Q2 - Q1;

    quiver3(Q1(1), Q1(2), Q1(3), ...
            V(1), V(2), V(3), ...
            0, ...
            'Color', colorValue, ...
            'LineWidth', lineWidthValue, ...
            'MaxHeadSize', headSizeValue);
end

function textL(P, str, varargin)
    Q = mapXYZ(P);
    text(Q(1), Q(2), Q(3), str, varargin{:});
end

function plotPointL(P, colorValue, sizeValue)
    Q = mapXYZ(P);
    scatter3(Q(1), Q(2), Q(3), ...
        sizeValue, ...
        'MarkerFaceColor', colorValue, ...
        'MarkerEdgeColor', colorValue);
end