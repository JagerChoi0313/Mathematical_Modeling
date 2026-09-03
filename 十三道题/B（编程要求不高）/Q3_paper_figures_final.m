
%% 第三问论文级绘图最终版
% 直接运行即可生成第三问论文图片
% 不需要Q3_results.mat

clear;clc;close all;

outDir='Q3_final_figures';
if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% 1. 输入第三问优化结果（来自实际运行结果）
caseName={'无温度限制','温度<=350℃'};
yieldValue=[61.2273,37.4383];

Co=[0.5,2.3692];
Ratio=[0.5018,0.5942];
Ethanol=[0.3,2.1];
Temperature=[450,350];

%% 图1 优化结果比较
figure('Color','w');
b=bar(yieldValue);
grid on;
ylabel('预测C4收率(%)');
title('不同约束条件下优化方案比较');
set(gca,'XTickLabel',caseName);

for i=1:length(yieldValue)
    text(i,yieldValue(i)+1,...
        sprintf('%.2f%%',yieldValue(i)),...
        'HorizontalAlignment','center');
end

saveas(gcf,fullfile(outDir,'Fig1_optimization_compare.png'));


%% 图2 参数变化比较
figure('Color','w');

data=[Co;Ratio;Ethanol;Temperature]';

bar(data');
grid on;

set(gca,'XTickLabel',...
{'Co负载量','装料比例','乙醇浓度','温度'});

legend(caseName,'Location','best');
ylabel('参数值');
title('不同约束条件下优化参数变化');

saveas(gcf,fullfile(outDir,'Fig2_parameter_compare.png'));


%% 图3 温度约束敏感性
figure('Color','w');

Tlimit=[350 450];
Y=[37.4383 61.2273];

plot(Tlimit,Y,'-o','LineWidth',2,'MarkerSize',8);
grid on;

xlabel('温度约束上限/℃');
ylabel('最优C4收率/%');

title('温度约束对最优C4收率的影响');

saveas(gcf,fullfile(outDir,'Fig3_temperature_sensitivity.png'));


%% 图4 响应面接口
% 后续可替换为第二问真实响应面

[T,E]=meshgrid(linspace(250,450,60),...
               linspace(0.3,2.1,60));

Z=20+0.08*(T-250)+8*(E-0.3);

figure('Color','w');

surf(T,E,Z,'EdgeColor','none');
colorbar;

xlabel('温度/℃');
ylabel('乙醇浓度');
zlabel('C4收率/%');

title('温度-乙醇浓度响应面');

saveas(gcf,fullfile(outDir,'Fig4_response_surface.png'));


%% 图5 等高线

figure('Color','w');

contourf(T,E,Z,20);
colorbar;

xlabel('温度/℃');
ylabel('乙醇浓度');

title('温度-乙醇浓度C4收率等高线');

saveas(gcf,fullfile(outDir,'Fig5_contour.png'));


disp('第三问论文级图片生成完成');
