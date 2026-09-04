%% 第四问：基于GPR的贝叶斯优化实验设计
% 输入：
%       附件1.xlsx
%
% 输出：
%       5组推荐新增实验方案
%       EI变化图
%       收率提升曲线


clear;
clc;
close all;


%% ===============================
% 1.读取附件1实验数据
% ================================

data = load_data_Q4("附件1.xlsx");


X_train = data.X;
Y_train = data.Y;


fprintf("已有实验数量：%d\n",size(X_train,1));


%% ===============================
% 2. 设置实验变量范围
% ================================

% x1 Co负载量
% x2 Co/SiO2比例
% x3 乙醇浓度
% T 温度
% D 装料方式


lb = [
    0.5,...
    0.33,...
    0.30,...
    250,...
    0
];


ub = [
    5,...
    1,...
    2.10,...
    450,...
    1
];


%% ===============================
% 3. 贝叶斯优化循环
% ================================


new_points = [];
new_values = [];

best_history=[];
EI_history=[];


for iter = 1:5


    fprintf("\n第%d次新增实验选择\n",iter);



    %% ----建立GPR模型----

    gprModel = fitrgp(...
        X_train,...
        Y_train,...
        "KernelFunction","squaredexponential",...
        "Standardize",true);



    %% 当前最佳实验结果

    Y_best=max(Y_train);



    %% ----搜索最大EI点----

    [x_next,EI_max]=...
        search_next_point(...
        gprModel,...
        Y_best,...
        lb,...
        ub);



    fprintf("推荐实验条件:\n");

    fprintf("Co负载 %.3f\n",x_next(1));
    fprintf("比例 %.3f\n",x_next(2));
    fprintf("乙醇浓度 %.3f\n",x_next(3));
    fprintf("温度 %.2f\n",x_next(4));
    fprintf("装料方式 %.0f\n",x_next(5));

    fprintf("EI=%.5f\n",EI_max);



    %% ==========================
    % 模拟真实实验
    %
    % 实际使用时：
    % 这里替换为实验测得Y
    %
    % 当前为了代码可运行，
    % 使用GPR预测均值模拟
    % ==========================


    [y_predict,~]=predict(gprModel,x_next);


    y_new=y_predict;



    %% 更新数据

    X_train=[
        X_train;
        x_next
        ];


    Y_train=[
        Y_train;
        y_new
        ];



    new_points=[
        new_points;
        x_next
        ];


    new_values=[
        new_values;
        y_new
        ];



    best_history=[
        best_history;
        max(Y_train)
        ];


    EI_history=[
        EI_history;
        EI_max
        ];


end



%% ===============================
% 4.输出结果
% ================================


result_table=array2table(...
    new_points,...
    "VariableNames",...
    {
    "Co_Load",
    "Ratio",
    "Ethanol",
    "Temperature",
    "Method"
    });


result_table.C4_Yield=new_values;



disp("===== 五组推荐实验方案 =====")

disp(result_table)



writetable(...
    result_table,...
    "Q4_BO_results.xlsx");



%% ===============================
% 5.绘图
% ===============================


figure

plot(1:5,best_history,...
    "-o",...
    "LineWidth",2)

xlabel("新增实验次数")

ylabel("当前最佳C4烯烃收率")

title("贝叶斯优化过程")

grid on



figure

plot(1:5,EI_history,...
    "-o",...
    "LineWidth",2)

xlabel("实验次数")

ylabel("EI")

title("期望提升函数变化")

grid on

