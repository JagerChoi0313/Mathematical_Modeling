
%% CUMCM 2021 B 第三问
% 基于第二问响应面模型的非线性约束优化
% PSO + 响应面预测 + 可视化

clear;clc;close all;

%% 1. 读取第二问模型结果
% 将 Q2_response_surface_results.xlsx 放在当前目录
% 本程序默认从Excel读取模型系数

model = load_Q2_model();

%% 2. 优化设置
% x=[Co负载量, CoSiO2-HAP比例, 乙醇浓度, 温度]

lb=[0.5,0.33,0.3,250];
ub=[5,1,2.1,450];

cases={
    '无温度限制',250,450;
    '温度<=350℃',250,350
    };

result=[];

for k=1:size(cases,1)

    fprintf('\n===== %s =====\n',cases{k,1});

    lower=lb;
    upper=ub;
    upper(4)=cases{k,3};

    obj=@(x)-response_predict_final(x,0,model);

    options=optimoptions('particleswarm',...
        'SwarmSize',80,...
        'MaxIterations',100,...
        'Display','iter',...
        'OutputFcn',@save_pso);

    [xbest,fval]=particleswarm(obj,4,lower,upper,options);

    yield=-fval;

    fprintf('Co负载量 %.4f\n',xbest(1));
    fprintf('装料比例 %.4f\n',xbest(2));
    fprintf('乙醇浓度 %.4f\n',xbest(3));
    fprintf('温度 %.2f ℃\n',xbest(4));
    fprintf('预测C4收率 %.4f\n',yield);

    result=[result;
        {cases{k,1},xbest(1),xbest(2),xbest(3),xbest(4),yield}];

end


T=cell2table(result,...
'VariableNames',{'Case','Co_Load','Ratio','Ethanol','Temperature','C4_Yield'});

writetable(T,'Q3_optimization_results.xlsx');


%% 3. 绘图
plot_Q3_results(T);


