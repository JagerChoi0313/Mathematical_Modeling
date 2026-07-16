%% 问题四：最大可持续产能—订购—库存—转运分层优化模型
%
% 模型目标优先级：
%   第一层：企业未来24周稳定周产能最大；
%   第二层：原材料总运输体积最小；
%   第三层：相对采购成本最小；
%   第四层：累计库存占用最小；
%   第五层：运输损耗最小。
%
% 模型特点：
% 1. 使用附件1中全部402家供应商，自动剔除未来24周供货能力为0的供应商；
% 2. 根据近5年相同周期历史数据估计未来24周订货响应系数；
% 3. 根据历史正订货量90%分位数设置合理订货量上限；
% 4. 根据正供货量90%分位数和时间加权供货能力设置规划供货上限；
% 5. 将稳定周产能P、供应商预计供货量、转运量和库存量联合优化；
% 6. 采用稳定运行假设：初始库存和第24周末库存均等于2P；
% 7. 将问题4订购方案和转运方案分别写入附件A、附件B。
%
% -------------------------------------------------------------------------
% 必需输入文件及格式：
%
% （1）附件1：近5年402家供应商的相关数据.xlsx
%     工作表1：企业的订货量（m³）
%     工作表2：供应商的供货量（m³）
%     第1列：供应商编号，如S001；
%     第2列：材料类别A、B或C；
%     第3列起：第1周至第240周数据。
%
% （2）附件2：近5年8家转运商的相关数据.xlsx
%     工作表：运输损耗率（%）
%     第1列：转运商编号T1至T8；
%     第2列起：第1周至第240周损耗率。
%     表中0表示该周没有运输任务，不作为真实零损耗参与均值。
%
% （3）附件A：订购方案数据结果.xlsx
%     必须包含"问题4的订购方案结果"工作表；
%     供应商编号位于A7:A408，24周结果写入B7:Y408。
%
% （4）附件B：转运方案数据结果.xlsx
%     必须包含"问题4的转运方案结果"工作表；
%     供应商编号位于A7:A408；
%     24周×8家转运商结果写入B7:GK408；
%     合计公式写入GL7:GL408。
%
% -------------------------------------------------------------------------
% 运行环境：
% MATLAB R2019b及以上版本，需安装Optimization Toolbox。
%
% 主要输出：
% 1. 问题四_最大产能订购库存转运优化结果.xlsx
% 2. 附件A_问题4订购方案.xlsx
% 3. 附件B_问题4转运方案.xlsx
% 4. 问题四_产能提升对比.png
% 5. 问题四_24周原材料供货结构.png
% 6. 问题四_24周库存变化.png
% 7. 问题四_24周转运量.png
% 8. 问题四_供应与运输能力利用率.png

clear;
clc;
close all;

%% 1. 基本参数设置
historyWeeks = 240;          % 历史数据总周数
yearCount = 5;               % 历史年度数
weeksPerYear = 48;           % 每个年度48周
futureWeeks = 24;            % 未来规划周期
transporterCount = 8;        % 转运商数量

originalWeeklyCapacity = 28200; % 技术改造前周产能
transporterCapacity = 6000;     % 每家转运商每周最大运输量

orderUpperPercentile = 90;      % 合理订货量上限分位数
supplyUpperPercentile = 90;     % 稳健供货上限分位数
responseUpperPercentile = 90;   % 响应系数上限分位数
trimFraction = 0.10;            % 总体响应系数双侧截尾比例
shrinkageKappa = 2;             % 同周期小样本收缩参数

% 越接近当前的年度权重越高
yearWeights = (1:yearCount)';
yearWeights = yearWeights/sum(yearWeights);

% 求解与判零容差
zeroTolerance = 1e-7;
absoluteObjectiveTolerance = 1e-5;
relativeObjectiveTolerance = 1e-8;
constraintTolerance = 1e-4;

%% 2. 输入文件名与输出文件名
supplierHistoryDefaultNames = { ...
    '附件1 近5年402家供应商的相关数据.xlsx', ...
    '附件1 近5年402家供应商的相关数据(2).xlsx'};

transporterHistoryDefaultNames = { ...
    '附件2 近5年8家转运商的相关数据.xlsx', ...
    '附件2 近5年8家转运商的相关数据(2).xlsx'};

attachmentADefaultNames = { ...
    '附件A 订购方案数据结果.xlsx', ...
    '附件A 订购方案数据结果(2).xlsx'};

attachmentBDefaultNames = { ...
    '附件B 转运方案数据结果.xlsx', ...
    '附件B 转运方案数据结果(2).xlsx'};

resultFile = '问题四_最大产能订购库存转运优化结果.xlsx';
attachmentAOutput = '附件A_问题4订购方案.xlsx';
attachmentBOutput = '附件B_问题4转运方案.xlsx';

figureCapacityFile = '问题四_产能提升对比.png';
figureMaterialFile = '问题四_24周原材料供货结构.png';
figureInventoryFile = '问题四_24周库存变化.png';
figureTransportFile = '问题四_24周转运量.png';
figureUtilizationFile = '问题四_供应与运输能力利用率.png';

if isfile(resultFile)
    delete(resultFile);
end

%% 3. 检查Optimization Toolbox
if exist('linprog','file')~=2
    error('未检测到linprog。请安装或启用MATLAB Optimization Toolbox。');
end

solverOptions = optimoptions( ...
    'linprog', ...
    'Display','none');

%% 4. 自动寻找输入文件
supplierHistoryFile = localFindInputFile( ...
    supplierHistoryDefaultNames, ...
    '附件1*402家供应商*.xlsx', ...
    '附件1供应商历史数据');

transporterHistoryFile = localFindInputFile( ...
    transporterHistoryDefaultNames, ...
    '附件2*8家转运商*.xlsx', ...
    '附件2转运商历史数据');

attachmentAFile = localFindInputFile( ...
    attachmentADefaultNames, ...
    '附件A*订购方案数据结果*.xlsx', ...
    '附件A订购方案模板');

attachmentBFile = localFindInputFile( ...
    attachmentBDefaultNames, ...
    '附件B*转运方案数据结果*.xlsx', ...
    '附件B转运方案模板');

fprintf('\n================ 输入文件 ================\n');
fprintf('供应商历史数据：%s\n',supplierHistoryFile);
fprintf('转运商历史数据：%s\n',transporterHistoryFile);
fprintf('附件A模板：%s\n',attachmentAFile);
fprintf('附件B模板：%s\n',attachmentBFile);

%% 5. 读取并核验附件1
orderSheet = '企业的订货量（m³）';
supplySheet = '供应商的供货量（m³）';

orderCell = readcell(supplierHistoryFile,'Sheet',orderSheet);
supplyCell = readcell(supplierHistoryFile,'Sheet',supplySheet);

if size(orderCell,2)<historyWeeks+2 || ...
        size(supplyCell,2)<historyWeeks+2
    error('附件1的周数据列数不足，需包含240周数据。');
end

% 删除供应商编号为空的尾部空白行
orderIDRaw = strtrim(string(orderCell(2:end,1)));
supplyIDRaw = strtrim(string(supplyCell(2:end,1)));

validOrderRow = strlength(orderIDRaw)>0 & ~ismissing(orderIDRaw);
validSupplyRow = strlength(supplyIDRaw)>0 & ~ismissing(supplyIDRaw);

orderCell = [orderCell(1,:);orderCell(find(validOrderRow)+1,:)];
supplyCell = [supplyCell(1,:);supplyCell(find(validSupplyRow)+1,:)];

allSupplierID = strtrim(string(orderCell(2:end,1)));
allMaterialType = upper(strtrim(string(orderCell(2:end,2))));

supplySupplierID = strtrim(string(supplyCell(2:end,1)));
supplyMaterialType = upper(strtrim(string(supplyCell(2:end,2))));

if numel(unique(allSupplierID))~=numel(allSupplierID)
    error('订货量工作表中存在重复供应商编号。');
end

if numel(unique(supplySupplierID))~=numel(supplySupplierID)
    error('供货量工作表中存在重复供应商编号。');
end

% 按订货表的供应商顺序排列供货表
[foundSupplier,supplyLocation] = ismember(allSupplierID,supplySupplierID);

if any(~foundSupplier)
    error('供货量工作表中缺少部分供应商。');
end

supplyCell = [supplyCell(1,:);supplyCell(supplyLocation+1,:)];
supplyMaterialType = supplyMaterialType(supplyLocation);

if any(allMaterialType~=supplyMaterialType)
    error('订货量工作表与供货量工作表中的材料类别不一致。');
end

historicalOrder = localCellBlockToDouble( ...
    orderCell(2:end,3:historyWeeks+2), ...
    0,'历史订货量');

historicalSupply = localCellBlockToDouble( ...
    supplyCell(2:end,3:historyWeeks+2), ...
    0,'历史供货量');

[allSupplierCount,readHistoryWeeks] = size(historicalOrder);

if readHistoryWeeks~=historyWeeks
    error('当前读取到%d周数据，理论上应为240周。',readHistoryWeeks);
end

if ~isequal(size(historicalOrder),size(historicalSupply))
    error('历史订货量矩阵与供货量矩阵维度不一致。');
end

if any(historicalOrder(:)<0) || any(historicalSupply(:)<0)
    error('历史数据中存在负数订货量或供货量。');
end

validType = allMaterialType=="A" | ...
    allMaterialType=="B" | ...
    allMaterialType=="C";

if any(~validType)
    error('供应商材料类别存在A、B、C以外的内容。');
end

if allSupplierCount~=402
    warning('当前读取到%d家供应商，题目理论数量为402家。', ...
        allSupplierCount);
end

% 检查无订货却供货的记录，仅作为数据诊断，不直接删除
unexpectedSupplyCount = sum( ...
    historicalOrder(:)<=0 & historicalSupply(:)>0);

fprintf('\n================ 原始数据核验 ================\n');
fprintf('读取供应商数量：%d家\n',allSupplierCount);
fprintf('读取历史周数：%d周\n',readHistoryWeeks);
fprintf('无订货但出现供货的记录：%d条\n',unexpectedSupplyCount);

%% 6. 计算全部供应商的原材料参数
allConsumption = zeros(allSupplierCount,1);
allPrice = zeros(allSupplierCount,1);

allConsumption(allMaterialType=="A") = 0.60;
allConsumption(allMaterialType=="B") = 0.66;
allConsumption(allMaterialType=="C") = 0.72;

allPrice(allMaterialType=="A") = 1.20;
allPrice(allMaterialType=="B") = 1.10;
allPrice(allMaterialType=="C") = 1.00;

%% 7. 估计供应商未来24周供货参数
%
% 对每家供应商计算：
% 1. 合理订货量上限Xmax：历史正订货量90%分位数；
% 2. 稳健供货上限：历史正供货量90%分位数；
% 3. 时间加权供货能力：5个年度订货周平均供货量的加权值；
% 4. 规划供货上限：稳健上限与时间加权能力的较大值；
% 5. 总体响应系数：有订货周供货率的10%双侧截尾均值；
% 6. 未来24周响应系数：同周期时间加权后向总体响应系数收缩；
% 7. 最大可实现预计供货量：
%       qbar(i,t)=min(rho(i,t)*Xmax(i),Uplan(i))。

orderUpperAll = zeros(allSupplierCount,1);
stableSupplyUpperAll = zeros(allSupplierCount,1);
timeWeightedAbilityAll = zeros(allSupplierCount,1);
planningSupplyUpperAll = zeros(allSupplierCount,1);
overallResponseAll = zeros(allSupplierCount,1);
responseUpperAll = zeros(allSupplierCount,1);

futureResponseAll = zeros(allSupplierCount,futureWeeks);
samePeriodSampleCountAll = zeros(allSupplierCount,futureWeeks);
maximumSupplyAll = zeros(allSupplierCount,futureWeeks);

for i = 1:allSupplierCount
    currentOrder = historicalOrder(i,:);
    currentSupply = historicalSupply(i,:);

    positiveOrder = currentOrder(currentOrder>0);
    positiveSupply = currentSupply(currentSupply>0);

    % 合理订货量上限
    if isempty(positiveOrder)
        orderUpperAll(i) = 0;
    else
        orderUpperAll(i) = localPercentile( ...
            positiveOrder,orderUpperPercentile);
    end

    % 稳健供货上限
    if isempty(positiveSupply)
        stableSupplyUpperAll(i) = 0;
    else
        stableSupplyUpperAll(i) = localPercentile( ...
            positiveSupply,supplyUpperPercentile);
    end

    % 有订货周的历史供货响应率，未供货时自然计为0
    orderedMask = currentOrder>0;

    if any(orderedMask)
        historicalResponse = ...
            currentSupply(orderedMask)./currentOrder(orderedMask);

        historicalResponse = historicalResponse( ...
            isfinite(historicalResponse) & historicalResponse>=0);

        if isempty(historicalResponse)
            overallResponseAll(i) = 0;
            responseUpperAll(i) = 0;
        else
            overallResponseAll(i) = localTrimmedMean( ...
                historicalResponse,trimFraction);

            responseUpperAll(i) = max( ...
                overallResponseAll(i), ...
                localPercentile( ...
                historicalResponse,responseUpperPercentile));
        end
    else
        historicalResponse = [];
        overallResponseAll(i) = 0;
        responseUpperAll(i) = 0;
    end

    % 计算5个年度中有订货周的平均实际供货量
    annualAbility = nan(yearCount,1);

    for y = 1:yearCount
        weekIndex = ...
            (y-1)*weeksPerYear+(1:weeksPerYear);

        annualOrder = currentOrder(weekIndex);
        annualSupply = currentSupply(weekIndex);
        annualOrderedMask = annualOrder>0;

        if any(annualOrderedMask)
            annualAbility(y) = mean( ...
                annualSupply(annualOrderedMask));
        end
    end

    validAnnualAbility = isfinite(annualAbility);

    if any(validAnnualAbility)
        currentWeights = yearWeights(validAnnualAbility);

        timeWeightedAbilityAll(i) = ...
            sum(currentWeights.*annualAbility(validAnnualAbility)) / ...
            sum(currentWeights);
    elseif any(orderedMask)
        timeWeightedAbilityAll(i) = ...
            mean(currentSupply(orderedMask));
    else
        timeWeightedAbilityAll(i) = 0;
    end

    planningSupplyUpperAll(i) = max( ...
        stableSupplyUpperAll(i), ...
        timeWeightedAbilityAll(i));

    % 估计未来24周响应系数
    for t = 1:futureWeeks
        historicalIndex = ...
            t+weeksPerYear*(0:yearCount-1);

        samePeriodOrder = currentOrder(historicalIndex);
        samePeriodSupply = currentSupply(historicalIndex);
        validSamePeriod = samePeriodOrder>0;

        sampleCount = sum(validSamePeriod);
        samePeriodSampleCountAll(i,t) = sampleCount;

        if sampleCount>0
            responseSample = ...
                samePeriodSupply(validSamePeriod)./ ...
                samePeriodOrder(validSamePeriod);

            currentWeights = yearWeights(validSamePeriod);

            seasonalResponse = ...
                sum(currentWeights.*responseSample')/ ...
                sum(currentWeights);
        else
            seasonalResponse = overallResponseAll(i);
        end

        shrinkageWeight = ...
            sampleCount/(sampleCount+shrinkageKappa);

        responseEstimate = ...
            shrinkageWeight*seasonalResponse + ...
            (1-shrinkageWeight)*overallResponseAll(i);

        responseEstimate = max(responseEstimate,0);

        if responseUpperAll(i)>0
            responseEstimate = min( ...
                responseEstimate,responseUpperAll(i));
        end

        futureResponseAll(i,t) = responseEstimate;
    end

    maximumSupplyAll(i,:) = min( ...
        futureResponseAll(i,:)*orderUpperAll(i), ...
        planningSupplyUpperAll(i));
end

% 将极小数清零
futureResponseAll(abs(futureResponseAll)<zeroTolerance) = 0;
maximumSupplyAll(abs(maximumSupplyAll)<zeroTolerance) = 0;

%% 8. 确定第四问有效供应商集合
%
% 第四问使用全部402家供应商中的有效供应商。
% 只剔除未来24周最大可实现预计供货量总和为0的供应商。

effectiveMask = ...
    sum(maximumSupplyAll,2)>zeroTolerance & ...
    orderUpperAll>zeroTolerance & ...
    planningSupplyUpperAll>zeroTolerance;

supplierID = allSupplierID(effectiveMask);
materialType = allMaterialType(effectiveMask);
consumption = allConsumption(effectiveMask);
price = allPrice(effectiveMask);

orderUpper = orderUpperAll(effectiveMask);
stableSupplyUpper = stableSupplyUpperAll(effectiveMask);
timeWeightedAbility = timeWeightedAbilityAll(effectiveMask);
planningSupplyUpper = planningSupplyUpperAll(effectiveMask);
overallResponse = overallResponseAll(effectiveMask);
responseUpper = responseUpperAll(effectiveMask);

futureResponse = futureResponseAll(effectiveMask,:);
samePeriodSampleCount = samePeriodSampleCountAll(effectiveMask,:);
maximumSupply = maximumSupplyAll(effectiveMask,:);

effectiveSupplierCount = numel(supplierID);

if effectiveSupplierCount==0
    error('没有供应商具备有效的未来供货能力。');
end

fprintf('\n================ 有效供应商集合 ================\n');
fprintf('有效供应商数量：%d家\n',effectiveSupplierCount);
fprintf('A/B/C类供应商数量：%d/%d/%d\n', ...
    sum(materialType=="A"), ...
    sum(materialType=="B"), ...
    sum(materialType=="C"));

%% 9. 读取附件2并估计未来24周运输损耗率
lossSheet = '运输损耗率（%）';
lossCell = readcell(transporterHistoryFile,'Sheet',lossSheet);

if size(lossCell,1)<transporterCount+1 || ...
        size(lossCell,2)<historyWeeks+1
    error('附件2结构不完整，需包含8家转运商和240周损耗率。');
end

transporterID = strtrim(string( ...
    lossCell(2:transporterCount+1,1)));

historicalLossPercent = localCellBlockToDouble( ...
    lossCell(2:transporterCount+1,2:historyWeeks+1), ...
    0,'历史运输损耗率');

futureLossRate = zeros(transporterCount,futureWeeks);

for k = 1:transporterCount
    positiveLoss = historicalLossPercent( ...
        k,historicalLossPercent(k,:)>0);

    if isempty(positiveLoss)
        fallbackLossPercent = 0;
    else
        fallbackLossPercent = mean(positiveLoss);
    end

    for t = 1:futureWeeks
        historicalIndex = ...
            t+weeksPerYear*(0:yearCount-1);

        lossSample = ...
            historicalLossPercent(k,historicalIndex);

        validLoss = lossSample>0;

        if any(validLoss)
            currentWeights = yearWeights(validLoss);

            estimatedLossPercent = ...
                sum(currentWeights.*lossSample(validLoss)') / ...
                sum(currentWeights);
        else
            estimatedLossPercent = fallbackLossPercent;
        end

        futureLossRate(k,t) = estimatedLossPercent/100;
    end
end

fprintf('\n未来24周各转运商平均预计损耗率：\n');
for k = 1:transporterCount
    fprintf('%s：%.4f%%\n', ...
        transporterID(k), ...
        100*mean(futureLossRate(k,:)));
end

%% 10. 理论能力上界预检
%
% 供应端乐观产能上界：
% 忽略运输损耗，将各供应商最大供货量直接换算为产品产能。
%
% 运输端乐观产能上界：
% 假设8家转运商全部满载且运输的都是A类原材料。
% 该值只用于设置P的安全上界，不作为最终答案。

weeklySupplierProductUpper = sum( ...
    bsxfun(@rdivide,maximumSupply,consumption),1)';

weeklySupplierRawVolumeUpper = sum(maximumSupply,1)';

weeklyTransportProductUpper = zeros(futureWeeks,1);

for t = 1:futureWeeks
    weeklyTransportProductUpper(t) = ...
        sum((1-futureLossRate(:,t))*transporterCapacity)/0.60;
end

averageSupplierProductUpper = ...
    mean(weeklySupplierProductUpper);

averageTransportProductUpper = ...
    mean(weeklyTransportProductUpper);

theoreticalCapacityUpper = min( ...
    averageSupplierProductUpper, ...
    averageTransportProductUpper);

if theoreticalCapacityUpper<=0
    error('理论产能上界非正，无法建立优化模型。');
end

fprintf('\n================ 理论能力上界预检 ================\n');
fprintf('供应端24周平均乐观产能上界：%.2f m³产品/周\n', ...
    averageSupplierProductUpper);
fprintf('运输端24周平均乐观产能上界：%.2f m³产品/周\n', ...
    averageTransportProductUpper);
fprintf('模型采用的周产能变量上界：%.2f m³产品/周\n', ...
    theoreticalCapacityUpper);

%% 11. 构造联合线性规划变量
%
% 决策变量：
% q(i,t)   ：供应商i在第t周预计供货量；
% y(i,k,t) ：供应商i在第t周由转运商k运输的数量；
% H(t)     ：第t周生产结束后的库存产能当量；
% P        ：未来24周稳定周产能。

n = effectiveSupplierCount;
K = transporterCount;
T = futureWeeks;

qIndex = reshape(1:n*T,n,T);

yIndex = reshape( ...
    n*T+(1:n*K*T), ...
    n,K,T);

hIndex = ...
    n*T+n*K*T+(1:T);

pIndex = ...
    n*T+n*K*T+T+1;

variableCount = pIndex;

%% 12. 构造等式约束
%
% 等式约束包括：
% 1. 供应商预计供货量必须全部完成转运；
% 2. 未来24周库存动态递推；
% 3. 第24周末库存恢复到2P。

equalityCount = n*T+T+1;

Aeq = spalloc( ...
    equalityCount, ...
    variableCount, ...
    n*T*(K+1)+T*(n*K+3)+2);

beq = zeros(equalityCount,1);

row = 0;

% 12.1 供货量与转运量平衡
for t = 1:T
    for i = 1:n
        row = row+1;

        Aeq(row,qIndex(i,t)) = 1;

        for k = 1:K
            Aeq(row,yIndex(i,k,t)) = -1;
        end
    end
end

% 12.2 库存递推
for t = 1:T
    row = row+1;

    Aeq(row,hIndex(t)) = 1;

    if t==1
        % H1 = 2P + R1 - P = R1 + P
        % 整理为：H1 - R1 - P = 0
        Aeq(row,pIndex) = -1;
    else
        % Ht = H(t-1) + Rt - P
        % 整理为：Ht - H(t-1) - Rt + P = 0
        Aeq(row,hIndex(t-1)) = -1;
        Aeq(row,pIndex) = 1;
    end

    for i = 1:n
        for k = 1:K
            receivedProductCoefficient = ...
                (1-futureLossRate(k,t))/consumption(i);

            Aeq(row,yIndex(i,k,t)) = ...
                -receivedProductCoefficient;
        end
    end
end

% 12.3 终端库存H24=2P
row = row+1;
Aeq(row,hIndex(T)) = 1;
Aeq(row,pIndex) = -2;
beq(row) = 0;

%% 13. 构造不等式约束
%
% 不等式约束包括：
% 1. 每家转运商每周运输量不超过6000；
% 2. 每周库存不低于2P，即2P-Ht<=0。

capacityConstraintCount = K*T;
safetyConstraintCount = T;
inequalityCount = capacityConstraintCount+safetyConstraintCount;

AubBase = spalloc( ...
    inequalityCount, ...
    variableCount, ...
    n*K*T+2*T);

bubBase = zeros(inequalityCount,1);

row = 0;

% 13.1 转运商容量约束
for t = 1:T
    for k = 1:K
        row = row+1;

        for i = 1:n
            AubBase(row,yIndex(i,k,t)) = 1;
        end

        bubBase(row) = transporterCapacity;
    end
end

% 13.2 安全库存约束
for t = 1:T
    row = row+1;

    % 2P-Ht<=0
    AubBase(row,pIndex) = 2;
    AubBase(row,hIndex(t)) = -1;
    bubBase(row) = 0;
end

%% 14. 设置变量上下界
lowerBound = zeros(variableCount,1);
upperBound = inf(variableCount,1);

% 供应商预计供货量和各转运分配量均不超过最大供货能力
for t = 1:T
    for i = 1:n
        upperBound(qIndex(i,t)) = maximumSupply(i,t);

        for k = 1:K
            upperBound(yIndex(i,k,t)) = maximumSupply(i,t);
        end
    end
end

% 稳定周产能的乐观上界
upperBound(pIndex) = theoreticalCapacityUpper*(1+1e-8);

%% 15. 构造五层目标函数
objectiveNegativeCapacity = zeros(variableCount,1);
objectiveVolume = zeros(variableCount,1);
objectiveCost = zeros(variableCount,1);
objectiveInventory = zeros(variableCount,1);
objectiveLoss = zeros(variableCount,1);

% linprog执行最小化，因此最大化P转化为最小化-P
objectiveNegativeCapacity(pIndex) = -1;

for t = 1:T
    for i = 1:n
        objectiveVolume(qIndex(i,t)) = 1;
        objectiveCost(qIndex(i,t)) = price(i);

        for k = 1:K
            objectiveLoss(yIndex(i,k,t)) = ...
                futureLossRate(k,t);
        end
    end
end

objectiveInventory(hIndex) = 1;

%% 16. 第一层：最大化未来24周稳定周产能
fprintf('\n================ 第一层：稳定周产能最大 ================\n');

[solution1,value1,exitflag1,output1] = linprog( ...
    objectiveNegativeCapacity, ...
    AubBase,bubBase, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    solverOptions);

localCheckSolution( ...
    solution1,exitflag1, ...
    '第一层最大稳定周产能模型');

bestWeeklyCapacity = solution1(pIndex);

tolerance1 = localObjectiveTolerance( ...
    value1, ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance);

fprintf('最大稳定周产能：%.6f m³产品/周\n', ...
    bestWeeklyCapacity);

if isfield(output1,'iterations')
    fprintf('求解器迭代次数：%d\n',output1.iterations);
end

%% 17. 第二层：在最大产能下最小化原材料运输体积
Aub2 = [
    AubBase;
    sparse(objectiveNegativeCapacity')
    ];

bub2 = [
    bubBase;
    value1+tolerance1
    ];

fprintf('\n================ 第二层：原材料运输体积最小 ================\n');

[solution2,value2,exitflag2] = linprog( ...
    objectiveVolume, ...
    Aub2,bub2, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    solverOptions);

localCheckSolution( ...
    solution2,exitflag2, ...
    '第二层原材料运输体积最小模型');

tolerance2 = localObjectiveTolerance( ...
    value2, ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance);

fprintf('24周最小原材料运输体积：%.6f m³\n',value2);

%% 18. 第三层：在前两层最优下最小化相对采购成本
Aub3 = [
    Aub2;
    sparse(objectiveVolume')
    ];

bub3 = [
    bub2;
    value2+tolerance2
    ];

fprintf('\n================ 第三层：相对采购成本最小 ================\n');

[solution3,value3,exitflag3] = linprog( ...
    objectiveCost, ...
    Aub3,bub3, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    solverOptions);

localCheckSolution( ...
    solution3,exitflag3, ...
    '第三层相对采购成本最小模型');

tolerance3 = localObjectiveTolerance( ...
    value3, ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance);

fprintf('24周最小相对采购成本：%.6f\n',value3);

%% 19. 第四层：在前三层最优下最小化累计库存
Aub4 = [
    Aub3;
    sparse(objectiveCost')
    ];

bub4 = [
    bub3;
    value3+tolerance3
    ];

fprintf('\n================ 第四层：累计库存最小 ================\n');

[solution4,value4,exitflag4] = linprog( ...
    objectiveInventory, ...
    Aub4,bub4, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    solverOptions);

localCheckSolution( ...
    solution4,exitflag4, ...
    '第四层累计库存最小模型');

tolerance4 = localObjectiveTolerance( ...
    value4, ...
    absoluteObjectiveTolerance, ...
    relativeObjectiveTolerance);

fprintf('24周最小累计库存产能当量：%.6f\n',value4);

%% 20. 第五层：在前四层最优下最小化运输损耗
Aub5 = [
    Aub4;
    sparse(objectiveInventory')
    ];

bub5 = [
    bub4;
    value4+tolerance4
    ];

fprintf('\n================ 第五层：运输损耗最小 ================\n');

[solution5,value5,exitflag5] = linprog( ...
    objectiveLoss, ...
    Aub5,bub5, ...
    Aeq,beq, ...
    lowerBound,upperBound, ...
    solverOptions);

localCheckSolution( ...
    solution5,exitflag5, ...
    '第五层运输损耗最小模型');

fprintf('24周最小运输损耗：%.6f m³\n',value5);

%% 21. 提取最终方案
finalWeeklyCapacity = solution5(pIndex);

supplyPlan = zeros(n,T);
transportPlan = zeros(n,K,T);
inventoryPlan = zeros(T,1);

for t = 1:T
    for i = 1:n
        supplyPlan(i,t) = solution5(qIndex(i,t));

        for k = 1:K
            transportPlan(i,k,t) = ...
                solution5(yIndex(i,k,t));
        end
    end

    inventoryPlan(t) = solution5(hIndex(t));
end

supplyPlan(abs(supplyPlan)<zeroTolerance) = 0;
transportPlan(abs(transportPlan)<zeroTolerance) = 0;
inventoryPlan(abs(inventoryPlan)<zeroTolerance) = 0;

safetyInventory = 2*finalWeeklyCapacity;

%% 22. 根据预计供货量反推订货量
orderPlan = zeros(n,T);

for t = 1:T
    for i = 1:n
        if supplyPlan(i,t)>zeroTolerance
            if futureResponse(i,t)<=zeroTolerance
                error('供应商%s第%d周响应系数为0，但模型安排了正供货量。', ...
                    supplierID(i),t);
            end

            orderPlan(i,t) = ...
                supplyPlan(i,t)/futureResponse(i,t);
        end
    end
end

orderUpperMatrix = repmat(orderUpper,1,T);
orderViolation = orderPlan-orderUpperMatrix;

if any(orderViolation(:)>constraintTolerance)
    error('反推订货量超过合理订货量上限。');
end

%% 23. 核验约束并计算实施指标
materialLabels = ["A","B","C"];
weekNumber = (1:T)';

weeklyOrderByType = zeros(T,3);
weeklySupplyByType = zeros(T,3);
weeklyReceivedByType = zeros(T,3);
weeklyReceivedRaw = zeros(T,1);
weeklyReceivedProduct = zeros(T,1);
weeklyLossAmount = zeros(T,1);
weeklyPurchaseCost = zeros(T,1);
weeklyTransporterLoad = zeros(K,T);

for t = 1:T
    for k = 1:K
        weeklyTransporterLoad(k,t) = ...
            sum(transportPlan(:,k,t));
    end

    for i = 1:n
        typeIndex = find( ...
            materialLabels==materialType(i),1);

        weeklyOrderByType(t,typeIndex) = ...
            weeklyOrderByType(t,typeIndex)+orderPlan(i,t);

        weeklySupplyByType(t,typeIndex) = ...
            weeklySupplyByType(t,typeIndex)+supplyPlan(i,t);

        weeklyPurchaseCost(t) = ...
            weeklyPurchaseCost(t)+price(i)*supplyPlan(i,t);

        for k = 1:K
            transportedQuantity = transportPlan(i,k,t);

            lossQuantity = ...
                futureLossRate(k,t)*transportedQuantity;

            receivedQuantity = ...
                (1-futureLossRate(k,t))*transportedQuantity;

            weeklyLossAmount(t) = ...
                weeklyLossAmount(t)+lossQuantity;

            weeklyReceivedRaw(t) = ...
                weeklyReceivedRaw(t)+receivedQuantity;

            weeklyReceivedProduct(t) = ...
                weeklyReceivedProduct(t)+ ...
                receivedQuantity/consumption(i);

            weeklyReceivedByType(t,typeIndex) = ...
                weeklyReceivedByType(t,typeIndex)+ ...
                receivedQuantity;
        end
    end
end

% 23.1 核验转运商容量
if any(weeklyTransporterLoad(:)> ...
        transporterCapacity+constraintTolerance)
    error('最终方案存在转运商周运输量超过6000 m³。');
end

% 23.2 核验供货量与转运量平衡
for t = 1:T
    supplierTransferred = ...
        reshape(sum(transportPlan(:,:,t),2),n,1);

    if max(abs( ...
            supplierTransferred-supplyPlan(:,t)))> ...
            constraintTolerance
        error('第%d周供应商供货量与转运量不一致。',t);
    end
end

% 23.3 核验库存递推
inventoryRecalculated = zeros(T,1);
previousInventory = safetyInventory;

for t = 1:T
    inventoryRecalculated(t) = ...
        previousInventory+ ...
        weeklyReceivedProduct(t)- ...
        finalWeeklyCapacity;

    previousInventory = inventoryRecalculated(t);
end

if max(abs( ...
        inventoryRecalculated-inventoryPlan))> ...
        constraintTolerance
    error('库存递推重新计算结果与优化变量不一致。');
end

if any(inventoryPlan< ...
        safetyInventory-constraintTolerance)
    error('最终方案存在库存低于两周安全库存的周次。');
end

if abs(inventoryPlan(T)-safetyInventory)> ...
        constraintTolerance
    error('第24周末库存未恢复到两周安全库存。');
end

% 23.4 汇总指标
totalOrderByType = sum(weeklyOrderByType,1);
totalSupplyByType = sum(weeklySupplyByType,1);
totalReceivedByType = sum(weeklyReceivedByType,1);

totalOrder = sum(totalOrderByType);
totalSupply = sum(totalSupplyByType);
totalReceivedRaw = sum(weeklyReceivedRaw);
totalReceivedProduct = sum(weeklyReceivedProduct);
totalLoss = sum(weeklyLossAmount);
totalPurchaseCost = sum(weeklyPurchaseCost);

if totalSupply>0
    averageLossRate = totalLoss/totalSupply;
    supplyShareByType = totalSupplyByType/totalSupply;
else
    averageLossRate = 0;
    supplyShareByType = zeros(1,3);
end

capacityIncrease = ...
    finalWeeklyCapacity-originalWeeklyCapacity;

capacityIncreaseRate = ...
    capacityIncrease/originalWeeklyCapacity;

cumulativeInventory = sum(inventoryPlan);
cumulativeExcessInventory = ...
    sum(inventoryPlan-safetyInventory);

activeSupplierCount = ...
    sum(sum(supplyPlan,2)>zeroTolerance);

positiveSupplierWeekCount = ...
    sum(supplyPlan(:)>zeroTolerance);

splitSupplierWeekCount = 0;

for t = 1:T
    for i = 1:n
        if sum(transportPlan(i,:,t)>zeroTolerance)>1
            splitSupplierWeekCount = ...
                splitSupplierWeekCount+1;
        end
    end
end

if positiveSupplierWeekCount>0
    splitRate = ...
        splitSupplierWeekCount/positiveSupplierWeekCount;
else
    splitRate = 0;
end

% 23.5 供应端与运输端利用率
weeklySupplierProductUse = sum( ...
    bsxfun(@rdivide,supplyPlan,consumption),1)';

weeklySupplierCapacityUtilization = ...
    weeklySupplierProductUse ./ ...
    weeklySupplierProductUpper;

weeklyTransportTotal = ...
    sum(weeklyTransporterLoad,1)';

weeklyTransportCapacityUtilization = ...
    weeklyTransportTotal/(K*transporterCapacity);

weeklySupplierCapacityUtilization( ...
    ~isfinite(weeklySupplierCapacityUtilization)) = 0;

% 转运商个体利用率
transporterUtilization = ...
    weeklyTransporterLoad/transporterCapacity;

% 23.6 瓶颈诊断
maxSupplierUtilization = ...
    max(weeklySupplierCapacityUtilization);

maxTransportUtilization = ...
    max(weeklyTransportCapacityUtilization);

fullTransporterWeekCount = ...
    sum(transporterUtilization(:)>=0.999);

nearUpperSupplierWeekCount = ...
    sum(abs(supplyPlan(:)-maximumSupply(:))<=1e-4 & ...
    maximumSupply(:)>zeroTolerance);

if maxTransportUtilization>=0.99 && ...
        maxSupplierUtilization<0.99
    bottleneckConclusion = "转运能力是主要瓶颈";
elseif maxSupplierUtilization>=0.99 && ...
        maxTransportUtilization<0.99
    bottleneckConclusion = "供应商供货能力是主要瓶颈";
elseif maxSupplierUtilization>=0.99 && ...
        maxTransportUtilization>=0.99
    bottleneckConclusion = "供应能力与转运能力共同构成瓶颈";
else
    bottleneckConclusion = ...
        "产能上限由跨周供货、库存与运输约束共同决定";
end

%% 24. 在命令行输出关键结果
fprintf('\n============================================================\n');
fprintf(' 问题四：最大可持续产能优化结果\n');
fprintf('============================================================\n');

fprintf('第一层理论最优周产能：%.6f m³产品/周\n', ...
    bestWeeklyCapacity);

fprintf('最终方案稳定周产能：%.6f m³产品/周\n', ...
    finalWeeklyCapacity);

fprintf('原周产能：%.6f m³产品/周\n', ...
    originalWeeklyCapacity);

fprintf('周产能提高量：%.6f m³产品/周\n', ...
    capacityIncrease);

fprintf('周产能提高比例：%.6f%%\n', ...
    100*capacityIncreaseRate);

fprintf('新产能下两周安全库存：%.6f m³产品\n', ...
    safetyInventory);

fprintf('\n有效供应商：%d家，实际启用：%d家\n', ...
    effectiveSupplierCount,activeSupplierCount);

fprintf('24周订货总量：%.6f m³\n',totalOrder);
fprintf('24周预计供货总量：%.6f m³\n',totalSupply);
fprintf('24周预计接收总量：%.6f m³\n',totalReceivedRaw);
fprintf('24周接收产能当量：%.6f m³产品\n', ...
    totalReceivedProduct);

fprintf('24周相对采购成本：%.6f\n', ...
    totalPurchaseCost);

fprintf('24周运输损耗：%.6f m³\n',totalLoss);
fprintf('平均运输损耗率：%.6f%%\n', ...
    100*averageLossRate);

fprintf('最低库存产能当量：%.6f\n', ...
    min(inventoryPlan));

fprintf('期末库存产能当量：%.6f\n', ...
    inventoryPlan(T));

fprintf('累计超额库存产能当量：%.6f\n', ...
    cumulativeExcessInventory);

fprintf('拆分运输供应商—周组合：%d个，占%.4f%%\n', ...
    splitSupplierWeekCount,100*splitRate);

fprintf('\nA/B/C类预计供货结构：\n');
fprintf('A类：%.6f m³，占%.4f%%\n', ...
    totalSupplyByType(1),100*supplyShareByType(1));
fprintf('B类：%.6f m³，占%.4f%%\n', ...
    totalSupplyByType(2),100*supplyShareByType(2));
fprintf('C类：%.6f m³，占%.4f%%\n', ...
    totalSupplyByType(3),100*supplyShareByType(3));

fprintf('\n供应端最大利用率：%.4f%%\n', ...
    100*maxSupplierUtilization);

fprintf('运输端总能力最大利用率：%.4f%%\n', ...
    100*maxTransportUtilization);

fprintf('达到满载的"转运商—周"组合：%d个\n', ...
    fullTransporterWeekCount);

fprintf('达到供货上限的"供应商—周"组合：%d个\n', ...
    nearUpperSupplierWeekCount);

fprintf('瓶颈诊断：%s\n',bottleneckConclusion);

%% 25. 构造结果表
% 25.1 总体指标
metricName = [ ...
    "第一层理论最优周产能"; ...
    "最终稳定周产能"; ...
    "原周产能"; ...
    "周产能提高量"; ...
    "周产能提高比例"; ...
    "新产能两周安全库存"; ...
    "全部供应商数量"; ...
    "有效供应商数量"; ...
    "实际启用供应商数量"; ...
    "A类订货总量"; ...
    "B类订货总量"; ...
    "C类订货总量"; ...
    "A类预计供货总量"; ...
    "B类预计供货总量"; ...
    "C类预计供货总量"; ...
    "A类预计供货占比"; ...
    "B类预计供货占比"; ...
    "C类预计供货占比"; ...
    "24周订货总量"; ...
    "24周预计供货总量"; ...
    "24周预计接收总量"; ...
    "24周接收产能当量"; ...
    "相对采购成本"; ...
    "总运输损耗量"; ...
    "平均运输损耗率"; ...
    "累计库存产能当量"; ...
    "累计超额库存产能当量"; ...
    "最低库存产能当量"; ...
    "期末库存产能当量"; ...
    "拆分运输供应商周数"; ...
    "拆分运输比例"; ...
    "供应端最大利用率"; ...
    "运输端总能力最大利用率"; ...
    "满载转运商周数"; ...
    "达到供货上限供应商周数"];

metricValue = [ ...
    bestWeeklyCapacity; ...
    finalWeeklyCapacity; ...
    originalWeeklyCapacity; ...
    capacityIncrease; ...
    capacityIncreaseRate; ...
    safetyInventory; ...
    allSupplierCount; ...
    effectiveSupplierCount; ...
    activeSupplierCount; ...
    totalOrderByType(1); ...
    totalOrderByType(2); ...
    totalOrderByType(3); ...
    totalSupplyByType(1); ...
    totalSupplyByType(2); ...
    totalSupplyByType(3); ...
    supplyShareByType(1); ...
    supplyShareByType(2); ...
    supplyShareByType(3); ...
    totalOrder; ...
    totalSupply; ...
    totalReceivedRaw; ...
    totalReceivedProduct; ...
    totalPurchaseCost; ...
    totalLoss; ...
    averageLossRate; ...
    cumulativeInventory; ...
    cumulativeExcessInventory; ...
    min(inventoryPlan); ...
    inventoryPlan(T); ...
    splitSupplierWeekCount; ...
    splitRate; ...
    maxSupplierUtilization; ...
    maxTransportUtilization; ...
    fullTransporterWeekCount; ...
    nearUpperSupplierWeekCount];

overallMetricTable = table( ...
    metricName,metricValue, ...
    'VariableNames',{'指标名称','指标值'});

% 25.2 24周实施效果
weeklySummaryTable = table( ...
    weekNumber, ...
    repmat(finalWeeklyCapacity,T,1), ...
    repmat(safetyInventory,T,1), ...
    weeklyOrderByType(:,1), ...
    weeklyOrderByType(:,2), ...
    weeklyOrderByType(:,3), ...
    sum(weeklyOrderByType,2), ...
    weeklySupplyByType(:,1), ...
    weeklySupplyByType(:,2), ...
    weeklySupplyByType(:,3), ...
    sum(weeklySupplyByType,2), ...
    weeklyReceivedByType(:,1), ...
    weeklyReceivedByType(:,2), ...
    weeklyReceivedByType(:,3), ...
    weeklyReceivedRaw, ...
    weeklyReceivedProduct, ...
    inventoryPlan, ...
    weeklyPurchaseCost, ...
    weeklyLossAmount, ...
    weeklySupplierCapacityUtilization, ...
    weeklyTransportCapacityUtilization, ...
    'VariableNames',{ ...
    '周次','稳定周产能','两周安全库存', ...
    'A类订货量','B类订货量','C类订货量','订货总量', ...
    'A类预计供货量','B类预计供货量','C类预计供货量', ...
    '预计供货总量','A类预计接收量','B类预计接收量', ...
    'C类预计接收量','预计接收总量','接收产能当量', ...
    '周末库存产能当量','相对采购成本','运输损耗量', ...
    '供应端能力利用率','运输端能力利用率'});

% 25.3 未来24周参数表
weekVariableNames = cell(1,T);

for t = 1:T
    weekVariableNames{t} = sprintf('第%02d周',t);
end

responseTable = array2table( ...
    futureResponse, ...
    'VariableNames',weekVariableNames);

responseTable = addvars( ...
    responseTable, ...
    supplierID,materialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

maximumSupplyTable = array2table( ...
    maximumSupply, ...
    'VariableNames',weekVariableNames);

maximumSupplyTable = addvars( ...
    maximumSupplyTable, ...
    supplierID,materialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

% 25.4 订购和供货方案
orderPlanTable = array2table( ...
    orderPlan, ...
    'VariableNames',weekVariableNames);

orderPlanTable = addvars( ...
    orderPlanTable, ...
    supplierID,materialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

supplyPlanTable = array2table( ...
    supplyPlan, ...
    'VariableNames',weekVariableNames);

supplyPlanTable = addvars( ...
    supplyPlanTable, ...
    supplierID,materialType, ...
    'Before',1, ...
    'NewVariableNames',{'供应商编号','材料类别'});

% 25.5 转运商运输量和利用率
transporterLoadTable = table(weekNumber);
transporterUtilizationTable = table(weekNumber);

for k = 1:K
    transporterLoadTable = addvars( ...
        transporterLoadTable, ...
        weeklyTransporterLoad(k,:)', ...
        'NewVariableNames',{char(transporterID(k))});

    transporterUtilizationTable = addvars( ...
        transporterUtilizationTable, ...
        transporterUtilization(k,:)', ...
        'NewVariableNames',{char(transporterID(k))});
end

% 25.6 转运明细长表
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
            quantity = transportPlan(i,k,t);

            if quantity>zeroTolerance
                longRow = longRow+1;

                longSupplier(longRow) = supplierID(i);
                longWeek(longRow) = t;
                longTransporter(longRow) = transporterID(k);
                longQuantity(longRow) = quantity;
                longLossRate(longRow) = ...
                    100*futureLossRate(k,t);
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
    '供应商编号','周次','转运商编号', ...
    '转运量','预计损耗率百分比','预计损耗量'});

% 25.7 供应商参数与使用情况
supplierSummaryTable = table( ...
    supplierID, ...
    materialType, ...
    orderUpper, ...
    stableSupplyUpper, ...
    timeWeightedAbility, ...
    planningSupplyUpper, ...
    overallResponse, ...
    responseUpper, ...
    mean(futureResponse,2), ...
    sum(orderPlan,2), ...
    sum(supplyPlan,2), ...
    sum(supplyPlan>zeroTolerance,2), ...
    'VariableNames',{ ...
    '供应商编号','材料类别','合理订货量上限', ...
    '稳健供货上限','时间加权供货能力','规划供货上限', ...
    '总体响应系数','响应系数上限','24周平均响应系数', ...
    '24周订货总量','24周预计供货总量','实际订货周数'});

% 25.8 能力上界和瓶颈表
capacityDiagnosticTable = table( ...
    weekNumber, ...
    weeklySupplierRawVolumeUpper, ...
    weeklySupplierProductUpper, ...
    weeklyTransportProductUpper, ...
    weeklySupplierProductUse, ...
    weeklySupplierCapacityUtilization, ...
    weeklyTransportTotal, ...
    weeklyTransportCapacityUtilization, ...
    'VariableNames',{ ...
    '周次','供应商最大原料供货体积', ...
    '供应端最大产品产能','运输端乐观产品产能上界', ...
    '方案使用的供应端产品产能', ...
    '供应端能力利用率','实际运输总量', ...
    '运输端能力利用率'});

bottleneckTable = table( ...
    string(bottleneckConclusion), ...
    maxSupplierUtilization, ...
    maxTransportUtilization, ...
    fullTransporterWeekCount, ...
    nearUpperSupplierWeekCount, ...
    'VariableNames',{ ...
    '瓶颈诊断','供应端最大利用率', ...
    '运输端最大利用率','满载转运商周数', ...
    '达到供货上限供应商周数'});

% 25.9 未来损耗率表
lossRateTable = table(weekNumber);

for k = 1:K
    lossRateTable = addvars( ...
        lossRateTable, ...
        100*futureLossRate(k,:)', ...
        'NewVariableNames',{char(transporterID(k))});
end

%% 26. 写入完整结果工作簿
writetable(overallMetricTable, ...
    resultFile,'Sheet','总体指标');

writetable(weeklySummaryTable, ...
    resultFile,'Sheet','24周实施效果');

writetable(orderPlanTable, ...
    resultFile,'Sheet','有效供应商24周订购方案');

writetable(supplyPlanTable, ...
    resultFile,'Sheet','有效供应商24周预计供货');

writetable(responseTable, ...
    resultFile,'Sheet','24周订货响应系数');

writetable(maximumSupplyTable, ...
    resultFile,'Sheet','24周最大预计供货量');

writetable(transportLongTable, ...
    resultFile,'Sheet','24周转运方案明细');

writetable(transporterLoadTable, ...
    resultFile,'Sheet','转运商每周运输量');

writetable(transporterUtilizationTable, ...
    resultFile,'Sheet','转运商每周利用率');

writetable(supplierSummaryTable, ...
    resultFile,'Sheet','供应商参数与使用情况');

writetable(capacityDiagnosticTable, ...
    resultFile,'Sheet','能力上界与利用率');

writetable(bottleneckTable, ...
    resultFile,'Sheet','瓶颈诊断');

writetable(lossRateTable, ...
    resultFile,'Sheet','未来24周损耗率');

%% 27. 填写附件A中的问题4订购方案
copyfile(attachmentAFile,attachmentAOutput,'f');

question4OrderSheet = localFindSheetByKeywords( ...
    attachmentAOutput, ...
    {'问题4','订购'});

attachmentAID = strtrim(string(readcell( ...
    attachmentAOutput, ...
    'Sheet',question4OrderSheet, ...
    'Range','A7:A408')));

attachmentAData = cell(numel(attachmentAID),T);

for rowIndex = 1:numel(attachmentAID)
    supplierPosition = find( ...
        supplierID==attachmentAID(rowIndex),1);

    for t = 1:T
        if ~isempty(supplierPosition) && ...
                orderPlan(supplierPosition,t)>zeroTolerance

            attachmentAData{rowIndex,t} = ...
                orderPlan(supplierPosition,t);
        else
            attachmentAData{rowIndex,t} = [];
        end
    end
end

writecell( ...
    attachmentAData, ...
    attachmentAOutput, ...
    'Sheet',question4OrderSheet, ...
    'Range','B7');

%% 28. 填写附件B中的问题4转运方案
copyfile(attachmentBFile,attachmentBOutput,'f');

question4TransportSheet = localFindSheetByKeywords( ...
    attachmentBOutput, ...
    {'问题4','转运'});

attachmentBID = strtrim(string(readcell( ...
    attachmentBOutput, ...
    'Sheet',question4TransportSheet, ...
    'Range','A7:A408')));

attachmentBData = cell(numel(attachmentBID),T*K);

for rowIndex = 1:numel(attachmentBID)
    supplierPosition = find( ...
        supplierID==attachmentBID(rowIndex),1);

    for t = 1:T
        for k = 1:K
            outputColumn = (t-1)*K+k;

            if ~isempty(supplierPosition) && ...
                    transportPlan( ...
                    supplierPosition,k,t)>zeroTolerance

                attachmentBData{rowIndex,outputColumn} = ...
                    transportPlan( ...
                    supplierPosition,k,t);
            else
                attachmentBData{rowIndex,outputColumn} = [];
            end
        end
    end
end

writecell( ...
    attachmentBData, ...
    attachmentBOutput, ...
    'Sheet',question4TransportSheet, ...
    'Range','B7');

% 修正模板中GL列"合计"公式
totalFormula = cell(numel(attachmentBID),1);

for rowIndex = 1:numel(attachmentBID)
    excelRow = rowIndex+6;
    totalFormula{rowIndex} = ...
        sprintf('=SUM(B%d:GK%d)',excelRow,excelRow);
end

writecell( ...
    totalFormula, ...
    attachmentBOutput, ...
    'Sheet',question4TransportSheet, ...
    'Range','GL7');

%% 29. 绘制产能提升对比图
fig1 = figure( ...
    'Color','w', ...
    'Position',[100,100,820,620]);

ax1 = axes(fig1);

bar(ax1, ...
    [originalWeeklyCapacity,finalWeeklyCapacity]);

set(ax1, ...
    'XTick',1:2, ...
    'XTickLabel',{'技术改造前','技术改造后'}, ...
    'FontSize',11);

ylabel(ax1,'周产能（立方米产品/周）');
title(ax1,'技术改造前后企业周产能对比', ...
    'FontSize',15);
grid(ax1,'on');

text(ax1,1,originalWeeklyCapacity, ...
    sprintf('  %.2f',originalWeeklyCapacity), ...
    'VerticalAlignment','bottom', ...
    'HorizontalAlignment','center');

text(ax1,2,finalWeeklyCapacity, ...
    sprintf('  %.2f',finalWeeklyCapacity), ...
    'VerticalAlignment','bottom', ...
    'HorizontalAlignment','center');

localExportFigure(fig1,figureCapacityFile);

%% 30. 绘制未来24周原材料供货结构图
fig2 = figure( ...
    'Color','w', ...
    'Position',[100,100,1100,680]);

ax2 = axes(fig2);

bar(ax2,weekNumber, ...
    weeklySupplyByType,'stacked');

set(ax2,'XTick',1:T,'FontSize',11);
xlabel(ax2,'未来周次');
ylabel(ax2,'预计供货量（立方米）');
title(ax2,'问题四未来24周原材料预计供货结构', ...
    'FontSize',15);
legend(ax2,{'A类','B类','C类'}, ...
    'Location','best');
grid(ax2,'on');

localExportFigure(fig2,figureMaterialFile);

%% 31. 绘制未来24周库存变化图
fig3 = figure( ...
    'Color','w', ...
    'Position',[100,100,1100,680]);

ax3 = axes(fig3);
hold(ax3,'on');

plot(ax3,weekNumber,inventoryPlan, ...
    '-o','LineWidth',1.8,'MarkerSize',5);

plot(ax3,weekNumber, ...
    safetyInventory*ones(T,1), ...
    'k--','LineWidth',1.5);

set(ax3,'XTick',1:T,'FontSize',11);
xlabel(ax3,'未来周次');
ylabel(ax3,'库存产能当量（立方米产品）');
title(ax3,'问题四未来24周库存变化', ...
    'FontSize',15);
legend(ax3,{'实际库存','两周安全库存'}, ...
    'Location','best');
grid(ax3,'on');
hold(ax3,'off');

localExportFigure(fig3,figureInventoryFile);

%% 32. 绘制未来24周转运量图
fig4 = figure( ...
    'Color','w', ...
    'Position',[100,100,1180,700]);

ax4 = axes(fig4);
hold(ax4,'on');

bar(ax4,weekNumber, ...
    weeklyTransporterLoad','stacked');

plot(ax4,weekNumber, ...
    K*transporterCapacity*ones(T,1), ...
    'k--','LineWidth',1.5);

set(ax4,'XTick',1:T,'FontSize',11);
xlabel(ax4,'未来周次');
ylabel(ax4,'运输量（立方米）');
title(ax4,'问题四未来24周各转运商运输量', ...
    'FontSize',15);

legendEntries = [cellstr(transporterID);{'总运输能力上限'}];

legend(ax4,legendEntries, ...
    'Location','eastoutside');

grid(ax4,'on');
hold(ax4,'off');

localExportFigure(fig4,figureTransportFile);

%% 33. 绘制供应端和运输端能力利用率图
fig5 = figure( ...
    'Color','w', ...
    'Position',[100,100,1100,680]);

ax5 = axes(fig5);
hold(ax5,'on');

plot(ax5,weekNumber, ...
    100*weeklySupplierCapacityUtilization, ...
    '-o','LineWidth',1.8,'MarkerSize',5);

plot(ax5,weekNumber, ...
    100*weeklyTransportCapacityUtilization, ...
    '-s','LineWidth',1.8,'MarkerSize',5);

plot(ax5,weekNumber, ...
    100*ones(T,1), ...
    'k--','LineWidth',1.5);

set(ax5,'XTick',1:T,'FontSize',11);
xlabel(ax5,'未来周次');
ylabel(ax5,'能力利用率（%）');
title(ax5,'问题四供应端与运输端能力利用率', ...
    'FontSize',15);

legend(ax5, ...
    {'供应端能力利用率','运输端能力利用率','100%能力线'}, ...
    'Location','best');

grid(ax5,'on');
hold(ax5,'off');

localExportFigure(fig5,figureUtilizationFile);

%% 34. 完成提示
fprintf('\n计算完成。\n');
fprintf('完整结果工作簿：%s\n',resultFile);
fprintf('问题4订购方案附件：%s\n',attachmentAOutput);
fprintf('问题4转运方案附件：%s\n',attachmentBOutput);
fprintf('产能提升图：%s\n',figureCapacityFile);
fprintf('原材料结构图：%s\n',figureMaterialFile);
fprintf('库存变化图：%s\n',figureInventoryFile);
fprintf('转运量图：%s\n',figureTransportFile);
fprintf('能力利用率图：%s\n',figureUtilizationFile);

%% ========================================================================
%                              局部函数
% ========================================================================

%% 局部函数1：自动寻找输入文件
function fileName = localFindInputFile( ...
        defaultNameList,pattern,description)

    for i = 1:numel(defaultNameList)
        if isfile(defaultNameList{i})
            fileName = defaultNameList{i};
            return;
        end
    end

    candidates = dir(pattern);

    % 排除已经生成的问题结果文件和临时文件
    keep = true(numel(candidates),1);

    for i = 1:numel(candidates)
        currentName = string(candidates(i).name);

        if contains(currentName,"_问题") || ...
                contains(currentName,"修正版") || ...
                startsWith(currentName,"~$")
            keep(i) = false;
        end
    end

    candidates = candidates(keep);

    if isempty(candidates)
        error('未找到%s。请将文件与程序放在同一文件夹。', ...
            description);
    end

    if numel(candidates)>1
        fprintf('检测到多个%s候选文件：\n',description);

        for i = 1:numel(candidates)
            fprintf('  %d. %s\n',i,candidates(i).name);
        end

        % 优先使用修改时间最新的文件
        [~,latestIndex] = max([candidates.datenum]);
        fileName = candidates(latestIndex).name;

        fprintf('已自动使用：%s\n',fileName);
    else
        fileName = candidates(1).name;
    end
end

%% 局部函数2：将混合单元格区域转换为数值矩阵
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

%% 局部函数3：计算百分位数
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

    percentileLevel = min(max(percentileLevel,0),100);

    position = ...
        1+(numel(dataVector)-1)*percentileLevel/100;

    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex==upperIndex
        percentileValue = dataVector(lowerIndex);
    else
        interpolationWeight = position-lowerIndex;

        percentileValue = ...
            dataVector(lowerIndex)+ ...
            interpolationWeight* ...
            (dataVector(upperIndex)- ...
            dataVector(lowerIndex));
    end
end

%% 局部函数4：计算双侧截尾均值
function trimmedMeanValue = localTrimmedMean( ...
        dataVector,trimFraction)

    dataVector = dataVector(:);
    dataVector = dataVector(isfinite(dataVector));
    dataVector = sort(dataVector);

    if isempty(dataVector)
        trimmedMeanValue = 0;
        return;
    end

    trimCount = floor( ...
        numel(dataVector)*trimFraction);

    if 2*trimCount>=numel(dataVector)
        trimmedMeanValue = mean(dataVector);
    else
        retainedData = dataVector( ...
            trimCount+1:end-trimCount);

        trimmedMeanValue = mean(retainedData);
    end
end

%% 局部函数5：目标函数容差
function tolerance = localObjectiveTolerance( ...
        objectiveValue,absoluteTolerance,relativeTolerance)

    tolerance = max( ...
        absoluteTolerance, ...
        relativeTolerance*abs(objectiveValue));
end

%% 局部函数6：检查线性规划求解结果
function localCheckSolution( ...
        solution,exitflag,modelName)

    if exitflag<=0 || isempty(solution)
        error('%s求解失败，exitflag=%d。', ...
            modelName,exitflag);
    end
end

%% 局部函数7：按关键词查找工作表
function sheetName = localFindSheetByKeywords( ...
        workbookFile,keywordCell)

    try
        sheetList = sheetnames(workbookFile);
    catch
        [~,sheetList] = xlsfinfo(workbookFile);
        sheetList = string(sheetList);
    end

    sheetName = '';

    for sheetIndex = 1:numel(sheetList)
        currentName = string(sheetList(sheetIndex));
        matched = true;

        for keywordIndex = 1:numel(keywordCell)
            if ~contains( ...
                    currentName, ...
                    string(keywordCell{keywordIndex}))
                matched = false;
                break;
            end
        end

        if matched
            sheetName = char(currentName);
            return;
        end
    end

    error('工作簿%s中未找到包含指定关键词的工作表。', ...
        workbookFile);
end

%% 局部函数8：导出图像
function localExportFigure(fig,fileName)
    try
        exportgraphics(fig,fileName,'Resolution',300);
    catch
        print(fig,fileName,'-dpng','-r300');
    end
end
