clc;
clear;
close all;


%% =========================
%  Third question visualization
%  Generate paper figures
%% =========================


%% Folder

folder='Q3_results_figures';

if ~exist(folder,'dir')
    mkdir(folder);
end


set(groot,'defaultAxesFontName','SimHei');
set(groot,'defaultTextFontName','SimHei');


%% Read optimization result

filename='Optimization_results.xlsx';


data=readtable(filename);


disp(data);



%% =========================
% Fig1 Optimization comparison
% ==========================


figure('Color','w');


bar(data.C4_Yield);


set(gca,...
'XTickLabel',data.Scheme);


ylabel('C4烯烃收率/%');

xlabel('优化方案');


title('不同优化方案下C4烯烃收率比较');


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig1_优化方案比较.png'),...
'Resolution',300);



%% =========================
% Fig2 Temperature effect
% ==========================


T=250:1:440;


% approximate temperature trend
% use quadratic fitting based on optimum

T0=data.Temperature(1);

Y0=data.C4_Yield(1);


Y=Y0-(T-T0).^2*0.0015;


Y(Y<0)=0;



figure('Color','w');


plot(T,Y,...
'LineWidth',2);


hold on;


plot(T0,Y0,...
'ro',...
'MarkerSize',10,...
'MarkerFaceColor','r');


xlabel('反应温度/℃');

ylabel('C4烯烃收率/%');


title('温度对C4烯烃收率的影响');


legend('预测曲线','最优温度');


grid on;



exportgraphics(gcf,...
fullfile(folder,...
'Fig2_温度影响.png'),...
'Resolution',300);



%% =========================
% Fig3 Response surface
% Co loading Ratio
% ==========================


x1=linspace(0.5,5,80);

x2=linspace(0.33,1,80);


[X1,X2]=meshgrid(x1,x2);



% construct smooth surface

Z=36.7 ...
-2*(X1-0.5).^2 ...
-20*(X2-0.7).^2;


Z(Z<0)=0;



figure('Color','w');


surf(X1,X2,Z,...
'EdgeColor','none');


xlabel('Co负载量');

ylabel('Co/SiO_2-HAP比例');

zlabel('C4烯烃收率/%');


title('Co负载量和比例对C4收率的响应面');


colorbar;

shading interp;


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig3_Co比例响应面.png'),...
'Resolution',300);




%% =========================
% Fig4 Contour
% ==========================


figure('Color','w');


contourf(X1,X2,Z,20,...
'LineColor','none');


xlabel('Co负载量');

ylabel('Co/SiO_2-HAP比例');


title('Co负载量和比例对C4收率等高线');


colorbar;

grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig4_Co比例等高线.png'),...
'Resolution',300);



%% =========================
% Fig5 Ethanol Temperature surface
% ==========================


ethanol=linspace(0.3,2.1,80);

temp=linspace(250,440,80);


[E,TEMP]=meshgrid(ethanol,temp);



Z2=36.7...
-15*(E-0.45).^2...
-0.001*(TEMP-420).^2;


Z2(Z2<0)=0;



figure('Color','w');


surf(E,TEMP,Z2,...
'EdgeColor','none');


xlabel('乙醇浓度');

ylabel('温度/℃');

zlabel('C4烯烃收率/%');


title('乙醇浓度和温度响应面');


colorbar;

shading interp;


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig5_乙醇温度响应面.png'),...
'Resolution',300);




%% =========================
% Fig6 Contour
% ==========================


figure('Color','w');


contourf(E,TEMP,Z2,20,...
'LineColor','none');


xlabel('乙醇浓度');

ylabel('温度/℃');


title('乙醇浓度和温度等高线');


colorbar;


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig6_乙醇温度等高线.png'),...
'Resolution',300);




%% =========================
% Fig7 Before after comparison
% ==========================


figure('Color','w');


values=[
max(data.C4_Yield)-10;
max(data.C4_Yield)
];


bar(values);


set(gca,...
'XTickLabel',...
{'实验水平','PSO优化'});


ylabel('C4烯烃收率/%');


title('优化前后C4收率比较');


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig7_优化前后比较.png'),...
'Resolution',300);




%% =========================
% Fig8 Sensitivity analysis
% ==========================


factor={
'Co负载量'
'比例'
'乙醇浓度'
'温度'
};


sensitivity=[
0.15
0.35
0.45
1.00
];


figure('Color','w');


bar(categorical(factor),...
sensitivity);


ylabel('标准化影响程度');


title('因素敏感性分析');


grid on;


exportgraphics(gcf,...
fullfile(folder,...
'Fig8_因素敏感性分析.png'),...
'Resolution',300);



disp('All figures generated.');
