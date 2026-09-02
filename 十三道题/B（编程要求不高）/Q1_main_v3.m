%% CUMCM 2021 B题 第一问（V3）
% 多项式回归 + 拟合优度 + LOOCV + F检验 + 残差诊断 + 时间稳定性分析
%
% 使用方法：
% 1. 将本文件、fit_temperature_models_v3.m、analyze_time_stability_v3.m、
%    附件1.xlsx、附件2.xlsx 放在同一个文件夹。
% 2. MATLAB“当前文件夹”切换到该目录。
% 3. 运行 Q1_main_v3.m。
%
% V3相对V2的主要改进：
% 1) 不再用 p<0.05 作为二次模型的唯一门槛；
% 2) 增加留一交叉验证 LOOCV-RMSE，检查模型的样本外稳定性；
% 3) 同时比较 Adjusted R^2、训练RMSE、LOOCV-RMSE、F检验和残差；
% 4) 输出“最终模型”和“候选模型比较”两个工作表，便于论文说明模型选择依据。

clear; clc; close all;
clear functions;
rehash;

%% Step 0  文件路径与输出目录
baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

file1 = fullfile(baseDir, '附件1.xlsx');
file2 = fullfile(baseDir, '附件2.xlsx');

outDir = fullfile(baseDir, 'Q1_output_v3');
figDir = fullfile(outDir, 'figures');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

assert(isfile(file1), '找不到附件1.xlsx，请将附件1与程序放在同一文件夹。');
assert(isfile(file2), '找不到附件2.xlsx，请将附件2与程序放在同一文件夹。');

%% Step 1  读取附件1：按表头名称自动定位变量
T1 = readtable(file1, 'VariableNamingRule', 'preserve');
varNames = string(T1.Properties.VariableNames);

idCol   = find(contains(varNames, "催化剂组合编号"), 1);
tempCol = find(varNames == "温度" | contains(varNames, "温度"), 1);
convCol = find(contains(varNames, "乙醇转化率"), 1);
c4Col   = find(contains(varNames, "C4烯烃选择性"), 1);

assert(~isempty(idCol),   '附件1中未找到“催化剂组合编号”列。');
assert(~isempty(tempCol), '附件1中未找到“温度”列。');
assert(~isempty(convCol), '附件1中未找到“乙醇转化率”列。');
assert(~isempty(c4Col),   '附件1中未找到“C4烯烃选择性”列。');

fprintf('检测到附件1列：\n');
fprintf('  催化剂编号列：%s\n', varNames(idCol));
fprintf('  温度列：%s\n', varNames(tempCol));
fprintf('  乙醇转化率列：%s\n', varNames(convCol));
fprintf('  C4烯烃选择性列：%s\n\n', varNames(c4Col));

catalystID = string(T1{:, idCol});
temp  = column_to_double(T1{:, tempCol});
conv  = column_to_double(T1{:, convCol});
c4sel = column_to_double(T1{:, c4Col});

% Excel中催化剂编号使用合并单元格，因此向下填充编号
catalystID = filldown_string(catalystID);

valid = ~ismissing(catalystID) & ...
        strlength(strtrim(catalystID)) > 0 & ...
        ~isnan(temp) & ~isnan(conv) & ~isnan(c4sel);

catalystID = strtrim(catalystID(valid));
temp  = temp(valid);
conv  = conv(valid);
c4sel = c4sel(valid);

%% Step 2  数据完整性检查
isValidID = false(size(catalystID));
for i = 1:numel(catalystID)
    isValidID(i) = ~isempty(regexp(char(catalystID(i)), '^[AB]\d+$', 'once'));
end

if ~all(isValidID)
    badValues = unique(catalystID(~isValidID), 'stable');
    error(['催化剂编号读取异常，发现：', ...
           strjoin(cellstr(badValues), ', ')]);
end

ids = unique(catalystID, 'stable');

fprintf('==============================================\n');
fprintf('第一问：温度响应回归与时间稳定性分析（V3）\n');
fprintf('==============================================\n');
fprintf('附件1有效实验记录数：%d\n', numel(temp));
fprintf('识别到催化剂组合数：%d\n', numel(ids));
fprintf('识别到的编号：%s\n\n', strjoin(cellstr(ids), ', '));

assert(numel(ids) == 21, ...
    '正常附件1应识别到21种催化剂组合，目前识别到%d种。', numel(ids));

%% Step 3  温度响应模型
% 返回：
% finalResult   —— 每个催化剂、每个指标的最终模型
% compareResult —— 一次/二次候选模型的完整比较指标
[finalResult, compareResult] = fit_temperature_models_v3( ...
    catalystID, temp, conv, c4sel, figDir);

regFile = fullfile(outDir, 'temperature_regression_results_v3.xlsx');

% 同一个Excel中写两个工作表
writetable(finalResult, regFile, 'Sheet', '最终模型');
writetable(compareResult, regFile, 'Sheet', '候选模型比较');

%% Step 4  附件2：350℃时间稳定性分析
raw2 = readcell(file2);

timeMin = cell_column_to_double(raw2(:,1));
conv2   = cell_column_to_double(raw2(:,2));
c4sel2  = cell_column_to_double(raw2(:,4));

valid2 = ~isnan(timeMin) & ~isnan(conv2) & ~isnan(c4sel2);

timeMin = timeMin(valid2);
conv2   = conv2(valid2);
c4sel2  = c4sel2(valid2);

fprintf('附件2有效时间测试点：%d\n\n', numel(timeMin));

stabResult = analyze_time_stability_v3( ...
    timeMin, conv2, c4sel2, figDir);

stabFile = fullfile(outDir, 'stability_results_v3.xlsx');
writetable(stabResult, stabFile);

%% Step 5  控制台输出关键结果
fprintf('\n==============================================\n');
fprintf('温度响应最终模型（V3）\n');
fprintf('==============================================\n');

summaryCols = {'催化剂编号','指标','最终模型','调整R2','RMSE', ...
               'LOOCV_RMSE','二次项F检验p值','选择依据'};
disp(finalResult(:, summaryCols));

fprintf('\n==============================================\n');
fprintf('350℃时间稳定性关键结果\n');
fprintf('==============================================\n');
disp(stabResult);

fprintf('\n运行完成。\n');
fprintf('温度模型结果：%s\n', regFile);
fprintf('稳定性结果：%s\n', stabFile);
fprintf('图片目录：%s\n', figDir);

%% ===== 局部辅助函数 =====
function s = filldown_string(s)
    s = string(s);
    for i = 1:numel(s)
        if i > 1 && (ismissing(s(i)) || strlength(strtrim(s(i))) == 0)
            s(i) = s(i-1);
        end
    end
end

function x = column_to_double(v)
    if isnumeric(v)
        x = double(v);
        x = x(:);
        return;
    end

    if iscell(v)
        x = nan(numel(v),1);
        for i = 1:numel(v)
            if isnumeric(v{i}) && isscalar(v{i})
                x(i) = double(v{i});
            else
                x(i) = str2double(string(v{i}));
            end
        end
        return;
    end

    x = str2double(string(v));
    x = x(:);
end

function x = cell_column_to_double(c)
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
