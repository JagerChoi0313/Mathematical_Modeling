%% 问题三：分层多目标订购—库存—转运联合优化（快速完整求解版）
%
% 目标优先级：
% 1. C类预计供货量最少；
% 2. A类损耗后入库产能最大；
% 3. 原材料总运输体积最小；
% 4. 累计库存占用最小；
% 5. 运输损耗最小。
%
% 本程序采用连续联合线性规划求解订购量、供货量、转运量和库存量。
% "一家供应商每周尽量由一家转运商运输"不作为强制0-1约束，
% 而通过最终拆分运输比例进行评价，因此运行速度明显快于大规模MILP。
%
% 必需输入文件：
% 1. 附件1 近5年402家供应商的相关数据.xlsx
% 2. 附件2 近5年8家转运商的相关数据.xlsx
% 3. 问题三_候选供应商与未来24周供货能力估计.xlsx
% 4. 附件A 订购方案数据结果.xlsx
% 5. 附件B 转运方案数据结果.xlsx
%
% 可选输入：
% 6. 问题二_24周经济订购与最小损耗转运结果.xlsx
%
% 输出：
% 1. 问题三_24周订购库存转运优化结果.xlsx
% 2. 附件A_问题3订购方案.xlsx
% 3. 附件B_问题3转运方案.xlsx
% 4. 四张结果图

clear;
clc;
close all;

%% 1. 参数设置
allSupplierCount = 402;
historyWeeks = 240;
yearCount = 5;
weeksPerYear = 48;
futureWeeks = 24;
transporterCount = 8;

weeklyDemand = 28200;
safetyInventory = 2*weeklyDemand;
transporterCapacity = 6000;
orderUpperPercentile = 90;

yearWeights = (1:yearCount)';
yearWeights = yearWeights/sum(yearWeights);

zeroTolerance = 1e-7;
absoluteTolerance = 1e-5;
relativeTolerance = 1e-8;

supplierHistoryDefault = '附件1 近5年402家供应商的相关数据.xlsx';
transporterHistoryDefault = '附件2 近5年8家转运商的相关数据.xlsx';
candidateDefault = '问题三_候选供应商与未来24周供货能力估计.xlsx';
question2Default = '问题二_24周经济订购与最小损耗转运结果.xlsx';
attachmentADefault = '附件A 订购方案数据结果.xlsx';
attachmentBDefault = '附件B 转运方案数据结果.xlsx';

resultFile = '问题三_24周订购库存转运优化结果.xlsx';
attachmentAOutput = '附件A_问题3订购方案.xlsx';
attachmentBOutput = '附件B_问题3转运方案.xlsx';

figureMaterialFile = '问题三_24周原材料结构.png';
figureInventoryFile = '问题三_24周库存变化.png';
figureTransportFile = '问题三_24周转运商运输量.png';
figureCompareFile = '问题二与问题三原材料结构对比.png';

if isfile(resultFile)
    delete(resultFile);
end

if exist('linprog','file')~=2
    error('未检测到linprog，请安装或启用Optimization Toolbox。');
end

options = optimoptions('linprog','Display','none');

%% 2. 自动寻找输入文件
supplierHistoryFile = localFindFile( ...
    supplierHistoryDefault,'附件1*402家供应商*.xlsx','附件1');

transporterHistoryFile = localFindFile( ...
    transporterHistoryDefault,'附件2*8家转运商*.xlsx','附件2');

candidateFile = localFindFile( ...
    candidateDefault,'问题三_候选供应商与未来24周供货能力估计*.xlsx', ...
    '问题三候选供应商参数');

attachmentAFile = localFindFile( ...
    attachmentADefault,'附件A*订购方案数据结果*.xlsx','附件A');

attachmentBFile = localFindFile( ...
    attachmentBDefault,'附件B*转运方案数据结果*.xlsx','附件B');

question2File = '';
if isfile(question2Default)
    question2File = question2Default;
else
    files = dir('问题二_24周经济订购与最小损耗转运结果*.xlsx');
    if ~isempty(files)
        [~,idx] = max([files.datenum]);
        question2File = files(idx).name;
    end
end

fprintf('\n================ 输入文件 ================\n');
fprintf('供应商历史数据：%s\n',supplierHistoryFile);
fprintf('转运商历史数据：%s\n',transporterHistoryFile);
fprintf('第三问候选参数：%s\n',candidateFile);

%% 3. 读取候选供应商参数
candidateCell = readcell(candidateFile,'Sheet','候选供应商参数');
header = strtrim(string(candidateCell(1,:)));

idCol = localFindHeader(header,'供应商编号');
typeCol = localFindHeader(header,'材料类别');
rankCol = localFindHeader(header,'问题一综合排名');
upperCol = localFindHeader(header,'规划供货上限');
coreCol = localFindHeader(header,'是否问题二核心供应商');

supplierID = strtrim(string(candidateCell(2:end,idCol)));
materialType = upper(strtrim(string(candidateCell(2:end,typeCol))));
rankValue = localCellToDouble(candidateCell(2:end,rankCol),NaN,'综合排名');
planningUpper = localCellToDouble(candidateCell(2:end,upperCol),0,'规划供货上限');

coreFlag = false(size(supplierID));
for i = 1:numel(supplierID)
    v = candidateCell{i+1,coreCol};
    if islogical(v)
        coreFlag(i) = v;
    elseif isnumeric(v)
        coreFlag(i) = v~=0;
    else
        s = lower(strtrim(string(v)));
        coreFlag(i) = s=="true" || s=="1" || s=="是";
    end
end

valid = strlength(supplierID)>0 & ~ismissing(supplierID);
supplierID = supplierID(valid);
materialType = materialType(valid);
rankValue = rankValue(valid);
planningUpper = planningUpper(valid);
coreFlag = coreFlag(valid);

n = numel(supplierID);

if numel(unique(supplierID))~=n
    error('候选供应商编号存在重复。');
end

%% 4. 读取未来24周响应系数
responseCell = readcell(candidateFile,'Sheet','24周订货响应系数');
responseHeader = strtrim(string(responseCell(1,:)));

responseIDCol = localFindHeader(responseHeader,'供应商编号');
responseTypeCol = localFindHeader(responseHeader,'材料类别');

responseID = strtrim(string(responseCell(2:end,responseIDCol)));
responseType = upper(strtrim(string(responseCell(2:end,responseTypeCol))));

weekCols = zeros(1,futureWeeks);
for t = 1:futureWeeks
    weekCols(t) = localFindHeader(responseHeader,sprintf('第%d周',t));
end

responseAll = localCellToDouble( ...
    responseCell(2:end,weekCols),0,'未来响应系数');

[found,loc] = ismember(supplierID,responseID);
if any(~found)
    error('响应系数表中缺少部分候选供应商。');
end

if any(materialType~=responseType(loc))
    error('候选参数表与响应系数表材料类别不一致。');
end

futureResponse = responseAll(loc,:);

%% 5. 读取附件1并计算合理订货量上限
orderCell = readcell(supplierHistoryFile,'Sheet','企业的订货量（m³）');

allSupplierID = strtrim(string(orderCell(2:allSupplierCount+1,1)));
allMaterialType = upper(strtrim(string(orderCell(2:allSupplierCount+1,2))));

historicalOrder = localCellToDouble( ...
    orderCell(2:allSupplierCount+1,3:historyWeeks+2),0,'历史订货量');

[found,globalLoc] = ismember(supplierID,allSupplierID);
if any(~found)
    error('附件1中缺少部分候选供应商。');
end

if any(materialType~=allMaterialType(globalLoc))
    error('附件1与候选参数表材料类别不一致。');
end

orderUpper = zeros(n,1);
for i = 1:n
    sample = historicalOrder(globalLoc(i),:);
    sample = sample(sample>0);
    if isempty(sample)
        orderUpper(i) = 0;
    else
        orderUpper(i) = localPercentile(sample,orderUpperPercentile);
    end
end

maximumSupply = min( ...
    futureResponse.*repmat(orderUpper,1,futureWeeks), ...
    repmat(planningUpper,1,futureWeeks));

maximumSupply = min(maximumSupply,transporterCapacity);

%% 6. 材料参数
consumption = zeros(n,1);
price = zeros(n,1);

consumption(materialType=="A") = 0.60;
consumption(materialType=="B") = 0.66;
consumption(materialType=="C") = 0.72;

price(materialType=="A") = 1.20;
price(materialType=="B") = 1.10;
price(materialType=="C") = 1.00;

%% 7. 估计未来24周转运损耗率
lossCell = readcell(transporterHistoryFile,'Sheet','运输损耗率（%）');
transporterID = strtrim(string(lossCell(2:transporterCount+1,1)));

historicalLoss = localCellToDouble( ...
    lossCell(2:transporterCount+1,2:historyWeeks+1),0,'历史损耗率');

futureLoss = zeros(transporterCount,futureWeeks);

for k = 1:transporterCount
    positiveLoss = historicalLoss(k,historicalLoss(k,:)>0);
    if isempty(positiveLoss)
        fallback = 0;
    else
        fallback = mean(positiveLoss);
    end

    for t = 1:futureWeeks
        idx = t+weeksPerYear*(0:yearCount-1);
        sample = historicalLoss(k,idx);
        validLoss = sample>0;

        if any(validLoss)
            currentWeights = yearWeights(validLoss);
            lossPercent = sum(currentWeights.*sample(validLoss)')/sum(currentWeights);
        else
            lossPercent = fallback;
        end

        futureLoss(k,t) = lossPercent/100;
    end
end

%% 8. 候选集合可行性核验
weeklyMaximumCapacity = zeros(futureWeeks,1);
weeklyAMaximumCapacity = zeros(futureWeeks,1);

for t = 1:futureWeeks
    weeklyMaximumCapacity(t) = sum(maximumSupply(:,t)./consumption);
    weeklyAMaximumCapacity(t) = sum(maximumSupply(materialType=="A",t)/0.60);
end

if any(weeklyMaximumCapacity<weeklyDemand-zeroTolerance)
    badWeek = find(weeklyMaximumCapacity<weeklyDemand-zeroTolerance);
    error('候选集合第%s周最大产能不足。',strjoin(string(badWeek),'、'));
end

fprintf('\n================ 候选集合核验 ================\n');
fprintf('候选供应商：%d家，A/B/C=%d/%d/%d\n', ...
    n,sum(materialType=="A"),sum(materialType=="B"),sum(materialType=="C"));
fprintf('最小周最大产能：%.2f\n',min(weeklyMaximumCapacity));
fprintf('A类最小周最大产能：%.2f\n',min(weeklyAMaximumCapacity));

%% 9. 构造变量索引
K = transporterCount;
T = futureWeeks;

qIndex = reshape(1:n*T,n,T);
yIndex = reshape(n*T+(1:n*K*T),n,K,T);
hIndex = n*T+n*K*T+(1:T);

variableCount = n*T+n*K*T+T;

%% 10. 构造等式约束
Aeq = spalloc(n*T+T,variableCount,n*T*(K+1)+T*(n*K+2));
beq = zeros(n*T+T,1);

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
        beq(row) = safetyInventory-weeklyDemand;
    else
        Aeq(row,hIndex(t-1)) = -1;
        beq(row) = -weeklyDemand;
    end

    for i = 1:n
        for k = 1:K
            coeff = (1-futureLoss(k,t))/consumption(i);
            Aeq(row,yIndex(i,k,t)) = -coeff;
        end
    end
end

%% 11. 转运商容量约束
AubBase = spalloc(K*T,variableCount,n*K*T);
bubBase = transporterCapacity*ones(K*T,1);

row = 0;
for t = 1:T
    for k = 1:K
        row = row+1;
        for i = 1:n
            AubBase(row,yIndex(i,k,t)) = 1;
        end
    end
end

%% 12. 变量上下界
lb = zeros(variableCount,1);
ub = inf(variableCount,1);

for t = 1:T
    for i = 1:n
        ub(qIndex(i,t)) = maximumSupply(i,t);
        for k = 1:K
            ub(yIndex(i,k,t)) = maximumSupply(i,t);
        end
    end
end

lb(hIndex) = safetyInventory;
ub(hIndex(T)) = safetyInventory;

%% 13. 五层目标函数
objC = zeros(variableCount,1);
objNegA = zeros(variableCount,1);
objVolume = zeros(variableCount,1);
objInventory = zeros(variableCount,1);
objLoss = zeros(variableCount,1);

for t = 1:T
    for i = 1:n
        if materialType(i)=="C"
            objC(qIndex(i,t)) = 1;
        end

        objVolume(qIndex(i,t)) = 1;

        for k = 1:K
            if materialType(i)=="A"
                objNegA(yIndex(i,k,t)) = -(1-futureLoss(k,t))/0.60;
            end
            objLoss(yIndex(i,k,t)) = futureLoss(k,t);
        end
    end
end

objInventory(hIndex) = 1;

%% 14. 分层求解
fprintf('\n================ 分层优化求解 ================\n');

[x1,f1,ef1] = linprog(objC,AubBase,bubBase,Aeq,beq,lb,ub,options);
localCheck(x1,ef1,'第一层C类供货最少');
tol1 = localTol(f1,absoluteTolerance,relativeTolerance);
fprintf('第一层：最小C类供货量=%.6f\n',f1);

Aub2 = [AubBase;sparse(objC')];
bub2 = [bubBase;f1+tol1];

[x2,f2,ef2] = linprog(objNegA,Aub2,bub2,Aeq,beq,lb,ub,options);
localCheck(x2,ef2,'第二层A类入库产能最大');
tol2 = localTol(f2,absoluteTolerance,relativeTolerance);
fprintf('第二层：最大A类入库产能=%.6f\n',-f2);

Aub3 = [Aub2;sparse(objNegA')];
bub3 = [bub2;f2+tol2];

[x3,f3,ef3] = linprog(objVolume,Aub3,bub3,Aeq,beq,lb,ub,options);
localCheck(x3,ef3,'第三层原材料体积最小');
tol3 = localTol(f3,absoluteTolerance,relativeTolerance);
fprintf('第三层：最小原材料体积=%.6f\n',f3);

Aub4 = [Aub3;sparse(objVolume')];
bub4 = [bub3;f3+tol3];

[x4,f4,ef4] = linprog(objInventory,Aub4,bub4,Aeq,beq,lb,ub,options);
localCheck(x4,ef4,'第四层累计库存最小');
tol4 = localTol(f4,absoluteTolerance,relativeTolerance);
fprintf('第四层：最小累计库存=%.6f\n',f4);

Aub5 = [Aub4;sparse(objInventory')];
bub5 = [bub4;f4+tol4];

[x5,f5,ef5] = linprog(objLoss,Aub5,bub5,Aeq,beq,lb,ub,options);
localCheck(x5,ef5,'第五层运输损耗最小');
fprintf('第五层：最小运输损耗=%.6f\n',f5);

%% 15. 提取方案
supplyPlan = zeros(n,T);
transportPlan = zeros(n,K,T);
inventory = zeros(T,1);

for t = 1:T
    for i = 1:n
        supplyPlan(i,t) = x5(qIndex(i,t));
        for k = 1:K
            transportPlan(i,k,t) = x5(yIndex(i,k,t));
        end
    end
    inventory(t) = x5(hIndex(t));
end

supplyPlan(abs(supplyPlan)<zeroTolerance) = 0;
transportPlan(abs(transportPlan)<zeroTolerance) = 0;

orderPlan = zeros(n,T);
for t = 1:T
    for i = 1:n
        if supplyPlan(i,t)>zeroTolerance
            if futureResponse(i,t)<=zeroTolerance
                error('供应商%s第%d周响应系数为0。',supplierID(i),t);
            end
            orderPlan(i,t) = supplyPlan(i,t)/futureResponse(i,t);
        end
    end
end

orderUpperMatrix = repmat(orderUpper,1,T);
violation = orderPlan-orderUpperMatrix;
if any(violation(:)>1e-4)
    error('反推订货量超过合理订货量上限。');
end

%% 16. 指标核验
materialLabels = ["A","B","C"];

weeklyOrderByType = zeros(T,3);
weeklySupplyByType = zeros(T,3);
weeklyReceivedByType = zeros(T,3);
weeklyReceivedRaw = zeros(T,1);
weeklyReceivedProduct = zeros(T,1);
weeklyLoss = zeros(T,1);
weeklyCost = zeros(T,1);
weeklyTransporterLoad = zeros(K,T);

for t = 1:T
    for k = 1:K
        weeklyTransporterLoad(k,t) = sum(transportPlan(:,k,t));
    end

    for i = 1:n
        typeIndex = find(materialLabels==materialType(i),1);

        weeklyOrderByType(t,typeIndex) = ...
            weeklyOrderByType(t,typeIndex)+orderPlan(i,t);

        weeklySupplyByType(t,typeIndex) = ...
            weeklySupplyByType(t,typeIndex)+supplyPlan(i,t);

        weeklyCost(t) = weeklyCost(t)+price(i)*supplyPlan(i,t);

        for k = 1:K
            amount = transportPlan(i,k,t);
            lossAmount = futureLoss(k,t)*amount;
            received = (1-futureLoss(k,t))*amount;

            weeklyLoss(t) = weeklyLoss(t)+lossAmount;
            weeklyReceivedRaw(t) = weeklyReceivedRaw(t)+received;
            weeklyReceivedProduct(t) = weeklyReceivedProduct(t)+received/consumption(i);
            weeklyReceivedByType(t,typeIndex) = ...
                weeklyReceivedByType(t,typeIndex)+received;
        end
    end
end

if any(weeklyTransporterLoad(:)>transporterCapacity+1e-4)
    error('转运商存在超载。');
end

if any(inventory<safetyInventory-1e-4)
    error('库存低于两周安全库存。');
end

for t = 1:T
    transported = reshape(sum(transportPlan(:,:,t),2),n,1);
    if max(abs(transported-supplyPlan(:,t)))>1e-4
        error('第%d周供货量与转运量不一致。',t);
    end
end

totalOrderByType = sum(weeklyOrderByType,1);
totalSupplyByType = sum(weeklySupplyByType,1);
totalSupply = sum(totalSupplyByType);
totalLoss = sum(weeklyLoss);
totalReceived = sum(weeklyReceivedRaw);
totalCost = sum(weeklyCost);
averageLossRate = totalLoss/totalSupply;
supplyShare = totalSupplyByType/totalSupply;
cumulativeInventory = sum(inventory);
cumulativeExcessInventory = sum(inventory-safetyInventory);

activeSupplierCount = sum(sum(supplyPlan,2)>zeroTolerance);
positiveSupplierWeekCount = sum(supplyPlan(:)>zeroTolerance);

splitCount = 0;
for t = 1:T
    for i = 1:n
        if sum(transportPlan(i,:,t)>zeroTolerance)>1
            splitCount = splitCount+1;
        end
    end
end

if positiveSupplierWeekCount>0
    splitRate = splitCount/positiveSupplierWeekCount;
else
    splitRate = 0;
end

fprintf('\n============================================================\n');
fprintf(' 问题三最终结果\n');
fprintf('============================================================\n');
fprintf('实际启用供应商：%d家\n',activeSupplierCount);
fprintf('24周订货总量：%.6f\n',sum(totalOrderByType));
fprintf('24周预计供货总量：%.6f\n',totalSupply);
fprintf('24周预计接收总量：%.6f\n',totalReceived);
fprintf('24周相对采购成本：%.6f\n',totalCost);
fprintf('24周运输损耗：%.6f\n',totalLoss);
fprintf('平均损耗率：%.6f%%\n',100*averageLossRate);
fprintf('最低库存：%.6f\n',min(inventory));
fprintf('期末库存：%.6f\n',inventory(T));
fprintf('拆分运输组合：%d个，占%.4f%%\n',splitCount,100*splitRate);

fprintf('\nA/B/C类预计供货总量：\n');
fprintf('A类：%.6f，占%.4f%%\n',totalSupplyByType(1),100*supplyShare(1));
fprintf('B类：%.6f，占%.4f%%\n',totalSupplyByType(2),100*supplyShare(2));
fprintf('C类：%.6f，占%.4f%%\n',totalSupplyByType(3),100*supplyShare(3));

%% 17. 构造输出表
weekNumber = (1:T)';

weeklyTable = table( ...
    weekNumber, ...
    weeklyOrderByType(:,1),weeklyOrderByType(:,2),weeklyOrderByType(:,3), ...
    sum(weeklyOrderByType,2), ...
    weeklySupplyByType(:,1),weeklySupplyByType(:,2),weeklySupplyByType(:,3), ...
    sum(weeklySupplyByType,2), ...
    weeklyReceivedByType(:,1),weeklyReceivedByType(:,2),weeklyReceivedByType(:,3), ...
    weeklyReceivedRaw,weeklyReceivedProduct,inventory,weeklyCost,weeklyLoss, ...
    'VariableNames',{ ...
    '周次','A类订货量','B类订货量','C类订货量','订货总量', ...
    'A类预计供货量','B类预计供货量','C类预计供货量','预计供货总量', ...
    'A类预计接收量','B类预计接收量','C类预计接收量', ...
    '预计接收总量','接收产能当量','周末库存产能当量', ...
    '相对采购成本','运输损耗量'});

weekNames = cell(1,T);
for t = 1:T
    weekNames{t} = sprintf('第%02d周',t);
end

orderTable = array2table(orderPlan,'VariableNames',weekNames);
orderTable = addvars(orderTable,supplierID,materialType,coreFlag, ...
    'Before',1,'NewVariableNames',{'供应商编号','材料类别','是否问题二核心供应商'});

supplyTable = array2table(supplyPlan,'VariableNames',weekNames);
supplyTable = addvars(supplyTable,supplierID,materialType,coreFlag, ...
    'Before',1,'NewVariableNames',{'供应商编号','材料类别','是否问题二核心供应商'});

loadTable = table(weekNumber);
utilizationTable = table(weekNumber);

for k = 1:K
    loadTable = addvars(loadTable,weeklyTransporterLoad(k,:)', ...
        'NewVariableNames',{char(transporterID(k))});
    utilizationTable = addvars(utilizationTable, ...
        weeklyTransporterLoad(k,:)'/transporterCapacity, ...
        'NewVariableNames',{char(transporterID(k))});
end

maxRows = n*K*T;
longSupplier = strings(maxRows,1);
longWeek = zeros(maxRows,1);
longTransporter = strings(maxRows,1);
longQuantity = zeros(maxRows,1);
longLossRate = zeros(maxRows,1);
longLossAmount = zeros(maxRows,1);

r = 0;
for t = 1:T
    for i = 1:n
        for k = 1:K
            amount = transportPlan(i,k,t);
            if amount>zeroTolerance
                r = r+1;
                longSupplier(r) = supplierID(i);
                longWeek(r) = t;
                longTransporter(r) = transporterID(k);
                longQuantity(r) = amount;
                longLossRate(r) = 100*futureLoss(k,t);
                longLossAmount(r) = futureLoss(k,t)*amount;
            end
        end
    end
end

transportLongTable = table( ...
    longSupplier(1:r),longWeek(1:r),longTransporter(1:r), ...
    longQuantity(1:r),longLossRate(1:r),longLossAmount(1:r), ...
    'VariableNames',{'供应商编号','周次','转运商编号', ...
    '转运量','预计损耗率百分比','预计损耗量'});

supplierSummaryTable = table( ...
    supplierID,materialType,coreFlag,rankValue,orderUpper,planningUpper, ...
    mean(futureResponse,2),sum(orderPlan,2),sum(supplyPlan,2), ...
    sum(supplyPlan>zeroTolerance,2), ...
    'VariableNames',{'供应商编号','材料类别','是否问题二核心供应商', ...
    '问题一综合排名','合理订货量上限','规划供货上限', ...
    '24周平均响应系数','24周订货总量','24周预计供货总量','实际订货周数'});

metricName = [ ...
    "候选供应商数量";"实际启用供应商数量"; ...
    "A类订货总量";"B类订货总量";"C类订货总量"; ...
    "A类预计供货总量";"B类预计供货总量";"C类预计供货总量"; ...
    "A类预计供货占比";"B类预计供货占比";"C类预计供货占比"; ...
    "预计供货总量";"预计接收总量";"相对采购成本"; ...
    "总运输损耗量";"平均运输损耗率"; ...
    "累计库存产能当量";"累计超额库存产能当量"; ...
    "最低库存产能当量";"期末库存产能当量"; ...
    "拆分运输供应商周数";"拆分运输比例"];

metricValue = [ ...
    n;activeSupplierCount; ...
    totalOrderByType(1);totalOrderByType(2);totalOrderByType(3); ...
    totalSupplyByType(1);totalSupplyByType(2);totalSupplyByType(3); ...
    supplyShare(1);supplyShare(2);supplyShare(3); ...
    totalSupply;totalReceived;totalCost;totalLoss;averageLossRate; ...
    cumulativeInventory;cumulativeExcessInventory; ...
    min(inventory);inventory(T);splitCount;splitRate];

metricTable = table(metricName,metricValue, ...
    'VariableNames',{'指标名称','指标值'});

%% 18. 与问题二结果比较
comparisonTable = table();

if strlength(string(question2File))>0
    try
        q2Metric = readtable(question2File,'Sheet','总体指标', ...
            'VariableNamingRule','preserve');

        q2Name = string(q2Metric{:,1});
        q2Value = double(q2Metric{:,2});

        q2A = localGetMetric(q2Name,q2Value,'A类预计供货总量');
        q2B = localGetMetric(q2Name,q2Value,'B类预计供货总量');
        q2C = localGetMetric(q2Name,q2Value,'C类预计供货总量');
        q2Total = localGetMetric(q2Name,q2Value,'预计供货总量');
        q2Cost = localGetMetric(q2Name,q2Value,'相对采购成本');
        q2Loss = localGetMetric(q2Name,q2Value,'总运输损耗量');
        q2AverageLoss = localGetMetric(q2Name,q2Value,'平均运输损耗率');

        q2Weekly = readtable(question2File,'Sheet','24周实施效果', ...
            'VariableNamingRule','preserve');

        inventoryCol = find( ...
            string(q2Weekly.Properties.VariableNames)=="周末库存产能当量",1);

        if isempty(inventoryCol)
            q2Inventory = NaN;
        else
            q2Inventory = sum(q2Weekly{:,inventoryCol});
        end

        comparisonMetric = [ ...
            "A类预计供货量";"B类预计供货量";"C类预计供货量"; ...
            "A类预计供货占比";"B类预计供货占比";"C类预计供货占比"; ...
            "原材料总运输体积";"相对采购成本"; ...
            "运输损耗量";"平均运输损耗率";"累计库存产能当量"];

        question2Value = [ ...
            q2A;q2B;q2C;q2A/q2Total;q2B/q2Total;q2C/q2Total; ...
            q2Total;q2Cost;q2Loss;q2AverageLoss;q2Inventory];

        question3Value = [ ...
            totalSupplyByType(1);totalSupplyByType(2);totalSupplyByType(3); ...
            supplyShare(1);supplyShare(2);supplyShare(3); ...
            totalSupply;totalCost;totalLoss;averageLossRate;cumulativeInventory];

        absoluteChange = question3Value-question2Value;
        relativeChange = absoluteChange./question2Value;
        relativeChange(~isfinite(relativeChange)) = NaN;

        comparisonTable = table( ...
            comparisonMetric,question2Value,question3Value, ...
            absoluteChange,relativeChange, ...
            'VariableNames',{'评价指标','问题二方案','问题三方案', ...
            '绝对变化','相对变化率'});

        fprintf('\n================ 相对问题二的变化 ================\n');
        fprintf('A类占比：%.4f%% → %.4f%%\n',100*q2A/q2Total,100*supplyShare(1));
        fprintf('C类占比：%.4f%% → %.4f%%\n',100*q2C/q2Total,100*supplyShare(3));
        fprintf('原材料总运输体积变化：%.6f\n',totalSupply-q2Total);
        fprintf('运输损耗变化：%.6f\n',totalLoss-q2Loss);

    catch ME
        warning('问题二对比读取失败：%s',ME.message);
    end
end

%% 19. 写入结果工作簿
writetable(metricTable,resultFile,'Sheet','总体指标');
writetable(weeklyTable,resultFile,'Sheet','24周实施效果');
writetable(orderTable,resultFile,'Sheet','79家24周订购方案');
writetable(supplyTable,resultFile,'Sheet','79家24周预计供货');
writetable(transportLongTable,resultFile,'Sheet','24周转运方案明细');
writetable(loadTable,resultFile,'Sheet','转运商每周运输量');
writetable(utilizationTable,resultFile,'Sheet','转运商每周利用率');
writetable(supplierSummaryTable,resultFile,'Sheet','供应商汇总');

if ~isempty(comparisonTable)
    writetable(comparisonTable,resultFile,'Sheet','问题二与问题三对比');
end

%% 20. 填写附件A问题3
copyfile(attachmentAFile,attachmentAOutput,'f');
orderSheet = localFindSheet(attachmentAOutput,{'问题3','订购'});

templateID = strtrim(string(readcell(attachmentAOutput, ...
    'Sheet',orderSheet,'Range','A7:A408')));

outputDataA = cell(allSupplierCount,T);

for rowIndex = 1:allSupplierCount
    pos = find(supplierID==templateID(rowIndex),1);
    for t = 1:T
        if ~isempty(pos) && orderPlan(pos,t)>zeroTolerance
            outputDataA{rowIndex,t} = orderPlan(pos,t);
        else
            outputDataA{rowIndex,t} = [];
        end
    end
end

writecell(outputDataA,attachmentAOutput, ...
    'Sheet',orderSheet,'Range','B7');

%% 21. 填写附件B问题3
copyfile(attachmentBFile,attachmentBOutput,'f');
transportSheet = localFindSheet(attachmentBOutput,{'问题3','转运'});

templateID = strtrim(string(readcell(attachmentBOutput, ...
    'Sheet',transportSheet,'Range','A7:A408')));

outputDataB = cell(allSupplierCount,T*K);

for rowIndex = 1:allSupplierCount
    pos = find(supplierID==templateID(rowIndex),1);

    for t = 1:T
        for k = 1:K
            col = (t-1)*K+k;

            if ~isempty(pos) && transportPlan(pos,k,t)>zeroTolerance
                outputDataB{rowIndex,col} = transportPlan(pos,k,t);
            else
                outputDataB{rowIndex,col} = [];
            end
        end
    end
end

writecell(outputDataB,attachmentBOutput, ...
    'Sheet',transportSheet,'Range','B7');

%% 22. 绘图
fig1 = figure('Color','w','Position',[100,100,1100,680]);
ax1 = axes(fig1);
bar(ax1,weekNumber,weeklySupplyByType,'stacked');
set(ax1,'XTick',1:T,'FontSize',11);
xlabel(ax1,'未来周次');
ylabel(ax1,'预计供货量（立方米）');
title(ax1,'问题三未来24周原材料供货结构','FontSize',15);
legend(ax1,{'A类','B类','C类'},'Location','best');
grid(ax1,'on');
localExport(fig1,figureMaterialFile);

fig2 = figure('Color','w','Position',[100,100,1100,680]);
ax2 = axes(fig2);
hold(ax2,'on');
plot(ax2,weekNumber,inventory,'-o','LineWidth',1.8,'MarkerSize',5);
plot(ax2,weekNumber,safetyInventory*ones(T,1),'k--','LineWidth',1.5);
set(ax2,'XTick',1:T,'FontSize',11);
xlabel(ax2,'未来周次');
ylabel(ax2,'周末库存产能当量（立方米产品）');
title(ax2,'问题三未来24周库存变化','FontSize',15);
legend(ax2,{'实际库存','两周安全库存'},'Location','best');
grid(ax2,'on');
hold(ax2,'off');
localExport(fig2,figureInventoryFile);

fig3 = figure('Color','w','Position',[100,100,1150,700]);
ax3 = axes(fig3);
bar(ax3,weekNumber,weeklyTransporterLoad','stacked');
set(ax3,'XTick',1:T,'FontSize',11);
xlabel(ax3,'未来周次');
ylabel(ax3,'运输量（立方米）');
title(ax3,'问题三未来24周转运商运输量','FontSize',15);
legend(ax3,cellstr(transporterID),'Location','eastoutside');
grid(ax3,'on');
localExport(fig3,figureTransportFile);

if ~isempty(comparisonTable)
    % 中文表变量名不能使用 comparisonTable.中文列名 的点号形式
    % 改用花括号按列名提取数值，兼容不同MATLAB版本
    q2Type = comparisonTable{1:3,'问题二方案'}';
    q3Type = comparisonTable{1:3,'问题三方案'}';

    fig4 = figure('Color','w','Position',[100,100,950,650]);
    ax4 = axes(fig4);
    bar(ax4,[q2Type;q3Type]);
    set(ax4,'XTick',1:2, ...
        'XTickLabel',{'问题二方案','问题三方案'},'FontSize',11);
    ylabel(ax4,'预计供货量（立方米）');
    title(ax4,'问题二与问题三原材料结构对比','FontSize',15);
    legend(ax4,{'A类','B类','C类'},'Location','best');
    grid(ax4,'on');
    localExport(fig4,figureCompareFile);
end

fprintf('\n计算完成。\n');
fprintf('完整结果：%s\n',resultFile);
fprintf('附件A：%s\n',attachmentAOutput);
fprintf('附件B：%s\n',attachmentBOutput);

%% 局部函数
function fileName = localFindFile(defaultName,pattern,description)
    if isfile(defaultName)
        fileName = defaultName;
        return;
    end

    files = dir(pattern);
    if isempty(files)
        error('未找到%s。',description);
    end

    [~,idx] = max([files.datenum]);
    fileName = files(idx).name;
end

function columnIndex = localFindHeader(headerRow,targetName)
    columnIndex = find(headerRow==string(targetName),1);
    if isempty(columnIndex)
        error('未找到列：%s',targetName);
    end
end

function numericMatrix = localCellToDouble(cellBlock,blankValue,blockName)
    numericMatrix = zeros(size(cellBlock));

    for idx = 1:numel(cellBlock)
        value = cellBlock{idx};

        if isempty(value)
            numericMatrix(idx) = blankValue;
        elseif isnumeric(value)
            if isnan(value)
                numericMatrix(idx) = blankValue;
            else
                numericMatrix(idx) = double(value);
            end
        elseif islogical(value)
            numericMatrix(idx) = double(value);
        else
            textValue = strtrim(string(value));

            if ismissing(textValue) || strlength(textValue)==0
                numericMatrix(idx) = blankValue;
            else
                converted = str2double(textValue);

                if isnan(converted)
                    error('%s中存在非数值内容：%s',blockName,textValue);
                end

                numericMatrix(idx) = converted;
            end
        end
    end
end

function value = localPercentile(data,level)
    data = sort(data(isfinite(data)));
    data = data(:);

    if isempty(data)
        value = NaN;
        return;
    end

    if numel(data)==1
        value = data(1);
        return;
    end

    position = 1+(numel(data)-1)*level/100;
    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex==upperIndex
        value = data(lowerIndex);
    else
        w = position-lowerIndex;
        value = data(lowerIndex)+w*(data(upperIndex)-data(lowerIndex));
    end
end

function tolerance = localTol(value,absoluteTolerance,relativeTolerance)
    tolerance = max(absoluteTolerance,relativeTolerance*abs(value));
end

function localCheck(solution,exitflag,modelName)
    if exitflag<=0 || isempty(solution)
        error('%s求解失败，exitflag=%d。',modelName,exitflag);
    end
end

function metric = localGetMetric(nameVector,valueVector,targetName)
    idx = find(nameVector==string(targetName),1);

    if isempty(idx)
        error('问题二结果中未找到指标：%s',targetName);
    end

    metric = valueVector(idx);
end

function sheetName = localFindSheet(workbookFile,keywords)
    try
        sheets = sheetnames(workbookFile);
    catch
        [~,sheets] = xlsfinfo(workbookFile);
        sheets = string(sheets);
    end

    for i = 1:numel(sheets)
        current = string(sheets(i));
        matched = true;

        for j = 1:numel(keywords)
            if ~contains(current,string(keywords{j}))
                matched = false;
                break;
            end
        end

        if matched
            sheetName = char(current);
            return;
        end
    end

    error('工作簿中未找到指定问题3工作表。');
end

function localExport(fig,fileName)
    try
        exportgraphics(fig,fileName,'Resolution',300);
    catch
        print(fig,fileName,'-dpng','-r300');
    end
end
