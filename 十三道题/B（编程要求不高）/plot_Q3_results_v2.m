
%% 第三问论文级绘图主程序
% 读取 Q3_optimization_results.xlsx
% 自动生成论文需要的5类图片

clear;clc;close all;

filename='Q3_optimization_results.xlsx';

T=readtable(filename);

out='Q3_figures';
if ~exist(out,'dir')
    mkdir(out);
end

%% 1 优化方案比较
figure('Position',[200 200 800 500]);

bar(T.C4_Yield);
grid on;

set(gca,'XTickLabel',T.Case);

ylabel('预测C4烯烃收率(%)');
title('不同约束条件下优化方案比较');

for i=1:length(T.C4_Yield)
    text(i,T.C4_Yield(i)+1,...
        sprintf('%.2f',T.C4_Yield(i)),...
        'HorizontalAlignment','center');
end

saveas(gcf,fullfile(out,'Fig1_optimization_compare.png'));


%% 2 参数变化雷达图
plot_radar(T,out);


%% 3 响应面
plot_response_surface(out);


%% 4 等高线
plot_contour(out);


disp('第三问论文级图片生成完成');
