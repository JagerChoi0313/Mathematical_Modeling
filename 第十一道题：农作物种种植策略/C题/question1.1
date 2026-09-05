function main_problem1
% MAIN_PROBLEM1
% 2024 CUMCM C题"农作物的种植策略"——问题1
% 多周期混合整数线性规划（MILP）MATLAB实现
%
% 使用方法：
% 1) 将本文件与"附件1(1).xlsx/附件1.xlsx""附件2(1).xlsx/附件2.xlsx"放在同一文件夹；
% 2) MATLAB 当前文件夹切换到该目录；
% 3) 命令行运行：main_problem1
%
% 需要工具箱：Optimization Toolbox（intlinprog）
%
% 重要说明：
% - 题目没有给出"单块最小种植面积"和"每种作物最多分散到多少地块"的具体数值。
%   下面 cfg.minPlantAreaMu 与 cfg.maxPlotsPerCrop 是可调的管理参数，不是附件中的已知数据。
% - 代码默认用2023年"种植面积 × 对应亩产量"计算各"作物-季次"的预期销售量。
% - 销售价格区间采用区间中点作为确定性价格。
% - 智慧大棚第一季的亩产、成本、价格按附件2注释，自动沿用普通大棚第一季数据。

clc; clear; close all;

%% ======================= 第0步：基本设置 ==============================
if exist('intlinprog','file') ~= 2
    error('未检测到 intlinprog。请安装/启用 MATLAB Optimization Toolbox。');
end

file1 = firstExistingFile({'附件1(1).xlsx','附件1.xlsx'});
file2 = firstExistingFile({'附件2(1).xlsx','附件2.xlsx'});

years = 2024:2030;

% ---- 管理便利性参数（题目未给定，必须在论文中说明属于模型参数） ----
cfg.minPlantAreaMu   = 0.10;  % 单个"地块-作物-季次"一旦种植，最少种植面积/亩
cfg.maxPlotsPerCrop  = 10;    % 同一作物同一季最多分散到的地块数量
cfg.enableMinArea    = true;
cfg.enableDispersion = true;

% 求解器设置
cfg.relativeGapTolerance = 1e-4;

fprintf('============================================================\n');
fprintf('问题1：多周期混合整数线性规划模型\n');
fprintf('附件1：%s\n', file1);
fprintf('附件2：%s\n', file2);
fprintf('规划年份：%d-%d\n', years(1), years(end));
fprintf('============================================================\n\n');

%% ======================= 第1步：读取并预处理数据 ======================
data = loadProblemData(file1, file2);

fprintf('数据读取完成：\n');
fprintf('  地块/大棚数量：%d\n', numel(data.plotName));
fprintf('  作物数量：%d\n', numel(data.cropID));
fprintf('  豆类作物数量：%d\n', numel(data.beanCropIdx));
fprintf('  2023年总种植记录已用于销量基准与轮作边界。\n\n');

%% ======================= 第2步：构建统一 MILP 约束 ====================
model = buildMILPModel(data, years, cfg);

fprintf('MILP构建完成：\n');
fprintf('  可行"地块-作物-季次"组合数：%d\n', model.K);
fprintf('  销售分组（作物-季次）数：%d\n', model.G);
fprintf('  总变量数：%d\n', model.nVar);
fprintf('  其中0-1整数变量数：%d\n', numel(model.intcon));
fprintf('  不等式约束数：%d\n', size(model.Aineq,1));
fprintf('  等式约束数：%d\n\n', size(model.Aeq,1));

%% ======================= 第3步：求解情形1 =============================
% 超过预期销售量的部分完全滞销，gamma = 0
gamma1 = 0;
fprintf('\n================ 情形1：超额产量完全滞销 ================\n');
res1 = solveScenario(model, data, years, cfg, gamma1);

%% ======================= 第4步：求解情形2 =============================
% 超过预期销售量的部分按照正常价格50%%出售，gamma = 0.5
gamma2 = 0.5;
fprintf('\n================ 情形2：超额产量按50%%销售 ================\n');
res2 = solveScenario(model, data, years, cfg, gamma2);

%% ======================= 第5步：输出关键结果 ==========================
fprintf('\n============================================================\n');
fprintf('关键结果汇总\n');
fprintf('============================================================\n');
fprintf('情形1规划期总利润：%.2f 元\n', res1.totalProfit);
fprintf('情形2规划期总利润：%.2f 元\n', res2.totalProfit);
fprintf('两种情形总利润差：%.2f 元\n\n', res2.totalProfit-res1.totalProfit);

fprintf('情形1年度结果：\n');
disp(res1.annualSummary);
fprintf('情形2年度结果：\n');
disp(res2.annualSummary);

%% ======================= 第6步：写出结果 Excel ========================
% 当前没有附件3官方模板，因此这里输出"长表+汇总表"结构。
% 若之后上传附件3，可按官方模板的地块×作物布局进一步映射。
out1 = 'result1_1_model.xlsx';
out2 = 'result1_2_model.xlsx';
writeScenarioWorkbook(res1, out1, cfg);
writeScenarioWorkbook(res2, out2, cfg);

fprintf('结果文件已生成：\n');
fprintf('  %s\n', out1);
fprintf('  %s\n\n', out2);

%% ======================= 第7步：绘制必要图像 ==========================
plotComparison(res1, res2, years);

fprintf('图像已保存：\n');
fprintf('  fig1_annual_profit.png        年度利润比较\n');
fprintf('  fig2_overproduction.png       年度超额产量比较\n');
fprintf('  fig3_area_scenario1.png       情形1作物类别面积结构\n');
fprintf('  fig4_area_scenario2.png       情形2作物类别面积结构\n');
fprintf('\n全部计算完成。\n');

end

%% =====================================================================
%% 函数1：读取附件数据，并生成亩产/成本/价格矩阵、2023销量基准等
%% =====================================================================
function data = loadProblemData(file1, file2)

seasonNames = ["单季","第一季","第二季"];
S = numel(seasonNames);

%% 1.1 读取附件1：地块
rawLand = readcell(file1, 'Sheet', '乡村的现有耕地');
plotName = strings(0,1);
plotType = strings(0,1);
plotArea = zeros(0,1);

for r = 2:size(rawLand,1)
    nm = cleanString(rawLand{r,1});
    tp = cleanString(rawLand{r,2});
    ar = toNumber(rawLand{r,3});
    if strlength(nm)>0 && strlength(tp)>0 && isFiniteScalar(ar)
        plotName(end+1,1) = nm; %#ok<AGROW>
        plotType(end+1,1) = tp; %#ok<AGROW>
        plotArea(end+1,1) = ar; %#ok<AGROW>
    end
end

I = numel(plotName);

%% 1.2 读取附件1：作物
rawCrop = readcell(file1, 'Sheet', '乡村种植的农作物');
cropID   = zeros(0,1);
cropName = strings(0,1);
cropType = strings(0,1);

for r = 2:size(rawCrop,1)
    cid = toNumber(rawCrop{r,1});
    if isFiniteScalar(cid)
        cropID(end+1,1)   = cid; %#ok<AGROW>
        cropName(end+1,1) = cleanString(rawCrop{r,2}); %#ok<AGROW>
        cropType(end+1,1) = cleanString(rawCrop{r,3}); %#ok<AGROW>
    end
end

J = numel(cropID);
beanCropIdx = find(contains(cropType,"豆类"));

%% 1.3 读取附件2统计参数
rawStat = readcell(file2, 'Sheet', '2023年统计的相关数据');

yieldMat = nan(I,J,S);     % 亩产量/斤
costMat  = nan(I,J,S);     % 种植成本/(元/亩)
priceMat = nan(I,J,S);     % 销售价格/(元/斤)，区间中点

for r = 2:size(rawStat,1)
    seq = toNumber(rawStat{r,1});
    if ~isFiniteScalar(seq)
        continue;
    end

    cid = toNumber(rawStat{r,2});
    landTp = cleanString(rawStat{r,4});
    seasonStr = cleanString(rawStat{r,5});
    q = toNumber(rawStat{r,6});
    c = toNumber(rawStat{r,7});
    p = parsePriceMid(rawStat{r,8});

    j = find(cropID==cid,1);
    s = seasonToIndex(seasonStr);
    if isempty(j) || s==0 || ~isFiniteScalar(q) || ~isFiniteScalar(c) || ~isFiniteScalar(p)
        continue;
    end

    ii = find(plotType==landTp);
    yieldMat(ii,j,s) = q;
    costMat(ii,j,s)  = c;
    priceMat(ii,j,s) = p;
end

%% 1.4 智慧大棚第一季参数沿用普通大棚第一季
% 附件2注释明确：智慧大棚第一季可种蔬菜，亩产量、成本、价格均与普通大棚相同。
iOrd = find(plotType=="普通大棚",1);
iSmart = find(plotType=="智慧大棚");
if ~isempty(iOrd) && ~isempty(iSmart)
    for j = 1:J
        if isFiniteScalar(yieldMat(iOrd,j,2))
            yieldMat(iSmart,j,2) = yieldMat(iOrd,j,2);
            costMat(iSmart,j,2)  = costMat(iOrd,j,2);
            priceMat(iSmart,j,2) = priceMat(iOrd,j,2);
        end
    end
end

%% 1.5 读取附件2：2023实际种植情况
raw2023 = readcell(file2, 'Sheet', '2023年的农作物种植情况');

prevY = false(I,J,S);      % 2023是否在某地块某季种植过某作物
prevBeanArea = zeros(I,1); % 2023各地块豆类累计面积
expectedDemand = zeros(J,S); % 由2023产量估算的"作物-季次"预期销售量

currentPlot = "";
for r = 2:size(raw2023,1)
    pnm = cleanString(raw2023{r,1});
    if strlength(pnm)>0
        currentPlot = pnm;
    end

    cid = toNumber(raw2023{r,2});
    ar  = toNumber(raw2023{r,5});
    seasonStr = cleanString(raw2023{r,6});

    if strlength(currentPlot)==0 || ~isFiniteScalar(cid) || ~isFiniteScalar(ar)
        continue;
    end

    i = find(plotName==currentPlot,1);
    j = find(cropID==cid,1);
    s = seasonToIndex(seasonStr);
    if isempty(i) || isempty(j) || s==0
        continue;
    end

    q = yieldMat(i,j,s);
    if ~isFiniteScalar(q)
        warning('未找到2023记录对应的亩产参数：地块%s，作物%d，季次%s。该条记录未计入销量。', ...
            currentPlot, cid, seasonStr);
        continue;
    end

    prevY(i,j,s) = true;
    expectedDemand(j,s) = expectedDemand(j,s) + ar*q;

    if ismember(j, beanCropIdx)
        prevBeanArea(i) = prevBeanArea(i) + ar;
    end
end

%% 1.6 数据完整性检查
noFeasiblePlot = all(all(~finiteMask(yieldMat),3),2);
if any(noFeasiblePlot(:))
    warning('存在地块没有任何可种植组合，请检查附件数据。');
end

% 返回数据结构
data.plotName = plotName;
data.plotType = plotType;
data.plotArea = plotArea;
data.cropID = cropID;
data.cropName = cropName;
data.cropType = cropType;
data.beanCropIdx = beanCropIdx;
data.seasonNames = seasonNames;
data.yield = yieldMat;
data.cost = costMat;
data.price = priceMat;
data.prevY = prevY;
data.prevBeanArea = prevBeanArea;
data.expectedDemand = expectedDemand;

end

%% =====================================================================
%% 函数2：构建统一的MILP约束矩阵
%% =====================================================================
function model = buildMILPModel(data, years, cfg)

I = numel(data.plotName);
J = numel(data.cropID);
S = numel(data.seasonNames);
NY = numel(years);

%% 2.1 只为"有统计参数的可行地块-作物-季次组合"建立变量
feasible = finiteMask(data.yield) & finiteMask(data.cost) & finiteMask(data.price);
linFeas = find(feasible);
[comboPlot, comboCrop, comboSeason] = ind2sub(size(feasible), linFeas);

K = numel(linFeas);
comboYield = data.yield(linFeas);
comboCost  = data.cost(linFeas);
comboPrice = data.price(linFeas);

% 快速查找某(i,j,s)对应的combo编号
comboMap = zeros(I,J,S);
comboMap(linFeas) = (1:K)';

%% 2.2 建立"作物-季次"销售分组
pair = [comboCrop, comboSeason];
[groupPair,~,comboGroup] = unique(pair,'rows');
G = size(groupPair,1);

groupPrice = zeros(G,1);
groupDemand = zeros(G,1);
for g = 1:G
    ks = find(comboGroup==g);
    prices = comboPrice(ks);
    groupPrice(g) = prices(1);
    if max(prices)-min(prices) > 1e-8
        warning('作物%d-季次%s在不同土地上的价格不一致，当前销售分组采用第一条价格。', ...
            data.cropID(groupPair(g,1)), data.seasonNames(groupPair(g,2)));
    end
    groupDemand(g) = data.expectedDemand(groupPair(g,1), groupPair(g,2));
end

%% 2.3 变量编号
% x(k,t)：组合k在年份t的种植面积（连续）
% y(k,t)：组合k在年份t是否种植（0-1）
% z(g,t)：正常价格销售量（连续）
% h(g,t)：超额产量（连续）
% m(w,t)：水浇地种植模式，1=单季水稻，0=两季蔬菜（0-1）

offset = 0;
idxX = reshape(offset+(1:K*NY), K, NY); offset = offset + K*NY;
idxUse = reshape(offset+(1:K*NY), K, NY); offset = offset + K*NY;
idxZ = reshape(offset+(1:G*NY), G, NY); offset = offset + G*NY;
idxH = reshape(offset+(1:G*NY), G, NY); offset = offset + G*NY;

waterPlots = find(data.plotType=="水浇地");
NW = numel(waterPlots);
idxMode = reshape(offset+(1:NW*NY), NW, NY); offset = offset + NW*NY;

nVar = offset;

%% 2.4 变量上下界
lb = zeros(nVar,1);
ub = inf(nVar,1);

areaPerCombo = data.plotArea(comboPlot);
for t = 1:NY
    ub(idxX(:,t)) = areaPerCombo;
    ub(idxUse(:,t)) = 1;
    ub(idxZ(:,t)) = groupDemand;
end
if NW>0
    ub(idxMode(:)) = 1;
end

%% 2.5 用cell暂存每一行约束，最后统一转为稀疏矩阵
ineqCols = cell(0,1); ineqVals = cell(0,1); bineq = zeros(0,1);
eqCols   = cell(0,1); eqVals   = cell(0,1); beq   = zeros(0,1);

%% (A) 产量 = 正常销售量 + 超额产量
for t = 1:NY
    for g = 1:G
        ks = find(comboGroup==g);
        cols = [idxX(ks,t)' idxZ(g,t) idxH(g,t)];
        vals = [comboYield(ks)' -1 -1];
        eqCols{end+1,1} = cols; %#ok<AGROW>
        eqVals{end+1,1} = vals; %#ok<AGROW>
        beq(end+1,1) = 0; %#ok<AGROW>
    end
end

%% (B) 每个地块、每个季次的面积约束：sum x <= A_i
for t = 1:NY
    for i = 1:I
        for s = 1:S
            ks = find(comboPlot==i & comboSeason==s);
            if isempty(ks), continue; end
            ineqCols{end+1,1} = idxX(ks,t)'; %#ok<AGROW>
            ineqVals{end+1,1} = ones(1,numel(ks)); %#ok<AGROW>
            bineq(end+1,1) = data.plotArea(i); %#ok<AGROW>
        end
    end
end

%% (C) 种植面积与0-1变量关联
% x <= A_i*y；若启用最小种植面积，则 x >= L*y
for t = 1:NY
    for k = 1:K
        Ai = data.plotArea(comboPlot(k));

        % x - A*y <= 0
        ineqCols{end+1,1} = [idxX(k,t), idxUse(k,t)]; %#ok<AGROW>
        ineqVals{end+1,1} = [1, -Ai]; %#ok<AGROW>
        bineq(end+1,1) = 0; %#ok<AGROW>

        if cfg.enableMinArea && cfg.minPlantAreaMu>0
            L = min(cfg.minPlantAreaMu, Ai);
            % -x + L*y <= 0  等价于 x >= L*y
            ineqCols{end+1,1} = [idxX(k,t), idxUse(k,t)]; %#ok<AGROW>
            ineqVals{end+1,1} = [-1, L]; %#ok<AGROW>
            bineq(end+1,1) = 0; %#ok<AGROW>
        end
    end
end

%% (D) 防止同一作物同一季过度分散
if cfg.enableDispersion && isFiniteScalar(cfg.maxPlotsPerCrop)
    for t = 1:NY
        for g = 1:G
            ks = find(comboGroup==g);
            ineqCols{end+1,1} = idxUse(ks,t)'; %#ok<AGROW>
            ineqVals{end+1,1} = ones(1,numel(ks)); %#ok<AGROW>
            bineq(end+1,1) = cfg.maxPlotsPerCrop; %#ok<AGROW>
        end
    end
end

%% (E) 水浇地模式：单季水稻 或 两季蔬菜
jRice = find(data.cropID==16,1);
for w = 1:NW
    i = waterPlots(w);
    Ai = data.plotArea(i);

    kRice = 0;
    if ~isempty(jRice)
        kRice = comboMap(i,jRice,1);
    end
    ksV1 = find(comboPlot==i & comboSeason==2); % 水浇地第一季蔬菜
    ksV2 = find(comboPlot==i & comboSeason==3); % 水浇地第二季三种蔬菜

    for t = 1:NY
        m = idxMode(w,t);

        if kRice>0
            % x_rice <= A*m
            ineqCols{end+1,1} = [idxX(kRice,t),m]; %#ok<AGROW>
            ineqVals{end+1,1} = [1,-Ai]; %#ok<AGROW>
            bineq(end+1,1) = 0; %#ok<AGROW>
        end

        if ~isempty(ksV1)
            % sum x_veg1 <= A*(1-m) -> sum x + A*m <= A
            ineqCols{end+1,1} = [idxX(ksV1,t)' m]; %#ok<AGROW>
            ineqVals{end+1,1} = [ones(1,numel(ksV1)) Ai]; %#ok<AGROW>
            bineq(end+1,1) = Ai; %#ok<AGROW>
        end

        if ~isempty(ksV2)
            % sum x_veg2 <= A*(1-m)
            ineqCols{end+1,1} = [idxX(ksV2,t)' m]; %#ok<AGROW>
            ineqVals{end+1,1} = [ones(1,numel(ksV2)) Ai]; %#ok<AGROW>
            bineq(end+1,1) = Ai; %#ok<AGROW>

            % 第二季只能从大白菜、白萝卜、红萝卜中选择一种
            ineqCols{end+1,1} = idxUse(ksV2,t)'; %#ok<AGROW>
            ineqVals{end+1,1} = ones(1,numel(ksV2)); %#ok<AGROW>
            bineq(end+1,1) = 1; %#ok<AGROW>
        end
    end
end

%% (F) 重茬约束1：同一地块、同一作物、同一季次不能连续两年种植
for k = 1:K
    for t = 1:NY-1
        ineqCols{end+1,1} = [idxUse(k,t), idxUse(k,t+1)]; %#ok<AGROW>
        ineqVals{end+1,1} = [1,1]; %#ok<AGROW>
        bineq(end+1,1) = 1; %#ok<AGROW>
    end
end

%% (G) 2023 -> 2024 重茬边界
for k = 1:K
    i = comboPlot(k); j = comboCrop(k); s = comboSeason(k);
    if data.prevY(i,j,s)
        ub(idxUse(k,1)) = 0;
    end
end

%% (H) 智慧大棚两季均可种相同蔬菜：补充相邻季重茬约束
smartPlots = find(data.plotType=="智慧大棚");
for ii = 1:numel(smartPlots)
    i = smartPlots(ii);
    for j = 1:J
        k1 = comboMap(i,j,2); % 第一季
        k2 = comboMap(i,j,3); % 第二季
        if k1==0 || k2==0
            continue;
        end

        % 同一年第一季与第二季不能连续种相同作物
        for t = 1:NY
            ineqCols{end+1,1} = [idxUse(k1,t),idxUse(k2,t)]; %#ok<AGROW>
            ineqVals{end+1,1} = [1,1]; %#ok<AGROW>
            bineq(end+1,1) = 1; %#ok<AGROW>
        end

        % 当年第二季与下一年第一季也不能相同
        for t = 1:NY-1
            ineqCols{end+1,1} = [idxUse(k2,t),idxUse(k1,t+1)]; %#ok<AGROW>
            ineqVals{end+1,1} = [1,1]; %#ok<AGROW>
            bineq(end+1,1) = 1; %#ok<AGROW>
        end

        % 2023第二季 -> 2024第一季边界
        if data.prevY(i,j,3)
            ub(idxUse(k1,1)) = 0;
        end
    end
end

%% (I) 三年内至少种植一次豆类：采用三年累计豆类面积 >= 地块面积
for i = 1:I
    beanKs = find(comboPlot==i & ismember(comboCrop,data.beanCropIdx));
    if isempty(beanKs)
        warning('地块%s没有可行豆类作物，三年豆类约束无法建立。',data.plotName(i));
        continue;
    end

    Ai = data.plotArea(i);

    % 第一个窗口：2023-2025，其中2023豆类面积已知
    if NY >= 2
        colsMat = idxX(beanKs,1:2);
        cols = colsMat(:)';
        if data.prevBeanArea(i) < Ai-1e-9
            ineqCols{end+1,1} = cols; %#ok<AGROW>
            ineqVals{end+1,1} = -ones(1,numel(cols)); %#ok<AGROW>
            bineq(end+1,1) = data.prevBeanArea(i)-Ai; %#ok<AGROW>
        end
    end

    % 后续完整三年窗口：2024-2026,...,2028-2030
    for t0 = 1:NY-2
        colsMat = idxX(beanKs,t0:t0+2);
        cols = colsMat(:)';
        ineqCols{end+1,1} = cols; %#ok<AGROW>
        ineqVals{end+1,1} = -ones(1,numel(cols)); %#ok<AGROW>
        bineq(end+1,1) = -Ai; %#ok<AGROW>
    end
end

%% 2.6 转为稀疏矩阵
Aineq = rowsToSparse(ineqCols,ineqVals,nVar);
Aeq   = rowsToSparse(eqCols,eqVals,nVar);

%% 2.7 整数变量
intcon = [idxUse(:); idxMode(:)];
intcon = unique(intcon);

%% 返回模型
model.K = K;
model.G = G;
model.NY = NY;
model.nVar = nVar;
model.comboPlot = comboPlot;
model.comboCrop = comboCrop;
model.comboSeason = comboSeason;
model.comboYield = comboYield;
model.comboCost = comboCost;
model.comboPrice = comboPrice;
model.comboGroup = comboGroup;
model.comboMap = comboMap;
model.groupPair = groupPair;
model.groupPrice = groupPrice;
model.groupDemand = groupDemand;
model.waterPlots = waterPlots;
model.idxX = idxX;
model.idxUse = idxUse;
model.idxZ = idxZ;
model.idxH = idxH;
model.idxMode = idxMode;
model.Aineq = Aineq;
model.bineq = bineq;
model.Aeq = Aeq;
model.beq = beq;
model.lb = lb;
model.ub = ub;
model.intcon = intcon;

end

%% =====================================================================
%% 函数3：求解某一种超额销售情形
%% =====================================================================
function result = solveScenario(model, data, years, cfg, gamma)

% intlinprog求最小值，因此：
% -利润 = 种植成本 - 正常销售收入 - gamma*超额销售收入
f = zeros(model.nVar,1);
for t = 1:model.NY
    f(model.idxX(:,t)) = model.comboCost;
    f(model.idxZ(:,t)) = -model.groupPrice;
    f(model.idxH(:,t)) = -gamma*model.groupPrice;
end

opts = optimoptions('intlinprog', ...
    'Display','iter', ...
    'RelativeGapTolerance',cfg.relativeGapTolerance);

[xsol,fval,exitflag,output] = intlinprog( ...
    f, model.intcon, ...
    model.Aineq, model.bineq, ...
    model.Aeq, model.beq, ...
    model.lb, model.ub, opts);

if isempty(xsol)
    error('该情形未获得可行解。请首先检查管理参数 minPlantAreaMu 和 maxPlotsPerCrop 是否过严。');
end
if exitflag <= 0
    warning('intlinprog退出标志为%d。已获得当前解，但建议查看求解器输出并确认最优性。',exitflag);
end

result = decodeSolution(xsol, -fval, exitflag, output, model, data, years, gamma);

fprintf('求解完成：\n');
fprintf('  exitflag = %d\n', exitflag);
fprintf('  规划期总利润 = %.2f 元\n', result.totalProfit);
if isfield(output,'relativegap')
    fprintf('  相对最优间隙 = %.6g\n', output.relativegap);
end

end

%% =====================================================================
%% 函数4：将求解向量还原成可读结果
%% =====================================================================
function result = decodeSolution(xsol, totalProfit, exitflag, output, model, data, years, gamma)

X = xsol(model.idxX);
Z = xsol(model.idxZ);
H = xsol(model.idxH);

NY = numel(years);
J = numel(data.cropID);

%% 4.1 年度汇总
Revenue = zeros(NY,1);
PlantCost = zeros(NY,1);
Profit = zeros(NY,1);
TotalProduction = zeros(NY,1);
NormalSales = zeros(NY,1);
OverProduction = zeros(NY,1);

for t = 1:NY
    Revenue(t) = sum(model.groupPrice .* (Z(:,t) + gamma*H(:,t)));
    PlantCost(t) = sum(model.comboCost .* X(:,t));
    Profit(t) = Revenue(t)-PlantCost(t);
    TotalProduction(t) = sum(model.comboYield .* X(:,t));
    NormalSales(t) = sum(Z(:,t));
    OverProduction(t) = sum(H(:,t));
end

annualSummary = table(years',Revenue,PlantCost,Profit,TotalProduction,NormalSales,OverProduction, ...
    'VariableNames',{'Year','RevenueYuan','PlantCostYuan','ProfitYuan', ...
    'TotalProductionJin','NormalSalesJin','OverProductionJin'});

%% 4.2 生成非零种植方案长表
tol = 1e-6;
lin = find(X>tol);
[kList,tList] = ind2sub(size(X),lin);

AreaMu = X(lin);
Year = years(tList)';
Plot = data.plotName(model.comboPlot(kList));
PlotType = data.plotType(model.comboPlot(kList));
Season = data.seasonNames(model.comboSeason(kList))';
CropID = data.cropID(model.comboCrop(kList));
CropName = data.cropName(model.comboCrop(kList));
YieldPerMu = model.comboYield(kList);
ProductionJin = AreaMu .* YieldPerMu;
CostPerMu = model.comboCost(kList);
PlantCostYuan = AreaMu .* CostPerMu;
PriceYuanPerJin = model.comboPrice(kList);

plantingPlan = table(Year,Plot,PlotType,Season,CropID,CropName,AreaMu,YieldPerMu, ...
    ProductionJin,CostPerMu,PlantCostYuan,PriceYuanPerJin);
plantingPlan = sortrows(plantingPlan,{'Year','Plot','Season','CropID'});

%% 4.3 各作物各年度总种植面积
cropArea = zeros(J,NY);
for j = 1:J
    mask = (model.comboCrop==j);
    cropArea(j,:) = sum(X(mask,:),1);
end

cropAreaTable = table(data.cropID,data.cropName, ...
    'VariableNames',{'CropID','CropName'});
for t = 1:NY
    cropAreaTable.(sprintf('Y%d',years(t))) = cropArea(:,t);
end

%% 4.4 作物类别面积：粮食、蔬菜、食用菌
classNames = ["粮食","蔬菜","食用菌"];
classArea = zeros(3,NY);
comboType = data.cropType(model.comboCrop);
for t = 1:NY
    classArea(1,t) = sum(X(contains(comboType,"粮食"),t));
    classArea(2,t) = sum(X(contains(comboType,"蔬菜"),t));
    classArea(3,t) = sum(X(contains(comboType,"食用菌"),t));
end

%% 4.5 销售分组明细
G = model.G;
gCropIdx = model.groupPair(:,1);
gSeasonIdx = model.groupPair(:,2);
DemandCropID = data.cropID(gCropIdx);
DemandCropName = data.cropName(gCropIdx);
DemandSeason = data.seasonNames(gSeasonIdx)';
ExpectedSalesJin = model.groupDemand;
SalesPriceYuanPerJin = model.groupPrice;

demandTable = table(DemandCropID,DemandCropName,DemandSeason,ExpectedSalesJin,SalesPriceYuanPerJin, ...
    'VariableNames',{'CropID','CropName','Season','ExpectedSalesJin','PriceYuanPerJin'});

%% 4.6 各销售分组逐年正常/超额销量
salesDetail = table(DemandCropID,DemandCropName,DemandSeason, ...
    'VariableNames',{'CropID','CropName','Season'});
for t = 1:NY
    salesDetail.(sprintf('Normal_%d',years(t))) = Z(:,t);
    salesDetail.(sprintf('Excess_%d',years(t))) = H(:,t);
end

result.gamma = gamma;
result.totalProfit = totalProfit;
result.exitflag = exitflag;
result.output = output;
result.X = X;
result.Z = Z;
result.H = H;
result.annualSummary = annualSummary;
result.plantingPlan = plantingPlan;
result.cropAreaTable = cropAreaTable;
result.classNames = classNames;
result.classArea = classArea;
result.demandTable = demandTable;
result.salesDetail = salesDetail;

end

%% =====================================================================
%% 函数5：写出Excel结果
%% =====================================================================
function writeScenarioWorkbook(result, filename, cfg)

if isfile(filename)
    delete(filename);
end

writetable(result.plantingPlan, filename, 'Sheet','PlantingPlan');
writetable(result.annualSummary, filename, 'Sheet','AnnualSummary');
writetable(result.cropAreaTable, filename, 'Sheet','CropArea');
writetable(result.demandTable, filename, 'Sheet','ExpectedDemand');
writetable(result.salesDetail, filename, 'Sheet','SalesDetail');

% 模型参数表，明确哪些值是人为可调管理参数
Parameter = ["gamma";"minPlantAreaMu";"maxPlotsPerCrop";"enableMinArea";"enableDispersion"];
Value = [string(result.gamma); string(cfg.minPlantAreaMu); string(cfg.maxPlotsPerCrop); ...
    string(cfg.enableMinArea); string(cfg.enableDispersion)];
Source = ["题目情形参数";"模型可调参数（题目未给具体值）";"模型可调参数（题目未给具体值）"; ...
    "模型设置";"模型设置"];
paramTable = table(Parameter,Value,Source);
writetable(paramTable, filename, 'Sheet','ModelParameters');

end

%% =====================================================================
%% 函数6：绘图
%% =====================================================================
function plotComparison(res1, res2, years)

% 图1：年度利润比较
figure('Name','年度利润比较');
bar(years,[res1.annualSummary.ProfitYuan,res2.annualSummary.ProfitYuan],'grouped');
xlabel('年份'); ylabel('利润 / 元');
title('两种超额销售情形下的年度利润比较');
legend('超额部分滞销','超额部分50%价格销售','Location','best');
grid on;
saveas(gcf,'fig1_annual_profit.png');

% 图2：年度超额产量比较
figure('Name','年度超额产量比较');
bar(years,[res1.annualSummary.OverProductionJin,res2.annualSummary.OverProductionJin],'grouped');
xlabel('年份'); ylabel('超额产量 / 斤');
title('两种情形下的年度超额产量比较');
legend('超额部分滞销','超额部分50%价格销售','Location','best');
grid on;
saveas(gcf,'fig2_overproduction.png');

% 图3：情形1面积结构
figure('Name','情形1种植面积结构');
bar(years,res1.classArea','stacked');
xlabel('年份'); ylabel('累计种植面积 / 亩');
title('情形1：各类作物年度种植面积结构');
legend(cellstr(res1.classNames),'Location','best');
grid on;
saveas(gcf,'fig3_area_scenario1.png');

% 图4：情形2面积结构
figure('Name','情形2种植面积结构');
bar(years,res2.classArea','stacked');
xlabel('年份'); ylabel('累计种植面积 / 亩');
title('情形2：各类作物年度种植面积结构');
legend(cellstr(res2.classNames),'Location','best');
grid on;
saveas(gcf,'fig4_area_scenario2.png');

end

%% =====================================================================
%% 工具函数：cell行约束转稀疏矩阵
%% =====================================================================
function A = rowsToSparse(colsCell, valsCell, nVar)

nRows = numel(colsCell);
if nRows==0
    A = sparse(0,nVar);
    return;
end

nnzTotal = 0;
for r = 1:nRows
    nnzTotal = nnzTotal + numel(colsCell{r});
end

II = zeros(nnzTotal,1);
JJ = zeros(nnzTotal,1);
VV = zeros(nnzTotal,1);

pos = 1;
for r = 1:nRows
    cols = colsCell{r}(:);
    vals = valsCell{r}(:);
    n = numel(cols);
    idx = pos:pos+n-1;
    II(idx) = r;
    JJ(idx) = cols;
    VV(idx) = vals;
    pos = pos+n;
end

A = sparse(II,JJ,VV,nRows,nVar);

end

%% =====================================================================
%% 工具函数：找到存在的输入文件
%% =====================================================================
function f = firstExistingFile(candidates)
for k = 1:numel(candidates)
    if isfile(candidates{k})
        f = candidates{k};
        return;
    end
end
error('未找到输入文件。请确保附件1和附件2与main_problem1.m位于同一文件夹。');
end

%% =====================================================================
%% 工具函数：清洗字符串
%% =====================================================================
function s = cleanString(x)
if isempty(x)
    s = "";
    return;
end
if isnumeric(x)
    if isempty(x) || any(isnan(x))
        s = "";
    else
        s = strtrim(string(x));
    end
    return;
end
try
    s = strtrim(string(x));
    if ismissing(s)
        s = "";
    end
catch
    s = "";
end
end

%% =====================================================================
%% 工具函数：转换数值
%% =====================================================================
function v = toNumber(x)
v = NaN;
if isempty(x)
    return;
end
if isnumeric(x) && isscalar(x)
    if isFiniteScalar(x)
        v = double(x);
    end
    return;
end
try
    tmp = str2double(strtrim(string(x)));
    if isFiniteScalar(tmp)
        v = tmp;
    end
catch
end
end

%% =====================================================================
%% 工具函数：价格区间取中点
%% =====================================================================
function p = parsePriceMid(x)
p = NaN;
s = cleanString(x);
if strlength(s)==0
    return;
end
nums = regexp(char(s),'[0-9]+\.?[0-9]*','match');
if isempty(nums)
    return;
elseif numel(nums)==1
    p = str2double(nums{1});
else
    p = (str2double(nums{1}) + str2double(nums{2}))/2;
end
end

%% =====================================================================
%% 工具函数：有限数判断（兼容不同MATLAB版本）
%% =====================================================================
function tf = isFiniteScalar(x)
tf = isnumeric(x) && isscalar(x) && ~isnan(x) && ~isinf(x);
end

function tf = finiteMask(x)
tf = ~isnan(x) & ~isinf(x);
end

%% =====================================================================
%% 工具函数：季次文字 -> 1/2/3
%% =====================================================================
function s = seasonToIndex(seasonStr)
seasonStr = cleanString(seasonStr);
if seasonStr=="单季"
    s = 1;
elseif seasonStr=="第一季"
    s = 2;
elseif seasonStr=="第二季"
    s = 3;
else
    s = 0;
end
end
