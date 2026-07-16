%% 问题二完整求解：57家供应商未来24周经济订购与最小损耗转运
%
% 本程序补全问题二尚未完成的两个核心结果：
% 1. 针对问题二选出的57家供应商，制定未来24周最经济订购方案；
% 2. 根据订购方案，制定未来24周损耗最少的转运方案；
% 3. 检验每周库存是否始终不少于两周生产需求；
% 4. 自动填写附件A、附件B中"问题2"的结果区域；
% 5. 输出订购、供货、转运、库存、成本和损耗分析结果。
%
% -------------------------------------------------------------------------
% 一、模型结构
%
% 供应商预计供货量 q(i,t) 满足：
%   q(i,t) <= rho(i,t) * Xmax(i)
%   q(i,t) <= Uplan(i)
%
% 其中：
%   rho(i,t) 为未来第t周的订货响应系数；
%   Xmax(i)  为历史正订货量的90%分位数；
%   Uplan(i) 为规划供货上限。
%
% 订货量由预计供货量反推：
%   order(i,t) = q(i,t) / rho(i,t)
%
% 第一层：最小化原材料采购成本；
% 第二层：在采购成本最优的前提下最小化累计库存；
% 第三层：在前两层最优的前提下最小化运输损耗；
% 第四步：采用快速贪心法逐周整理转运方案，使一家供应商尽量由一家转运商运输。
%
% -------------------------------------------------------------------------
% 二、必需输入文件
%
% 1. 附件1 近5年402家供应商的相关数据.xlsx
% 2. 附件2 近5年8家转运商的相关数据.xlsx
% 3. 问题二_供应商未来供货能力分析.xlsx
% 4. 问题二_多年度情景最少供应商选择结果.xlsx
% 5. 附件A 订购方案数据结果.xlsx
% 6. 附件B 转运方案数据结果.xlsx
%
% 文件名带"(2)"等编号时，程序会自动查找。
%
% -------------------------------------------------------------------------
% 三、主要输出
%
% 1. 问题二_24周经济订购与最小损耗转运结果.xlsx
% 2. 附件A 订购方案数据结果.xlsx
% 3. 附件B 转运方案数据结果.xlsx
% 4. 问题二_24周原材料订购结构.png
% 5. 问题二_24周库存变化.png
% 6. 问题二_24周转运商运输量.png
%
% 运行条件：
% MATLAB需要安装 Optimization Toolbox，使用 linprog 和 intlinprog。

clear;
clc;
close all;

%% 1. 参数设置
numberOfSuppliers = 402;
historyWeeks = 240;
numberOfYears = 5;
weeksPerYear = 48;
futureWeeks = 24;
numberOfTransporters = 8;

weeklyProductDemand = 28200;
safetyInventory = 2 * weeklyProductDemand;
transporterCapacity = 6000;

% 历史年度递增权重
yearWeights = (1:numberOfYears)';
yearWeights = yearWeights / sum(yearWeights);

% 同周期响应系数收缩参数
responseShrinkageKappa = 2;

% 合理订货量上限分位数
orderUpperPercentile = 90;

% 数值容差
zeroTolerance = 1e-7;
relativeObjectiveTolerance = 1e-8;
absoluteObjectiveTolerance = 1e-5;

% 输入文件
supplierHistoryDefault = '附件1 近5年402家供应商的相关数据.xlsx';
transporterHistoryDefault = '附件2 近5年8家转运商的相关数据.xlsx';
capacityParameterDefault = '问题二_供应商未来供货能力分析.xlsx';
selectionResultDefault = '问题二_多年度情景最少供应商选择结果.xlsx';
attachmentADefault = '附件A 订购方案数据结果.xlsx';
attachmentBDefault = '附件B 转运方案数据结果.xlsx';

% 输出文件
resultFile = '问题二_24周经济订购与最小损耗转运结果.xlsx';
attachmentAOutput = '附件A 订购方案数据结果.xlsx';
attachmentBOutput = '附件B 转运方案数据结果.xlsx';

figureMaterialFile = '问题二_24周原材料订购结构.png';
figureInventoryFile = '问题二_24周库存变化.png';
figureTransportFile = '问题二_24周转运商运输量.png';

% 删除旧的独立结果工作簿，避免重复运行时残留旧数据
if isfile(resultFile)
    delete(resultFile);
end

%% 2. 检查求解器
if exist('linprog','file') ~= 2
    error('未检测到linprog，请安装或启用MATLAB Optimization Toolbox。');
end

linearOptions = optimoptions('linprog','Display','iter');

%% 3. 自动查找输入文件
supplierHistoryFile = localFindInputFile( ...
    supplierHistoryDefault, ...
    '附件1*402家供应商*.xlsx', ...
    '附件1供应商历史数据');

transporterHistoryFile = localFindInputFile( ...
    transporterHistoryDefault, ...
    '附件2*8家转运商*.xlsx', ...
    '附件2转运商历史数据');

capacityParameterFile = localFindInputFile( ...
    capacityParameterDefault, ...
    '问题二_供应商未来供货能力分析*.xlsx', ...
    '问题二供应商供货能力参数');

selectionResultFile = localFindInputFile( ...
    selectionResultDefault, ...
    '问题二_多年度情景最少供应商选择结果*.xlsx', ...
    '问题二最少供应商选择结果');

attachmentAFile = localFindInputFile( ...
    attachmentADefault, ...
    '附件A*订购方案数据结果*.xlsx', ...
    '附件A订购方案模板');

attachmentBFile = localFindInputFile( ...
    attachmentBDefault, ...
    '附件B*转运方案数据结果*.xlsx', ...
    '附件B转运方案模板');

fprintf('\n================ 输入文件 ================\n');
fprintf('供应商历史数据：%s\n',supplierHistoryFile);
fprintf('转运商历史数据：%s\n',transporterHistoryFile);
fprintf('供货能力参数：%s\n',capacityParameterFile);
fprintf('57家供应商集合：%s\n',selectionResultFile);
fprintf('附件A模板：%s\n',attachmentAFile);
fprintf('附件B模板：%s\n',attachmentBFile);

%% 4. 读取附件1：402家供应商历史订货量和供货量
orderCell = readcell( ...
    supplierHistoryFile, ...
    'Sheet','企业的订货量（m³）');

supplyCell = readcell( ...
    supplierHistoryFile, ...
    'Sheet','供应商的供货量（m³）');

if size(orderCell,1) < numberOfSuppliers+1 || ...
        size(orderCell,2) < historyWeeks+2
    error('附件1订货量工作表结构不完整。');
end

if size(supplyCell,1) < numberOfSuppliers+1 || ...
        size(supplyCell,2) < historyWeeks+2
    error('附件1供货量工作表结构不完整。');
end

allSupplierID = strtrim(string( ...
    orderCell(2:numberOfSuppliers+1,1)));

allMaterialType = upper(strtrim(string( ...
    orderCell(2:numberOfSuppliers+1,2))));

supplySupplierID = strtrim(string( ...
    supplyCell(2:numberOfSuppliers+1,1)));

supplyMaterialType = upper(strtrim(string( ...
    supplyCell(2:numberOfSuppliers+1,2))));

if any(allSupplierID ~= supplySupplierID)
    error('订货量表和供货量表中的供应商编号不一致。');
end

if any(allMaterialType ~= supplyMaterialType)
    error('订货量表和供货量表中的材料类别不一致。');
end

historicalOrder = localCellBlockToDouble( ...
    orderCell(2:numberOfSuppliers+1,3:historyWeeks+2), ...
    0, ...
    '历史订货量');

historicalSupply = localCellBlockToDouble( ...
    supplyCell(2:numberOfSuppliers+1,3:historyWeeks+2), ...
    0, ...
    '历史供货量');

if any(historicalOrder(:)<0) || any(historicalSupply(:)<0)
    error('附件1中存在负数订货量或供货量。');
end

%% 5. 读取问题二确定的57家核心供应商
selectionCell = readcell( ...
    selectionResultFile, ...
    'Sheet','选择集合_0p0pct');

selectionHeader = strtrim(string(selectionCell(1,:)));
selectionIDColumn = localFindHeader( ...
    selectionHeader,'供应商编号');

selectedSupplierID = strtrim(string( ...
    selectionCell(2:end,selectionIDColumn)));

selectedSupplierID = selectedSupplierID( ...
    strlength(selectedSupplierID)>0 & ...
    ~ismissing(selectedSupplierID));

[selectedFound,selectedLocation] = ...
    ismember(selectedSupplierID,allSupplierID);

if any(~selectedFound)
    error('57家供应商集合中存在无法在附件1中找到的供应商。');
end

selectedGlobalIndex = selectedLocation;
selectedMaterialType = ...
    allMaterialType(selectedGlobalIndex);

selectedSupplierCount = numel(selectedSupplierID);

if selectedSupplierCount ~= 57
    warning('读取到%d家供应商，不是预期的57家。', ...
        selectedSupplierCount);
end

fprintf('\n================ 供应商集合 ================\n');
fprintf('选定供应商数量：%d家\n',selectedSupplierCount);
fprintf('A类：%d家，B类：%d家，C类：%d家\n', ...
    sum(selectedMaterialType=="A"), ...
    sum(selectedMaterialType=="B"), ...
    sum(selectedMaterialType=="C"));

selectedSupplierListTable = table( ...
    (1:selectedSupplierCount)', ...
    selectedSupplierID, ...
    selectedMaterialType, ...
    'VariableNames',{'集合内序号','供应商编号','材料类别'});

fprintf('\n57家供应商编号及材料类别：\n');
disp(selectedSupplierListTable);

%% 6. 读取问题二供货能力参数
capacityCell = readcell( ...
    capacityParameterFile, ...
    'Sheet','未来供货能力参数');

capacityHeader = strtrim(string(capacityCell(1,:)));

capacityIDColumn = localFindHeader( ...
    capacityHeader,'供应商编号');
stableUpperColumn = localFindHeader( ...
    capacityHeader,'稳健供货上限');
overallResponseColumn = localFindHeader( ...
    capacityHeader,'订货响应系数');
timeWeightedColumn = localFindHeader( ...
    capacityHeader,'时间加权期望供货能力');
rankColumn = localFindHeader( ...
    capacityHeader,'问题一综合排名');

capacitySupplierID = strtrim(string( ...
    capacityCell(2:end,capacityIDColumn)));

[capacityFound,capacityLocation] = ...
    ismember(selectedSupplierID,capacitySupplierID);

if any(~capacityFound)
    error('供货能力参数表中缺少部分选定供应商。');
end

allStableUpper = localCellBlockToDouble( ...
    capacityCell(2:end,stableUpperColumn), ...
    0, ...
    '稳健供货上限');

allOverallResponse = localCellBlockToDouble( ...
    capacityCell(2:end,overallResponseColumn), ...
    0, ...
    '总体订货响应系数');

allTimeWeightedAbility = localCellBlockToDouble( ...
    capacityCell(2:end,timeWeightedColumn), ...
    0, ...
    '时间加权期望供货能力');

allProblem1Rank = localCellBlockToDouble( ...
    capacityCell(2:end,rankColumn), ...
    NaN, ...
    '问题一综合排名');

stableSupplyUpper = ...
    allStableUpper(capacityLocation);

overallResponse = ...
    allOverallResponse(capacityLocation);

timeWeightedAbility = ...
    allTimeWeightedAbility(capacityLocation);

problem1Rank = ...
    allProblem1Rank(capacityLocation);

% 规划供货上限：
% 避免时间加权期望能力高于原稳健上限而产生参数矛盾
planningSupplyUpper = max( ...
    stableSupplyUpper, ...
    timeWeightedAbility);

%% 7. 计算单位产品消耗系数和采购价格
materialConsumption = zeros(selectedSupplierCount,1);
purchasePrice = zeros(selectedSupplierCount,1);

materialConsumption(selectedMaterialType=="A") = 0.60;
materialConsumption(selectedMaterialType=="B") = 0.66;
materialConsumption(selectedMaterialType=="C") = 0.72;

% 以C类单位价格为1
purchasePrice(selectedMaterialType=="A") = 1.20;
purchasePrice(selectedMaterialType=="B") = 1.10;
purchasePrice(selectedMaterialType=="C") = 1.00;

%% 8. 估计未来24周订货响应系数和合理订货上限
futureResponse = zeros( ...
    selectedSupplierCount,futureWeeks);

samePeriodSampleCount = zeros( ...
    selectedSupplierCount,futureWeeks);

orderUpper = zeros(selectedSupplierCount,1);
responseUpper = zeros(selectedSupplierCount,1);

for i = 1:selectedSupplierCount
    globalIndex = selectedGlobalIndex(i);

    positiveOrders = historicalOrder( ...
        globalIndex, ...
        historicalOrder(globalIndex,:)>0);

    if isempty(positiveOrders)
        orderUpper(i) = 0;
    else
        orderUpper(i) = localPercentile( ...
            positiveOrders, ...
            orderUpperPercentile);
    end

    validOrderWeek = ...
        historicalOrder(globalIndex,:)>0;

    historicalResponseSample = ...
        historicalSupply(globalIndex,validOrderWeek) ./ ...
        historicalOrder(globalIndex,validOrderWeek);

    historicalResponseSample = ...
        historicalResponseSample( ...
        isfinite(historicalResponseSample) & ...
        historicalResponseSample>=0);

    if isempty(historicalResponseSample)
        responseUpper(i) = max(overallResponse(i),0);
    else
        responseUpper(i) = max( ...
            overallResponse(i), ...
            localPercentile( ...
            historicalResponseSample,90));
    end

    for t = 1:futureWeeks
        historicalWeekIndex = ...
            t + weeksPerYear*(0:numberOfYears-1);

        historicalOrderSample = ...
            historicalOrder(globalIndex,historicalWeekIndex);

        historicalSupplySample = ...
            historicalSupply(globalIndex,historicalWeekIndex);

        validSamePeriod = ...
            historicalOrderSample>0;

        sampleCount = sum(validSamePeriod);
        samePeriodSampleCount(i,t) = sampleCount;

        if sampleCount>0
            responseSample = ...
                historicalSupplySample(validSamePeriod) ./ ...
                historicalOrderSample(validSamePeriod);

            currentYearWeights = ...
                yearWeights(validSamePeriod);

            samePeriodResponse = ...
                sum(currentYearWeights .* responseSample') / ...
                sum(currentYearWeights);
        else
            samePeriodResponse = overallResponse(i);
        end

        shrinkageWeight = ...
            sampleCount / ...
            (sampleCount+responseShrinkageKappa);

        estimatedResponse = ...
            shrinkageWeight*samePeriodResponse + ...
            (1-shrinkageWeight)*overallResponse(i);

        estimatedResponse = max(estimatedResponse,0);

        if responseUpper(i)>0
            estimatedResponse = min( ...
                estimatedResponse,responseUpper(i));
        end

        futureResponse(i,t) = estimatedResponse;
    end
end

% 每家供应商未来各周最大可实现预计供货量
maximumExpectedSupply = min( ...
    futureResponse .* repmat(orderUpper,1,futureWeeks), ...
    repmat(planningSupplyUpper,1,futureWeeks));

% 选定供应商的单周供货量均不超过一家转运商6000立方米的容量
maximumExpectedSupply = min( ...
    maximumExpectedSupply, ...
    transporterCapacity);

% 供货量上限换算成产品产能
maximumProductCapacity = ...
    maximumExpectedSupply ./ ...
    repmat(materialConsumption,1,futureWeeks);

weeklyMaximumProductCapacity = ...
    sum(maximumProductCapacity,1);

if any(weeklyMaximumProductCapacity < weeklyProductDemand-zeroTolerance)
    infeasibleWeek = find( ...
        weeklyMaximumProductCapacity < weeklyProductDemand-zeroTolerance);

    error(['57家供应商在合理订货上限下，第%s周最大产能不足。' ...
        '请检查供货参数或扩展供应商集合。'], ...
        strjoin(string(infeasibleWeek),'、'));
end

fprintf('\n================ 未来供货能力核验 ================\n');
fprintf('24周最小最大产能：%.2f立方米产品/周\n', ...
    min(weeklyMaximumProductCapacity));
fprintf('24周最大产能覆盖率最低值：%.4f\n', ...
    min(weeklyMaximumProductCapacity)/weeklyProductDemand);

%% 9. 读取附件2并估计未来24周转运损耗率
lossCell = readcell( ...
    transporterHistoryFile, ...
    'Sheet','运输损耗率（%）');

if size(lossCell,1) < numberOfTransporters+1 || ...
        size(lossCell,2) < historyWeeks+1
    error('附件2运输损耗率工作表结构不完整。');
end

transporterID = strtrim(string( ...
    lossCell(2:numberOfTransporters+1,1)));

historicalLossPercent = localCellBlockToDouble( ...
    lossCell(2:numberOfTransporters+1,2:historyWeeks+1), ...
    0, ...
    '历史运输损耗率');

if any(historicalLossPercent(:)<0)
    error('历史运输损耗率中存在负数。');
end

% 题目说明：损耗率为0表示该周没有运送，因此估计时排除0
futureLossRate = zeros( ...
    numberOfTransporters,futureWeeks);

futureLossSampleCount = zeros( ...
    numberOfTransporters,futureWeeks);

for k = 1:numberOfTransporters
    allPositiveLoss = historicalLossPercent( ...
        k,historicalLossPercent(k,:)>0);

    if isempty(allPositiveLoss)
        fallbackLossPercent = 0;
    else
        fallbackLossPercent = mean(allPositiveLoss);
    end

    for t = 1:futureWeeks
        historicalWeekIndex = ...
            t + weeksPerYear*(0:numberOfYears-1);

        lossSample = ...
            historicalLossPercent(k,historicalWeekIndex);

        validLossSample = lossSample>0;
        futureLossSampleCount(k,t) = sum(validLossSample);

        if any(validLossSample)
            currentYearWeights = ...
                yearWeights(validLossSample);

            estimatedLossPercent = ...
                sum(currentYearWeights .* ...
                lossSample(validLossSample)') / ...
                sum(currentYearWeights);
        else
            estimatedLossPercent = fallbackLossPercent;
        end

        futureLossRate(k,t) = ...
            estimatedLossPercent/100;
    end
end

fprintf('\n================ 未来运输损耗率 ================\n');
for k = 1:numberOfTransporters
    fprintf('%s未来24周平均预计损耗率：%.4f%%\n', ...
        transporterID(k), ...
        100*mean(futureLossRate(k,:)));
end

%% 10. 构造联合订购—转运线性规划变量
%
% q(i,t)：供应商预计供货量
% y(i,k,t)：供应商由转运商运输的数量
% H(t)：第t周末库存产能当量
%
% 订货量将在求解后通过 q/rho 反推。

n = selectedSupplierCount;
K = numberOfTransporters;
T = futureWeeks;

qIndex = reshape( ...
    1:n*T, ...
    n,T);

yIndex = reshape( ...
    n*T + (1:n*K*T), ...
    n,K,T);

hIndex = ...
    n*T+n*K*T+(1:T);

numberOfVariables = ...
    n*T+n*K*T+T;

%% 11. 构造等式约束
%
% 11.1 每家供应商的供货量必须全部转运：
%      q(i,t) = sum_k y(i,k,t)
%
% 11.2 库存产能当量递推：
%      H(t)=H(t-1)+接收产能-D
%
numberOfEqualityConstraints = ...
    n*T+T;

Aeq = spalloc( ...
    numberOfEqualityConstraints, ...
    numberOfVariables, ...
    n*T*(K+1)+T*(n*K+2));

beq = zeros( ...
    numberOfEqualityConstraints,1);

row = 0;

% 供货量全部转运
for t = 1:T
    for i = 1:n
        row = row+1;

        Aeq(row,qIndex(i,t)) = 1;

        for k = 1:K
            Aeq(row,yIndex(i,k,t)) = -1;
        end
    end
end

% 库存递推
for t = 1:T
    row = row+1;

    Aeq(row,hIndex(t)) = 1;

    if t==1
        % H1 - 接收产能 = H0 - D = 2D-D=D
        beq(row) = safetyInventory-weeklyProductDemand;
    else
        Aeq(row,hIndex(t-1)) = -1;
        beq(row) = -weeklyProductDemand;
    end

    for i = 1:n
        for k = 1:K
            receivedProductCoefficient = ...
                (1-futureLossRate(k,t)) / ...
                materialConsumption(i);

            Aeq(row,yIndex(i,k,t)) = ...
                -receivedProductCoefficient;
        end
    end
end

%% 12. 构造转运商容量约束
%
% 每家转运商每周运输量不超过6000立方米
numberOfCapacityConstraints = K*T;

AubBase = spalloc( ...
    numberOfCapacityConstraints, ...
    numberOfVariables, ...
    n*K*T);

bubBase = ...
    transporterCapacity * ...
    ones(numberOfCapacityConstraints,1);

row = 0;

for t = 1:T
    for k = 1:K
        row = row+1;

        for i = 1:n
            AubBase(row,yIndex(i,k,t)) = 1;
        end
    end
end

%% 13. 变量上下界
lowerBound = zeros(numberOfVariables,1);
upperBound = inf(numberOfVariables,1);

% 预计供货量上限
for t = 1:T
    for i = 1:n
        upperBound(qIndex(i,t)) = ...
            maximumExpectedSupply(i,t);
    end
end

% 每个供应商—转运商运输量不超过该供应商当周供货上限
for t = 1:T
    for i = 1:n
        for k = 1:K
            upperBound(yIndex(i,k,t)) = ...
                maximumExpectedSupply(i,t);
        end
    end
end

% 各周库存不少于两周生产需求
for t = 1:T
    lowerBound(hIndex(t)) = safetyInventory;
end

% 第24周末恢复到初始安全库存，防止期末无效囤货
upperBound(hIndex(T)) = safetyInventory;

%% 14. 第一层：最小化原材料采购成本
purchaseCostObjective = zeros( ...
    numberOfVariables,1);

for t = 1:T
    for i = 1:n
        purchaseCostObjective(qIndex(i,t)) = ...
            purchasePrice(i);
    end
end

fprintf('\n================ 第一层：采购成本最小 ================\n');

[solutionCost,costOptimalValue,costExitflag] = linprog( ...
    purchaseCostObjective, ...
    AubBase,bubBase, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    linearOptions);

if costExitflag<=0 || isempty(solutionCost)
    error('采购成本最小化模型求解失败，exitflag=%d。', ...
        costExitflag);
end

costTolerance = max( ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance*abs(costOptimalValue));

fprintf('最优相对采购成本：%.6f\n',costOptimalValue);

%% 15. 第二层：固定最优成本，最小化累计库存
inventoryObjective = zeros( ...
    numberOfVariables,1);

inventoryObjective(hIndex) = 1;

AubInventory = [
    AubBase;
    sparse(purchaseCostObjective')
    ];

bubInventory = [
    bubBase;
    costOptimalValue+costTolerance
    ];

fprintf('\n================ 第二层：累计库存最小 ================\n');

[solutionInventory,inventoryOptimalValue,inventoryExitflag] = linprog( ...
    inventoryObjective, ...
    AubInventory,bubInventory, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    linearOptions);

if inventoryExitflag<=0 || isempty(solutionInventory)
    error('累计库存最小化模型求解失败，exitflag=%d。', ...
        inventoryExitflag);
end

inventoryTolerance = max( ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance*abs(inventoryOptimalValue));

fprintf('24周累计库存产能当量：%.6f\n', ...
    inventoryOptimalValue);

%% 16. 第三层：固定成本和库存，最小化连续转运损耗
lossObjective = zeros( ...
    numberOfVariables,1);

for t = 1:T
    for i = 1:n
        for k = 1:K
            lossObjective(yIndex(i,k,t)) = ...
                futureLossRate(k,t);
        end
    end
end

AubLoss = [
    AubBase;
    sparse(purchaseCostObjective');
    sparse(inventoryObjective')
    ];

bubLoss = [
    bubBase;
    costOptimalValue+costTolerance;
    inventoryOptimalValue+inventoryTolerance
    ];

fprintf('\n================ 第三层：运输损耗最小 ================\n');

[solutionLoss,continuousLossOptimalValue,lossExitflag] = linprog( ...
    lossObjective, ...
    AubLoss,bubLoss, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    linearOptions);

if lossExitflag<=0 || isempty(solutionLoss)
    error('运输损耗最小化模型求解失败，exitflag=%d。', ...
        lossExitflag);
end

fprintf('连续转运模型最小损耗量：%.6f立方米\n', ...
    continuousLossOptimalValue);

%% 17. 提取经济订购方案和连续转运方案
expectedSupplyPlan = zeros(n,T);
continuousTransportPlan = zeros(n,K,T);
plannedInventory = zeros(T,1);

for t = 1:T
    for i = 1:n
        expectedSupplyPlan(i,t) = ...
            solutionLoss(qIndex(i,t));

        for k = 1:K
            continuousTransportPlan(i,k,t) = ...
                solutionLoss(yIndex(i,k,t));
        end
    end

    plannedInventory(t) = ...
        solutionLoss(hIndex(t));
end

expectedSupplyPlan( ...
    abs(expectedSupplyPlan)<zeroTolerance) = 0;

continuousTransportPlan( ...
    abs(continuousTransportPlan)<zeroTolerance) = 0;

% 根据预计供货量反推订货量
orderPlan = zeros(n,T);

for t = 1:T
    for i = 1:n
        if expectedSupplyPlan(i,t)>zeroTolerance
            if futureResponse(i,t)<=zeroTolerance
                error('供应商%s第%d周响应系数为0但供货量大于0。', ...
                    selectedSupplierID(i),t);
            end

            orderPlan(i,t) = ...
                expectedSupplyPlan(i,t) / ...
                futureResponse(i,t);
        end
    end
end

% 数值核验
% orderPlan为n×T矩阵，orderUpperMatrix也必须保持n×T，
% 不能将orderPlan先拉成列向量后再与矩阵直接相减。
orderUpperMatrix = repmat(orderUpper,1,T);
orderUpperViolation = orderPlan-orderUpperMatrix;

if any(orderUpperViolation(:)>1e-4)
    error('反推订货量超过合理订货量上限。');
end

%% 18. 第四步：快速整理转运方案
%
% 原程序在每一周重复调用整数规划，会明显增加运行时间。
% 现改为"降序装载 + 低损耗优先"的快速贪心法：
% 1. 先按供应商当周供货量从大到小排序；
% 2. 优先分配给损耗率较低且剩余容量足够的转运商；
% 3. 若单家转运商容量不足，再进行最少次数拆分；
% 4. 若整理后的方案无法维持原线性规划库存轨迹，
%    自动退回该周连续线性规划转运方案。
%
% 该步骤不再反复求解整数规划，运行速度会明显加快。

finalTransportPlan = zeros(n,K,T);
actualInventory = zeros(T,1);
weeklyTransportMode = strings(T,1);
weeklyActiveAssignments = zeros(T,1);

previousActualInventory = safetyInventory;

for t = 1:T
    fixedSupply = expectedSupplyPlan(:,t);

    if sum(fixedSupply)<=zeroTolerance
        finalTransportPlan(:,:,t) = 0;
        actualInventory(t) = ...
            previousActualInventory-weeklyProductDemand;
        weeklyTransportMode(t) = "无供货";

        if actualInventory(t)<safetyInventory-zeroTolerance
            error('第%d周无供货导致库存低于安全库存。',t);
        end

        previousActualInventory = actualInventory(t);
        continue;
    end

    requiredReceivedProduct = ...
        weeklyProductDemand + ...
        plannedInventory(t) - ...
        previousActualInventory;

    requiredReceivedProduct = max(requiredReceivedProduct,0);

    greedyTransport = localGreedyWeeklyTransport( ...
        fixedSupply, ...
        futureLossRate(:,t), ...
        transporterCapacity, ...
        zeroTolerance);

    receivedProductGreedy = 0;

    for i = 1:n
        for k = 1:K
            receivedProductGreedy = ...
                receivedProductGreedy + ...
                (1-futureLossRate(k,t))* ...
                greedyTransport(i,k) / ...
                materialConsumption(i);
        end
    end

    if receivedProductGreedy+1e-5 >= requiredReceivedProduct
        finalTransportPlan(:,:,t) = greedyTransport;
        weeklyTransportMode(t) = "快速贪心单周方案";
    else
        finalTransportPlan(:,:,t) = ...
            continuousTransportPlan(:,:,t);
        weeklyTransportMode(t) = ...
            "连续线性规划兜底方案";
    end

    receivedProductCurrentWeek = 0;

    for i = 1:n
        for k = 1:K
            receivedProductCurrentWeek = ...
                receivedProductCurrentWeek + ...
                (1-futureLossRate(k,t))* ...
                finalTransportPlan(i,k,t) / ...
                materialConsumption(i);
        end
    end

    actualInventory(t) = ...
        previousActualInventory + ...
        receivedProductCurrentWeek - ...
        weeklyProductDemand;

    if actualInventory(t)<safetyInventory-1e-4
        finalTransportPlan(:,:,t) = ...
            continuousTransportPlan(:,:,t);

        weeklyTransportMode(t) = ...
            "连续线性规划库存兜底方案";

        receivedProductCurrentWeek = 0;

        for i = 1:n
            for k = 1:K
                receivedProductCurrentWeek = ...
                    receivedProductCurrentWeek + ...
                    (1-futureLossRate(k,t))* ...
                    finalTransportPlan(i,k,t) / ...
                    materialConsumption(i);
            end
        end

        actualInventory(t) = ...
            previousActualInventory + ...
            receivedProductCurrentWeek - ...
            weeklyProductDemand;
    end

    previousActualInventory = actualInventory(t);

    currentWeekTransport = finalTransportPlan(:,:,t);
    weeklyActiveAssignments(t) = ...
        sum(currentWeekTransport(:)>zeroTolerance);
end

%% 19. 最终结果核验
weeklyTransporterLoad = zeros(K,T);
weeklyLossAmount = zeros(T,1);
weeklyRawSupply = sum(expectedSupplyPlan,1)';
weeklyReceivedRaw = zeros(T,1);
weeklyReceivedProduct = zeros(T,1);
weeklyPurchaseCost = zeros(T,1);

for t = 1:T
    for k = 1:K
        weeklyTransporterLoad(k,t) = ...
            sum(finalTransportPlan(:,k,t));
    end

    for i = 1:n
        weeklyPurchaseCost(t) = ...
            weeklyPurchaseCost(t) + ...
            purchasePrice(i)*expectedSupplyPlan(i,t);

        for k = 1:K
            transportedQuantity = ...
                finalTransportPlan(i,k,t);

            weeklyLossAmount(t) = ...
                weeklyLossAmount(t) + ...
                futureLossRate(k,t)*transportedQuantity;

            weeklyReceivedRaw(t) = ...
                weeklyReceivedRaw(t) + ...
                (1-futureLossRate(k,t))*transportedQuantity;

            weeklyReceivedProduct(t) = ...
                weeklyReceivedProduct(t) + ...
                (1-futureLossRate(k,t))*transportedQuantity / ...
                materialConsumption(i);
        end
    end
end

if any(weeklyTransporterLoad(:) > transporterCapacity+1e-4)
    error('最终转运方案存在转运商超载。');
end

if any(actualInventory < safetyInventory-1e-4)
    error('最终方案存在库存低于两周安全库存的情况。');
end

% 核验每家供应商供货是否全部完成转运
for t = 1:T
    transferredBySupplier = ...
        sum(finalTransportPlan(:,:,t),2);

    transferredBySupplier = ...
        reshape(transferredBySupplier,n,1);

    if max(abs( ...
            transferredBySupplier- ...
            expectedSupplyPlan(:,t))) > 1e-4
        error('第%d周供应商供货量与转运量不一致。',t);
    end
end

%% 20. 汇总A、B、C三类原材料
materialLabels = ["A","B","C"];

weeklyOrderByType = zeros(T,3);
weeklySupplyByType = zeros(T,3);
weeklyReceivedByType = zeros(T,3);
weeklyProductReceivedByType = zeros(T,3);

for typeIndex = 1:3
    currentTypeMask = ...
        selectedMaterialType==materialLabels(typeIndex);

    weeklyOrderByType(:,typeIndex) = ...
        sum(orderPlan(currentTypeMask,:),1)';

    weeklySupplyByType(:,typeIndex) = ...
        sum(expectedSupplyPlan(currentTypeMask,:),1)';

    for t = 1:T
        receivedRawCurrentType = 0;

        for i = find(currentTypeMask)'
            for k = 1:K
                receivedRawCurrentType = ...
                    receivedRawCurrentType + ...
                    (1-futureLossRate(k,t))* ...
                    finalTransportPlan(i,k,t);
            end
        end

        weeklyReceivedByType(t,typeIndex) = ...
            receivedRawCurrentType;

        currentConsumption = ...
            materialConsumption(find(currentTypeMask,1));

        weeklyProductReceivedByType(t,typeIndex) = ...
            receivedRawCurrentType/currentConsumption;
    end
end

totalOrderByType = sum(weeklyOrderByType,1);
totalSupplyByType = sum(weeklySupplyByType,1);
totalReceivedByType = sum(weeklyReceivedByType,1);

totalPurchaseCost = sum(weeklyPurchaseCost);
totalLossAmount = sum(weeklyLossAmount);
totalTransportQuantity = sum(weeklyRawSupply);

if totalTransportQuantity>0
    averageLossRate = ...
        totalLossAmount/totalTransportQuantity;
else
    averageLossRate = 0;
end

activeSupplierCount = ...
    sum(sum(expectedSupplyPlan,2)>zeroTolerance);

splitSupplierWeekCount = 0;

for t = 1:T
    for i = 1:n
        if sum(finalTransportPlan(i,:,t)>zeroTolerance)>1
            splitSupplierWeekCount = ...
                splitSupplierWeekCount+1;
        end
    end
end

%% 21. 命令行输出关键结果
fprintf('\n============================================================\n');
fprintf(' 问题二：24周经济订购与最小损耗转运结果\n');
fprintf('============================================================\n');

fprintf('实际启用供应商：%d家\n',activeSupplierCount);
fprintf('24周相对采购成本：%.6f\n',totalPurchaseCost);
fprintf('24周预计供货总量：%.6f立方米\n',totalTransportQuantity);
fprintf('24周预计接收总量：%.6f立方米\n',sum(weeklyReceivedRaw));
fprintf('24周总运输损耗：%.6f立方米\n',totalLossAmount);
fprintf('平均运输损耗率：%.6f%%\n',100*averageLossRate);
fprintf('最低库存产能当量：%.6f立方米产品\n',min(actualInventory));
fprintf('期末库存产能当量：%.6f立方米产品\n',actualInventory(T));
fprintf('发生拆分运输的供应商—周组合：%d个\n', ...
    splitSupplierWeekCount);

fprintf('\nA/B/C类预计供货总量：\n');
fprintf('A类：%.6f立方米\n',totalSupplyByType(1));
fprintf('B类：%.6f立方米\n',totalSupplyByType(2));
fprintf('C类：%.6f立方米\n',totalSupplyByType(3));

fprintf('\nA/B/C类订货总量：\n');
fprintf('A类：%.6f立方米\n',totalOrderByType(1));
fprintf('B类：%.6f立方米\n',totalOrderByType(2));
fprintf('C类：%.6f立方米\n',totalOrderByType(3));

%% 22. 构造结果表
weekNumber = (1:T)';

weeklySummaryTable = table( ...
    weekNumber, ...
    weeklyOrderByType(:,1), ...
    weeklyOrderByType(:,2), ...
    weeklyOrderByType(:,3), ...
    sum(weeklyOrderByType,2), ...
    weeklySupplyByType(:,1), ...
    weeklySupplyByType(:,2), ...
    weeklySupplyByType(:,3), ...
    weeklyRawSupply, ...
    weeklyReceivedByType(:,1), ...
    weeklyReceivedByType(:,2), ...
    weeklyReceivedByType(:,3), ...
    weeklyReceivedRaw, ...
    weeklyReceivedProduct, ...
    actualInventory, ...
    weeklyPurchaseCost, ...
    weeklyLossAmount, ...
    weeklyTransportMode, ...
    weeklyActiveAssignments, ...
    'VariableNames',{ ...
    '周次','A类订货量','B类订货量','C类订货量', ...
    '订货总量','A类预计供货量','B类预计供货量', ...
    'C类预计供货量','预计供货总量','A类预计接收量', ...
    'B类预计接收量','C类预计接收量','预计接收总量', ...
    '接收产能当量','周末库存产能当量','相对采购成本', ...
    '运输损耗量','转运整理方式','有效转运分配数'});

transporterLoadTable = table(weekNumber);

for k = 1:K
    transporterLoadTable = addvars( ...
        transporterLoadTable, ...
        weeklyTransporterLoad(k,:)', ...
        'NewVariableNames',{char(transporterID(k))});
end

transporterUtilizationTable = table(weekNumber);

for k = 1:K
    transporterUtilizationTable = addvars( ...
        transporterUtilizationTable, ...
        weeklyTransporterLoad(k,:)'/transporterCapacity, ...
        'NewVariableNames',{char(transporterID(k))});
end

% 供应商订购与供货汇总
supplierTotalOrder = sum(orderPlan,2);
supplierTotalSupply = sum(expectedSupplyPlan,2);
supplierTotalTransport = zeros(n,1);
supplierTotalLoss = zeros(n,1);
supplierActiveWeeks = sum(expectedSupplyPlan>zeroTolerance,2);

for i = 1:n
    for t = 1:T
        for k = 1:K
            supplierTotalTransport(i) = ...
                supplierTotalTransport(i) + ...
                finalTransportPlan(i,k,t);

            supplierTotalLoss(i) = ...
                supplierTotalLoss(i) + ...
                futureLossRate(k,t)* ...
                finalTransportPlan(i,k,t);
        end
    end
end

supplierSummaryTable = table( ...
    selectedSupplierID, ...
    selectedMaterialType, ...
    problem1Rank, ...
    orderUpper, ...
    planningSupplyUpper, ...
    mean(futureResponse,2), ...
    supplierTotalOrder, ...
    supplierTotalSupply, ...
    supplierTotalTransport, ...
    supplierTotalLoss, ...
    supplierActiveWeeks, ...
    'VariableNames',{ ...
    '供应商编号','材料类别','问题一综合排名', ...
    '合理订货量上限','规划供货上限','24周平均响应系数', ...
    '24周订货总量','24周预计供货总量', ...
    '24周转运总量','24周运输损耗量','实际订货周数'});

% 24周订购方案表
weekVariableNames = cell(1,T);

for t = 1:T
    weekVariableNames{t} = ...
        sprintf('第%02d周',t);
end

orderPlanTable = array2table( ...
    orderPlan, ...
    'VariableNames',weekVariableNames);

orderPlanTable = addvars( ...
    orderPlanTable, ...
    selectedSupplierID, ...
    selectedMaterialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

supplyPlanTable = array2table( ...
    expectedSupplyPlan, ...
    'VariableNames',weekVariableNames);

supplyPlanTable = addvars( ...
    supplyPlanTable, ...
    selectedSupplierID, ...
    selectedMaterialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

% 预计损耗率表
lossRateTable = array2table( ...
    100*futureLossRate, ...
    'VariableNames',weekVariableNames);

lossRateTable = addvars( ...
    lossRateTable, ...
    transporterID, ...
    'Before',1, ...
    'NewVariableNames',{'转运商编号'});

% 转运方案长表
maximumLongRows = n*K*T;
longSupplier = strings(maximumLongRows,1);
longWeek = zeros(maximumLongRows,1);
longTransporter = strings(maximumLongRows,1);
longQuantity = zeros(maximumLongRows,1);
longLossRate = zeros(maximumLongRows,1);
longLossAmount = zeros(maximumLongRows,1);

longRow = 0;

for t = 1:T
    for i = 1:n
        for k = 1:K
            quantity = finalTransportPlan(i,k,t);

            if quantity>zeroTolerance
                longRow = longRow+1;
                longSupplier(longRow) = selectedSupplierID(i);
                longWeek(longRow) = t;
                longTransporter(longRow) = transporterID(k);
                longQuantity(longRow) = quantity;
                longLossRate(longRow) = 100*futureLossRate(k,t);
                longLossAmount(longRow) = ...
                    futureLossRate(k,t)*quantity;
            end
        end
    end
end

transportLongTable = table( ...
    longSupplier(1:longRow), ...
    longWeek(1:longRow), ...
    longTransporter(1:longRow), ...
    longQuantity(1:longRow), ...
    longLossRate(1:longRow), ...
    longLossAmount(1:longRow), ...
    'VariableNames',{ ...
    '供应商编号','周次','转运商编号','转运量', ...
    '预计损耗率百分比','预计损耗量'});

% 总体指标表
metricName = [ ...
    "选定供应商数量"; ...
    "实际启用供应商数量"; ...
    "A类订货总量"; ...
    "B类订货总量"; ...
    "C类订货总量"; ...
    "A类预计供货总量"; ...
    "B类预计供货总量"; ...
    "C类预计供货总量"; ...
    "预计供货总量"; ...
    "预计接收总量"; ...
    "相对采购成本"; ...
    "总运输损耗量"; ...
    "平均运输损耗率"; ...
    "最低库存产能当量"; ...
    "期末库存产能当量"; ...
    "拆分运输供应商周数"];

metricValue = [ ...
    selectedSupplierCount; ...
    activeSupplierCount; ...
    totalOrderByType(1); ...
    totalOrderByType(2); ...
    totalOrderByType(3); ...
    totalSupplyByType(1); ...
    totalSupplyByType(2); ...
    totalSupplyByType(3); ...
    totalTransportQuantity; ...
    sum(weeklyReceivedRaw); ...
    totalPurchaseCost; ...
    totalLossAmount; ...
    averageLossRate; ...
    min(actualInventory); ...
    actualInventory(T); ...
    splitSupplierWeekCount];

overallMetricTable = table( ...
    metricName,metricValue, ...
    'VariableNames',{'指标名称','指标值'});

%% 23. 写入独立结果工作簿
writetable(overallMetricTable, ...
    resultFile,'Sheet','总体指标');

writetable(weeklySummaryTable, ...
    resultFile,'Sheet','24周实施效果');

writetable(orderPlanTable, ...
    resultFile,'Sheet','57家24周订购方案');

writetable(supplyPlanTable, ...
    resultFile,'Sheet','57家24周预计供货');

writetable(transportLongTable, ...
    resultFile,'Sheet','24周转运方案明细');

writetable(transporterLoadTable, ...
    resultFile,'Sheet','转运商每周运输量');

writetable(transporterUtilizationTable, ...
    resultFile,'Sheet','转运商每周利用率');

writetable(supplierSummaryTable, ...
    resultFile,'Sheet','供应商汇总');

writetable(lossRateTable, ...
    resultFile,'Sheet','未来24周预计损耗率');

%% 24. 自动填写附件A问题2订购方案
if ~strcmp(char(attachmentAFile),attachmentAOutput)
    copyfile(attachmentAFile,attachmentAOutput,'f');
end

attachmentAIDCell = readcell( ...
    attachmentAOutput, ...
    'Sheet','问题2的订购方案结果', ...
    'Range','A7:A408');

attachmentASupplierID = strtrim(string(attachmentAIDCell));
attachmentAData = cell(numberOfSuppliers,T);

for globalRow = 1:numberOfSuppliers
    supplierIDCurrent = ...
        attachmentASupplierID(globalRow);

    selectedPosition = find( ...
        selectedSupplierID==supplierIDCurrent,1);

    for t = 1:T
        if ~isempty(selectedPosition) && ...
                orderPlan(selectedPosition,t)>zeroTolerance
            attachmentAData{globalRow,t} = ...
                orderPlan(selectedPosition,t);
        else
            attachmentAData{globalRow,t} = [];
        end
    end
end

writecell( ...
    attachmentAData, ...
    attachmentAOutput, ...
    'Sheet','问题2的订购方案结果', ...
    'Range','B7');

%% 25. 自动填写附件B问题2转运方案
if ~strcmp(char(attachmentBFile),attachmentBOutput)
    copyfile(attachmentBFile,attachmentBOutput,'f');
end

attachmentBIDCell = readcell( ...
    attachmentBOutput, ...
    'Sheet','问题2的转运方案结果', ...
    'Range','A7:A408');

attachmentBSupplierID = strtrim(string(attachmentBIDCell));
attachmentBData = cell(numberOfSuppliers,T*K);

for globalRow = 1:numberOfSuppliers
    supplierIDCurrent = ...
        attachmentBSupplierID(globalRow);

    selectedPosition = find( ...
        selectedSupplierID==supplierIDCurrent,1);

    for t = 1:T
        for k = 1:K
            outputColumn = ...
                (t-1)*K+k;

            if ~isempty(selectedPosition) && ...
                    finalTransportPlan( ...
                    selectedPosition,k,t)>zeroTolerance
                attachmentBData{globalRow,outputColumn} = ...
                    finalTransportPlan( ...
                    selectedPosition,k,t);
            else
                attachmentBData{globalRow,outputColumn} = [];
            end
        end
    end
end

writecell( ...
    attachmentBData, ...
    attachmentBOutput, ...
    'Sheet','问题2的转运方案结果', ...
    'Range','B7');

%% 26. 绘制24周原材料订购结构图
fig1 = figure( ...
    'Color','w', ...
    'Position',[100,100,1100,680]);

ax1 = axes(fig1);

bar(ax1,weekNumber,weeklyOrderByType,'stacked');

set(ax1,'XTick',1:T,'FontSize',11);
xlabel(ax1,'未来周次');
ylabel(ax1,'订货量（立方米）');
title(ax1,'问题二未来24周原材料订购结构','FontSize',15);
legend(ax1,{'A类','B类','C类'},'Location','best');
grid(ax1,'on');

localCloseToolbar(ax1);
drawnow;
localExportFigure(fig1,figureMaterialFile);

%% 27. 绘制库存变化图
fig2 = figure( ...
    'Color','w', ...
    'Position',[100,100,1100,680]);

ax2 = axes(fig2);
hold(ax2,'on');

plot(ax2,weekNumber,actualInventory, ...
    '-o','LineWidth',1.8,'MarkerSize',5);

plot(ax2,weekNumber, ...
    safetyInventory*ones(T,1), ...
    'k--','LineWidth',1.5);

set(ax2,'XTick',1:T,'FontSize',11);
xlabel(ax2,'未来周次');
ylabel(ax2,'周末库存产能当量（立方米产品）');
title(ax2,'问题二未来24周库存变化','FontSize',15);
legend(ax2,{'实际库存','两周安全库存'}, ...
    'Location','best');
grid(ax2,'on');
hold(ax2,'off');

localCloseToolbar(ax2);
drawnow;
localExportFigure(fig2,figureInventoryFile);

%% 28. 绘制转运商每周运输量
fig3 = figure( ...
    'Color','w', ...
    'Position',[100,100,1150,700]);

ax3 = axes(fig3);

bar(ax3,weekNumber,weeklyTransporterLoad','stacked');

set(ax3,'XTick',1:T,'FontSize',11);
xlabel(ax3,'未来周次');
ylabel(ax3,'运输量（立方米）');
title(ax3,'问题二未来24周转运商运输量','FontSize',15);
legend(ax3,cellstr(transporterID),'Location','eastoutside');
grid(ax3,'on');

localCloseToolbar(ax3);
drawnow;
localExportFigure(fig3,figureTransportFile);

%% 29. 完成提示
fprintf('\n计算完成。\n');
fprintf('完整分析结果：%s\n',resultFile);
fprintf('已填写附件A：%s\n',attachmentAOutput);
fprintf('已填写附件B：%s\n',attachmentBOutput);
fprintf('订购结构图：%s\n',figureMaterialFile);
fprintf('库存变化图：%s\n',figureInventoryFile);
fprintf('转运商运输量图：%s\n',figureTransportFile);

%% 局部函数1：自动查找输入文件
function fileName = localFindInputFile( ...
        defaultName,pattern,description)

    if isfile(defaultName)
        fileName = defaultName;
        return;
    end

    candidates = dir(pattern);

    if isempty(candidates)
        error('未找到%s。',description);
    end

    % 排除程序刚生成的无编号输出文件，优先使用最新文件
    [~,latestIndex] = max([candidates.datenum]);
    fileName = candidates(latestIndex).name;

    fprintf('未找到默认文件名，已自动使用：%s\n',fileName);
end

%% 局部函数2：查找表头
function columnIndex = localFindHeader( ...
        headerRow,targetName)

    columnIndex = find( ...
        headerRow==string(targetName),1);

    if isempty(columnIndex)
        error('未找到列：%s',targetName);
    end
end

%% 局部函数3：混合单元格转数值
function numericMatrix = localCellBlockToDouble( ...
        cellBlock,blankValue,blockName)

    numericMatrix = zeros(size(cellBlock));

    for index = 1:numel(cellBlock)
        value = cellBlock{index};

        if isempty(value)
            numericMatrix(index) = blankValue;

        elseif isnumeric(value)
            if isnan(value)
                numericMatrix(index) = blankValue;
            else
                numericMatrix(index) = double(value);
            end

        elseif islogical(value)
            numericMatrix(index) = double(value);

        else
            textValue = strtrim(string(value));

            if ismissing(textValue) || ...
                    strlength(textValue)==0
                numericMatrix(index) = blankValue;
            else
                convertedValue = str2double(textValue);

                if isnan(convertedValue)
                    error('%s中存在无法转换为数值的内容：%s', ...
                        blockName,textValue);
                end

                numericMatrix(index) = convertedValue;
            end
        end
    end
end

%% 局部函数4：百分位数，不依赖Statistics Toolbox
function percentileValue = localPercentile( ...
        dataVector,percentileLevel)

    dataVector = dataVector(:);
    dataVector = dataVector(isfinite(dataVector));
    dataVector = sort(dataVector);

    if isempty(dataVector)
        percentileValue = NaN;
        return;
    end

    if numel(dataVector)==1
        percentileValue = dataVector(1);
        return;
    end

    percentileLevel = min( ...
        max(percentileLevel,0),100);

    position = 1 + ...
        (numel(dataVector)-1)* ...
        percentileLevel/100;

    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex==upperIndex
        percentileValue = ...
            dataVector(lowerIndex);
    else
        interpolationWeight = ...
            position-lowerIndex;

        percentileValue = ...
            dataVector(lowerIndex) + ...
            interpolationWeight * ...
            (dataVector(upperIndex)- ...
            dataVector(lowerIndex));
    end
end

%% 局部函数5：逐周整数转运整理
function [fullWeekTransport,modeText,exitflagOutput] = ...
        localSolveWeeklyTransportMILP( ...
        fixedSupply, ...
        positiveSupplierIndex, ...
        materialConsumption, ...
        currentLossRate, ...
        transporterCapacity, ...
        requiredReceivedProduct, ...
        maximumCarriersPerSupplier, ...
        integerOptions, ...
        zeroTolerance)

    nAll = numel(fixedSupply);
    K = numel(currentLossRate);
    nPositive = numel(positiveSupplierIndex);

    numberOfY = nPositive*K;
    numberOfZ = nPositive*K;
    numberOfVariables = numberOfY+numberOfZ;

    yIndex = reshape( ...
        1:numberOfY, ...
        nPositive,K);

    zIndex = reshape( ...
        numberOfY+(1:numberOfZ), ...
        nPositive,K);

    integerVariables = ...
        numberOfY+(1:numberOfZ);

    % 每家供应商的运输量之和等于固定供货量
    Aeq = spalloc( ...
        nPositive, ...
        numberOfVariables, ...
        nPositive*K);

    beq = zeros(nPositive,1);

    for p = 1:nPositive
        supplierIndex = ...
            positiveSupplierIndex(p);

        for k = 1:K
            Aeq(p,yIndex(p,k)) = 1;
        end

        beq(p) = fixedSupply(supplierIndex);
    end

    % 不等式：
    % 1. 转运商容量；
    % 2. y <= q*z；
    % 3. 每家供应商最多使用指定数量的转运商；
    % 4. 接收产能不低于需求。
    numberOfInequalities = ...
        K+nPositive*K+nPositive+1;

    Aub = spalloc( ...
        numberOfInequalities, ...
        numberOfVariables, ...
        K*nPositive + ...
        2*nPositive*K + ...
        nPositive*K);

    bub = zeros(numberOfInequalities,1);

    row = 0;

    % 转运商容量
    for k = 1:K
        row = row+1;

        for p = 1:nPositive
            Aub(row,yIndex(p,k)) = 1;
        end

        bub(row) = transporterCapacity;
    end

    % y <= q*z
    for p = 1:nPositive
        supplierIndex = ...
            positiveSupplierIndex(p);

        supplierQuantity = ...
            fixedSupply(supplierIndex);

        for k = 1:K
            row = row+1;

            Aub(row,yIndex(p,k)) = 1;
            Aub(row,zIndex(p,k)) = ...
                -supplierQuantity;

            bub(row) = 0;
        end
    end

    % 每家供应商使用的转运商数量
    for p = 1:nPositive
        row = row+1;

        for k = 1:K
            Aub(row,zIndex(p,k)) = 1;
        end

        bub(row) = ...
            maximumCarriersPerSupplier;
    end

    % 接收产能下限
    row = row+1;

    for p = 1:nPositive
        supplierIndex = ...
            positiveSupplierIndex(p);

        for k = 1:K
            receivedCoefficient = ...
                (1-currentLossRate(k)) / ...
                materialConsumption(supplierIndex);

            Aub(row,yIndex(p,k)) = ...
                -receivedCoefficient;
        end
    end

    bub(row) = ...
        -requiredReceivedProduct;

    lowerBound = zeros(numberOfVariables,1);
    upperBound = ones(numberOfVariables,1);

    % y变量上界为供应商固定供货量
    for p = 1:nPositive
        supplierIndex = ...
            positiveSupplierIndex(p);

        supplierQuantity = ...
            fixedSupply(supplierIndex);

        for k = 1:K
            upperBound(yIndex(p,k)) = ...
                supplierQuantity;
        end
    end

    % 第一阶段：损耗量最小
    lossObjective = zeros(numberOfVariables,1);

    for p = 1:nPositive
        for k = 1:K
            lossObjective(yIndex(p,k)) = ...
                currentLossRate(k);
        end
    end

    [solutionLoss,lossOptimal,exitflagLoss] = intlinprog( ...
        lossObjective, ...
        integerVariables, ...
        Aub,bub, ...
        Aeq,beq, ...
        lowerBound,upperBound, ...
        integerOptions);

    if exitflagLoss<=0 || isempty(solutionLoss)
        fullWeekTransport = zeros(nAll,K);
        modeText = "整数转运不可行";
        exitflagOutput = exitflagLoss;
        return;
    end

    % 第二阶段：固定最小损耗，最少化有效转运分配数
    lossTolerance = max( ...
        1e-7, ...
        1e-8*abs(lossOptimal));

    assignmentObjective = zeros(numberOfVariables,1);
    assignmentObjective(numberOfY+1:end) = 1;

    AubSecond = [
        Aub;
        sparse(lossObjective')
        ];

    bubSecond = [
        bub;
        lossOptimal+lossTolerance
        ];

    [solutionAssignment,~,exitflagAssignment] = intlinprog( ...
        assignmentObjective, ...
        integerVariables, ...
        AubSecond,bubSecond, ...
        Aeq,beq, ...
        lowerBound,upperBound, ...
        integerOptions);

    if exitflagAssignment>0 && ...
            ~isempty(solutionAssignment)
        finalSolution = solutionAssignment;
        exitflagOutput = exitflagAssignment;
    else
        finalSolution = solutionLoss;
        exitflagOutput = exitflagLoss;
    end

    fullWeekTransport = zeros(nAll,K);

    for p = 1:nPositive
        supplierIndex = ...
            positiveSupplierIndex(p);

        for k = 1:K
            quantity = ...
                finalSolution(yIndex(p,k));

            if abs(quantity)<zeroTolerance
                quantity = 0;
            end

            fullWeekTransport(supplierIndex,k) = ...
                quantity;
        end
    end

    if maximumCarriersPerSupplier==1
        modeText = "单一转运商整数方案";
    else
        modeText = "最多两家转运商整数方案";
    end
end

%% 局部函数6：快速贪心转运分配
function weekTransport = localGreedyWeeklyTransport( ...
        fixedSupply,currentLossRate,transporterCapacity,zeroTolerance)

    n = numel(fixedSupply);
    K = numel(currentLossRate);

    weekTransport = zeros(n,K);
    remainingCapacity = ...
        transporterCapacity*ones(K,1);

    positiveSupplier = find(fixedSupply>zeroTolerance);

    if isempty(positiveSupplier)
        return;
    end

    % 先处理供货量大的供应商，降低容量碎片化
    [~,supplierOrder] = sort( ...
        fixedSupply(positiveSupplier),'descend');

    sortedSupplier = positiveSupplier(supplierOrder);

    % 转运商按预计损耗率从低到高排序
    [~,lowLossOrder] = sort(currentLossRate,'ascend');

    for p = 1:numel(sortedSupplier)
        supplierIndex = sortedSupplier(p);
        quantityRemaining = fixedSupply(supplierIndex);

        % 优先寻找能够整单承运且损耗最低的转运商
        selectedCarrier = 0;

        for orderIndex = 1:K
            carrierIndex = lowLossOrder(orderIndex);

            if remainingCapacity(carrierIndex) >= ...
                    quantityRemaining-zeroTolerance
                selectedCarrier = carrierIndex;
                break;
            end
        end

        if selectedCarrier>0
            weekTransport(supplierIndex,selectedCarrier) = ...
                quantityRemaining;

            remainingCapacity(selectedCarrier) = ...
                remainingCapacity(selectedCarrier)- ...
                quantityRemaining;

            continue;
        end

        % 无法整单承运时，按低损耗优先进行最少必要拆分
        for orderIndex = 1:K
            carrierIndex = lowLossOrder(orderIndex);

            if remainingCapacity(carrierIndex)<=zeroTolerance
                continue;
            end

            allocatedQuantity = min( ...
                quantityRemaining, ...
                remainingCapacity(carrierIndex));

            weekTransport(supplierIndex,carrierIndex) = ...
                allocatedQuantity;

            remainingCapacity(carrierIndex) = ...
                remainingCapacity(carrierIndex)- ...
                allocatedQuantity;

            quantityRemaining = ...
                quantityRemaining-allocatedQuantity;

            if quantityRemaining<=zeroTolerance
                break;
            end
        end

        if quantityRemaining>1e-5
            error('快速转运分配失败：本周转运总容量不足。');
        end
    end
end

%% 局部函数7：关闭坐标区工具栏
function localCloseToolbar(ax)
    try
        if ~isempty(ax.Toolbar)
            ax.Toolbar.Visible = 'off';
        end
    catch
    end

    try
        disableDefaultInteractivity(ax);
    catch
    end
end

%% 局部函数8：导出图像
function localExportFigure(fig,fileName)
    try
        exportgraphics(fig,fileName,'Resolution',300);
    catch
        print(fig,fileName,'-dpng','-r300');
    end
end
