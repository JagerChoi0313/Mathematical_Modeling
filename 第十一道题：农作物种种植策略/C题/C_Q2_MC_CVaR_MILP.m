function C_Q2_MC_CVaR_MILP()
% C_Q2_MC_CVaR_MILP
% ============================================================
% 2024 高教社杯 C题 问题二
% 基于“蒙特卡洛情景模拟 + CVaR风险控制 + 多时期MILP”的种植优化
%
% 模型主线：
%   1) 读取2023年地块、作物、亩产量、成本、价格、种植历史；
%   2) 由2023年产量计算预期销售量基准 D_j；
%   3) 蒙特卡洛生成2024-2030年不同未来情景：
%        - 小麦、玉米销售量：年增长率 U(5%,10%)，逐年递推；
%        - 其他作物销售量：相对2023年 U(-5%,5%)；
%        - 亩产量：相对基准 U(-10%,10%)；
%        - 种植成本：每年确定增长5%；
%        - 粮食价格：保持稳定；
%        - 蔬菜价格：每年确定增长5%；
%        - 食用菌(除羊肚菌)：年降幅 U(1%,5%)，逐年递推；
%        - 羊肚菌：每年固定下降5%。
%   4) 所有情景共用一套种植决策 x,y,z；
%   5) 每个情景单独建立正常销售量 u；
%   6) 目标：最大化“情景平均利润 - lambda*CVaR(损失)”；
%   7) 沿用问题一的土地适种、面积、重茬、三年豆类轮作、
%      最小种植面积、种植集中度等约束；
%   8) 用 intlinprog 求解，并写入 result2 模板；
%   9) 输出风险指标、年度期望利润，并绘制图像。
%
% ------------------------------------------------------------
% 重要口径
% ------------------------------------------------------------
% A. 本程序与前面已确定的数学模型保持一致：
%    超过情景预期销售量 D_jt 的部分不计销售收入（视为滞销）。
%
% B. D_j 的基准口径仍与问题一相同：
%    先用2023年实际种植面积×亩产量得到作物全年总产量，
%    再将情景中的 D_jt 作为该作物每一个可种季的正常销售上限。
%    如果后续论文改成“分季销售量”，代码也必须同步修改。
%
% C. 下列参数是模型设定值，不是题目直接给出的“最优参数”：
%       K = 30, beta = 0.90, lambdaRisk = 0.20
%    它们只是为了使当前程序能够直接运行。
%    若最终论文要说明参数选取依据，建议后续实际比较多组参数，
%    再根据真实计算结果决定最终值。
%
% ------------------------------------------------------------
% 运行要求
% ------------------------------------------------------------
% 1) MATLAB Optimization Toolbox（需要 intlinprog）
% 2) 将本文件与以下Excel放在同一文件夹：
%      附件1*.xlsx
%      附件2*.xlsx
%      result2(1).xlsx 或 result2.xlsx
%
% 输出：
%   result2_MATLAB_CVaR.xlsx
%   Q2_风险分析.xlsx
%   Q2_figures\*.png
% ============================================================

clc;
close all;

%% ============================================================
% Step 0. 文件路径与模型参数
% =============================================================
dataDir = fileparts(mfilename('fullpath'));
if isempty(dataDir)
    dataDir = pwd;
end

% 自动查找文件，避免本地文件名与上传时文件名不同
file1 = findOneFile(dataDir, {'附件1(20260827-120155).xlsx','附件1.xlsx','附件1*.xlsx'}, {});
file2 = findOneFile(dataDir, {'附件2(20260827-120154).xlsx','附件2.xlsx','附件2*.xlsx'}, {});
template2 = findOneFile(dataDir, {'result2(1).xlsx','result2.xlsx','result2*.xlsx'}, ...
    {'result2_MATLAB_CVaR.xlsx'});

outResult = fullfile(dataDir,'result2_MATLAB_CVaR.xlsx');
outAnalysis = fullfile(dataDir,'Q2_风险分析.xlsx');
figDir = fullfile(dataDir,'Q2_figures');
if ~exist(figDir,'dir')
    mkdir(figDir);
end

years = 2024:2030;
nT = numel(years);
nS = 2;

% ---------------- 蒙特卡洛与CVaR参数 ----------------
K = 30;                    % 情景数；30情景适合作为先跑通模型的规模
beta = 0.90;               % CVaR置信水平；30情景下尾部约对应3个最差情景
lambdaRisk = 0.20;         % 风险权重；仅为当前可运行的工作参数
randomSeed = 2024;         % 固定随机种子，保证结果可重复

% ---------------- 问题一沿用的管理参数 ----------------
minAreaRatio = 0.10;       % 一旦种植，面积至少占该地块10%
maxPlotsPerCropSeason = 6; % 同一种作物同年同季最多分布6块地
tol = 1e-7;

% ---------------- MILP求解设置 ----------------
maxSolveTime = 900;        % 最大求解时间（秒）
relativeGap = 0.02;        % 允许2%相对最优间隙

fprintf('============================================================\n');
fprintf('2024 C题 问题二：Monte Carlo + CVaR + MILP\n');
fprintf('============================================================\n');
fprintf('附件1：%s\n',file1);
fprintf('附件2：%s\n',file2);
fprintf('result2模板：%s\n',template2);
fprintf('情景数 K = %d\n',K);
fprintf('CVaR beta = %.2f\n',beta);
fprintf('风险权重 lambda = %.3f\n',lambdaRisk);
fprintf('随机种子 = %d\n',randomSeed);
fprintf('最小种植面积比例 = %.1f%%\n',100*minAreaRatio);
fprintf('单作物单季最大地块数 = %d\n',maxPlotsPerCropSeason);
fprintf('============================================================\n\n');

%% ============================================================
% Step 1. 读取附件1：地块与作物基本信息
% =============================================================
landRaw = readcell(file1,'Sheet','乡村的现有耕地');
cropRaw = readcell(file1,'Sheet','乡村种植的农作物');

% 地块
landRows = landRaw(2:end,:);
landNameAll = strings(size(landRows,1),1);
for r = 1:size(landRows,1)
    landNameAll(r) = cleanString(landRows{r,1});
end
validLand = strlength(landNameAll)>0;
landRows = landRows(validLand,:);

nI = size(landRows,1);
plotNames = strings(nI,1);
plotTypes = strings(nI,1);
plotArea = zeros(nI,1);

for i = 1:nI
    plotNames(i) = cleanString(landRows{i,1});
    plotTypes(i) = cleanString(landRows{i,2});
    plotArea(i) = cellToDouble(landRows{i,3});
end

% 作物
cropRows = cropRaw(2:end,:);
cropIdAll = nan(size(cropRows,1),1);
for r = 1:size(cropRows,1)
    cropIdAll(r) = cellToDouble(cropRows{r,1});
end
validCrop = ~isnan(cropIdAll);
cropRows = cropRows(validCrop,:);
cropIds = cropIdAll(validCrop);

nJ = numel(cropIds);
cropNames = strings(nJ,1);
cropTypes = strings(nJ,1);

for j = 1:nJ
    cropNames(j) = cleanString(cropRows{j,2});
    cropTypes(j) = cleanString(cropRows{j,3});
end

assert(nI==54,'地块数量应为54，当前读到%d。',nI);
assert(nJ==41,'作物数量应为41，当前读到%d。',nJ);

fprintf('[Step 1] 读取完成：%d个地块，%d种作物。\n',nI,nJ);

%% ============================================================
% Step 2. 读取附件2：构造2023基准亩产量、成本、价格
% =============================================================
plantRaw = readcell(file2,'Sheet','2023年的农作物种植情况');
statRaw  = readcell(file2,'Sheet','2023年统计的相关数据');

% 基准数组
Yield0 = nan(nI,nJ,nS);      % 2023亩产量，斤/亩
Cost0  = nan(nI,nJ,nS);      % 2023成本，元/亩
PriceCell0 = nan(nI,nJ,nS);  % 2023价格区间中点，元/斤

statRows = statRaw(2:end,:);

for r = 1:size(statRows,1)
    cropId = cellToDouble(statRows{r,2});
    if isnan(cropId)
        continue;
    end

    j = find(cropIds==cropId,1);
    if isempty(j)
        continue;
    end

    landType = cleanString(statRows{r,4});
    s = seasonCode(statRows{r,5});
    if s==0
        continue;
    end

    yieldVal = cellToDouble(statRows{r,6});
    costVal  = cellToDouble(statRows{r,7});
    priceVal = priceMidpoint(statRows{r,8});

    idxPlot = find(plotTypes==landType);
    for kk = 1:numel(idxPlot)
        i = idxPlot(kk);
        Yield0(i,j,s) = yieldVal;
        Cost0(i,j,s) = costVal;
        PriceCell0(i,j,s) = priceVal;
    end
end

% 智慧大棚第一季：按附件说明采用普通大棚第一季参数
iOrd = find(plotTypes=="普通大棚",1);
smartPlots = find(plotTypes=="智慧大棚");
for j = 17:34
    for kk = 1:numel(smartPlots)
        i = smartPlots(kk);
        Yield0(i,j,1) = Yield0(iOrd,j,1);
        Cost0(i,j,1) = Cost0(iOrd,j,1);
        PriceCell0(i,j,1) = PriceCell0(iOrd,j,1);
    end
end

% 可行的“地块-作物-季节”组合
feasible = isfinite(Yield0) & isfinite(Cost0) & isfinite(PriceCell0);
[fi,fj,fs] = ind2sub([nI,nJ,nS],find(feasible));
nCell = numel(fi);

% 每个作物-季节的2023代表价格
Price0 = nan(nJ,nS);
for j = 1:nJ
    for s = 1:nS
        vals = PriceCell0(:,j,s);
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            Price0(j,s) = mean(vals);
        end
    end
end

pairMask = squeeze(any(feasible,1));   % nJ×nS
[pairJ,pairS] = find(pairMask);
nPair = numel(pairJ);

fprintf('[Step 2] 基准参数构造完成：每年可行种植单元 = %d，作物-季节组合 = %d。\n', ...
    nCell,nPair);

%% ============================================================
% Step 3. 由2023种植情况计算销售量基准D_j，并保存历史轮作状态
% =============================================================
histX = zeros(nI,nJ,nS);
expectedSales0 = zeros(nJ,1);

plantRows = plantRaw(2:end,:);
currentPlot = "";

for r = 1:size(plantRows,1)
    pName = cleanString(plantRows{r,1});
    if strlength(pName)>0
        currentPlot = pName;
    end

    cropId = cellToDouble(plantRows{r,2});
    areaVal = cellToDouble(plantRows{r,5});

    if strlength(currentPlot)==0 || isnan(cropId) || isnan(areaVal)
        continue;
    end

    i = find(plotNames==currentPlot,1);
    j = find(cropIds==cropId,1);
    s = seasonCode(plantRows{r,6});

    if isempty(i) || isempty(j) || s==0
        continue;
    end

    if ~isfinite(Yield0(i,j,s))
        error('2023历史种植参数缺失：地块%s，作物%d，第%d季。', ...
            currentPlot,cropId,s);
    end

    histX(i,j,s) = histX(i,j,s) + areaVal;
    expectedSales0(j) = expectedSales0(j) + ...
        areaVal*Yield0(i,j,s);
end

fprintf('[Step 3] 2023销售量基准计算完成。\n');
fprintf('         小麦D0 = %.0f斤，玉米D0 = %.0f斤，水稻D0 = %.0f斤。\n', ...
    expectedSales0(6),expectedSales0(7),expectedSales0(16));

%% ============================================================
% Step 4. 蒙特卡洛生成2024-2030年情景参数
% =============================================================
rng(randomSeed,'twister');

% DScenario(j,t,k)：预期销售量
DScenario = zeros(nJ,nT,K);

% YieldScale(j,t,k)：相对于2023亩产量的乘数
YieldScale = zeros(nJ,nT,K);

% PriceScenario(j,s,t,k)：销售价格
PriceScenario = nan(nJ,nS,nT,K);

% CostT(i,j,s,t)：成本按照每年5%确定增长
CostT = nan(nI,nJ,nS,nT);
for tt = 1:nT
    factorCost = 1.05^(years(tt)-2023);
    CostT(:,:,:,tt) = Cost0 .* factorCost;
end

% 生成情景
for k = 1:K

    % ---------- 4.1 预期销售量 ----------
    % 小麦、玉米：5%-10%逐年增长
    for j = [6,7]
        prevD = expectedSales0(j);
        for tt = 1:nT
            growthRate = 0.05 + 0.05*rand;
            prevD = prevD*(1+growthRate);
            DScenario(j,tt,k) = prevD;
        end
    end

    % 其他作物：每年相对2023年±5%
    otherCrops = setdiff(1:nJ,[6,7]);
    for j = otherCrops
        for tt = 1:nT
            epsD = -0.05 + 0.10*rand;
            DScenario(j,tt,k) = expectedSales0(j)*(1+epsD);
        end
    end

    % ---------- 4.2 亩产量 ----------
    % 每个作物每年在2023基准上±10%；
    % 同一作物同一年在不同土地类型上使用同一个相对波动系数，
    % 保留各土地之间原本的亩产量差异。
    for tt = 1:nT
        YieldScale(:,tt,k) = 0.90 + 0.20*rand(nJ,1);
    end

    % ---------- 4.3 销售价格 ----------
    % 粮食1-16：稳定
    for j = 1:16
        for s = 1:nS
            if isfinite(Price0(j,s))
                for tt = 1:nT
                    PriceScenario(j,s,tt,k) = Price0(j,s);
                end
            end
        end
    end

    % 蔬菜17-37：每年上涨5%
    for j = 17:37
        for s = 1:nS
            if isfinite(Price0(j,s))
                for tt = 1:nT
                    PriceScenario(j,s,tt,k) = ...
                        Price0(j,s)*1.05^(years(tt)-2023);
                end
            end
        end
    end

    % 食用菌38-40：每年随机下降1%-5%，逐年递推
    for j = 38:40
        for s = 1:nS
            if isfinite(Price0(j,s))
                prevP = Price0(j,s);
                for tt = 1:nT
                    declineRate = 0.01 + 0.04*rand;
                    prevP = prevP*(1-declineRate);
                    PriceScenario(j,s,tt,k) = prevP;
                end
            end
        end
    end

    % 羊肚菌41：每年固定下降5%
    j = 41;
    for s = 1:nS
        if isfinite(Price0(j,s))
            for tt = 1:nT
                PriceScenario(j,s,tt,k) = ...
                    Price0(j,s)*0.95^(years(tt)-2023);
            end
        end
    end
end

% 输出部分情景参数摘要，便于检查
meanWheatGrowth2024 = mean(DScenario(6,1,:),'all')/expectedSales0(6)-1;
meanCornGrowth2024  = mean(DScenario(7,1,:),'all')/expectedSales0(7)-1;

fprintf('[Step 4] 蒙特卡洛情景生成完成。\n');
fprintf('         2024小麦情景平均增长率 = %.2f%%\n',100*meanWheatGrowth2024);
fprintf('         2024玉米情景平均增长率 = %.2f%%\n',100*meanCornGrowth2024);

%% ============================================================
% Step 5. 建立MILP变量编号
% =============================================================
% 决策变量：
%   X：所有情景共同的种植面积
%   Y：所有情景共同的是否种植0-1变量
%   Z：所有情景共同的水浇地模式0-1变量
%   U：每个情景的正常销售量
%   ETA：CVaR中的VaR阈值
%   XI：每个情景超出VaR阈值的尾部损失辅助变量

Xidx = zeros(nI,nJ,nS,nT,'uint32');
Yidx = zeros(nI,nJ,nS,nT,'uint32');
Zidx = zeros(nI,nT,'uint32');
Uidx = zeros(nJ,nS,nT,K,'uint32');

nVar = 0;

% X
for tt = 1:nT
    for c = 1:nCell
        nVar = nVar+1;
        Xidx(fi(c),fj(c),fs(c),tt) = uint32(nVar);
    end
end
nX = nVar;

% Y
for tt = 1:nT
    for c = 1:nCell
        nVar = nVar+1;
        Yidx(fi(c),fj(c),fs(c),tt) = uint32(nVar);
    end
end
nY = nVar-nX;

% Z
waterPlots = find(plotTypes=="水浇地");
for tt = 1:nT
    for kk = 1:numel(waterPlots)
        i = waterPlots(kk);
        nVar = nVar+1;
        Zidx(i,tt) = uint32(nVar);
    end
end
nZ = numel(waterPlots)*nT;

% U：每个情景×年份×可销售作物季节组合
for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            nVar = nVar+1;
            Uidx(j,s,tt,k) = uint32(nVar);
        end
    end
end
nU = K*nT*nPair;

% ETA
nVar = nVar+1;
ETAidx = nVar;

% XI
XIidx = zeros(K,1,'uint32');
for k = 1:K
    nVar = nVar+1;
    XIidx(k) = uint32(nVar);
end

fprintf('[Step 5] 变量编号完成：\n');
fprintf('         X连续变量 = %d\n',nX);
fprintf('         Y二进制变量 = %d\n',nY);
fprintf('         Z二进制变量 = %d\n',nZ);
fprintf('         U情景销售变量 = %d\n',nU);
fprintf('         CVaR变量 = %d（1个ETA + %d个XI）\n',1+K,K);
fprintf('         总变量数 = %d\n',nVar);

%% ============================================================
% Step 6. 变量上下界和整数变量
% =============================================================
lb = zeros(nVar,1);
ub = inf(nVar,1);

% X不能超过对应地块面积
for tt = 1:nT
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        ub(double(Xidx(i,j,s,tt))) = plotArea(i);
    end
end

% Y、Z为0-1
yLinear = double(Yidx(Yidx>0));
zLinear = double(Zidx(Zidx>0));
ub(yLinear) = 1;
ub(zLinear) = 1;
intcon = sort([yLinear;zLinear]);

% U上界：情景预期销售量 D_jt^k
for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            u = double(Uidx(j,s,tt,k));
            ub(u) = DScenario(j,tt,k);
        end
    end
end

% ETA允许为任意实数
lb(ETAidx) = -inf;
ub(ETAidx) = inf;

% XI默认lb=0

%% ============================================================
% Step 7. 构造目标函数
% =============================================================
% 原目标：
% max [ E(Pi) - lambda * CVaR_beta(Loss) ]
%
% 其中：
% Pi_k = Revenue_k - Cost
% Loss_k = -Pi_k
%
% CVaR = ETA + 1/[(1-beta)K] * sum XI_k
%
% intlinprog求最小化，因此写成：
% min [ Cost - E(Revenue)
%       + lambda*ETA
%       + lambda/((1-beta)K)*sum XI ]
%
f = zeros(nVar,1);

% 7.1 种植成本系数
for tt = 1:nT
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        f(double(Xidx(i,j,s,tt))) = CostT(i,j,s,tt);
    end
end

% 7.2 情景平均销售收入（取负号）
for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            p = PriceScenario(j,s,tt,k);
            u = double(Uidx(j,s,tt,k));
            f(u) = -(1/K)*p;
        end
    end
end

% 7.3 CVaR项
f(ETAidx) = lambdaRisk;
for k = 1:K
    f(double(XIidx(k))) = lambdaRisk/((1-beta)*K);
end

%% ============================================================
% Step 8. 构造农业生产与情景销售约束
% =============================================================
ineqCols = cell(0,1);
ineqVals = cell(0,1);
ineqRhs  = zeros(0,1);

eqCols = cell(0,1);
eqVals = cell(0,1);
eqRhs  = zeros(0,1);

% ------------------------------------------------------------
% 8.1 X-Y关联：
%     0.1*A_i*y <= x <= A_i*y
% -------------------------------------------------------------
for tt = 1:nT
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        x = double(Xidx(i,j,s,tt));
        y = double(Yidx(i,j,s,tt));

        Ai = plotArea(i);
        Li = minAreaRatio*Ai;

        % x - Ai*y <= 0
        addIneq([x,y],[1,-Ai],0);

        % -x + Li*y <= 0
        addIneq([x,y],[-1,Li],0);
    end
end

dryPlots = find(plotTypes=="平旱地" | ...
                plotTypes=="梯田" | ...
                plotTypes=="山坡地");
ordinaryPlots = find(plotTypes=="普通大棚");
smartPlots = find(plotTypes=="智慧大棚");

% ------------------------------------------------------------
% 8.2 平旱地、梯田、山坡地：每年第一季粮食面积用满
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(dryPlots)
        i = dryPlots(kk);
        idx = double(squeeze(Xidx(i,:,1,tt)));
        idx = idx(idx>0);
        addEq(idx,ones(size(idx)),plotArea(i));
    end
end

% ------------------------------------------------------------
% 8.3 水浇地：一季水稻 或 两季蔬菜
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(waterPlots)
        i = waterPlots(kk);
        z = double(Zidx(i,tt));

        % 水稻 x = A*z
        xRice = double(Xidx(i,16,1,tt));
        addEq([xRice,z],[1,-plotArea(i)],0);

        % 第一季蔬菜 sum x = A*(1-z)
        idxS1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idxS1 = idxS1(idxS1>0);
        addEq([idxS1(:);z], ...
            [ones(numel(idxS1),1);plotArea(i)],plotArea(i));

        % 第二季35-37 sum x = A*(1-z)
        idxS2 = double(squeeze(Xidx(i,35:37,2,tt)));
        idxS2 = idxS2(idxS2>0);
        addEq([idxS2(:);z], ...
            [ones(numel(idxS2),1);plotArea(i)],plotArea(i));

        % 第二季三种蔬菜中只能选一种
        yS2 = double(squeeze(Yidx(i,35:37,2,tt)));
        yS2 = yS2(yS2>0);
        addEq([yS2(:);z], ...
            [ones(numel(yS2),1);1],1);
    end
end

% ------------------------------------------------------------
% 8.4 普通大棚：第一季蔬菜，第二季食用菌
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(ordinaryPlots)
        i = ordinaryPlots(kk);

        idx1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idx1 = idx1(idx1>0);
        addEq(idx1,ones(size(idx1)),plotArea(i));

        idx2 = double(squeeze(Xidx(i,38:41,2,tt)));
        idx2 = idx2(idx2>0);
        addEq(idx2,ones(size(idx2)),plotArea(i));
    end
end

% ------------------------------------------------------------
% 8.5 智慧大棚：两季均种17-34号蔬菜
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(smartPlots)
        i = smartPlots(kk);

        idx1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idx1 = idx1(idx1>0);
        addEq(idx1,ones(size(idx1)),plotArea(i));

        idx2 = double(squeeze(Xidx(i,17:34,2,tt)));
        idx2 = idx2(idx2>0);
        addEq(idx2,ones(size(idx2)),plotArea(i));
    end
end

% ------------------------------------------------------------
% 8.6 同一种作物同年同季最多分布在6个地块
% -------------------------------------------------------------
for tt = 1:nT
    for j = 1:nJ
        for s = 1:nS
            if ~pairMask(j,s)
                continue;
            end
            idx = double(squeeze(Yidx(:,j,s,tt)));
            idx = idx(idx>0);
            if ~isempty(idx)
                addIneq(idx,ones(size(idx)),maxPlotsPerCropSeason);
            end
        end
    end
end

% ------------------------------------------------------------
% 8.7 禁止连续重茬
% -------------------------------------------------------------
% (a) 平旱地、梯田、山坡地：相邻年份不能同作物
for kk = 1:numel(dryPlots)
    i = dryPlots(kk);
    for j = 1:15
        for tt = 1:nT-1
            y1 = double(Yidx(i,j,1,tt));
            y2 = double(Yidx(i,j,1,tt+1));
            addIneq([y1,y2],[1,1],1);
        end

        % 2023 -> 2024
        if histX(i,j,1)>tol
            addIneq(double(Yidx(i,j,1,1)),1,0);
        end
    end
end

% (b) 水浇地：不能连续两年都种水稻
for kk = 1:numel(waterPlots)
    i = waterPlots(kk);

    for tt = 1:nT-1
        z1 = double(Zidx(i,tt));
        z2 = double(Zidx(i,tt+1));
        addIneq([z1,z2],[1,1],1);
    end

    if histX(i,16,1)>tol
        addIneq(double(Zidx(i,1)),1,0);
    end
end

% (c) 智慧大棚：第一季->第二季、第二季->下一年第一季
for kk = 1:numel(smartPlots)
    i = smartPlots(kk);

    for j = 17:34
        for tt = 1:nT
            y1 = double(Yidx(i,j,1,tt));
            y2 = double(Yidx(i,j,2,tt));
            addIneq([y1,y2],[1,1],1);
        end

        for tt = 1:nT-1
            y2 = double(Yidx(i,j,2,tt));
            yNext1 = double(Yidx(i,j,1,tt+1));
            addIneq([y2,yNext1],[1,1],1);
        end

        % 2023第二季 -> 2024第一季
        if histX(i,j,2)>tol
            addIneq(double(Yidx(i,j,1,1)),1,0);
        end
    end
end

% ------------------------------------------------------------
% 8.8 三年豆类轮作（面积等价处理）
% -------------------------------------------------------------
beanCrops = [1:5,17:19];

for i = 1:nI
    histBeanArea = sum(histX(i,beanCrops,:),'all');

    % 2023-2025窗口
    cols = [];
    vals = [];
    for tt = 1:2
        for s = 1:nS
            for j = beanCrops
                x = double(Xidx(i,j,s,tt));
                if x>0
                    cols(end+1,1) = x; %#ok<AGROW>
                    vals(end+1,1) = -1; %#ok<AGROW>
                end
            end
        end
    end
    addIneq(cols,vals,-(plotArea(i)-histBeanArea));

    % 2024-2026 ... 2028-2030
    for startT = 1:5
        cols = [];
        vals = [];

        for tt = startT:startT+2
            for s = 1:nS
                for j = beanCrops
                    x = double(Xidx(i,j,s,tt));
                    if x>0
                        cols(end+1,1) = x; %#ok<AGROW>
                        vals(end+1,1) = -1; %#ok<AGROW>
                    end
                end
            end
        end

        addIneq(cols,vals,-plotArea(i));
    end
end

% ------------------------------------------------------------
% 8.9 每个情景的正常销售量：
%     u_jstk <= sum_i q_ijst^k * x_ijst
%     u_jstk <= D_jt^k 已通过变量上界实现
% -------------------------------------------------------------
fprintf('[Step 8] 正在建立%d个情景的产量-销量约束...\n',K);

for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            u = double(Uidx(j,s,tt,k));

            cols = u;
            vals = 1;

            scale = YieldScale(j,tt,k);

            for i = 1:nI
                x = double(Xidx(i,j,s,tt));
                if x>0
                    qScenario = Yield0(i,j,s)*scale;
                    cols(end+1,1) = x; %#ok<AGROW>
                    vals(end+1,1) = -qScenario; %#ok<AGROW>
                end
            end

            % u - sum(q*x) <= 0
            addIneq(cols,vals,0);
        end
    end
end

% ------------------------------------------------------------
% 8.10 CVaR情景约束
%
% Loss_k = Cost - Revenue_k
% XI_k >= Loss_k - ETA
%
% 等价：
% Cost - Revenue_k - ETA - XI_k <= 0
% -------------------------------------------------------------

% 总成本表达式中的列与系数（所有情景相同）
costCols = zeros(nX,1);
costVals = zeros(nX,1);
pos = 0;
for tt = 1:nT
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        pos = pos+1;
        costCols(pos) = double(Xidx(i,j,s,tt));
        costVals(pos) = CostT(i,j,s,tt);
    end
end

for k = 1:K
    cols = costCols;
    vals = costVals;

    % 减去该情景全部销售收入
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            u = double(Uidx(j,s,tt,k));
            p = PriceScenario(j,s,tt,k);

            cols(end+1,1) = u; %#ok<AGROW>
            vals(end+1,1) = -p; %#ok<AGROW>
        end
    end

    % -ETA - XI_k
    cols(end+1,1) = ETAidx;
    vals(end+1,1) = -1;

    cols(end+1,1) = double(XIidx(k));
    vals(end+1,1) = -1;

    addIneq(cols,vals,0);
end

%% ============================================================
% Step 9. 将逐条约束打包为稀疏矩阵
% =============================================================
[A,b] = packRows(ineqCols,ineqVals,ineqRhs,nVar);
[Aeq,beq] = packRows(eqCols,eqVals,eqRhs,nVar);

fprintf('[Step 9] 约束矩阵构造完成：\n');
fprintf('         不等式约束 = %d\n',size(A,1));
fprintf('         等式约束 = %d\n',size(Aeq,1));
fprintf('         nnz(A) = %d\n',nnz(A));
fprintf('         nnz(Aeq) = %d\n',nnz(Aeq));
fprintf('         整数变量 = %d\n\n',numel(intcon));

%% ============================================================
% Step 10. 调用 intlinprog 求解
% =============================================================
options = optimoptions('intlinprog', ...
    'Display','iter', ...
    'MaxTime',maxSolveTime, ...
    'RelativeGapTolerance',relativeGap);

fprintf('============================================================\n');
fprintf('开始求解问题二 MILP...\n');
fprintf('最大时间 = %d秒，相对Gap阈值 = %.2f%%\n', ...
    maxSolveTime,100*relativeGap);
fprintf('============================================================\n');

tic;
[sol,fval,exitflag,output] = intlinprog( ...
    f,intcon,A,b,Aeq,beq,lb,ub,options);
solveTime = toc;

if isempty(sol)
    error('求解器未得到可行解。exitflag=%d',exitflag);
end

fprintf('\n[Step 10] 求解完成，用时 %.1f 秒。\n',solveTime);
fprintf('          exitflag = %d\n',exitflag);
if isfield(output,'relativegap')
    fprintf('          relative gap = %.4f%%\n',100*output.relativegap);
end
if isfield(output,'numnodes')
    fprintf('          分支定界节点数 = %d\n',output.numnodes);
end

%% ============================================================
% Step 11. 恢复种植方案与情景利润
% =============================================================
X = zeros(nI,nJ,nS,nT);
U = zeros(nJ,nS,nT,K);

for tt = 1:nT
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        val = sol(double(Xidx(i,j,s,tt)));
        if abs(val)<1e-6
            val = 0;
        end
        X(i,j,s,tt) = val;
    end
end

for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            U(j,s,tt,k) = sol(double(Uidx(j,s,tt,k)));
        end
    end
end

etaSol = sol(ETAidx);
xiSol = zeros(K,1);
for k = 1:K
    xiSol(k) = sol(double(XIidx(k)));
end

% 年度确定成本
yearCost = zeros(nT,1);
for tt = 1:nT
    cst = 0;
    for c = 1:nCell
        i = fi(c); j = fj(c); s = fs(c);
        cst = cst + CostT(i,j,s,tt)*X(i,j,s,tt);
    end
    yearCost(tt) = cst;
end

% 每个情景、每年的销售收入与利润
scenarioYearRevenue = zeros(K,nT);
scenarioYearProfit = zeros(K,nT);

for k = 1:K
    for tt = 1:nT
        rev = 0;
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);
            rev = rev + PriceScenario(j,s,tt,k)*U(j,s,tt,k);
        end

        scenarioYearRevenue(k,tt) = rev;
        scenarioYearProfit(k,tt) = rev-yearCost(tt);
    end
end

scenarioProfit = sum(scenarioYearProfit,2);

expectedProfit = mean(scenarioProfit);
medianProfit = median(scenarioProfit);
stdProfit = std(scenarioProfit);
minProfit = min(scenarioProfit);
maxProfit = max(scenarioProfit);

cvarLoss = etaSol + sum(xiSol)/((1-beta)*K);
lowerTailProfit = -cvarLoss;

modelObjective = expectedProfit - lambdaRisk*cvarLoss;

% 各年度情景统计
expectedYearProfit = mean(scenarioYearProfit,1)';
medianYearProfit = median(scenarioYearProfit,1)';
p05YearProfit = zeros(nT,1);
p95YearProfit = zeros(nT,1);
minYearProfit = min(scenarioYearProfit,[],1)';
maxYearProfit = max(scenarioYearProfit,[],1)';

for tt = 1:nT
    p05YearProfit(tt) = empiricalQuantile(scenarioYearProfit(:,tt),0.05);
    p95YearProfit(tt) = empiricalQuantile(scenarioYearProfit(:,tt),0.95);
end

fprintf('\n================= 问题二关键结果 =================\n');
fprintf('情景平均七年利润 = %.2f 元 = %.4f 万元\n', ...
    expectedProfit,expectedProfit/1e4);
fprintf('情景七年利润中位数 = %.4f 万元\n',medianProfit/1e4);
fprintf('情景七年利润标准差 = %.4f 万元\n',stdProfit/1e4);
fprintf('最差情景七年利润 = %.4f 万元\n',minProfit/1e4);
fprintf('最好情景七年利润 = %.4f 万元\n',maxProfit/1e4);
fprintf('ETA（损失VaR阈值） = %.4f 万元\n',etaSol/1e4);
fprintf('CVaR损失 = %.4f 万元\n',cvarLoss/1e4);
fprintf('对应下行CVaR利润水平 = %.4f 万元\n',lowerTailProfit/1e4);
fprintf('综合目标值 E(Pi)-lambda*CVaR(Loss) = %.4f 万元\n', ...
    modelObjective/1e4);
fprintf('====================================================\n');

yearTable = table(years(:), ...
    expectedYearProfit/1e4,medianYearProfit/1e4, ...
    p05YearProfit/1e4,p95YearProfit/1e4, ...
    minYearProfit/1e4,maxYearProfit/1e4, ...
    yearCost/1e4, ...
    'VariableNames',{'Year','ExpectedProfit_万元','MedianProfit_万元', ...
    'P05Profit_万元','P95Profit_万元','MinProfit_万元','MaxProfit_万元', ...
    'PlantingCost_万元'});
disp(yearTable);

%% ============================================================
% Step 12. 写入 result2 模板
% =============================================================
writeResultWorkbook(template2,outResult,X,plotTypes,years);
fprintf('\n[Step 12] 已生成种植方案：\n%s\n',outResult);

%% ============================================================
% Step 13. 输出风险分析Excel
% =============================================================
if isfile(outAnalysis)
    delete(outAnalysis);
end

% 13.1 参数表
paramName = [ ...
    "MonteCarlo情景数K"; ...
    "CVaR置信水平beta"; ...
    "风险权重lambda"; ...
    "随机种子"; ...
    "最小种植面积比例"; ...
    "单作物单季最大地块数"; ...
    "最大求解时间_秒"; ...
    "RelativeGapTolerance"];

paramValue = [ ...
    K;beta;lambdaRisk;randomSeed;minAreaRatio; ...
    maxPlotsPerCropSeason;maxSolveTime;relativeGap];

Tparam = table(paramName,paramValue, ...
    'VariableNames',{'参数','数值'});
writetable(Tparam,outAnalysis,'Sheet','参数设置');

% 13.2 总风险指标
metricName = [ ...
    "情景平均七年利润_万元"; ...
    "七年利润中位数_万元"; ...
    "七年利润标准差_万元"; ...
    "最差情景七年利润_万元"; ...
    "最好情景七年利润_万元"; ...
    "ETA损失阈值_万元"; ...
    "CVaR损失_万元"; ...
    "下行CVaR利润水平_万元"; ...
    "综合目标值_万元"; ...
    "求解时间_秒"];

metricValue = [ ...
    expectedProfit/1e4;medianProfit/1e4;stdProfit/1e4; ...
    minProfit/1e4;maxProfit/1e4;etaSol/1e4; ...
    cvarLoss/1e4;lowerTailProfit/1e4; ...
    modelObjective/1e4;solveTime];

Tmetric = table(metricName,metricValue, ...
    'VariableNames',{'指标','数值'});
writetable(Tmetric,outAnalysis,'Sheet','风险指标');

% 13.3 情景总利润
Tscenario = table((1:K)',scenarioProfit/1e4, ...
    'VariableNames',{'情景编号','七年总利润_万元'});
Tscenario = sortrows(Tscenario,'七年总利润_万元','ascend');
writetable(Tscenario,outAnalysis,'Sheet','情景利润');

% 13.4 年度利润统计
Tyear = table(years(:), ...
    expectedYearProfit/1e4,medianYearProfit/1e4, ...
    p05YearProfit/1e4,p95YearProfit/1e4, ...
    minYearProfit/1e4,maxYearProfit/1e4, ...
    yearCost/1e4, ...
    'VariableNames',{'年份','期望利润_万元','中位数利润_万元', ...
    'P05利润_万元','P95利润_万元','最小利润_万元','最大利润_万元', ...
    '种植成本_万元'});
writetable(Tyear,outAnalysis,'Sheet','年度利润');

% 13.5 主要作物累计面积
cropArea = zeros(nJ,1);
for j = 1:nJ
    temp = X(:,j,:,:);
    cropArea(j) = sum(temp(:));
end
Tcrop = table(cropIds(:),cropNames(:),cropArea, ...
    'VariableNames',{'作物编号','作物名称','2024至2030累计种植面积_亩'});
Tcrop = sortrows(Tcrop,'2024至2030累计种植面积_亩','descend');
writetable(Tcrop,outAnalysis,'Sheet','作物累计面积');

fprintf('[Step 13] 已生成风险分析表：\n%s\n',outAnalysis);

%% ============================================================
% Step 14. 绘制必要图像
% =============================================================

% ------------------------------------------------------------
% 图1：蒙特卡洛情景七年总利润分布
% -------------------------------------------------------------
figure('Color','w','Position',[100 80 920 560]);
histogram(scenarioProfit/1e4,10);
hold on;
xline(expectedProfit/1e4,'--','平均利润','LineWidth',1.5);
xline(lowerTailProfit/1e4,'-.','下行CVaR利润','LineWidth',1.5);
grid on;
xlabel('2024—2030七年总利润/万元');
ylabel('情景数量');
title(sprintf('蒙特卡洛情景利润分布（K=%d，\\beta=%.2f）',K,beta));
saveFig(figDir,'图1_蒙特卡洛情景七年利润分布.png');

% ------------------------------------------------------------
% 图2：年度期望利润及5%-95%情景区间
% -------------------------------------------------------------
figure('Color','w','Position',[100 80 950 560]);

x = years(:);
low = p05YearProfit/1e4;
high = p95YearProfit/1e4;

fill([x;flipud(x)],[low;flipud(high)], ...
    [0.85 0.85 0.85], ...
    'EdgeColor','none','FaceAlpha',0.45);
hold on;
plot(years,expectedYearProfit/1e4,'-o','LineWidth',1.8,'MarkerSize',7);
plot(years,medianYearProfit/1e4,'--s','LineWidth',1.3,'MarkerSize',6);
grid on;
xlabel('年份');
ylabel('利润/万元');
title('各年度情景利润及不确定性区间');
legend({'5%-95%情景区间','期望利润','中位数利润'}, ...
    'Location','best');
xticks(years);
saveFig(figDir,'图2_年度期望利润与情景区间.png');

% ------------------------------------------------------------
% 图3：累计种植面积最大的前12种作物
% -------------------------------------------------------------
[sortedArea,ord] = sort(cropArea,'descend');
topN = min(12,nJ);
top = ord(1:topN);

figure('Color','w','Position',[100 80 1000 620]);
barh(1:topN,sortedArea(1:topN));
set(gca,'YTick',1:topN,'YTickLabel',cropNames(top),'YDir','reverse');
grid on;
xlabel('2024—2030累计种植面积/亩');
ylabel('作物');
title('问题二主要作物累计种植面积');
saveFig(figDir,'图3_主要作物累计种植面积.png');

% ------------------------------------------------------------
% 图4：作物类别年度种植结构
% -------------------------------------------------------------
catNames = ["粮食非豆类","粮食豆类","蔬菜非豆类","蔬菜豆类","食用菌"];
catCrop = {6:16,1:5,20:37,17:19,38:41};
catArea = zeros(nT,5);

for cc = 1:5
    ids = catCrop{cc};
    for tt = 1:nT
        temp = X(:,ids,:,tt);
        catArea(tt,cc) = sum(temp(:));
    end
end

figure('Color','w','Position',[100 80 1000 580]);
bar(years,catArea,'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('问题二各类作物年度种植结构');
legend(cellstr(catNames),'Location','bestoutside');
saveFig(figDir,'图4_作物类别年度种植结构.png');

% ------------------------------------------------------------
% 图5：按利润从低到高排列的情景曲线
% 更直观地观察低收益尾部
% -------------------------------------------------------------
sortedProfit = sort(scenarioProfit,'ascend');

figure('Color','w','Position',[100 80 950 560]);
plot(1:K,sortedProfit/1e4,'-o','LineWidth',1.5,'MarkerSize',5);
hold on;
yline(lowerTailProfit/1e4,'--','下行CVaR利润','LineWidth',1.4);
grid on;
xlabel('情景排序（由低利润到高利润）');
ylabel('七年总利润/万元');
title('蒙特卡洛情景利润排序及下行风险');
saveFig(figDir,'图5_情景利润排序与CVaR.png');

fprintf('[Step 14] 图像已保存到：\n%s\n',figDir);

%% ============================================================
% Step 15. 最终说明
% =============================================================
fprintf('\n============================================================\n');
fprintf('程序运行完成。\n');
fprintf('1) result2_MATLAB_CVaR.xlsx：最终统一种植方案。\n');
fprintf('2) Q2_风险分析.xlsx：情景利润、年度利润和风险指标。\n');
fprintf('3) Q2_figures：论文可使用的风险与种植结构图像。\n');
fprintf('\n解释：\n');
fprintf('- 期望利润表示同一套种植方案在%d个未来情景中的平均七年利润；\n',K);
fprintf('- 标准差反映不同情景之间的利润波动；\n');
fprintf('- 最差情景利润反映当前样本中最不利情景的表现；\n');
fprintf('- CVaR针对低利润尾部进行风险控制；\n');
fprintf('- lambda越大，优化时越重视低收益情景而非单纯追求平均利润。\n');
fprintf('\n注意：K、beta、lambda当前为工作参数，并未通过参数比较证明为“最优”。\n');
fprintf('============================================================\n');

%% ============================================================
% 嵌套函数：逐条加入约束
% =============================================================

    function addIneq(cols,vals,rhs)
        cols = double(cols(:));
        vals = double(vals(:));

        keep = cols>0 & abs(vals)>0;
        cols = cols(keep);
        vals = vals(keep);

        ineqCols{end+1,1} = cols;
        ineqVals{end+1,1} = vals;
        ineqRhs(end+1,1) = rhs;
    end

    function addEq(cols,vals,rhs)
        cols = double(cols(:));
        vals = double(vals(:));

        keep = cols>0 & abs(vals)>0;
        cols = cols(keep);
        vals = vals(keep);

        eqCols{end+1,1} = cols;
        eqVals{end+1,1} = vals;
        eqRhs(end+1,1) = rhs;
    end

end

%% ============================================================
% 本文件局部函数
% ============================================================

function filePath = findOneFile(dataDir,patterns,excludeNames)
% 按候选文件名和通配符自动寻找文件。
% excludeNames用于避免下次运行时把程序自己输出的Excel当作模板。

filePath = "";

for kk = 1:numel(patterns)
    pattern = patterns{kk};

    % 完全匹配优先
    if ~contains(pattern,'*') && ~contains(pattern,'?')
        p = fullfile(dataDir,pattern);
        if isfile(p)
            filePath = string(p);
            break;
        end
    end

    d = dir(fullfile(dataDir,pattern));
    d = d(~[d.isdir]);

    if ~isempty(d)
        keep = true(numel(d),1);
        for ii = 1:numel(d)
            for ee = 1:numel(excludeNames)
                if strcmpi(d(ii).name,excludeNames{ee})
                    keep(ii) = false;
                end
            end
        end
        d = d(keep);

        if ~isempty(d)
            [~,idx] = max([d.datenum]);
            filePath = string(fullfile(d(idx).folder,d(idx).name));
            break;
        end
    end
end

if strlength(filePath)==0
    fprintf(2,'\n当前程序目录：%s\n',dataDir);
    fprintf(2,'目录中的Excel文件：\n');
    d = dir(fullfile(dataDir,'*.xlsx'));
    for ii = 1:numel(d)
        fprintf(2,'  %s\n',d(ii).name);
    end
    error('未找到所需Excel文件，请检查文件是否与程序放在同一文件夹。');
end

filePath = char(filePath);
end

function s = cleanString(x)
% 安全地把单元格内容转成string并去除首尾空格
if isempty(x)
    s = "";
else
    try
        s = strtrim(string(x));
        if ismissing(s)
            s = "";
        end
    catch
        s = "";
    end
end
end

function v = cellToDouble(x)
% 将数值/数值字符串转成double，失败返回NaN
if isnumeric(x) && isscalar(x)
    v = double(x);
elseif islogical(x) && isscalar(x)
    v = double(x);
else
    try
        v = str2double(strtrim(string(x)));
        if isempty(v) || ~isscalar(v)
            v = NaN;
        end
    catch
        v = NaN;
    end
end
end

function s = seasonCode(x)
% 单季与第一季统一记为1，第二季记为2
txt = cleanString(x);

if txt=="单季" || txt=="第一季"
    s = 1;
elseif txt=="第二季"
    s = 2;
else
    s = 0;
end
end

function p = priceMidpoint(x)
% 将“2.50-4.00”等价格区间取中点
txt = char(cleanString(x));
nums = regexp(txt,'\d+(\.\d+)?','match');

if isempty(nums)
    p = NaN;
elseif numel(nums)==1
    p = str2double(nums{1});
else
    p = (str2double(nums{1})+str2double(nums{2}))/2;
end
end

function [M,rhs] = packRows(colsCell,valsCell,rhsIn,nVar)
% 将逐条约束系数打包为稀疏矩阵
m = numel(rhsIn);

if m==0
    M = sparse(0,nVar);
    rhs = zeros(0,1);
    return;
end

len = cellfun(@numel,colsCell);
totalNnz = sum(len);

rowIdx = zeros(totalNnz,1);
colIdx = zeros(totalNnz,1);
valVec = zeros(totalNnz,1);

pos = 1;

for r = 1:m
    nr = len(r);
    if nr>0
        rr = pos:pos+nr-1;
        rowIdx(rr) = r;
        colIdx(rr) = colsCell{r};
        valVec(rr) = valsCell{r};
        pos = pos+nr;
    end
end

M = sparse(rowIdx,colIdx,valVec,m,nVar);
rhs = rhsIn(:);
end

function writeResultWorkbook(templateFile,outFile,X,plotTypes,years)
% 保留题目result2模板格式，只写种植面积

copyfile(templateFile,outFile,'f');

% 第一季54块：A1-F4 -> C2:AQ55
% 第二季28块：D1-D8,E1-E16,F1-F4 -> C56:AQ83
secondPlotIdx = find(plotTypes=="水浇地" | ...
                     plotTypes=="普通大棚" | ...
                     plotTypes=="智慧大棚");

for tt = 1:numel(years)
    sh = num2str(years(tt));

    M1 = squeeze(X(:,:,1,tt));
    M1(abs(M1)<1e-6) = 0;

    M2 = squeeze(X(secondPlotIdx,:,2,tt));
    M2(abs(M2)<1e-6) = 0;

    writematrix(M1,outFile,'Sheet',sh,'Range','C2');
    writematrix(M2,outFile,'Sheet',sh,'Range','C56');
end
end

function q = empiricalQuantile(x,p)
% 不依赖Statistics Toolbox的简单经验分位数
x = sort(x(:));
n = numel(x);

if n==0
    q = NaN;
    return;
end

if p<=0
    q = x(1);
    return;
elseif p>=1
    q = x(end);
    return;
end

pos = 1 + (n-1)*p;
lo = floor(pos);
hi = ceil(pos);

if lo==hi
    q = x(lo);
else
    w = pos-lo;
    q = (1-w)*x(lo)+w*x(hi);
end
end

function saveFig(figDir,fileName)
% 保存300dpi PNG图像
drawnow;
exportgraphics(gcf,fullfile(figDir,fileName),'Resolution',300);
end
