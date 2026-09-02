%% CUMCM 2021 B题 第一问：温度响应 + 拟合检验 + 时间稳定性
% 使用说明：
% 1) 将本文件、fit_temperature_models.m、analyze_time_stability.m、附件1.xlsx、附件2.xlsx
%    放在同一个文件夹中。
% 2) 在 MATLAB 中把“当前文件夹”切换到该目录。
% 3) 直接运行本脚本 Q1_main.m。
% 4) 程序会自动生成：
%    - Q1_output/temperature_regression_results.xlsx
%    - Q1_output/stability_results.xlsx
%    - Q1_output/figures/ 下的拟合图、残差图和稳定性图

clear; clc; close all;

%% Step 0. 文件路径与输出目录
baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

file1 = fullfile(baseDir, '附件1.xlsx');
file2 = fullfile(baseDir, '附件2.xlsx');
outDir = fullfile(baseDir, 'Q1_output');
figDir = fullfile(outDir, 'figures');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

assert(isfile(file1), '找不到附件1.xlsx，请将其与代码放在同一文件夹。');
assert(isfile(file2), '找不到附件2.xlsx，请将其与代码放在同一文件夹。');

%% Step 1. 读取附件1并整理第一问需要的数据
% 附件1中：
% 第2列 = 催化剂组合编号
% 第4列 = 温度
% 第5列 = 乙醇转化率(%%)
% 第7列 = C4烯烃选择性(%%)
T1 = readtable(file1, 'VariableNamingRule', 'preserve');

catalystID = string(T1{:,2});
temp       = double(T1{:,4});
conv       = double(T1{:,5});
c4sel      = double(T1{:,7});

% Excel 合并单元格读入后，催化剂编号只有每组第一行有值，需要向下填充。
catalystID = filldown_string(catalystID);

% 删除关键变量为空的行（正常附件一般不会触发）
valid = ~ismissing(catalystID) & ~isnan(temp) & ~isnan(conv) & ~isnan(c4sel);
catalystID = catalystID(valid);
temp = temp(valid);
conv = conv(valid);
c4sel = c4sel(valid);

fprintf('==============================================\n');
fprintf('第一问：温度响应回归与时间稳定性分析\n');
fprintf('==============================================\n');
fprintf('附件1有效实验记录数：%d\n', numel(temp));
fprintf('催化剂组合数：%d\n\n', numel(unique(catalystID,'stable')));

%% Step 2. 对21种催化剂组合分别进行一次/二次多项式拟合
% 模型：
%   一次：y = b0 + b1*z
%   二次：y = b0 + b1*z + b2*z^2
% 其中 z=(T-350)/100，使回归计算更稳定。
% 模型选择：调整R^2 + RMSE + 一次/二次嵌套F检验。
% 残差用于诊断，不机械删除异常点。
regResult = fit_temperature_models(catalystID, temp, conv, c4sel, figDir);

% 保存结果
regFile = fullfile(outDir, 'temperature_regression_results.xlsx');
writetable(regResult, regFile);

%% Step 3. 读取附件2，分析350℃下随时间变化的稳定性
% 附件2中：
% 第1列 = 时间(min)
% 第2列 = 乙醇转化率(%%)
% 第4列 = C4烯烃选择性(%%)
% 注意附件2前两行是多级表头，所以从第3个Excel数据行开始读取更稳妥。
raw2 = readcell(file2);

% 将各列转换成数值；非数值表头会变成 NaN
col1 = to_numeric(raw2(:,1));
col2 = to_numeric(raw2(:,2));
col4 = to_numeric(raw2(:,4));

valid2 = ~isnan(col1) & ~isnan(col2) & ~isnan(col4);
timeMin = col1(valid2);
conv2   = col2(valid2);
c4sel2  = col4(valid2);

stabResult = analyze_time_stability(timeMin, conv2, c4sel2, figDir);

stabFile = fullfile(outDir, 'stability_results.xlsx');
writetable(stabResult, stabFile);

%% Step 4. 控制台输出核心结论
fprintf('\n==============================================\n');
fprintf('温度响应模型：关键结果摘要\n');
fprintf('==============================================\n');

% 展示每个催化剂最终选择的模型类型
summaryCols = {'催化剂编号','指标','最终模型','调整R2','RMSE','二次项F检验p值'};
disp(regResult(:, summaryCols));

fprintf('\n==============================================\n');
fprintf('350℃时间稳定性：关键结果\n');
fprintf('==============================================\n');
disp(stabResult);

fprintf('\n运行完成。结果文件位于：\n%s\n', outDir);

%% ===== 本脚本局部辅助函数 =====
function s = filldown_string(s)
% 将催化剂编号中的空白/缺失值用上一行编号补齐。
    s = string(s);
    for i = 1:numel(s)
        if i > 1 && (ismissing(s(i)) || strlength(strtrim(s(i))) == 0)
            s(i) = s(i-1);
        end
    end
end

function x = to_numeric(c)
% 将 table/cell 中混合文本与数值的一列安全转换成 double。
    x = nan(size(c,1),1);
    for i = 1:size(c,1)
        v = c{i};
        if isnumeric(v) && isscalar(v)
            x(i) = double(v);
        else
            x(i) = str2double(string(v));
        end
    end
end
