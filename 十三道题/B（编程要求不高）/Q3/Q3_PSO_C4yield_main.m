clc;clear;close all;

resultFolder='Q3_results';
if ~exist(resultFolder,'dir')
    mkdir(resultFolder);
end

set(groot,'defaultAxesFontName','SimHei');

filename='Q2_response_surface_results.xlsx';

conv=readtable(filename,'Sheet','Conv_Coefficients');
sel=readtable(filename,'Sheet','C4_Coefficients');
stdt=readtable(filename,'Sheet','Standardization');

convTerm=string(conv.Term);
convCoef=conv.Coefficient;
selTerm=string(sel.Term);
selCoef=sel.Coefficient;

mu=stdt.Mean;
sigma=stdt.Std;

lb=[0.5;0.33;0.30;250];
ub=[5;1;2.10;450];

D=0;
M=0;
zLimit=2;

fun=@(x)-C4_objective_function(x,D,M,zLimit,...
    convTerm,convCoef,selTerm,selCoef,mu,sigma);

options=optimoptions('particleswarm',...
    'SwarmSize',80,...
    'MaxIterations',100,...
    'Display','iter');

[x1,f1]=particleswarm(fun,4,lb,ub,options);

ub2=ub;
ub2(4)=349.5;

[x2,f2]=particleswarm(fun,4,lb,ub2,options);

[X1,S1,Y1]=C4_model_function(x1,D,M,...
    convTerm,convCoef,selTerm,selCoef,mu,sigma);

[X2,S2,Y2]=C4_model_function(x2,D,M,...
    convTerm,convCoef,selTerm,selCoef,mu,sigma);

Result=table(["Full temperature";"Below 350"],...
[x1(1);x2(1)],[x1(2);x2(2)],[x1(3);x2(3)],...
[x1(4);x2(4)],[X1;X2],[S1;S2],[Y1;Y2],...
'VariableNames',{'Scheme','Co_loading','Ratio','Ethanol','Temperature','Conversion','Selectivity','C4_Yield'});

writetable(Result,fullfile(resultFolder,'Optimization_results.xlsx'));
disp(Result);

T=250:1:450;
Y=zeros(size(T));
for i=1:length(T)
    xx=x1; xx(4)=T(i);
    [~,~,Y(i)]=C4_model_function(xx,D,M,...
        convTerm,convCoef,selTerm,selCoef,mu,sigma);
end

figure;
plot(T,Y,'LineWidth',2);
xlabel('Temperature');
ylabel('C4 Yield (%)');
title('Temperature Effect on C4 Yield');
grid on;
exportgraphics(gcf,fullfile(resultFolder,'Temperature_effect.png'),'Resolution',300);

[xg,yg]=meshgrid(linspace(lb(1),ub(1),50),linspace(lb(2),ub(2),50));
zg=zeros(size(xg));

for i=1:size(xg,1)
    for j=1:size(xg,2)
        xx=x1;
        xx(1)=xg(i,j);
        xx(2)=yg(i,j);
        [~,~,zg(i,j)]=C4_model_function(xx,D,M,...
            convTerm,convCoef,selTerm,selCoef,mu,sigma);
    end
end

figure;
surf(xg,yg,zg);
xlabel('Co loading');
ylabel('Ratio');
zlabel('C4 Yield');
title('Response Surface');
shading interp;
exportgraphics(gcf,fullfile(resultFolder,'Response_surface.png'),'Resolution',300);

disp('Finished');
