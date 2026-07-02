%% 第一问：线光源最优长度计算程序
% 坐标系：
% x轴：水平方向，线光源方向
% y轴：车灯对称轴，指向正前方
% z轴：竖直方向
%
% 模型方法：
% 采用几何覆盖判定法。
% 线光源长度为L时，测试屏上的最大水平覆盖范围为：
% Xmax(L) = D*L/(2f)
% 其中D为焦点到测试屏距离，f为抛物面焦距。
%
% 当Xmax(L)覆盖到B、C两点时，认为满足对应照明位置要求。
% 由于C点距离A点更远，因此最终最小可行长度由C点决定。

clear; clc; close all;

%% 1. 输入题目参数

R = 36;              % 车灯开口半径，单位：mm
d = 21.6;            % 车灯深度，单位：mm

D = 25000;           % 焦点到测试屏距离，单位：mm

AB = 1300;           % B点到A点的水平距离，单位：mm
AC = 2600;           % C点到A点的水平距离，单位：mm

%% 2. 计算抛物面焦距

% 抛物面方程：x^2 + z^2 = 4fy
% 开口处满足：x^2 + z^2 = R^2, y = d
% 因此：R^2 = 4fd

f = R^2 / (4*d);

%% 3. 计算B、C点达标所需线光源长度

% 线光源关于焦点对称放置，端点距焦点为L/2。
% 根据相似关系：
% Xmax(L) = D*(L/2)/f = D*L/(2f)
%
% 令Xmax(LB)=AB，得到B点达标长度：
% LB = 2f*AB/D
%
% 令Xmax(LC)=AC，得到C点达标长度：
% LC = 2f*AC/D

L_B = 2*f*AB/D;
L_C = 2*f*AC/D;

%% 4. 确定最小可行线光源长度

% 线光源必须同时满足B点和C点要求，
% 因此最小可行长度取二者中的较大值。

L_star = max(L_B, L_C);

%% 5. 计算功率

% 设线光源单位长度功率为k。
% 由于线光源均匀发光，总功率W与长度L成正比：
% W = kL
%
% 这里取k=1，得到相对功率。
% 若需要真实功率，只需将k替换为实际单位长度功率。

k = 1;
W_min = k * L_star;

% 归一化最小功率
W_min_normalized = 1;

%% 6. 输出结果

fprintf('================ 第一问计算结果 ================\n');
fprintf('车灯开口半径 R = %.2f mm\n', R);
fprintf('车灯深度 d = %.2f mm\n', d);
fprintf('抛物面焦距 f = %.2f mm\n', f);
fprintf('\n');

fprintf('测试屏距焦点 D = %.2f mm\n', D);
fprintf('B点水平距离 AB = %.2f mm\n', AB);
fprintf('C点水平距离 AC = %.2f mm\n', AC);
fprintf('\n');

fprintf('B点达标所需线光源长度 L_B = %.4f mm\n', L_B);
fprintf('C点达标所需线光源长度 L_C = %.4f mm\n', L_C);
fprintf('\n');

fprintf('最小可行线光源长度 L* = %.4f mm\n', L_star);
fprintf('若单位长度功率 k = %.2f，则最小功率 W_min = %.4f\n', k, W_min);
fprintf('归一化最小功率 W_min/W_min = %.2f\n', W_min_normalized);
fprintf('================================================\n');

%% 7. 可行性验证

Xmax_B = D*L_B/(2*f);
Xmax_C = D*L_C/(2*f);
Xmax_star = D*L_star/(2*f);

fprintf('\n================ 可行性验证 ================\n');
fprintf('当 L = L_B = %.4f mm 时，Xmax = %.2f mm，恰好覆盖B点\n', L_B, Xmax_B);
fprintf('当 L = L_C = %.4f mm 时，Xmax = %.2f mm，恰好覆盖C点\n', L_C, Xmax_C);
fprintf('当 L = L* = %.4f mm 时，Xmax = %.2f mm\n', L_star, Xmax_star);

if Xmax_star >= AB && Xmax_star >= AC
    fprintf('验证结果：L* 同时满足B、C两点要求。\n');
else
    fprintf('验证结果：L* 不满足要求，请检查计算。\n');
end

%% 8. 保存结果到表格

result_name = {'焦距f'; 'B点达标长度L_B'; 'C点达标长度L_C'; '最小可行长度L_star'; '最小相对功率W_min'};
result_value = [f; L_B; L_C; L_star; W_min];
result_unit = {'mm'; 'mm'; 'mm'; 'mm'; '相对单位'};

T = table(result_name, result_value, result_unit, ...
    'VariableNames', {'指标名称','数值','单位'});

writetable(T, '第一问计算结果.xlsx');

disp(' ');
disp('第一问计算结果表：');
disp(T);