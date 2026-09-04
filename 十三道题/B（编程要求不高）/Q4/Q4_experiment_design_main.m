%% CUMCM 2021 B题 第四问：新增5次实验设计
% 模型：包含第三问最优点约束的增广D最优—空间填充混合实验设计
%
% 功能：
% 1. 自动读取第二问结果文件中的原始解析数据、标准化参数和响应面系数；
% 2. 固定总催化剂装料量为100 mg，并采用装料方式I；
% 3. 强制把第三问的预测最优点作为第1个新增实验；
% 4. 利用五水平分层设计保证4个因素在各自范围内得到覆盖；
% 5. 在满足空间距离和物理可行性约束的设计中，选择增广D准则最大的方案；
% 6. 输出5组实验方案、模型诊断指标和论文所需图像。
%
% 不需要 Optimization Toolbox 或 Statistics and Machine Learning Toolbox。

clear; clc; close all;

%% Step 0  文件路径、参数和输出目录
baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

% 优先读取标准文件名；若不存在，则自动寻找带日期或括号后缀的同名文件。
exactFile = fullfile(baseDir, 'Q2_response_surface_results.xlsx');
if isfile(exactFile)
    modelFile = exactFile;
else
    candidates = dir(fullfile(baseDir, 'Q2_response_surface_results*.xlsx'));
    assert(~isempty(candidates), ...
        ['未找到第二问结果文件。请把 Q2_response_surface_results.xlsx ', ...
         '放在本程序同一文件夹中。']);
    [~, newestIndex] = max([candidates.datenum]);
    modelFile = fullfile(candidates(newestIndex).folder, ...
                         candidates(newestIndex).name);
end

outDir = fullfile(baseDir, 'Q4_output');
figDir = fullfile(outDir, 'figures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

% 与第三问论文保持一致的控制条件。
totalMassNew = 100;       % Co/SiO2与HAP总装料量，mg
loadingMethodD = 0;       % 方式I=0，方式II=1

% 第三问得到的一般温度条件下预测最优点：
% [Co负载量(wt%), Co/SiO2占比, 乙醇浓度(mL/min), 温度(℃)]
xOpt = [0.5000, 0.4822, 0.3000, 450.0000];

% 空间分散性阈值。距离均在[0,1]^4标准化空间内计算。
minPairDistanceRequired = 0.45; % 新增点之间的最小距离
minOldDistanceRequired  = 0.05; % 探索点与已有实验点的最小距离

% D准则数值稳定参数，只用于计算log(det)，不改变响应面预测。
regularization = 1e-8;

fprintf('============================================================\n');
fprintf('第四问：新增5次实验的增广D最优—空间填充设计\n');
fprintf('============================================================\n');
fprintf('读取第二问结果：%s\n\n', modelFile);

%% Step 1  读取第二问模型和已有实验数据
parsed = readtable(modelFile, 'Sheet', 'ParsedData', ...
                   'VariableNamingRule', 'preserve');
stdTable = readtable(modelFile, 'Sheet', 'Standardization', ...
                     'VariableNamingRule', 'preserve');
convCoefTable = readtable(modelFile, 'Sheet', 'Conv_Coefficients', ...
                          'VariableNamingRule', 'preserve');
c4CoefTable = readtable(modelFile, 'Sheet', 'C4_Coefficients', ...
                        'VariableNamingRule', 'preserve');

requiredParsed = {'CoLoading_wtPct','CoSiO2_Fraction','TotalCatalyst_mg', ...
                  'Ethanol_mlMin','Temperature_C','LoadingMethod_D'};
assert(all(ismember(requiredParsed, parsed.Properties.VariableNames)), ...
    'ParsedData工作表缺少必要列，请确认输入文件来自第二问程序。');
assert(height(stdTable) >= 4, ...
    'Standardization工作表至少应包含4个核心因素。');

% 4个核心因素的顺序必须与第二问一致。
XoldRaw = [parsed.CoLoading_wtPct, ...
           parsed.CoSiO2_Fraction, ...
           parsed.Ethanol_mlMin, ...
           parsed.Temperature_C];
Dold = parsed.LoadingMethod_D;
massOld = parsed.TotalCatalyst_mg;

mu = stdTable.Mean(1:4)';
sigma = stdTable.Std(1:4)';
lb = stdTable.Min(1:4)';
ub = stdTable.Max(1:4)';

assert(all(sigma > 0), '标准化参数中的标准差必须大于0。');
assert(all(ub > lb), '每个因素的上界必须大于下界。');

massMean = mean(massOld);
massStd = std(massOld, 0);
assert(massStd > 0, '已有数据中的总装料量没有变化，无法进行标准化。');

Mold = (massOld - massMean) / massStd;
Mnew = (totalMassNew - massMean) / massStd;

fprintf('已有有效实验记录：%d条\n', size(XoldRaw,1));
fprintf('4个因素范围：\n');
fprintf('  Co负载量：%.2f ~ %.2f wt%%\n', lb(1), ub(1));
fprintf('  Co/SiO2占比：%.2f ~ %.2f\n', lb(2), ub(2));
fprintf('  乙醇浓度：%.2f ~ %.2f mL/min\n', lb(3), ub(3));
fprintf('  温度：%.0f ~ %.0f ℃\n', lb(4), ub(4));
fprintf('新增实验固定条件：总装料量=%.0f mg，装料方式=I\n\n', totalMassNew);

%% Step 2  构造已有实验的完整二次设计矩阵
% 完整回归向量：
% [1,z1,z2,z3,z4,D,M,z1^2,z2^2,z3^2,z4^2,
%  z1*z2,z1*z3,z1*z4,z2*z3,z2*z4,z3*z4]
nOld = size(XoldRaw,1);
p = 17;
XdesignOld = zeros(nOld,p);
for i = 1:nOld
    XdesignOld(i,:) = full_quadratic_basis( ...
        XoldRaw(i,:), Dold(i), Mold(i), mu, sigma);
end

infoOld = XdesignOld' * XdesignOld;
rankOld = rank(XdesignOld);
logDetOld = stable_logdet(infoOld, regularization);

fprintf('原完整二次设计矩阵：%d行 × %d列\n', size(XdesignOld,1), p);
fprintf('原设计矩阵秩：%d（满秩应为%d）\n', rankOld, p);
if rankOld < p
    fprintf('说明：原实验不能独立估计全部二次项和交互项，新增实验有必要。\n\n');
else
    fprintf('说明：原设计矩阵已经满秩，新增实验主要用于降低参数不确定性。\n\n');
end

%% Step 3  生成满足空间填充要求的候选五点设计
% 每个因素划分为5个水平。第三问最优点占用其中一个水平；
% 其余4个点分别占用剩余4个水平，从而保证每个因素都覆盖整个范围。
fiveLevels = cell(1,4);
for j = 1:4
    fiveLevels{j} = linspace(lb(j), ub(j), 5);
end

% 从每个因素的5个水平中删除与强制最优点最接近的水平。
% Co负载量、乙醇浓度和温度的最优点恰好位于边界；
% 装料占比0.4822与五水平中的0.4975最接近。
remainingLevels = cell(1,4);
for j = 1:4
    [~, removeIndex] = min(abs(fiveLevels{j} - xOpt(j)));
    remainingLevels{j} = fiveLevels{j};
    remainingLevels{j}(removeIndex) = [];
end

% 将Co负载量的剩余水平按升序固定；对另外3个因素的水平排列进行穷举。
% 总组合数为4!^3=13824，计算规模较小且不需要优化工具箱。
coLevels = remainingLevels{1};
ratioPermutations = perms(remainingLevels{2});
ethanolPermutations = perms(remainingLevels{3});
temperaturePermutations = perms(remainingLevels{4});

XoldNorm = normalize_by_range(XoldRaw, lb, ub);

bestLogDet = -Inf;
bestDesign = [];
bestMinPairDistance = NaN;
bestMinOldDistance = NaN;
feasibleDesignCount = 0;
testedDesignCount = 0;

fprintf('开始枚举五水平空间填充设计……\n');

for ir = 1:size(ratioPermutations,1)
    for ie = 1:size(ethanolPermutations,1)
        for it = 1:size(temperaturePermutations,1)
            testedDesignCount = testedDesignCount + 1;

            Xnew = [xOpt; ...
                    coLevels(:), ...
                    ratioPermutations(ir,:)', ...
                    ethanolPermutations(ie,:)', ...
                    temperaturePermutations(it,:)'];

            % Step 3.1  物理可行性检查：预测转化率与选择性应在0~100%。
            physicalOK = true;
            for k = 1:5
                [predConv, predSel] = response_prediction( ...
                    Xnew(k,:), loadingMethodD, Mnew, ...
                    convCoefTable, c4CoefTable, mu, sigma);
                if ~isfinite(predConv) || ~isfinite(predSel) || ...
                   predConv < 0 || predConv > 100 || ...
                   predSel < 0 || predSel > 100
                    physicalOK = false;
                    break;
                end
            end
            if ~physicalOK
                continue;
            end

            % Step 3.2  最大最小距离约束。
            XnewNorm = normalize_by_range(Xnew, lb, ub);
            minPairDistance = minimum_pairwise_distance(XnewNorm);
            minOldDistance = minimum_distance_to_old( ...
                XnewNorm(2:5,:), XoldNorm);

            if minPairDistance < minPairDistanceRequired || ...
               minOldDistance < minOldDistanceRequired
                continue;
            end

            feasibleDesignCount = feasibleDesignCount + 1;

            % Step 3.3  计算增广D最优准则。
            infoAug = infoOld;
            for k = 1:5
                f = full_quadratic_basis( ...
                    Xnew(k,:), loadingMethodD, Mnew, mu, sigma);
                infoAug = infoAug + f' * f;
            end
            currentLogDet = stable_logdet(infoAug, regularization);

            % 以D准则为主；若数值几乎相同，则选择点间距离更大的设计。
            if currentLogDet > bestLogDet + 1e-10 || ...
               (abs(currentLogDet-bestLogDet) <= 1e-10 && ...
                minPairDistance > bestMinPairDistance)
                bestLogDet = currentLogDet;
                bestDesign = Xnew;
                bestMinPairDistance = minPairDistance;
                bestMinOldDistance = minOldDistance;
            end
        end
    end
end

assert(~isempty(bestDesign), ...
    ['没有找到满足当前距离阈值的可行设计。可适当减小程序开头的 ', ...
     'minPairDistanceRequired 或 minOldDistanceRequired。']);

fprintf('候选五点设计总数：%d\n', testedDesignCount);
fprintf('满足物理与距离约束的设计数：%d\n', feasibleDesignCount);
fprintf('最优增广设计 log(det) = %.6f\n', bestLogDet);
fprintf('新增点最小两两距离 = %.6f\n', bestMinPairDistance);
fprintf('探索点到原实验的最小距离 = %.6f\n\n', bestMinOldDistance);

%% Step 4  计算最终5组实验的预测结果和信息增量
nNew = 5;
predConv = zeros(nNew,1);
predSel = zeros(nNew,1);
predYield = zeros(nNew,1);
informationGain = zeros(nNew,1);

infoSequential = infoOld;
for k = 1:nNew
    [predConv(k), predSel(k)] = response_prediction( ...
        bestDesign(k,:), loadingMethodD, Mnew, ...
        convCoefTable, c4CoefTable, mu, sigma);
    predYield(k) = predConv(k) * predSel(k) / 100;

    f = full_quadratic_basis( ...
        bestDesign(k,:), loadingMethodD, Mnew, mu, sigma);
    logBefore = stable_logdet(infoSequential, regularization);
    infoSequential = infoSequential + f' * f;
    logAfter = stable_logdet(infoSequential, regularization);
    informationGain(k) = logAfter - logBefore;
end

XdesignAug = [XdesignOld; zeros(nNew,p)];
for k = 1:nNew
    XdesignAug(nOld+k,:) = full_quadratic_basis( ...
        bestDesign(k,:), loadingMethodD, Mnew, mu, sigma);
end
rankAug = rank(XdesignAug);

coMass = totalMassNew * bestDesign(:,2);
hapMass = totalMassNew * (1-bestDesign(:,2));

experimentID = (1:nNew)';
designRole = ["验证第三问最优点"; repmat("空间填充与模型增广",4,1)];
loadingMethod = repmat("I",nNew,1);
totalMassColumn = repmat(totalMassNew,nNew,1);

resultTable = table( ...
    experimentID, designRole, bestDesign(:,1), bestDesign(:,2), ...
    coMass, hapMass, bestDesign(:,3), bestDesign(:,4), ...
    loadingMethod, totalMassColumn, predConv, predSel, predYield, ...
    informationGain, ...
    'VariableNames', { ...
    'Experiment_ID','Design_Role','Co_Loading_wtPct','CoSiO2_Fraction', ...
    'CoSiO2_mg','HAP_mg','Ethanol_mlMin','Temperature_C', ...
    'Loading_Method','Total_Catalyst_mg','Pred_Conversion_pct', ...
    'Pred_C4_Selectivity_pct','Pred_C4_Yield_pct','D_Information_Gain'});

fprintf('============================================================\n');
fprintf('推荐的5组新增实验\n');
fprintf('============================================================\n');
disp(resultTable);
fprintf('设计矩阵秩：新增前 %d，新增后 %d。\n', rankOld, rankAug);
if rankOld < p && rankAug == p
    fprintf('新增实验后完整二次设计矩阵达到满秩，可识别原来混叠的高阶项。\n');
end
fprintf(['注意：第2~5组的主要目的不是获得高收率，而是补充实验空间、', ...
         '检验响应面并提高参数估计能力。\n\n']);

%% Step 5  保存Excel结果
resultFile = fullfile(outDir, 'Q4_experiment_design_results.xlsx');
writetable(resultTable, resultFile, 'Sheet', 'Five_Experiments');

metricName = [ ...
    "Original_Design_Rank";
    "Augmented_Design_Rank";
    "Full_Model_Parameter_Count";
    "Original_LogDet";
    "Augmented_LogDet";
    "Minimum_New_Point_Distance";
    "Minimum_Distance_To_Old";
    "Tested_Design_Count";
    "Feasible_Design_Count"];
metricValue = [ ...
    rankOld;
    rankAug;
    p;
    logDetOld;
    bestLogDet;
    bestMinPairDistance;
    bestMinOldDistance;
    testedDesignCount;
    feasibleDesignCount];
metricTable = table(metricName, metricValue, ...
                    'VariableNames', {'Metric','Value'});
writetable(metricTable, resultFile, 'Sheet', 'Design_Diagnostics');

fprintf('Excel结果已保存：%s\n\n', resultFile);

%% Step 6  绘制论文所需图像
% 图1：原实验点与新增实验点在4个二维投影中的分布。
fig1 = figure('Color','w','Position',[80,80,1000,760]);
pairs = [1,2; 1,3; 2,4; 3,4];
xLabels = {'Co负载量 / wt%','Co负载量 / wt%', ...
           'Co/SiO_2占比','乙醇浓度 / (mL/min)'};
yLabels = {'Co/SiO_2占比','乙醇浓度 / (mL/min)', ...
           '温度 / ℃','温度 / ℃'};

for q = 1:4
    subplot(2,2,q);
    a = pairs(q,1); b = pairs(q,2);
    scatter(XoldRaw(:,a), XoldRaw(:,b), 24, [0.72 0.72 0.72], ...
            'filled','DisplayName','原实验点');
    hold on;
    scatter(bestDesign(2:5,a), bestDesign(2:5,b), 75, ...
            [0.20 0.55 0.78], 'filled','DisplayName','新增探索点');
    scatter(bestDesign(1,a), bestDesign(1,b), 130, ...
            [0.85 0.20 0.18], 'p','filled','DisplayName','预测最优点');
    xlabel(xLabels{q}); ylabel(yLabels{q});
    grid on; box on;
    if q == 1
        legend('Location','best');
    end
end
sgtitle('原实验点与5个新增实验点的空间分布');
save_figure(fig1, fullfile(figDir, 'Fig1_实验点空间分布.png'));

% 图2：5组新增实验的预测指标。
fig2 = figure('Color','w','Position',[120,120,900,520]);
bar([predConv,predSel,predYield], 'grouped');
xlabel('新增实验编号');
ylabel('预测值 / %');
title('5组新增实验的响应面预测结果');
legend({'乙醇转化率','C4烯烃选择性','C4烯烃收率'}, ...
       'Location','northoutside','Orientation','horizontal');
grid on; box on;
save_figure(fig2, fullfile(figDir, 'Fig2_新增实验预测结果.png'));

% 图3：新增前后设计矩阵奇异值，反映秩和参数可识别性的改善。
fig3 = figure('Color','w','Position',[150,150,820,520]);
sOld = sort(svd(XdesignOld),'descend');
sAug = sort(svd(XdesignAug),'descend');
semilogy(1:numel(sOld), max(sOld,1e-14), 'o-', ...
         'LineWidth',1.7,'MarkerSize',6);
hold on;
semilogy(1:numel(sAug), max(sAug,1e-14), 's-', ...
         'LineWidth',1.7,'MarkerSize',6);
xlabel('奇异值序号');
ylabel('奇异值（对数坐标）');
title('新增实验前后设计矩阵的信息结构比较');
legend({'新增前','新增后'},'Location','best');
grid on; box on;
save_figure(fig3, fullfile(figDir, 'Fig3_设计矩阵奇异值比较.png'));

% 图4：标准化后的5组实验因素热图，展示五水平空间覆盖。
fig4 = figure('Color','w','Position',[180,180,820,430]);
bestNorm = normalize_by_range(bestDesign, lb, ub);
imagesc(bestNorm);
colormap(parula(256)); colorbar;
caxis([0 1]);
set(gca,'XTick',1:4, ...
        'XTickLabel',{'Co负载量','装料占比','乙醇浓度','温度'}, ...
        'YTick',1:5, ...
        'YTickLabel',compose('实验%d',1:5));
xlabel('实验因素'); ylabel('新增实验编号');
title('新增实验在四维因素空间中的标准化水平');
save_figure(fig4, fullfile(figDir, 'Fig4_新增实验因素水平热图.png'));

fprintf('论文图片已保存到：%s\n', figDir);
fprintf('程序运行完成。\n');

%% ======================== 局部函数 ========================
function f = full_quadratic_basis(x, D, M, mu, sigma)
% 构造与第二问一致的完整二次回归向量。
    z = (x(:)' - mu) ./ sigma;
    z1 = z(1); z2 = z(2); z3 = z(3); z4 = z(4);
    f = [1,z1,z2,z3,z4,D,M, ...
         z1^2,z2^2,z3^2,z4^2, ...
         z1*z2,z1*z3,z1*z4,z2*z3,z2*z4,z3*z4];
end

function Xn = normalize_by_range(X, lb, ub)
% 按各因素取值范围标准化到[0,1]，用于计算空间距离。
    Xn = (X - lb) ./ (ub - lb);
end

function dmin = minimum_pairwise_distance(X)
% 计算同一组新增实验点之间的最小欧氏距离。
    n = size(X,1);
    dmin = Inf;
    for i = 1:n-1
        for j = i+1:n
            d = norm(X(i,:) - X(j,:), 2);
            if d < dmin
                dmin = d;
            end
        end
    end
end

function dmin = minimum_distance_to_old(Xnew, Xold)
% 计算新增探索点与所有已有实验点之间的最小距离。
    dmin = Inf;
    for i = 1:size(Xnew,1)
        delta = Xold - Xnew(i,:);
        d = min(sqrt(sum(delta.^2,2)));
        if d < dmin
            dmin = d;
        end
    end
end

function value = stable_logdet(A, regularization)
% 利用奇异值稳定计算log(det(A+epsilon*I))。
    B = (A + A')/2 + regularization*eye(size(A));
    s = svd(B);
    value = sum(log(max(s,regularization)));
end

function [conv, sel] = response_prediction( ...
    x, D, M, convTable, selTable, mu, sigma)
% 调用第二问的最终系数，预测乙醇转化率和C4烯烃选择性。
    z = (x(:)' - mu) ./ sigma;
    conv = calculate_one_response(convTable, z, D, M);
    sel  = calculate_one_response(selTable,  z, D, M);
end

function y = calculate_one_response(coefTable, z, D, M)
% 按Excel中的Term名称逐项计算响应值。
    terms = string(coefTable.Term);
    coefficients = coefTable.Coefficient;
    y = 0;

    for i = 1:numel(coefficients)
        switch terms(i)
            case "Intercept"
                v = 1;
            case "z1"
                v = z(1);
            case "z2"
                v = z(2);
            case "z3"
                v = z(3);
            case "z4"
                v = z(4);
            case "D"
                v = D;
            case "M_total"
                v = M;
            case "z1^2"
                v = z(1)^2;
            case "z2^2"
                v = z(2)^2;
            case "z3^2"
                v = z(3)^2;
            case "z4^2"
                v = z(4)^2;
            case "z1*z2"
                v = z(1)*z(2);
            case "z1*z3"
                v = z(1)*z(3);
            case "z1*z4"
                v = z(1)*z(4);
            case "z2*z3"
                v = z(2)*z(3);
            case "z2*z4"
                v = z(2)*z(4);
            case "z3*z4"
                v = z(3)*z(4);
            otherwise
                error('发现无法识别的模型项：%s', terms(i));
        end
        y = y + coefficients(i)*v;
    end
end

function save_figure(figHandle, filePath)
% 优先使用exportgraphics；旧版MATLAB不支持时自动改用print。
    try
        exportgraphics(figHandle, filePath, 'Resolution', 300);
    catch
        print(figHandle, filePath, '-dpng', '-r300');
    end
end
