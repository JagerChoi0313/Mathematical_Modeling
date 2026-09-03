
%% 第三问论文级绘图主程序
% 功能：
% 1. 读取第三问优化结果
% 2. 绘制PSO收敛曲线
% 3. 绘制优化方案对比
% 4. 绘制响应面与等高线
% 5. 绘制温度约束敏感性分析
%
% 说明：
% 请将本文件与Q3_results.mat放在同一目录。
% Q3_results.mat中建议包含：
% bestHistory : PSO每代最优值
% resultTable : 优化结果表

clear;clc;close all;

outDir='Q3_paper_figures';
if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% 读取结果
if exist('Q3_results.mat','file')
    load('Q3_results.mat');
else
    error('未找到Q3_results.mat，请将第三问优化结果保存为mat文件');
end

%% 图1 PSO收敛曲线
figure;
plot(bestHistory,'LineWidth',2);
grid on;
xlabel('迭代次数');
ylabel('当前最优C4收率(%)');
title('PSO算法收敛过程');
saveas(gcf,fullfile(outDir,'Fig1_PSO_convergence.png'));

%% 图2 优化结果比较
figure;
bar(resultTable.C4_Yield);
grid on;
xticklabels(resultTable.Case);
ylabel('预测C4收率(%)');
title('不同约束条件下优化结果比较');

for i=1:length(resultTable.C4_Yield)
    text(i,resultTable.C4_Yield(i)+1,...
        sprintf('%.2f%%',resultTable.C4_Yield(i)),...
        'HorizontalAlignment','center');
end

saveas(gcf,fullfile(outDir,'Fig2_optimization_compare.png'));

%% 图3 响应面
plot_response_surface;
saveas(gcf,fullfile(outDir,'Fig3_response_surface.png'));

%% 图4 等高线
plot_contour;
saveas(gcf,fullfile(outDir,'Fig4_contour.png'));

%% 图5 约束敏感性
figure;
plot(resultTable.TemperatureLimit,resultTable.C4_Yield,...
    '-o','LineWidth',2,'MarkerSize',8);
grid on;
xlabel('温度约束上限/℃');
ylabel('最优C4收率/%');
title('温度约束对最优结果的影响');

saveas(gcf,fullfile(outDir,'Fig5_temperature_constraint.png'));

disp('第三问论文级图片生成完成');
