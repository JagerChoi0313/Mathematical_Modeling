%% CUMCM 2021 B题 第二问
% 多元二次响应面模型 + 层级约简 + LOOCV + 因素综合影响度
%
% 研究目标：
%   探讨催化剂组合及温度对
%   (1) 乙醇转化率
%   (2) C4烯烃选择性
%   的影响大小、方向、非线性与交互作用。
%
% 使用方法：
% 1. 将本文件、fit_response_surface_q2_v2.m、plot_q2_results.m
%    与附件1 Excel 放在同一个文件夹；
% 2. Excel 文件名可为“附件1.xlsx”或“附件1(日期...).xlsx”，
%    程序会自动寻找“附件1*.xlsx”；
% 3. 在 MATLAB 中将“当前文件夹”切换到该目录；
% 4. 运行 Q2_main_v3.m。
%
% 不要求 Statistics and Machine Learning Toolbox：
% t/F 检验、LOOCV、VIF 等均由程序自行计算。

clear; clc; close all;
clear functions;
rehash;

%% Step 0  定位输入文件与输出目录
baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

exactFile = fullfile(baseDir, '附件1.xlsx');
if isfile(exactFile)
    file1 = exactFile;
else
    files = dir(fullfile(baseDir, '附件1*.xlsx'));
    assert(~isempty(files), ...
        '未找到附件1 Excel。请将附件1*.xlsx与程序放在同一文件夹。');
    [~, idxNewest] = max([files.datenum]);
    file1 = fullfile(files(idxNewest).folder, files(idxNewest).name);
end

outDir = fullfile(baseDir, 'Q2_output');
figDir = fullfile(outDir, 'figures');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

fprintf('读取数据文件：%s\n\n', file1);

%% Step 1  读取附件1并按表头自动定位所需列
T = readtable(file1, 'VariableNamingRule', 'preserve');
varNames = string(T.Properties.VariableNames);

% 优先使用“精确列名”，避免“催化剂组合编号”被误识别成“催化剂组合”
idCol = find(varNames == "催化剂组合编号", 1);
if isempty(idCol)
    idCol = find(contains(varNames, "催化剂组合编号"), 1);
end

descCol = find(varNames == "催化剂组合", 1);
if isempty(descCol)
    descCol = find(contains(varNames, "催化剂组合") & ...
                   ~contains(varNames, "编号"), 1);
end

tempCol = find(varNames == "温度", 1);
if isempty(tempCol)
    tempCol = find(contains(varNames, "温度"), 1);
end

convCol = find(contains(varNames, "乙醇转化率"), 1);
c4Col   = find(contains(varNames, "C4烯烃选择性"), 1);

assert(~isempty(idCol),   '未找到“催化剂组合编号”列。');
assert(~isempty(descCol), '未找到“催化剂组合”描述列。');
assert(~isempty(tempCol), '未找到“温度”列。');
assert(~isempty(convCol), '未找到“乙醇转化率”列。');
assert(~isempty(c4Col),   '未找到“C4烯烃选择性”列。');

fprintf('检测到附件1列：\n');
fprintf('  催化剂编号列：第%d列 -> %s\n', idCol, varNames(idCol));
fprintf('  催化剂描述列：第%d列 -> %s\n', descCol, varNames(descCol));
fprintf('  温度列：第%d列 -> %s\n', tempCol, varNames(tempCol));
fprintf('  乙醇转化率列：第%d列 -> %s\n', convCol, varNames(convCol));
fprintf('  C4烯烃选择性列：第%d列 -> %s\n\n', c4Col, varNames(c4Col));

catalystID = string(T{:, idCol});
desc       = string(T{:, descCol});
temp       = column_to_double(T{:, tempCol});
yConv      = column_to_double(T{:, convCol});
yC4        = column_to_double(T{:, c4Col});

% 原表中催化剂编号与组合描述采用合并单元格，因此向下填充
catalystID = filldown_string(catalystID);
desc       = filldown_string(desc);

%% Step 2  从催化剂描述中自动提取数学模型所需因素
n0 = height(T);

coLoad    = nan(n0,1);   % x1：Co负载量 wt%
coMass    = nan(n0,1);   % Co/SiO2质量 mg（诊断用）
hapMass   = nan(n0,1);   % HAP质量 mg（诊断用）
loadRatio = nan(n0,1);   % x2：Co/SiO2在Co/SiO2+HAP中的质量占比
ethanol   = nan(n0,1);   % x3：乙醇浓度 ml/min
totalMass = nan(n0,1);   % 总催化剂装料量，作为可选控制变量
quartzFlag = false(n0,1);% 是否为石英砂/无HAP特殊组合

for i = 1:n0
    [coLoad(i), coMass(i), hapMass(i), loadRatio(i), ...
        ethanol(i), totalMass(i), quartzFlag(i)] = ...
        parse_catalyst_description(desc(i));
end

% x4：温度
% D：装料方式虚拟变量；A组=方式I=0，B组=方式II=1
D = double(startsWith(strtrim(catalystID), "B"));

% 删除不能用于本问建模的缺失记录
valid = ~ismissing(catalystID) & ~ismissing(desc) & ...
        isfinite(coLoad) & isfinite(loadRatio) & ...
        isfinite(ethanol) & isfinite(temp) & ...
        isfinite(yConv) & isfinite(yC4);

catalystID = catalystID(valid);
desc       = desc(valid);
temp       = temp(valid);
yConv      = yConv(valid);
yC4        = yC4(valid);
coLoad     = coLoad(valid);
coMass     = coMass(valid);
hapMass    = hapMass(valid);
loadRatio  = loadRatio(valid);
ethanol    = ethanol(valid);
totalMass  = totalMass(valid);
quartzFlag = quartzFlag(valid);
D          = D(valid);

n = numel(yConv);

% 正常附件1应得到114条有效记录；若解析失败则在建模前直接终止
if n == 0
    error(['催化剂参数解析后没有有效记录。请检查上方列识别结果。', newline, ...
           '正常情况下“催化剂编号列”应为第1列，“催化剂描述列”应为第2列。']);
end

fprintf('==============================================\n');
fprintf('第二问：多元二次响应面分析\n');
fprintf('==============================================\n');
fprintf('有效实验记录数：%d\n', n);
fprintf('催化剂组合数：%d\n', numel(unique(catalystID,'stable')));
fprintf('特殊“石英砂/无HAP”记录数：%d（保留，不删除）\n\n', sum(quartzFlag));

%% Step 3  构造四个核心连续因素并标准化
% x1 = Co负载量
% x2 = Co/SiO2在Co/SiO2+HAP中的质量占比
% x3 = 乙醇浓度
% x4 = 温度
Xraw = [coLoad, loadRatio, ethanol, temp];

factorNames = ["Co负载量", "CoSiO2-HAP装料比例", "乙醇浓度", "温度"];

mu = mean(Xraw, 1);
sigma = std(Xraw, 0, 1);

assert(all(sigma > 0), '存在没有变化的连续因素，无法标准化。');

Z = (Xraw - mu) ./ sigma;

% 附件中存在总装料量不同、但题面核心因素相同或接近的实验。
% 为避免这部分变化完全进入残差，程序额外建立“总装料量控制模型”做敏感性比较。
massMean = mean(totalMass);
massStd  = std(totalMass, 0);

if massStd > 0
    ZM = (totalMass - massMean) / massStd;
else
    ZM = zeros(size(totalMass));
end

fprintf('四个核心因素取值范围：\n');
for j = 1:4
    fprintf('  %-22s min=%8.4f, max=%8.4f\n', ...
        char(factorNames(j)), min(Xraw(:,j)), max(Xraw(:,j)));
end
fprintf('\n');

fprintf(['说明：主模型始终研究四个题面核心因素。\n' ...
         '程序另以“总装料量”作为控制变量进行敏感性比较；\n' ...
         '只有当其使LOOCV误差明显下降时，才在最终模型中保留该控制项，\n' ...
         '且总装料量不参与四个核心因素的影响度排名。\n\n']);

%% Step 4  分别建立“核心模型”和“增加总装料量控制项的模型”
% 核心模型：
% Y = 主效应 + 二次项 + 两两交互 + 装料方式D
%
% 扩展控制模型：
% 在核心模型基础上增加标准化总装料量 M
%
% 两种模型内部均：
% 1) 自动识别不可独立估计的高阶项；
% 2) 保留四个核心主效应；
% 3) 按层级原则约简二次项和交互项；
% 4) 综合p值、调整R2和LOOCV进行约简。

coreConv = fit_response_surface_q2_v2( ...
    Z, D, ZM, yConv, "乙醇转化率", false, factorNames);

massConv = fit_response_surface_q2_v2( ...
    Z, D, ZM, yConv, "乙醇转化率", true, factorNames);

coreC4 = fit_response_surface_q2_v2( ...
    Z, D, ZM, yC4, "C4烯烃选择性", false, factorNames);

massC4 = fit_response_surface_q2_v2( ...
    Z, D, ZM, yC4, "C4烯烃选择性", true, factorNames);

%% Step 5  控制模型选择
% 若加入总装料量后：
%   LOOCV-RMSE至少降低5%，且调整R2没有明显下降，
% 则采用含总装料量控制项的模型；
% 否则采用题面四因素核心模型。
[finalConv, convUseMass, convReason] = ...
    choose_control_model(coreConv, massConv);

[finalC4, c4UseMass, c4Reason] = ...
    choose_control_model(coreC4, massC4);

finalConv.selectionReason = convReason;
finalC4.selectionReason   = c4Reason;

%% Step 6  输出关键模型结果
fprintf('==============================================\n');
fprintf('乙醇转化率最终响应面模型\n');
fprintf('==============================================\n');
print_model_summary(finalConv, convUseMass);
fprintf('模型选择说明：%s\n\n', convReason);

fprintf('四因素综合影响度（乙醇转化率）：\n');
disp(finalConv.importanceTable(:, ...
    {'Factor','RelativeInfluence','GroupPValue','MeanMarginalEffect','PositivePercent'}));

fprintf('==============================================\n');
fprintf('C4烯烃选择性最终响应面模型\n');
fprintf('==============================================\n');
print_model_summary(finalC4, c4UseMass);
fprintf('模型选择说明：%s\n\n', c4Reason);

fprintf('四因素综合影响度（C4烯烃选择性）：\n');
disp(finalC4.importanceTable(:, ...
    {'Factor','RelativeInfluence','GroupPValue','MeanMarginalEffect','PositivePercent'}));

%% Step 7  绘制必要图像
preprocess.factorNames = factorNames;
preprocess.mu = mu;
preprocess.sigma = sigma;
preprocess.rawMin = min(Xraw,[],1);
preprocess.rawMax = max(Xraw,[],1);
preprocess.massMean = massMean;
preprocess.massStd = massStd;

plot_q2_results(finalConv, finalC4, ...
    Z, D, ZM, yConv, yC4, preprocess, figDir);

%% Step 8  保存 Excel 结果
resultFile = fullfile(outDir, 'Q2_response_surface_results.xlsx');

% 8.1 模型汇总
summaryTable = make_summary_table(finalConv, finalC4, convUseMass, c4UseMass);
writetable(summaryTable, resultFile, 'Sheet', 'ModelSummary');

% 8.2 回归系数及显著性
writetable(finalConv.coefTable, resultFile, 'Sheet', 'Conv_Coefficients');
writetable(finalC4.coefTable,   resultFile, 'Sheet', 'C4_Coefficients');

% 8.3 四个核心因素影响度
writetable(finalConv.importanceTable, resultFile, 'Sheet', 'Conv_Importance');
writetable(finalC4.importanceTable,   resultFile, 'Sheet', 'C4_Importance');

% 8.4 核心模型 vs 总装料量控制模型
controlCompare = make_control_compare_table( ...
    coreConv, massConv, coreC4, massC4, convUseMass, c4UseMass);
writetable(controlCompare, resultFile, 'Sheet', 'ControlCompare');

% 8.5 标准化参数
stdTable = table( ...
    factorNames(:), mu(:), sigma(:), ...
    min(Xraw,[],1)', max(Xraw,[],1)', ...
    'VariableNames', {'Factor','Mean','Std','Min','Max'});
writetable(stdTable, resultFile, 'Sheet', 'Standardization');

% 8.6 不可独立估计的候选高阶项
aliasTable = combine_alias_tables(coreConv, massConv, coreC4, massC4);
writetable(aliasTable, resultFile, 'Sheet', 'AliasedTerms');

% 8.7 模型约简历史
historyTable = combine_history_tables(finalConv, finalC4);
writetable(historyTable, resultFile, 'Sheet', 'ReductionHistory');

% 8.8 解析后的原始数据，便于检查催化剂因素提取是否正确
parsedTable = table( ...
    catalystID, desc, coLoad, coMass, hapMass, loadRatio, ...
    totalMass, ethanol, temp, D, quartzFlag, yConv, yC4, ...
    'VariableNames', ...
    {'CatalystID','Description','CoLoading_wtPct','CoSiO2_mg', ...
     'HAP_mg','CoSiO2_Fraction','TotalCatalyst_mg','Ethanol_mlMin', ...
     'Temperature_C','LoadingMethod_D','QuartzOrNoHAP', ...
     'EthanolConversion_pct','C4Selectivity_pct'});
writetable(parsedTable, resultFile, 'Sheet', 'ParsedData');

fprintf('\n==============================================\n');
fprintf('运行完成\n');
fprintf('==============================================\n');
fprintf('结果文件：%s\n', resultFile);
fprintf('图片目录：%s\n', figDir);
fprintf('\n建议首先查看 Excel 中的：\n');
fprintf('  1. ModelSummary\n');
fprintf('  2. Conv_Importance\n');
fprintf('  3. C4_Importance\n');
fprintf('  4. Conv_Coefficients / C4_Coefficients\n');

%% ==================== 局部辅助函数 ====================

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
        x = double(v(:));
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

function [coLoading, coMass, hapMass, ratio, ethanol, totalMass, quartzFlag] = ...
    parse_catalyst_description(desc)

    s = char(strtrim(desc));

    coLoading = NaN;
    coMass = NaN;
    hapMass = 0;
    ratio = NaN;
    ethanol = NaN;
    totalMass = NaN;
    quartzFlag = contains(string(s),"石英砂") || contains(string(s),"无HAP");

    % 例：200mg 1wt%Co/SiO2
    tok = regexp(s, ...
        '([\d.]+)\s*mg\s*([\d.]+)\s*wt%Co/SiO2', ...
        'tokens','once');

    if ~isempty(tok)
        coMass = str2double(tok{1});
        coLoading = str2double(tok{2});
    end

    % 例：200mg HAP
    tokHAP = regexp(s, '([\d.]+)\s*mg\s*HAP', 'tokens','once');
    if ~isempty(tokHAP)
        hapMass = str2double(tokHAP{1});
    end

    % 例：乙醇浓度1.68ml/min
    tokE = regexp(s, ...
        '乙醇浓度\s*([\d.]+)\s*ml/min', ...
        'tokens','once');
    if ~isempty(tokE)
        ethanol = str2double(tokE{1});
    end

    if isfinite(coMass) && isfinite(hapMass) && (coMass + hapMass) > 0
        ratio = coMass / (coMass + hapMass);
        totalMass = coMass + hapMass;
    end
end

function [chosen, useMass, reason] = choose_control_model(coreModel, massModel)
    % 总装料量控制项必须确实保留在最终模型中，
    % 且LOOCV至少改善5%，调整R2不明显恶化。
    massRetained = any(strcmp(string(massModel.coefTable.Term), "M_total"));

    cvImprove = (coreModel.stats.LOOCV_RMSE - massModel.stats.LOOCV_RMSE) ...
        / coreModel.stats.LOOCV_RMSE;

    if massRetained && ...
       cvImprove >= 0.05 && ...
       massModel.stats.AdjR2 >= coreModel.stats.AdjR2 - 0.01

        chosen = massModel;
        useMass = true;
        reason = sprintf( ...
            '加入总装料量控制项后LOOCV-RMSE降低%.2f%%，故保留该控制项。', ...
            100*cvImprove);
    else
        chosen = coreModel;
        useMass = false;
        reason = sprintf( ...
            '总装料量控制项未带来足够的样本外误差改善（LOOCV改善%.2f%%），采用核心四因素模型。', ...
            100*cvImprove);
    end
end

function print_model_summary(model, useMass)
    if useMass
        fprintf('模型类型：四核心因素响应面 + 装料方式 + 总装料量控制项\n');
    else
        fprintf('模型类型：四核心因素响应面 + 装料方式控制项\n');
    end

    fprintf('最终方程：%s\n', model.equation);
    fprintf('R2 = %.6f\n', model.stats.R2);
    fprintf('Adjusted R2 = %.6f\n', model.stats.AdjR2);
    fprintf('RMSE = %.6f\n', model.stats.RMSE);
    fprintf('LOOCV-RMSE = %.6f\n', model.stats.LOOCV_RMSE);
    fprintf('整体F检验 p = %.6g\n', model.stats.ModelPValue);
    fprintf('最大绝对标准化残差 = %.4f\n', model.stats.MaxAbsStdResidual);
    fprintf('最终模型最大VIF = %.4f\n', model.stats.MaxVIF);
end

function tbl = make_summary_table(model1, model2, useMass1, useMass2)
    Response = ["乙醇转化率"; "C4烯烃选择性"];
    UseTotalMassControl = [useMass1; useMass2];
    Equation = [string(model1.equation); string(model2.equation)];
    N = [model1.stats.N; model2.stats.N];
    NumParameters = [model1.stats.NumParameters; model2.stats.NumParameters];
    R2 = [model1.stats.R2; model2.stats.R2];
    AdjustedR2 = [model1.stats.AdjR2; model2.stats.AdjR2];
    RMSE = [model1.stats.RMSE; model2.stats.RMSE];
    LOOCV_RMSE = [model1.stats.LOOCV_RMSE; model2.stats.LOOCV_RMSE];
    ModelF = [model1.stats.ModelF; model2.stats.ModelF];
    ModelPValue = [model1.stats.ModelPValue; model2.stats.ModelPValue];
    MaxAbsStdResidual = ...
        [model1.stats.MaxAbsStdResidual; model2.stats.MaxAbsStdResidual];
    MaxVIF = [model1.stats.MaxVIF; model2.stats.MaxVIF];

    tbl = table(Response, UseTotalMassControl, Equation, N, NumParameters, ...
        R2, AdjustedR2, RMSE, LOOCV_RMSE, ModelF, ModelPValue, ...
        MaxAbsStdResidual, MaxVIF);
end

function tbl = make_control_compare_table(core1, mass1, core2, mass2, sel1, sel2)
    Response = ["乙醇转化率";"乙醇转化率";"C4烯烃选择性";"C4烯烃选择性"];
    CandidateModel = ["Core";"MassControl";"Core";"MassControl"];

    AdjR2 = [core1.stats.AdjR2; mass1.stats.AdjR2; ...
             core2.stats.AdjR2; mass2.stats.AdjR2];

    RMSE = [core1.stats.RMSE; mass1.stats.RMSE; ...
            core2.stats.RMSE; mass2.stats.RMSE];

    LOOCV_RMSE = [core1.stats.LOOCV_RMSE; mass1.stats.LOOCV_RMSE; ...
                   core2.stats.LOOCV_RMSE; mass2.stats.LOOCV_RMSE];

    Selected = [~sel1; sel1; ~sel2; sel2];

    tbl = table(Response, CandidateModel, AdjR2, RMSE, LOOCV_RMSE, Selected);
end

function tbl = combine_alias_tables(core1, mass1, core2, mass2)
    Model = strings(0,1);
    Term = strings(0,1);

    labels = ["Conv_Core","Conv_MassControl","C4_Core","C4_MassControl"];
    models = {core1,mass1,core2,mass2};

    for i = 1:4
        a = string(models{i}.aliasDropped(:));
        if isempty(a), continue; end
        Model = [Model; repmat(labels(i),numel(a),1)]; %#ok<AGROW>
        Term = [Term; a]; %#ok<AGROW>
    end

    if isempty(Model)
        Model = "None";
        Term = "无不可独立估计项";
    end

    tbl = table(Model,Term);
end

function tbl = combine_history_tables(model1, model2)
    h1 = model1.historyTable;
    h2 = model2.historyTable;

    if height(h1) > 0
        h1.Response = repmat("乙醇转化率",height(h1),1);
    end

    if height(h2) > 0
        h2.Response = repmat("C4烯烃选择性",height(h2),1);
    end

    if height(h1)==0 && height(h2)==0
        tbl = table("无删除项","-",NaN,NaN,NaN,NaN, ...
            'VariableNames', ...
            {'Response','RemovedTerm','PValueBefore', ...
             'LOOCV_Before','LOOCV_After','AdjR2_After'});
        return;
    end

    % 统一列顺序
    if height(h1)==0
        tbl = h2(:,{'Response','RemovedTerm','PValueBefore', ...
            'LOOCV_Before','LOOCV_After','AdjR2_After'});
    elseif height(h2)==0
        tbl = h1(:,{'Response','RemovedTerm','PValueBefore', ...
            'LOOCV_Before','LOOCV_After','AdjR2_After'});
    else
        tbl = [ ...
            h1(:,{'Response','RemovedTerm','PValueBefore', ...
            'LOOCV_Before','LOOCV_After','AdjR2_After'}); ...
            h2(:,{'Response','RemovedTerm','PValueBefore', ...
            'LOOCV_Before','LOOCV_After','AdjR2_After'})];
    end
end
