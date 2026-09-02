%% CUMCM 2021 B题 第一问（V2）
% 多项式回归 + 拟合优度/残差检验 + 350℃时间稳定性分析
%
% 使用方法：
% 1. 将本文件、fit_temperature_models_v2.m、analyze_time_stability_v2.m、
%    附件1.xlsx、附件2.xlsx 放在同一个文件夹。
% 2. MATLAB“当前文件夹”切换到该目录。
% 3. 运行 Q1_main_v2.m。
%
% 说明：
% 本版不再按“第几列”硬编码读取附件1，而是按表头名称自动定位，
% 可避免催化剂编号列被错读为“催化剂组合描述”的问题。

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

outDir = fullfile(baseDir, 'Q1_output_v2');
figDir = fullfile(outDir, 'figures');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

assert(isfile(file1), '找不到附件1.xlsx，请将附件1与程序放在同一文件夹。');
assert(isfile(file2), '找不到附件2.xlsx，请将附件2与程序放在同一文件夹。');

%% Step 1  读取附件1：按表头名称定位变量
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

% Excel 中催化剂编号采用合并单元格：
% 只有每组第一行写 A1/A2/...，其余行为空，因此向下填充。
catalystID = filldown_string(catalystID);

% 删除关键变量不完整的数据行
valid = ~ismissing(catalystID) & ...
        strlength(strtrim(catalystID)) > 0 & ...
        ~isnan(temp) & ~isnan(conv) & ~isnan(c4sel);

catalystID = strtrim(catalystID(valid));
temp  = temp(valid);
conv  = conv(valid);
c4sel = c4sel(valid);

%% Step 2  数据完整性检查
% 催化剂编号必须形如 A1...A14、B1...B7。
isValidID = false(size(catalystID));
for i = 1:numel(catalystID)
    isValidID(i) = ~isempty(regexp(char(catalystID(i)), '^[AB]\d+$', 'once'));
end

if ~all(isValidID)
    badValues = unique(catalystID(~isValidID), 'stable');
    error(['催化剂编号读取异常。发现非 A1~B7 格式的内容：', ...
           strjoin(cellstr(badValues), ', '), ...
           newline, ...
           '这通常说明运行的不是本 V2 程序，或附件1表头/数据结构被修改。']);
end

ids = unique(catalystID, 'stable');

fprintf('==============================================\n');
fprintf('第一问：温度响应回归与时间稳定性分析（V2）\n');
fprintf('==============================================\n');
fprintf('附件1有效实验记录数：%d\n', numel(temp));
fprintf('识别到催化剂组合数：%d\n', numel(ids));
fprintf('识别到的编号：%s\n\n', strjoin(cellstr(ids), ', '));

assert(numel(ids) == 21, ...
    '正常附件1应识别到21种催化剂组合，目前识别到%d种，请检查上方编号列表。', ...
    numel(ids));

%% Step 3  温度响应：一次/二次多项式回归 + F检验 + 残差
regResult = fit_temperature_models_v2( ...
    catalystID, temp, conv, c4sel, figDir);

regFile = fullfile(outDir, 'temperature_regression_results.xlsx');
writetable(regResult, regFile);

%% Step 4  读取附件2并进行350℃时间稳定性分析
raw2 = readcell(file2);

timeMin = cell_column_to_double(raw2(:,1));
conv2   = cell_column_to_double(raw2(:,2));
c4sel2  = cell_column_to_double(raw2(:,4));

valid2 = ~isnan(timeMin) & ~isnan(conv2) & ~isnan(c4sel2);

timeMin = timeMin(valid2);
conv2   = conv2(valid2);
c4sel2  = c4sel2(valid2);

fprintf('附件2有效时间测试点：%d\n\n', numel(timeMin));

stabResult = analyze_time_stability_v2( ...
    timeMin, conv2, c4sel2, figDir);

stabFile = fullfile(outDir, 'stability_results.xlsx');
writetable(stabResult, stabFile);

%% Step 5  控制台输出关键结果
fprintf('\n==============================================\n');
fprintf('温度响应模型关键结果\n');
fprintf('==============================================\n');

summaryCols = {'催化剂编号','指标','最终模型','调整R2','RMSE','二次项F检验p值'};
disp(regResult(:, summaryCols));

fprintf('\n==============================================\n');
fprintf('350℃时间稳定性关键结果\n');
fprintf('==============================================\n');
disp(stabResult);

fprintf('\n运行完成。\n');
fprintf('结果表：%s\n', regFile);
fprintf('稳定性表：%s\n', stabFile);
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
% 将 readtable 取出的列安全转为 double。
    if isnumeric(v)
        x = double(v);
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
