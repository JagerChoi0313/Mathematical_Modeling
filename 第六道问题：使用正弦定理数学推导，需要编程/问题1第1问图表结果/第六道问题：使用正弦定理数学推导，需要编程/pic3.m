%% draw_Q1_1_three_cases_fixed.m
% 问题1第(1)小问：三种情况讨论示意图
% 修正版：公式放在图右下方，不遮挡主图，并避免 annotation 公式乱码

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

R = 100;                    % 理想圆半径

theta_i_deg = 50;           % 圆周发射机 Ai 的极角
theta_j_deg = 130;          % 圆周发射机 Aj 的极角

theta_i = deg2rad(theta_i_deg);
theta_j = deg2rad(theta_j_deg);

% 三种情况下接收机 P 的极角（示意）
theta_case_deg = [15, 90, 170];

% 接收机极径（示意）
rho_P = 88;

caseTitles = { ...
    '情况一：接收机位于两架圆周发射机左侧', ...
    '情况二：接收机位于两架圆周发射机之间', ...
    '情况三：接收机位于两架圆周发射机右侧'};

caseIneq = { ...
    '\theta < \theta_i < \theta_j', ...
    '\theta_i < \theta < \theta_j', ...
    '\theta_i < \theta_j < \theta'};

% 三种情况对应的公式（放右下角）
formula1 = { ...
    '\rho=\dfrac{R\sin(\alpha_i+\theta_i-\theta)}{\sin\alpha_i}', ...
    '\rho=\dfrac{R\sin(\alpha_j+\theta_j-\theta)}{\sin\alpha_j}'};

formula2 = { ...
    '\rho=\dfrac{R\sin(\alpha_i+\theta-\theta_i)}{\sin\alpha_i}', ...
    '\rho=\dfrac{R\sin(\alpha_j+\theta_j-\theta)}{\sin\alpha_j}'};

formula3 = { ...
    '\rho=\dfrac{R\sin(\alpha_i+\theta-\theta_i)}{\sin\alpha_i}', ...
    '\rho=\dfrac{R\sin(\alpha_j+\theta-\theta_j)}{\sin\alpha_j}'};

formulaSet = {formula1, formula2, formula3};

fileNames = { ...
    '图1_情况一_接收机位于两发射机左侧.png', ...
    '图2_情况二_接收机位于两发射机之间.png', ...
    '图3_情况三_接收机位于两发射机右侧.png'};

outFolder = 'Q1_1_three_cases_figures_fixed';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% ==================== 2. 生成三张图 ====================

for c = 1:3

    theta_P = deg2rad(theta_case_deg(c));

    fig = figure('Color', 'w', 'Position', [80, 80, 1250, 760]);

    drawOneCaseFixed( ...
        fig, R, theta_i, theta_j, rho_P, theta_P, ...
        caseTitles{c}, caseIneq{c}, formulaSet{c});

    savePath = fullfile(outFolder, fileNames{c});
    saveFigure(fig, savePath);
end

fprintf('三张修正后的示意图已生成，保存位置：%s\n', outFolder);

%% ========================================================================
%                              局部函数
% ========================================================================

function drawOneCaseFixed(fig, R, theta_i, theta_j, rho_P, theta_P, ...
    titleStr, ineqStr, formulaStrs)

    %% ---------- 关键点 ----------
    O  = [0, 0];
    Ai = polar2xy(R, theta_i);
    Aj = polar2xy(R, theta_j);
    P  = polar2xy(rho_P, theta_P);

    %% ---------- 左侧主图坐标轴 ----------
    ax = axes('Parent', fig, 'Position', [0.07, 0.16, 0.58, 0.72]);
    hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal');

    % 理想圆
    t = linspace(0, 2*pi, 600);
    plot(ax, R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.5);

    % 坐标轴
    plot(ax, [-120, 120], [0, 0], 'k:', 'LineWidth', 1.0);
    plot(ax, [0, 0], [-120, 120], 'k:', 'LineWidth', 1.0);

    % 点
    plot(ax, O(1), O(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
    plot(ax, Ai(1), Ai(2), 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 10, 'LineWidth', 1.6);
    plot(ax, Aj(1), Aj(2), 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 10, 'LineWidth', 1.6);
    plot(ax, P(1), P(2), 'k^', 'MarkerFaceColor', 'w', 'MarkerSize', 11, 'LineWidth', 1.6);

    % 连线
    plot(ax, [P(1), O(1)],  [P(2), O(2)],  'k-', 'LineWidth', 1.3);
    plot(ax, [P(1), Ai(1)], [P(2), Ai(2)], 'k-', 'LineWidth', 1.3);
    plot(ax, [P(1), Aj(1)], [P(2), Aj(2)], 'k-', 'LineWidth', 1.3);

    plot(ax, [O(1), Ai(1)], [O(2), Ai(2)], 'k:', 'LineWidth', 1.2);
    plot(ax, [O(1), Aj(1)], [O(2), Aj(2)], 'k:', 'LineWidth', 1.2);
    plot(ax, [Ai(1), Aj(1)], [Ai(2), Aj(2)], 'k:', 'LineWidth', 1.2);

    % 标注点
    text(ax, O(1)+4, O(2)-8, '$O(FY00)$', ...
        'Interpreter', 'latex', 'FontSize', 13);

    text(ax, Ai(1)+4, Ai(2)+3, '$A_i(FY_i)$', ...
        'Interpreter', 'latex', 'FontSize', 13);

    text(ax, Aj(1)+4, Aj(2)+3, '$A_j(FY_j)$', ...
        'Interpreter', 'latex', 'FontSize', 13);

    text(ax, P(1)+4, P(2)+4, '$P(\rho,\theta)$', ...
        'Interpreter', 'latex', 'FontSize', 13);

    % 极角标注
    drawThetaArc(ax, O, 18, 0, theta_P, '$\theta$');
    drawThetaArc(ax, O, 28, 0, theta_i, '$\theta_i$');
    drawThetaArc(ax, O, 38, 0, theta_j, '$\theta_j$');

    % rho 标注
    midOP = 0.5 * P;
    text(ax, midOP(1)+3, midOP(2)-3, '$\rho$', ...
        'Interpreter', 'latex', 'FontSize', 14);

    % 接收点处三个角
    drawAngleArcShort(ax, P, O,  Ai, 13, '$\alpha_i$');
    drawAngleArcShort(ax, P, O,  Aj, 21, '$\alpha_j$');
    drawAngleArcShort(ax, P, Ai, Aj, 29, '$\alpha_{ij}$');

    % 坐标范围
    xlim(ax, [-120, 120]);
    ylim(ax, [-120, 120]);

    xlabel(ax, '$x/m$', 'Interpreter', 'latex', 'FontSize', 13);
    ylabel(ax, '$y/m$', 'Interpreter', 'latex', 'FontSize', 13);
    title(ax, titleStr, 'FontSize', 16, 'FontWeight', 'bold');

    % 图例
    legend(ax, ...
        {'理想圆周', '坐标轴', '坐标轴', '圆心 FY00', '圆周发射机', '圆周发射机', '接收机 P'}, ...
        'Location', 'southoutside', 'NumColumns', 4, 'FontSize', 11);

    %% ---------- 右上角：不等式条件 ----------
    axCond = axes('Parent', fig, 'Position', [0.72, 0.58, 0.23, 0.20]);
    axis(axCond, [0 1 0 1]);
    axCond.Visible = 'off';
    rectangle(axCond, 'Position', [0.02, 0.08, 0.96, 0.84], ...
        'EdgeColor', 'k', 'LineWidth', 1.2);
    text(axCond, 0.5, 0.5, ['$' ineqStr '$'], ...
        'Interpreter', 'latex', ...
        'FontSize', 20, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle');

    %% ---------- 右下角：公式框（重点修正） ----------
    axFormula = axes('Parent', fig, 'Position', [0.69, 0.29, 0.28, 0.20]);
    axis(axFormula, [0 1 0 1]);
    axFormula.Visible = 'off';

    rectangle(axFormula, 'Position', [0.02, 0.05, 0.96, 0.90], ...
        'EdgeColor', 'k', 'LineWidth', 1.2);

    % 两行公式，放在右下区域，不再遮挡主图
    text(axFormula, 0.08, 0.68, ['$' formulaStrs{1} '$'], ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle');

    text(axFormula, 0.08, 0.32, ['$' formulaStrs{2} '$'], ...
        'Interpreter', 'latex', ...
        'FontSize', 18, ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle');
end

function P = polar2xy(rho, theta)
    P = [rho*cos(theta), rho*sin(theta)];
end

function drawThetaArc(ax, center, radius, thetaStart, thetaEnd, labelStr)
    angleList = linspace(thetaStart, thetaEnd, 120);
    xArc = center(1) + radius*cos(angleList);
    yArc = center(2) + radius*sin(angleList);

    plot(ax, xArc, yArc, 'k-', 'LineWidth', 1.0);

    amid = (thetaStart + thetaEnd)/2;
    xText = center(1) + 1.18*radius*cos(amid);
    yText = center(2) + 1.18*radius*sin(amid);

    text(ax, xText, yText, labelStr, ...
        'Interpreter', 'latex', ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'center');
end

function drawAngleArcShort(ax, center, p1, p2, radius, labelStr)
    a1 = atan2(p1(2)-center(2), p1(1)-center(1));
    a2 = atan2(p2(2)-center(2), p2(1)-center(1));
    d = wrapToPi_local(a2 - a1);

    angleList = linspace(a1, a1 + d, 100);
    xArc = center(1) + radius*cos(angleList);
    yArc = center(2) + radius*sin(angleList);

    plot(ax, xArc, yArc, 'k-', 'LineWidth', 1.0);

    amid = a1 + d/2;
    xText = center(1) + 1.22*radius*cos(amid);
    yText = center(2) + 1.22*radius*sin(amid);

    text(ax, xText, yText, labelStr, ...
        'Interpreter', 'latex', ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'center');
end

function a = wrapToPi_local(a)
    a = mod(a + pi, 2*pi) - pi;
end

function saveFigure(figHandle, fileName)
    try
        exportgraphics(figHandle, fileName, 'Resolution', 300);
    catch
        print(figHandle, fileName, '-dpng', '-r300');
    end
end