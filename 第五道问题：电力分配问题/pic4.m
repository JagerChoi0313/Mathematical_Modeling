clc;
clear;
close all;

%% 第四问：初始方案线路潮流及阻塞判断表

%% 1. 输入第三问得到的初始出力方案

% 第三问初始出力分配预案
P_init = [150, 79, 180, 99.5, 125, 140, 95, 113.9];

%% 2. 输入第一问得到的线路潮流回归系数

% B第一行为常数项
% B第2行到第9行分别对应P1到P8的系数
% B每一列对应一条线路
B = [
    110.4775  131.3521 -108.9928   77.6116  133.1334  120.8481;
      0.0826   -0.0547   -0.0694   -0.0346    0.0003    0.2376;
      0.0478    0.1275    0.0620   -0.1028    0.2428   -0.0607;
      0.0528   -0.0001   -0.1565    0.2050   -0.0647   -0.0781;
      0.1199    0.0332   -0.0099   -0.0209   -0.0412    0.0929;
     -0.0257    0.0867    0.1247   -0.0120   -0.0655    0.0466;
      0.1216   -0.1127    0.0024    0.0057    0.0700   -0.0003;
      0.1220   -0.0186   -0.0028    0.1452   -0.0039    0.1664;
     -0.0015    0.0985   -0.2012    0.0763   -0.0092    0.0004
];

%% 3. 输入表6线路潮流限值

% 6条线路潮流限值
L = [165, 150, 160, 155, 132, 162];

%% 4. 计算第三问初始方案下的线路潮流

% 根据第一问回归模型计算线路潮流
F_init = B(1, :) + P_init * B(2:end, :);

% 计算潮流绝对值
Abs_F_init = abs(F_init);

% 判断是否阻塞
Block_Status = cell(6, 1);

for j = 1:6
    if Abs_F_init(j) > L(j)
        Block_Status{j} = '阻塞';
    else
        Block_Status{j} = '正常';
    end
end

%% 5. 生成结果表

Line = (1:6)';
Initial_Flow = F_init';
Initial_Abs_Flow = Abs_F_init';
Line_Limit = L';

result_table = table(Line, Initial_Flow, Initial_Abs_Flow, Line_Limit, Block_Status, ...
    'VariableNames', {'线路编号', '初始潮流_MW', '初始潮流绝对值_MW', ...
    '潮流限值_MW', '阻塞状态'});

%% 6. 显示结果表

disp('================ 第四问：初始方案线路潮流及阻塞判断表 ================');
disp(result_table);

%% 7. 导出为 Excel 表格

writetable(result_table, '第四问_初始方案线路潮流及阻塞判断表.xlsx');

fprintf('\n表格已导出为：第四问_初始方案线路潮流及阻塞判断表.xlsx\n');

%% 8. 输出阻塞线路汇总

blocked_lines = Line(Abs_F_init' > Line_Limit);

if isempty(blocked_lines)
    fprintf('初始方案下未发生输电阻塞。\n');
else
    fprintf('初始方案下发生输电阻塞的线路为：');
    fprintf('%d ', blocked_lines);
    fprintf('\n');
end