clc;
clear;
close all;

%% 1. 数据
scheme = {'原有20个平台','新增2个','新增3个','新增4个','新增5个'};
x = 1:length(scheme);

% 覆盖率（%）
weightedCoverage = [94.62, 98.876, 99.518, 100.000, 100.000];
normalCoverage   = [93.48, 97.826, 98.913, 100.000, 100.000];

% 距离指标（km）
maxDist         = [5.7005, 4.1902, 4.1902, 2.7083, 2.3854];
weightedAvgDist = [0.9093, 0.73215, 0.68186, 0.66167, 0.63122];

%% 2. 图窗
figure('Color','w','Units','normalized','OuterPosition',[0 0 0.88 0.85]);

cnFont = 'SimSun';              % 宋体，更像论文
enFont = 'Times New Roman';

%% 3. 左轴：覆盖率柱状图
yyaxis left

b = bar(x, [weightedCoverage' normalCoverage'], 0.58, 'grouped');
b(1).FaceColor = [0.35 0.35 0.35];   % 深灰
b(2).FaceColor = [0.75 0.75 0.75];   % 浅灰
b(1).EdgeColor = [0.15 0.15 0.15];
b(2).EdgeColor = [0.15 0.15 0.15];
b(1).LineWidth = 0.8;
b(2).LineWidth = 0.8;

ylabel('覆盖率（%）', 'FontName', cnFont, 'FontSize', 12);
ylim([90 102]);

ax = gca;
ax.YColor = [0.15 0.15 0.15];

%% 4. 右轴：距离折线图
yyaxis right

p1 = plot(x, maxDist, '-o', ...
    'Color', [0.05 0.05 0.05], ...     % 黑色
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.05 0.05 0.05]);
hold on;

p2 = plot(x, weightedAvgDist, '-s', ...
    'Color', [0.40 0.40 0.40], ...     % 深灰
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.40 0.40 0.40]);

ylabel('距离（km）', 'FontName', cnFont, 'FontSize', 12);
ylim([0 6.5]);
ax.YColor = [0.15 0.15 0.15];

% 3km阈值线
yline(3, '--', ...
    'Color', [0.55 0.55 0.55], ...
    'LineWidth', 1.0);

text(0.55, 3.12, '3 km阈值', ...
    'FontName', cnFont, ...
    'FontSize', 10, ...
    'Color', [0.35 0.35 0.35]);

%% 5. 坐标轴和网格
set(gca, ...
    'XTick', x, ...
    'XTickLabel', scheme, ...
    'FontName', cnFont, ...
    'FontSize', 11, ...
    'LineWidth', 1.0, ...
    'Box', 'on');

xtickangle(12);
grid on;

ax = gca;
ax.GridColor = [0.88 0.88 0.88];
ax.GridAlpha = 0.8;

xlabel('平台扩建方案', 'FontName', cnFont, 'FontSize', 12);
title('新增平台前后服务效果对比图', ...
    'FontName', cnFont, 'FontSize', 14, 'FontWeight', 'bold');

%% 6. 数值标注
% 柱状图全部保留
yyaxis left
for i = 1:length(x)
    text(x(i)-0.14, weightedCoverage(i)+0.23, sprintf('%.2f', weightedCoverage(i)), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 9, ...
        'FontName', enFont, ...
        'Color', [0.10 0.10 0.10]);

    text(x(i)+0.14, normalCoverage(i)+0.23, sprintf('%.2f', normalCoverage(i)), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 9, ...
        'FontName', enFont, ...
        'Color', [0.35 0.35 0.35]);
end

% 折线只标关键点，避免太满
yyaxis right
keyIdx = [1 4 5];
for i = keyIdx
    text(x(i), maxDist(i)+0.16, sprintf('%.2f', maxDist(i)), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 9, ...
        'FontName', enFont, ...
        'Color', [0.05 0.05 0.05]);

    text(x(i), weightedAvgDist(i)-0.18, sprintf('%.2f', weightedAvgDist(i)), ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 9, ...
        'FontName', enFont, ...
        'Color', [0.35 0.35 0.35]);
end

%% 7. 推荐方案轻量高亮（新增4个平台）
yyaxis left
yl = ylim;
rectangle('Position', [4-0.42, yl(1), 0.84, yl(2)-yl(1)], ...
    'EdgeColor', [0.35 0.35 0.35], ...
    'LineStyle', '--', ...
    'LineWidth', 1.0);

text(4, 95.35, '推荐方案', ...
    'HorizontalAlignment', 'center', ...
    'FontName', cnFont, ...
    'FontSize', 10, ...
    'Color', [0.20 0.20 0.20]);

%% 8. 图例
yyaxis left
legend({'加权3分钟覆盖率','普通3分钟覆盖率','最大出警距离','加权平均出警距离'}, ...
    'Location', 'southoutside', ...
    'NumColumns', 2, ...
    'FontName', cnFont, ...
    'FontSize', 10, ...
    'Box', 'off');

%% 9. 左右轴颜色统一
ax = gca;
ax.YAxis(1).Color = [0.15 0.15 0.15];
ax.YAxis(2).Color = [0.15 0.15 0.15];
ax.XColor = [0.15 0.15 0.15];

%% 10. 保存
exportgraphics(gcf, '第一问第三小问_新增平台前后服务效果对比图_黑灰版.png', 'Resolution', 400);
exportgraphics(gcf, '第一问第三小问_新增平台前后服务效果对比图_黑灰版.pdf', 'ContentType', 'vector');
savefig(gcf, '第一问第三小问_新增平台前后服务效果对比图_黑灰版.fig');

fprintf('黑灰版对比图已保存：PNG、PDF、FIG。\n');