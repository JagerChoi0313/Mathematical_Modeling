clc;
clear;
close all;


%% =========================
% Real response surface visualization
% Based on Question 2 model
%% =========================


%% folder

saveFolder='Q3_real_figures';

if ~exist(saveFolder,'dir')
    mkdir(saveFolder);
end


set(groot,'defaultAxesFontName','SimHei');


%% =========================
% Read Q2 model coefficients
% =========================


filename='Q2_response_surface_results.xlsx';


convTable=readtable(filename,...
    'Sheet','Conv_Coefficients');


selTable=readtable(filename,...
    'Sheet','C4_Coefficients');


stdTable=readtable(filename,...
    'Sheet','Standardization');


convTerm=string(convTable.Term);
convCoef=convTable.Coefficient;


selTerm=string(selTable.Term);
selCoef=selTable.Coefficient;


mu=stdTable.Mean;
sigma=stdTable.Std;



%% =========================
% Optimal point
% from PSO result
% =========================


opt=[
0.5
0.48876
0.4473
420.2
];


D=0;
M=0;



%% =========================
% Temperature effect
% =========================


T=250:1:450;

Y=zeros(size(T));


for i=1:length(T)

    x=opt;

    x(4)=T(i);


    [~,~,Y(i)] = C4_model(...
        x,D,M,...
        convTerm,convCoef,...
        selTerm,selCoef,...
        mu,sigma);

end



figure('Color','w');

plot(T,Y,'LineWidth',2);


xlabel('反应温度 / ℃');

ylabel('C4烯烃收率 / %');

title('温度对C4烯烃收率的影响');


grid on;


exportgraphics(gcf,...
fullfile(saveFolder,...
'Fig2_温度影响曲线.png'),...
'Resolution',300);



%% =========================
% Co loading - ratio response surface
% =========================


co=linspace(0.5,5,60);

ratio=linspace(0.33,1,60);


[CO,R]=meshgrid(co,ratio);


Z=zeros(size(CO));


for i=1:size(CO,1)

    for j=1:size(CO,2)


        x=opt;

        x(1)=CO(i,j);

        x(2)=R(i,j);


        [~,~,Z(i,j)] = C4_model(...
            x,D,M,...
            convTerm,convCoef,...
            selTerm,selCoef,...
            mu,sigma);


    end

end



figure('Color','w');


surf(CO,R,Z,...
    'EdgeColor','none');


xlabel('Co负载量');

ylabel('Co/SiO_2-HAP比例');

zlabel('C4烯烃收率');


title('Co负载量和比例对C4收率的响应面');


shading interp;

colorbar;


exportgraphics(gcf,...
fullfile(saveFolder,...
'Fig3_Co负载量比例真实响应面.png'),...
'Resolution',300);



%% contour


figure('Color','w');


contourf(CO,R,Z,20,...
'LineColor','none');


xlabel('Co负载量');

ylabel('Co/SiO_2-HAP比例');

title('Co负载量和比例影响等高线');


colorbar;


exportgraphics(gcf,...
fullfile(saveFolder,...
'Fig4_Co负载量比例真实等高线.png'),...
'Resolution',300);




%% =========================
% Ethanol concentration-temperature surface
% =========================


eth=linspace(0.3,2.1,60);

temp=linspace(250,450,60);


[E,TEMP]=meshgrid(eth,temp);


Z2=zeros(size(E));


for i=1:size(E,1)

    for j=1:size(E,2)


        x=opt;


        x(3)=E(i,j);

        x(4)=TEMP(i,j);


        [~,~,Z2(i,j)] = C4_model(...
            x,D,M,...
            convTerm,convCoef,...
            selTerm,selCoef,...
            mu,sigma);

    end

end



figure('Color','w');


surf(E,TEMP,Z2,...
'EdgeColor','none');


xlabel('乙醇浓度');

ylabel('温度 / ℃');

zlabel('C4烯烃收率');


title('乙醇浓度和温度响应面');


shading interp;

colorbar;


exportgraphics(gcf,...
fullfile(saveFolder,...
'Fig5_乙醇浓度温度真实响应面.png'),...
'Resolution',300);



%% contour


figure('Color','w');


contourf(E,TEMP,Z2,20,...
'LineColor','none');


xlabel('乙醇浓度');

ylabel('温度 / ℃');


title('乙醇浓度和温度等高线');


colorbar;


exportgraphics(gcf,...
fullfile(saveFolder,...
'Fig6_乙醇浓度温度真实等高线.png'),...
'Resolution',300);



disp('All real figures generated.');



%% =========================
% Function
% =========================


function [X,S,Y]=C4_model(x,D,M,...
convTerm,convCoef,...
selTerm,selCoef,...
mu,sigma)


z=(x-mu)./sigma;


X=response(convTerm,convCoef,z,D,M);

S=response(selTerm,selCoef,z,D,M);


Y=X*S/100;


if Y<0
    Y=0;
end


end



function y=response(term,coef,z,D,M)


y=0;


for k=1:length(coef)


    switch term(k)

        case "Intercept"
            v=1;

        case "z1"
            v=z(1);

        case "z2"
            v=z(2);

        case "z3"
            v=z(3);

        case "z4"
            v=z(4);

        case "z1^2"
            v=z(1)^2;

        case "z2^2"
            v=z(2)^2;

        case "z3^2"
            v=z(3)^2;

        case "z4^2"
            v=z(4)^2;

        case "z1*z2"
            v=z(1)*z(2);

        case "z1*z3"
            v=z(1)*z(3);

        case "z1*z4"
            v=z(1)*z(4);

        case "z2*z3"
            v=z(2)*z(3);

        case "z2*z4"
            v=z(2)*z(4);

        case "z3*z4"
            v=z(3)*z(4);

        case "D"
            v=D;

        case "M_total"
            v=M;

        otherwise
            v=0;

    end


    y=y+coef(k)*v;


end

end