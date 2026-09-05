%% ===================== 第二问厚度结果分布图 =====================
% d10: 10°下的全部厚度结果，例如 78x1 向量
% d15: 15°下的全部厚度结果，例如 78x1 向量

d10 = d10(:);
d15 = d15(:);

% 合并数据
d_all = [d10; d15];
group = [repmat("10°", length(d10), 1); repmat("15°", length(d15), 1)];
group = categorical(group, ["10°","15°"]);

figure('Color','w','Position',[200 150 900 600]);

% 画箱线图（推荐用 boxchart，不依赖额外工具箱）
boxchart(group, d_all, ...
    'BoxWidth', 0.5, ...
    'MarkerStyle', 'none');
hold on;

% 在箱线图上叠加散点，显示每一个厚度结果
x1 = 1 + 0.08*(rand(size(d10)) - 0.5);
x2 = 2 + 0.08*(rand(size(d15)) - 0.5);

scatter(x1, d10, 28, 'filled', ...
    'MarkerFaceAlpha', 0.7, ...
    'MarkerEdgeAlpha', 0.7);
scatter(x2, d15, 28, 'filled', ...
    'MarkerFaceAlpha', 0.7, ...
    'MarkerEdgeAlpha', 0.7);

% 画均值线
mean10 = mean(d10);
mean15 = mean(d15);

plot([0.8,1.2],[mean10,mean10],'r--','LineWidth',1.5);
plot([1.8,2.2],[mean15,mean15],'r--','LineWidth',1.5);

% 标注均值
text(1.22, mean10, sprintf('均值 = %.4f', mean10), ...
    'FontSize', 11, 'Color', 'r');
text(2.22, mean15, sprintf('均值 = %.4f', mean15), ...
    'FontSize', 11, 'Color', 'r');

xlabel('入射角', 'FontSize', 13);
ylabel('外延层厚度 d / \mum', 'FontSize', 13);
title('不同入射角下外延层厚度计算结果分布', 'FontSize', 14);

grid on;
box on;
set(gca, 'FontSize', 12);

% 保存图片
exportgraphics(gcf, 'question2_thickness_distribution.png', 'Resolution', 300);