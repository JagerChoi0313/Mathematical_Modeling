function C_Q3_Copula_Association_CVaR_MILP_WarmStart()
% C_Q3_Copula_Association_CVaR_MILP
% ============================================================
% 2024 高教社杯 C题 问题三
% 基于“Gaussian Copula相关情景 + 作物关联需求修正
%      + 下行CVaR风险控制 + 多时期MILP”的种植优化
%
% ------------------------------------------------------------
% 与问题二相比，本程序新增两部分：
% 1) 预期销售量、销售价格、种植成本不再独立随机，4
%    而是通过Gaussian Copula按相关矩阵R联合生成；
% 2) 通过作物关联矩阵A和自身价格响应系数alpha，
%    对预期销售量进行替代/互补关系修正。
%
% 农业生产约束与问题二保持一致：
% - 土地适种与面积约束
% - 水浇地一季水稻/两季蔬菜模式
% - 普通大棚与智慧大棚种植制度
% - 连续重茬
% - 三年豆类轮作
% - 单地块最小种植面积
% - 同作物同季最大分散地块数
%
% ------------------------------------------------------------
% 重要说明：以下参数不是附件统计估计结果，而是“相关情景模拟参数”
% ------------------------------------------------------------
% rhoDP = -0.40 ：销量驱动与价格驱动负相关
% rhoDC =  0.15 ：销量驱动与成本驱动弱正相关
% rhoPC =  0.45 ：价格驱动与成本驱动正相关
%
% selfAlpha = 0.30 ：自身价格响应系数
% subTotal  = 0.30 ：同类作物替代作用总强度（按组内作物均分）
% compTotal = -0.10：豆类与同类非豆作物之间弱互补作用总强度
%
% grainPriceNoise = 0.02 ：粮食围绕稳定价格最多±2%随机偏离
% vegPriceNoise   = 0.03 ：蔬菜围绕5%年增长趋势最多±3%随机偏离
% costNoise       = 0.03 ：成本围绕5%年增长趋势最多±3%随机偏离
%
% 这些数值只是为了构造一套“可运行的基准相关情景”。
% 最终论文中不能写成“由附件数据计算得到”，如需提高严谨性，
% 后续应对这些参数做敏感性分析。
%
% ------------------------------------------------------------
% 输入文件（与本程序放在同一文件夹）
% ------------------------------------------------------------
% 必需：
%   附件1.xlsx  或 附件1*.xlsx
%   附件2.xlsx  或 附件2*.xlsx
%   result2.xlsx / result2(1).xlsx
%
% 可选（用于与问题二同情景比较）：
%   result2_MATLAB_CVaR.xlsx
%
% 注：题目问题3没有要求单独提交result3模板，因此本程序复制
% result2模板的格式，生成一个分析用文件：
%   result3_MATLAB_Copula_CVaR.xlsx
%
% ------------------------------------------------------------
% 输出
% ------------------------------------------------------------
% 1) result3_MATLAB_Copula_CVaR.xlsx
%    问题三最终种植方案（沿用result2模板布局）
%
% 2) Q3_相关性风险分析.xlsx
%    包括参数、相关矩阵、风险指标、年度利润、作物面积及Q2/Q3比较
%
% 3) Q3_figures\*.png
%    相关性、利润风险、问题二/三比较、作物结构等图像
%
% ------------------------------------------------------------
% MATLAB要求
% ------------------------------------------------------------
% 需要 Optimization Toolbox（intlinprog）。
%
% 本版本新增“Q2方案 warm start”：
% - 若目录中存在 result2_MATLAB_CVaR.xlsx，则把问题二方案转换成
%   问题三完整初始可行点（X/Y/Z/U/ETA/XI）；
% - 求解前检查该初始点的约束违反量和目标值；
% - intlinprog直接以该可行点作为 incumbent 起点；
% - 求解结束后再次检查，最终返回方案不会比该warm start更差。
%
% Gaussian Copula部分不依赖Statistics Toolbox：
% 标准正态CDF通过 erf 实现。
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

file1 = findOneFile(dataDir, ...
    {'附件1.xlsx','附件1(20260827-120155).xlsx','附件1*.xlsx'}, {});

file2 = findOneFile(dataDir, ...
    {'附件2.xlsx','附件2(20260827-120154).xlsx','附件2*.xlsx'}, {});

template2 = findOneFile(dataDir, ...
    {'result2.xlsx','result2(1).xlsx','result2*.xlsx'}, ...
    {'result2_MATLAB_CVaR.xlsx','result3_MATLAB_Copula_CVaR.xlsx'});

% 问题二结果为可选项：存在时做“同一组Q3相关情景下”的公平比较
q2ResultFile = findOptionalFile(dataDir, ...
    {'result2_MATLAB_CVaR.xlsx','*result2*CVaR*.xlsx'}, ...
    {'result3_MATLAB_Copula_CVaR.xlsx'});

outResult   = fullfile(dataDir,'result3_MATLAB_Copula_CVaR.xlsx');
outAnalysis = fullfile(dataDir,'Q3_相关性风险分析.xlsx');
figDir      = fullfile(dataDir,'Q3_figures');

if ~exist(figDir,'dir')
    mkdir(figDir);
end

years = 2024:2030;
nT = numel(years);
nS = 2;

% ---------------- 情景数与风险参数 ----------------
K = 30;
beta = 0.90;
lambdaRisk = 0.20;
randomSeed = 2024;

% ---------------- Gaussian Copula相关参数 ----------------
rhoDP = -0.40;   % 销量驱动 - 价格驱动
rhoDC =  0.15;   % 销量驱动 - 成本驱动
rhoPC =  0.45;   % 价格驱动 - 成本驱动

Rtarget = [ ...
    1,     rhoDP, rhoDC; ...
    rhoDP, 1,     rhoPC; ...
    rhoDC, rhoPC, 1];

% 必须保证R为正定矩阵
[~,cholFlag] = chol(Rtarget);
if cholFlag ~= 0
    error('相关矩阵R不是正定矩阵，请修改rhoDP、rhoDC、rhoPC。');
end
Lcorr = chol(Rtarget,'lower');

% ---------------- 价格与成本的情景扰动幅度 ----------------
grainPriceNoise = 0.02;   % 粮食：稳定趋势附近±2%
vegPriceNoise   = 0.03;   % 蔬菜：5%年增长趋势附近±3%
costNoise       = 0.03;   % 成本：5%年增长趋势附近±3%

% ---------------- 作物替代/互补参数 ----------------
selfAlpha      = 0.30;    % 自身价格响应系数
subTotal       = 0.30;    % 同类作物总替代强度
compTotal      = -0.10;   % 豆类-同类非豆类总互补强度
demandAdjCap   = 0.10;    % 需求关联修正最大限制为±10%

% ---------------- 问题一/二沿用的管理参数 ----------------
minAreaRatio = 0.10;
maxPlotsPerCropSeason = 6;
tol = 1e-7;

% ---------------- 求解器设置 ----------------
maxSolveTime = 3600;
relativeGap  = 0.005;

fprintf('============================================================\n');
fprintf('2024 C题 问题三：Gaussian Copula + Association + CVaR + MILP\n');
fprintf('============================================================\n');
fprintf('附件1：%s\n',file1);
fprintf('附件2：%s\n',file2);
fprintf('结果模板：%s\n',template2);

if strlength(string(q2ResultFile))>0
    fprintf('问题二结果：%s\n',q2ResultFile);
else
    fprintf('问题二结果：未找到，将跳过Q2/Q3种植方案比较。\n');
end

fprintf('\n情景数 K = %d\n',K);
fprintf('CVaR beta = %.2f\n',beta);
fprintf('风险权重 lambda = %.3f\n',lambdaRisk);
fprintf('随机种子 = %d\n',randomSeed);

fprintf('\n目标相关矩阵R：\n');
disp(Rtarget);

fprintf('自身价格响应 alpha = %.3f\n',selfAlpha);
fprintf('同类替代总强度 = %.3f\n',subTotal);
fprintf('豆类-非豆类互补总强度 = %.3f\n',compTotal);
fprintf('需求修正上限 = ±%.1f%%\n',100*demandAdjCap);
fprintf('============================================================\n\n');

%% ============================================================
% Step 1. 读取附件1：地块与作物基本信息
% =============================================================
landRaw = readcell(file1,'Sheet','乡村的现有耕地');
cropRaw = readcell(file1,'Sheet','乡村种植的农作物');

% ---------- 地块信息 ----------
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

% ---------- 作物信息 ----------
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
% Step 2. 读取附件2：构造2023基准亩产量、成本和价格
% =============================================================
plantRaw = readcell(file2,'Sheet','2023年的农作物种植情况');
statRaw  = readcell(file2,'Sheet','2023年统计的相关数据');

Yield0 = nan(nI,nJ,nS);      % 斤/亩
Cost0  = nan(nI,nJ,nS);      % 元/亩
PriceCell0 = nan(nI,nJ,nS);  % 元/斤，价格区间中点

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

% 智慧大棚第一季参数按附件说明采用普通大棚第一季参数
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

% 可行地块-作物-季节单元
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

fprintf('[Step 2] 基准参数完成：可行种植单元=%d，作物-季节组合=%d。\n', ...
    nCell,nPair);

%% ============================================================
% Step 3. 根据2023实际种植计算销售量基准D0，并记录历史轮作
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
fprintf('         小麦D0 = %.0f斤\n',expectedSales0(6));
fprintf('         玉米D0 = %.0f斤\n',expectedSales0(7));
fprintf('         水稻D0 = %.0f斤\n',expectedSales0(16));

%% ============================================================
% Step 4. 建立作物关联矩阵A
% =============================================================
% 符号约定（交叉价格效应）：
% A(j,l)>0：l价格上涨时，j需求增加 -> 替代关系
% A(j,l)<0：l价格上涨时，j需求下降 -> 互补关系
%
% 当前基准情景采用：
% 1) 同一细分类组内部为替代关系；
% 2) 粮食豆类(1:5)与粮食非豆类(6:16)设弱互补；
% 3) 蔬菜豆类(17:19)与其他蔬菜(20:37)设弱互补。
%
% 这些关系属于“模型情景假设”，不是附件统计结果。

[Aassoc,relationInfo] = buildAssociationMatrix( ...
    nJ,subTotal,compTotal);

alphaSelf = selfAlpha*ones(nJ,1);

fprintf('[Step 4] 作物关联矩阵建立完成。\n');
fprintf('         非零交叉关联系数数量 = %d\n',nnz(Aassoc));
fprintf('         最大单行绝对关联强度 = %.4f\n', ...
    max(sum(abs(Aassoc),2)));
disp(relationInfo);

%% ============================================================
% Step 5. Gaussian Copula生成销量-价格-成本相关情景
% =============================================================
rng(randomSeed,'twister');

% 相关标准正态驱动
ZD = zeros(nJ,nT,K);
ZP = zeros(nJ,nT,K);
ZC = zeros(nJ,nT,K);

% Copula均匀变量
UD = zeros(nJ,nT,K);
UP = zeros(nJ,nT,K);
UC = zeros(nJ,nT,K);

for j = 1:nJ
    for tt = 1:nT

        % K×3相关标准正态样本
        Z = randn(K,3)*Lcorr.';

        % 不依赖Statistics Toolbox的标准正态CDF
        U = 0.5*(1 + erf(Z/sqrt(2)));

        ZD(j,tt,:) = reshape(Z(:,1),1,1,K);
        ZP(j,tt,:) = reshape(Z(:,2),1,1,K);
        ZC(j,tt,:) = reshape(Z(:,3),1,1,K);

        UD(j,tt,:) = reshape(U(:,1),1,1,K);
        UP(j,tt,:) = reshape(U(:,2),1,1,K);
        UC(j,tt,:) = reshape(U(:,3),1,1,K);
    end
end

% 实际样本相关矩阵：应与目标R方向和数量级一致
empCorrZ = corrcoef([ZD(:),ZP(:),ZC(:)]);
empCorrU = corrcoef([UD(:),UP(:),UC(:)]);

fprintf('[Step 5] Gaussian Copula相关驱动生成完成。\n');
fprintf('目标相关矩阵R：\n');
disp(Rtarget);
fprintf('标准正态驱动变量的样本相关矩阵：\n');
disp(empCorrZ);

%% ============================================================
% Step 6. 将相关驱动映射为销量、价格、成本和亩产量情景
% =============================================================

% ------------------------------------------------------------
% 6.1 基础销售量情景 DScenario(j,t,k)
% -------------------------------------------------------------
DScenario = zeros(nJ,nT,K);

for k = 1:K

    % 小麦6、玉米7：年增长5%-10%，逐年递推
    for j = [6,7]
        prevD = expectedSales0(j);

        for tt = 1:nT
            uD = UD(j,tt,k);
            growthRate = 0.05 + 0.05*uD;
            prevD = prevD*(1+growthRate);
            DScenario(j,tt,k) = prevD;
        end
    end

    % 其他作物：相对于2023年±5%
    otherCrops = setdiff(1:nJ,[6,7]);

    for j = otherCrops
        for tt = 1:nT
            uD = UD(j,tt,k);
            epsD = -0.05 + 0.10*uD;
            DScenario(j,tt,k) = expectedSales0(j)*(1+epsD);
        end
    end
end

% ------------------------------------------------------------
% 6.2 亩产量：仍按第二问独立±10%
% -------------------------------------------------------------
YieldScale = zeros(nJ,nT,K);

for k = 1:K
    for tt = 1:nT
        YieldScale(:,tt,k) = 0.90 + 0.20*rand(nJ,1);
    end
end

% ------------------------------------------------------------
% 6.3 建立销售价格的“基准趋势”PriceBase
% -------------------------------------------------------------
PriceBase = nan(nJ,nS,nT);

for j = 1:nJ
    for s = 1:nS
        if ~isfinite(Price0(j,s))
            continue;
        end

        for tt = 1:nT
            elapsed = years(tt)-2023;

            if j<=16
                % 粮食价格基本稳定
                PriceBase(j,s,tt) = Price0(j,s);

            elseif j<=37
                % 蔬菜平均每年上涨5%
                PriceBase(j,s,tt) = Price0(j,s)*1.05^elapsed;

            elseif j<=40
                % 38-40号食用菌：用1%-5%区间中点3%建立中心趋势
                PriceBase(j,s,tt) = Price0(j,s)*0.97^elapsed;

            else
                % 羊肚菌41：每年固定下降5%
                PriceBase(j,s,tt) = Price0(j,s)*0.95^elapsed;
            end
        end
    end
end

% ------------------------------------------------------------
% 6.4 相关销售价格情景 PriceScenario
% -------------------------------------------------------------
PriceScenario = nan(nJ,nS,nT,K);

% 粮食与蔬菜：在基准趋势附近作相关扰动
for k = 1:K
    for j = 1:37
        if j<=16
            sigmaP = grainPriceNoise;
        else
            sigmaP = vegPriceNoise;
        end

        for s = 1:nS
            if ~isfinite(Price0(j,s))
                continue;
            end

            for tt = 1:nT
                epsP = sigmaP*(2*UP(j,tt,k)-1);
                PriceScenario(j,s,tt,k) = ...
                    PriceBase(j,s,tt)*(1+epsP);
            end
        end
    end
end

% 食用菌38-40：将UP直接映射到1%-5%的下降率
% UP越高 -> 下降率越低 -> 价格越高
for k = 1:K
    for j = 38:40
        for s = 1:nS
            if ~isfinite(Price0(j,s))
                continue;
            end

            prevP = Price0(j,s);

            for tt = 1:nT
                declineRate = 0.05 - 0.04*UP(j,tt,k); % 1%-5%
                prevP = prevP*(1-declineRate);
                PriceScenario(j,s,tt,k) = prevP;
            end
        end
    end
end

% 羊肚菌：严格保留每年下降5%的题目趋势
j = 41;

for k = 1:K
    for s = 1:nS
        if ~isfinite(Price0(j,s))
            continue;
        end

        for tt = 1:nT
            PriceScenario(j,s,tt,k) = PriceBase(j,s,tt);
        end
    end
end

% ------------------------------------------------------------
% 6.5 价格相对偏离 DeltaPrice(j,t,k)
% 用于作物替代/互补需求修正
% -------------------------------------------------------------
DeltaPrice = zeros(nJ,nT,K);

for k = 1:K
    for tt = 1:nT
        for j = 1:nJ

            vals = [];

            for s = 1:nS
                pb = PriceBase(j,s,tt);
                ps = PriceScenario(j,s,tt,k);

                if isfinite(pb) && isfinite(ps) && pb>0
                    vals(end+1,1) = ps/pb - 1; %#ok<AGROW>
                end
            end

            if isempty(vals)
                DeltaPrice(j,tt,k) = 0;
            else
                DeltaPrice(j,tt,k) = mean(vals);
            end
        end
    end
end

% ------------------------------------------------------------
% 6.6 成本情景 CostScenario(i,j,s,t,k)
% 基准：每年增长5%
% 相关扰动：围绕基准±costNoise
% -------------------------------------------------------------
CostScenario = nan(nI,nJ,nS,nT,K);

for k = 1:K
    for tt = 1:nT
        elapsed = years(tt)-2023;
        baseFactor = 1.05^elapsed;

        for j = 1:nJ
            epsC = costNoise*(2*UC(j,tt,k)-1);
            CostScenario(:,j,:,tt,k) = ...
                Cost0(:,j,:) .* baseFactor .* (1+epsC);
        end
    end
end

fprintf('[Step 6] 销量、亩产量、价格和成本情景映射完成。\n');

%% ============================================================
% Step 7. 用作物关联矩阵修正预期销售量
% =============================================================
% H_jtk =
%   - alpha_j * DeltaPrice_jtk
%   + sum_l A(j,l)*DeltaPrice_ltk
%
% DAdjusted_jtk = DScenario_jtk * (1 + H_jtk)
%
% 为防止模拟关系过强，限制H在[-demandAdjCap,+demandAdjCap]。

DAdjusted = zeros(nJ,nT,K);
demandCorrection = zeros(nJ,nT,K);

for k = 1:K
    for tt = 1:nT
        dp = DeltaPrice(:,tt,k);

        H = -alphaSelf.*dp + Aassoc*dp;

        % 限制关联修正幅度
        H = max(-demandAdjCap,min(demandAdjCap,H));

        demandCorrection(:,tt,k) = H;
        DAdjusted(:,tt,k) = max(0,DScenario(:,tt,k).*(1+H));
    end
end

meanAbsDemandCorrection = mean(abs(demandCorrection),'all');
maxAbsDemandCorrection  = max(abs(demandCorrection),[],'all');

meanWheatGrowth2024 = mean(DScenario(6,1,:),'all')/expectedSales0(6)-1;
meanCornGrowth2024  = mean(DScenario(7,1,:),'all')/expectedSales0(7)-1;

fprintf('[Step 7] 作物关联需求修正完成。\n');
fprintf('         2024小麦基础销量平均增长率 = %.2f%%\n', ...
    100*meanWheatGrowth2024);
fprintf('         2024玉米基础销量平均增长率 = %.2f%%\n', ...
    100*meanCornGrowth2024);
fprintf('         平均绝对需求修正幅度 = %.3f%%\n', ...
    100*meanAbsDemandCorrection);
fprintf('         最大绝对需求修正幅度 = %.3f%%\n', ...
    100*maxAbsDemandCorrection);

%% ============================================================
% Step 8. 建立MILP变量编号
% =============================================================
% X：共同种植面积
% Y：共同0-1种植状态
% Z：水浇地模式
% U：每个情景下的实际销售量
% ETA：下行利润CVaR中的低收益阈值
% XI：每个情景低于阈值的不足部分

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

% U
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

fprintf('[Step 8] 变量编号完成：\n');
fprintf('         X连续变量 = %d\n',nX);
fprintf('         Y二进制变量 = %d\n',nY);
fprintf('         Z二进制变量 = %d\n',nZ);
fprintf('         U情景销售变量 = %d\n',nU);
fprintf('         CVaR变量 = %d\n',1+K);
fprintf('         总变量数 = %d\n',nVar);

%% ============================================================
% Step 9. 设置变量上下界和整数变量
% =============================================================
lb = zeros(nVar,1);
ub = inf(nVar,1);

% X上界
for tt = 1:nT
    for c = 1:nCell
        i = fi(c);
        j = fj(c);
        s = fs(c);

        ub(double(Xidx(i,j,s,tt))) = plotArea(i);
    end
end

% Y、Z为0-1变量
yLinear = double(Yidx(Yidx>0));
zLinear = double(Zidx(Zidx>0));

ub(yLinear) = 1;
ub(zLinear) = 1;

intcon = sort([yLinear;zLinear]);

% U的上界直接取关联修正后的预期销售量
for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);

            u = double(Uidx(j,s,tt,k));
            ub(u) = DAdjusted(j,tt,k);
        end
    end
end

% ETA可为任意实数
lb(ETAidx) = -inf;
ub(ETAidx) = inf;

% XI默认非负

%% ============================================================
% Step 10. 构造目标函数
% =============================================================
% 数学模型：
%
% max Z =
%   E(Pi)
%   + lambda * [
%       ETA - 1/((1-beta)K) * sum_k XI_k
%     ]
%
% Pi_k = Revenue_k - Cost_k
%
% intlinprog为最小化，因此等价写成：
%
% min
%   -E(Pi)
%   -lambda*ETA
%   +lambda/((1-beta)K)*sum_k XI_k
%
% 即：
% X系数 = 情景平均成本
% U系数 = -情景平均收入
% ETA系数 = -lambda
% XI系数 = lambda/((1-beta)K)

f = zeros(nVar,1);

% 10.1 X：情景平均成本
for tt = 1:nT
    for c = 1:nCell
        i = fi(c);
        j = fj(c);
        s = fs(c);

        x = double(Xidx(i,j,s,tt));

        costVals = squeeze(CostScenario(i,j,s,tt,:));
        f(x) = mean(costVals);
    end
end

% 10.2 U：负的情景平均销售收入
for k = 1:K
    for tt = 1:nT
        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);

            u = double(Uidx(j,s,tt,k));
            p = PriceScenario(j,s,tt,k);

            f(u) = -(1/K)*p;
        end
    end
end

% 10.3 下行CVaR项
f(ETAidx) = -lambdaRisk;

for k = 1:K
    f(double(XIidx(k))) = ...
        lambdaRisk/((1-beta)*K);
end

%% ============================================================
% Step 11. 构造农业生产、销售与CVaR约束
% =============================================================
ineqCols = cell(0,1);
ineqVals = cell(0,1);
ineqRhs  = zeros(0,1);

eqCols = cell(0,1);
eqVals = cell(0,1);
eqRhs  = zeros(0,1);

% ------------------------------------------------------------
% 11.1 X-Y关联：
% 0.1*A_i*y <= x <= A_i*y
% -------------------------------------------------------------
for tt = 1:nT
    for c = 1:nCell
        i = fi(c);
        j = fj(c);
        s = fs(c);

        x = double(Xidx(i,j,s,tt));
        y = double(Yidx(i,j,s,tt));

        Ai = plotArea(i);
        Li = minAreaRatio*Ai;

        addIneq([x,y],[1,-Ai],0);
        addIneq([x,y],[-1,Li],0);
    end
end

dryPlots = find( ...
    plotTypes=="平旱地" | ...
    plotTypes=="梯田"   | ...
    plotTypes=="山坡地");

ordinaryPlots = find(plotTypes=="普通大棚");
smartPlots = find(plotTypes=="智慧大棚");

% ------------------------------------------------------------
% 11.2 平旱地、梯田、山坡地：第一季粮食面积用满
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
% 11.3 水浇地：一季水稻或两季蔬菜
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(waterPlots)
        i = waterPlots(kk);
        z = double(Zidx(i,tt));

        % 水稻
        xRice = double(Xidx(i,16,1,tt));
        addEq([xRice,z],[1,-plotArea(i)],0);

        % 第一季蔬菜
        idxS1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idxS1 = idxS1(idxS1>0);

        addEq([idxS1(:);z], ...
            [ones(numel(idxS1),1);plotArea(i)], ...
            plotArea(i));

        % 第二季蔬菜
        idxS2 = double(squeeze(Xidx(i,35:37,2,tt)));
        idxS2 = idxS2(idxS2>0);

        addEq([idxS2(:);z], ...
            [ones(numel(idxS2),1);plotArea(i)], ...
            plotArea(i));

        % 第二季只能选择一种35-37号蔬菜
        yS2 = double(squeeze(Yidx(i,35:37,2,tt)));
        yS2 = yS2(yS2>0);

        addEq([yS2(:);z], ...
            [ones(numel(yS2),1);1],1);
    end
end

% ------------------------------------------------------------
% 11.4 普通大棚：第一季蔬菜、第二季食用菌
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
% 11.5 智慧大棚：两季均种17-34号蔬菜
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
% 11.6 同一种作物同年同季最多6个地块
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
% 11.7 禁止连续重茬
% -------------------------------------------------------------

% (a) 平旱地、梯田、山坡地
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

% (b) 水浇地水稻不能连续两年
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

% (c) 智慧大棚相邻种植季不能同作物
for kk = 1:numel(smartPlots)
    i = smartPlots(kk);

    for j = 17:34

        % 同一年第一季 -> 第二季
        for tt = 1:nT
            y1 = double(Yidx(i,j,1,tt));
            y2 = double(Yidx(i,j,2,tt));

            addIneq([y1,y2],[1,1],1);
        end

        % 第二季 -> 下一年第一季
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
% 11.8 三年豆类轮作（沿用问题二面积等价处理）
% -------------------------------------------------------------
beanCrops = [1:5,17:19];

for i = 1:nI

    histBeanArea = sum(histX(i,beanCrops,:),'all');

    % 2023-2025
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
% 11.9 每个情景的产量-销售量约束
%
% u_jstk <= sum_i q_ijst^k*x_ijst
%
% u <= DAdjusted 已通过U变量上界实现
% -------------------------------------------------------------
fprintf('[Step 11] 正在建立%d个相关情景的产量-销售约束...\n',K);

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

            addIneq(cols,vals,0);
        end
    end
end

% ------------------------------------------------------------
% 11.10 下行利润CVaR约束
%
% xi_k >= eta - Pi_k
%
% Pi_k = Revenue_k - Cost_k
%
% 等价：
% Cost_k - Revenue_k + eta - xi_k <= 0
% -------------------------------------------------------------
for k = 1:K

    cols = [];
    vals = [];

    % + Cost_k
    for tt = 1:nT
        for c = 1:nCell
            i = fi(c);
            j = fj(c);
            s = fs(c);

            x = double(Xidx(i,j,s,tt));

            cols(end+1,1) = x; %#ok<AGROW>
            vals(end+1,1) = CostScenario(i,j,s,tt,k); %#ok<AGROW>
        end
    end

    % - Revenue_k
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

    % + ETA - XI_k
    cols(end+1,1) = ETAidx;
    vals(end+1,1) = 1;

    cols(end+1,1) = double(XIidx(k));
    vals(end+1,1) = -1;

    addIneq(cols,vals,0);
end

%% ============================================================
% Step 12. 打包稀疏约束矩阵、构造Q2 warm start并求解
% =============================================================
[A,b] = packRows(ineqCols,ineqVals,ineqRhs,nVar);
[Aeq,beq] = packRows(eqCols,eqVals,eqRhs,nVar);

fprintf('[Step 12] 约束矩阵构造完成：\n');
fprintf('          不等式约束 = %d\n',size(A,1));
fprintf('          等式约束 = %d\n',size(Aeq,1));
fprintf('          nnz(A) = %d\n',nnz(A));
fprintf('          nnz(Aeq) = %d\n',nnz(Aeq));
fprintf('          整数变量 = %d\n\n',numel(intcon));

% ------------------------------------------------------------
% 12.1 用问题二方案构造完整warm start
% ------------------------------------------------------------
% warm start必须包含全部变量：
% X / Y / Z / U / ETA / XI
%
% 这样求解器一开始就拥有一个已知可行整数方案。
% 若Q2方案在同一组Q3相关情景下的综合目标优于之前找到的Q3方案，
% 求解器不会再从一个更差的incumbent开始搜索。

useWarmStart = false;
x0 = [];
warmObjMin = NaN;
warmExpected = NaN;
warmLCVaR = NaN;
warmMinProfit = NaN;

if strlength(string(q2ResultFile))>0

    fprintf('------------------------------------------------------------\n');
    fprintf('正在从问题二方案构造Q3 warm start...\n');

    Xwarm = readResultWorkbook( ...
        q2ResultFile,nI,nJ,nS,nT,plotTypes,years);

    x0 = zeros(nVar,1);

    % ----- X与Y -----
    for tt = 1:nT
        for c = 1:nCell
            i = fi(c);
            j = fj(c);
            s = fs(c);

            xind = double(Xidx(i,j,s,tt));
            yind = double(Yidx(i,j,s,tt));

            area = Xwarm(i,j,s,tt);

            if abs(area)<1e-8
                area = 0;
            end

            x0(xind) = area;
            x0(yind) = double(area>1e-8);
        end
    end

    % ----- Z：根据Q2方案中的水稻面积恢复水浇地模式 -----
    for tt = 1:nT
        for kk = 1:numel(waterPlots)
            i = waterPlots(kk);
            zind = double(Zidx(i,tt));

            xRiceWarm = Xwarm(i,16,1,tt);

            if xRiceWarm > 0.5*plotArea(i)
                x0(zind) = 1;
            else
                x0(zind) = 0;
            end
        end
    end

    % ----- U：在同一组Q3相关情景下取 min(产量,修正需求) -----
    for k = 1:K
        for tt = 1:nT
            for pp = 1:nPair
                j = pairJ(pp);
                s = pairS(pp);

                production = 0;
                scale = YieldScale(j,tt,k);

                for i = 1:nI
                    if isfinite(Yield0(i,j,s))
                        production = production + ...
                            Yield0(i,j,s)*scale*Xwarm(i,j,s,tt);
                    end
                end

                sold = min(production,DAdjusted(j,tt,k));
                uind = double(Uidx(j,s,tt,k));
                x0(uind) = max(0,sold);
            end
        end
    end

    % ----- 先评价Q2方案在同一Q3相关情景下的利润 -----
    [~,~,~,warmScenarioProfit] = ...
        evaluatePlan(Xwarm,Yield0,YieldScale,PriceScenario, ...
        CostScenario,DAdjusted,pairJ,pairS,K,nT,nI);

    warmExpected = mean(warmScenarioProfit);
    warmMinProfit = min(warmScenarioProfit);

    % ----- ETA / XI：取固定方案下最优下行CVaR -----
    [etaWarm,warmLCVaR] = computeLowerCVaR( ...
        warmScenarioProfit,beta);

    x0(ETAidx) = etaWarm;

    for k = 1:K
        x0(double(XIidx(k))) = ...
            max(etaWarm-warmScenarioProfit(k),0);
    end

    % ----- warm start可行性检查 -----
    ineqViol = max([0; A*x0-b]);
    eqViol = max([0; abs(Aeq*x0-beq)]);
    lbViol = max([0; lb-x0]);
    ubViol = max([0; x0-ub]);

    if isempty(intcon)
        intViol = 0;
    else
        intViol = max(abs(x0(intcon)-round(x0(intcon))));
    end

    warmObjMin = f.'*x0;
    warmObjEconomic = -warmObjMin;

    fprintf('Q2 warm start同情景平均利润 = %.4f 万元\n', ...
        warmExpected/1e4);
    fprintf('Q2 warm start同情景下行CVaR = %.4f 万元\n', ...
        warmLCVaR/1e4);
    fprintf('Q2 warm start最差情景利润 = %.4f 万元\n', ...
        warmMinProfit/1e4);
    fprintf('Q2 warm start综合目标 = %.4f 万元\n', ...
        warmObjEconomic/1e4);

    fprintf('warm start最大不等式违反 = %.3e\n',ineqViol);
    fprintf('warm start最大等式违反 = %.3e\n',eqViol);
    fprintf('warm start最大下界违反 = %.3e\n',lbViol);
    fprintf('warm start最大上界违反 = %.3e\n',ubViol);
    fprintf('warm start最大整数违反 = %.3e\n',intViol);

    warmTol = 5e-6;

    if ineqViol<=warmTol && ...
       eqViol<=warmTol && ...
       lbViol<=warmTol && ...
       ubViol<=warmTol && ...
       intViol<=warmTol

        useWarmStart = true;
        fprintf('warm start检查通过：将作为intlinprog初始可行解。\n');

    else
        warning(['Q2 warm start未通过严格可行性检查，', ...
                 '本次不传入x0。请检查Q2结果文件精度。']);
        x0 = [];
    end

    fprintf('------------------------------------------------------------\n');
else
    fprintf('未找到Q2结果文件，本次无法使用warm start。\n');
end

% ------------------------------------------------------------
% 12.2 更严格的求解设置
% ------------------------------------------------------------
options = optimoptions('intlinprog', ...
    'Display','iter', ...
    'MaxTime',maxSolveTime, ...
    'RelativeGapTolerance',relativeGap);

fprintf('============================================================\n');
fprintf('开始求解问题三 MILP...\n');
fprintf('最大时间 = %d秒，相对Gap阈值 = %.3f%%\n', ...
    maxSolveTime,100*relativeGap);

if useWarmStart
    fprintf('已启用Q2完整warm start。\n');
else
    fprintf('未启用warm start。\n');
end

fprintf('============================================================\n');

tic;

if useWarmStart

    [sol,fval,exitflag,output] = intlinprog( ...
        f,intcon,A,b,Aeq,beq,lb,ub,x0,options);

else

    [sol,fval,exitflag,output] = intlinprog( ...
        f,intcon,A,b,Aeq,beq,lb,ub,options);
end

solveTime = toc;

if isempty(sol)
    error('问题三未得到可行解。exitflag=%d',exitflag);
end

% ------------------------------------------------------------
% 12.3 安全检查：最终解不得比可行warm start更差
% ------------------------------------------------------------
% 对最小化目标而言，fval越小越好。
% 正常情况下，只要intlinprog接受了可行x0，最终结果不会比x0差。
% 这里额外加一道保护，避免任何版本差异或异常返回。

usedWarmFallback = false;

if useWarmStart
    objTol = 1e-7*max(1,abs(warmObjMin));

    if fval > warmObjMin + objTol

        warning(['求解器返回解的目标值比warm start差，', ...
                 '程序自动保留Q2 warm start作为最终可行解。']);

        sol = x0;
        fval = warmObjMin;
        usedWarmFallback = true;
    end
end

fprintf('\n[Step 12] 求解完成，用时 %.1f 秒。\n',solveTime);
fprintf('          exitflag = %d\n',exitflag);

if isfield(output,'relativegap')
    fprintf('          relative gap = %.4f%%\n', ...
        100*output.relativegap);
end

if isfield(output,'numnodes')
    fprintf('          分支定界节点数 = %d\n',output.numnodes);
end

if useWarmStart
    fprintf('          warm start综合目标 = %.4f 万元\n', ...
        -warmObjMin/1e4);
    fprintf('          最终综合目标 = %.4f 万元\n', ...
        -fval/1e4);

    if usedWarmFallback
        fprintf('          注意：最终采用warm start保护解。\n');
    else
        fprintf('          最终解不差于warm start。\n');
    end
end

%% ============================================================
% Step 13. 恢复问题三种植方案
% =============================================================
X3 = zeros(nI,nJ,nS,nT);

for tt = 1:nT
    for c = 1:nCell
        i = fi(c);
        j = fj(c);
        s = fs(c);

        val = sol(double(Xidx(i,j,s,tt)));

        if abs(val)<1e-6
            val = 0;
        end

        X3(i,j,s,tt) = val;
    end
end

etaSol = sol(ETAidx);

xiSol = zeros(K,1);

for k = 1:K
    xiSol(k) = sol(double(XIidx(k)));
end

% 在相同相关情景下重新评价最终方案
[scenarioYearRevenue3,scenarioYearCost3,scenarioYearProfit3,scenarioProfit3] = ...
    evaluatePlan(X3,Yield0,YieldScale,PriceScenario, ...
    CostScenario,DAdjusted,pairJ,pairS,K,nT,nI);

expectedProfit3 = mean(scenarioProfit3);
medianProfit3   = median(scenarioProfit3);
stdProfit3      = std(scenarioProfit3);
minProfit3      = min(scenarioProfit3);
maxProfit3      = max(scenarioProfit3);

% 求解器模型中的下行CVaR值
lcvarModel3 = etaSol - ...
    sum(xiSol)/((1-beta)*K);

% 根据最终利润样本重新计算一次经验LCVaR，用于校验
[etaEmp3,lcvarEmp3] = computeLowerCVaR(scenarioProfit3,beta);

objective3 = expectedProfit3 + lambdaRisk*lcvarModel3;

% 年度统计
expectedYearProfit3 = mean(scenarioYearProfit3,1)';
medianYearProfit3   = median(scenarioYearProfit3,1)';
minYearProfit3      = min(scenarioYearProfit3,[],1)';
maxYearProfit3      = max(scenarioYearProfit3,[],1)';

p05YearProfit3 = zeros(nT,1);
p95YearProfit3 = zeros(nT,1);

for tt = 1:nT
    p05YearProfit3(tt) = empiricalQuantile( ...
        scenarioYearProfit3(:,tt),0.05);

    p95YearProfit3(tt) = empiricalQuantile( ...
        scenarioYearProfit3(:,tt),0.95);
end

fprintf('\n================= 问题三关键结果 =================\n');
fprintf('情景平均七年利润 = %.4f 万元\n',expectedProfit3/1e4);
fprintf('情景七年利润中位数 = %.4f 万元\n',medianProfit3/1e4);
fprintf('情景七年利润标准差 = %.4f 万元\n',stdProfit3/1e4);
fprintf('最差情景七年利润 = %.4f 万元\n',minProfit3/1e4);
fprintf('最好情景七年利润 = %.4f 万元\n',maxProfit3/1e4);
fprintf('ETA低收益阈值 = %.4f 万元\n',etaSol/1e4);
fprintf('下行CVaR利润（模型） = %.4f 万元\n',lcvarModel3/1e4);
fprintf('下行CVaR利润（经验校验） = %.4f 万元\n',lcvarEmp3/1e4);
fprintf('综合目标值 E(Pi)+lambda*LCVaR = %.4f 万元\n', ...
    objective3/1e4);
fprintf('====================================================\n');

yearTable3 = table( ...
    years(:), ...
    expectedYearProfit3/1e4, ...
    medianYearProfit3/1e4, ...
    p05YearProfit3/1e4, ...
    p95YearProfit3/1e4, ...
    minYearProfit3/1e4, ...
    maxYearProfit3/1e4, ...
    'VariableNames',{ ...
    'Year','ExpectedProfit_万元','MedianProfit_万元', ...
    'P05Profit_万元','P95Profit_万元', ...
    'MinProfit_万元','MaxProfit_万元'});

disp(yearTable3);

%% ============================================================
% Step 14. 在同一组Q3相关情景下评价问题二方案
% =============================================================
hasQ2 = strlength(string(q2ResultFile))>0;

X2 = [];
scenarioProfit2 = [];
scenarioYearProfit2 = [];
expectedProfit2 = NaN;
medianProfit2 = NaN;
stdProfit2 = NaN;
minProfit2 = NaN;
maxProfit2 = NaN;
lcvar2 = NaN;
eta2 = NaN;

if hasQ2

    X2 = readResultWorkbook( ...
        q2ResultFile,nI,nJ,nS,nT,plotTypes,years);

    [~,~,scenarioYearProfit2,scenarioProfit2] = ...
        evaluatePlan(X2,Yield0,YieldScale,PriceScenario, ...
        CostScenario,DAdjusted,pairJ,pairS,K,nT,nI);

    expectedProfit2 = mean(scenarioProfit2);
    medianProfit2   = median(scenarioProfit2);
    stdProfit2      = std(scenarioProfit2);
    minProfit2      = min(scenarioProfit2);
    maxProfit2      = max(scenarioProfit2);

    [eta2,lcvar2] = computeLowerCVaR(scenarioProfit2,beta);

    fprintf('\n========== 问题二方案在同一Q3相关情景下的表现 ==========\n');
    fprintf('Q2方案情景平均七年利润 = %.4f 万元\n',expectedProfit2/1e4);
    fprintf('Q2方案下行CVaR利润 = %.4f 万元\n',lcvar2/1e4);
    fprintf('Q2方案最差情景利润 = %.4f 万元\n',minProfit2/1e4);

    fprintf('\n================= Q2 vs Q3 同情景比较 =================\n');
    fprintf('平均利润变化 = %.4f 万元（%+.3f%%）\n', ...
        (expectedProfit3-expectedProfit2)/1e4, ...
        100*(expectedProfit3/expectedProfit2-1));

    fprintf('下行CVaR变化 = %.4f 万元（%+.3f%%）\n', ...
        (lcvarModel3-lcvar2)/1e4, ...
        100*(lcvarModel3/lcvar2-1));

    fprintf('最差情景利润变化 = %.4f 万元\n', ...
        (minProfit3-minProfit2)/1e4);
    fprintf('========================================================\n');
end

%% ============================================================
% Step 15. 写入问题三种植方案Excel
% =============================================================
writeResultWorkbook(template2,outResult,X3,plotTypes,years);

fprintf('\n[Step 15] 已生成问题三种植方案：\n%s\n',outResult);

%% ============================================================
% Step 16. 输出Q3分析Excel
% =============================================================
if isfile(outAnalysis)
    delete(outAnalysis);
end

% ------------------------------------------------------------
% 16.1 参数设置
% -------------------------------------------------------------
paramName = [ ...
    "情景数K"; ...
    "CVaR置信水平beta"; ...
    "风险权重lambda"; ...
    "随机种子"; ...
    "rho_DP"; ...
    "rho_DC"; ...
    "rho_PC"; ...
    "粮食价格扰动幅度"; ...
    "蔬菜价格扰动幅度"; ...
    "成本扰动幅度"; ...
    "自身价格响应alpha"; ...
    "同类替代总强度"; ...
    "豆类非豆类互补总强度"; ...
    "需求修正上限"; ...
    "最小种植面积比例"; ...
    "单作物单季最大地块数"; ...
    "最大求解时间_秒"; ...
    "RelativeGapTolerance"];

paramValue = [ ...
    K;beta;lambdaRisk;randomSeed; ...
    rhoDP;rhoDC;rhoPC; ...
    grainPriceNoise;vegPriceNoise;costNoise; ...
    selfAlpha;subTotal;compTotal;demandAdjCap; ...
    minAreaRatio;maxPlotsPerCropSeason; ...
    maxSolveTime;relativeGap];

Tparam = table(paramName,paramValue, ...
    'VariableNames',{'参数','数值'});

writetable(Tparam,outAnalysis,'Sheet','参数设置');

% ------------------------------------------------------------
% 16.2 目标相关矩阵与样本相关矩阵
% -------------------------------------------------------------
corrLabels = {'变量','销量驱动','价格驱动','成本驱动'};

targetCell = cell(4,4);
targetCell(1,:) = corrLabels;
targetCell(2:4,1) = {'销量驱动';'价格驱动';'成本驱动'};

empZCell = targetCell;
empUCell = targetCell;

for r = 1:3
    for c = 1:3
        targetCell{r+1,c+1} = Rtarget(r,c);
        empZCell{r+1,c+1} = empCorrZ(r,c);
        empUCell{r+1,c+1} = empCorrU(r,c);
    end
end

writecell(targetCell,outAnalysis,'Sheet','目标相关矩阵','Range','A1');
writecell(empZCell,outAnalysis,'Sheet','样本相关矩阵Z','Range','A1');
writecell(empUCell,outAnalysis,'Sheet','样本相关矩阵U','Range','A1');

% ------------------------------------------------------------
% 16.3 Q3风险指标
% -------------------------------------------------------------
metricName3 = [ ...
    "情景平均七年利润_万元"; ...
    "七年利润中位数_万元"; ...
    "七年利润标准差_万元"; ...
    "最差情景七年利润_万元"; ...
    "最好情景七年利润_万元"; ...
    "ETA低收益阈值_万元"; ...
    "下行CVaR利润_模型_万元"; ...
    "下行CVaR利润_经验校验_万元"; ...
    "综合目标值_万元"; ...
    "求解时间_秒"; ...
    "平均绝对需求修正_pct"; ...
    "最大绝对需求修正_pct"];

metricValue3 = [ ...
    expectedProfit3/1e4; ...
    medianProfit3/1e4; ...
    stdProfit3/1e4; ...
    minProfit3/1e4; ...
    maxProfit3/1e4; ...
    etaSol/1e4; ...
    lcvarModel3/1e4; ...
    lcvarEmp3/1e4; ...
    objective3/1e4; ...
    solveTime; ...
    100*meanAbsDemandCorrection; ...
    100*maxAbsDemandCorrection];

Tmetric3 = table(metricName3,metricValue3, ...
    'VariableNames',{'指标','数值'});

writetable(Tmetric3,outAnalysis,'Sheet','Q3风险指标');

% ------------------------------------------------------------
% 16.4 情景利润
% -------------------------------------------------------------
if hasQ2
    Tscenario = table( ...
        (1:K)', ...
        scenarioProfit2/1e4, ...
        scenarioProfit3/1e4, ...
        (scenarioProfit3-scenarioProfit2)/1e4, ...
        'VariableNames',{ ...
        '情景编号','Q2方案利润_万元','Q3方案利润_万元','利润差_Q3减Q2_万元'});
else
    Tscenario = table( ...
        (1:K)',scenarioProfit3/1e4, ...
        'VariableNames',{'情景编号','Q3方案利润_万元'});
end

writetable(Tscenario,outAnalysis,'Sheet','情景利润');

% ------------------------------------------------------------
% 16.5 年度利润
% -------------------------------------------------------------
Tyear3 = table( ...
    years(:), ...
    expectedYearProfit3/1e4, ...
    medianYearProfit3/1e4, ...
    p05YearProfit3/1e4, ...
    p95YearProfit3/1e4, ...
    minYearProfit3/1e4, ...
    maxYearProfit3/1e4, ...
    'VariableNames',{ ...
    '年份','Q3期望利润_万元','Q3中位数利润_万元', ...
    'Q3_P05利润_万元','Q3_P95利润_万元', ...
    'Q3最小利润_万元','Q3最大利润_万元'});

writetable(Tyear3,outAnalysis,'Sheet','年度利润_Q3');

% ------------------------------------------------------------
% 16.6 Q2/Q3风险比较
% -------------------------------------------------------------
if hasQ2

    compareMetric = [ ...
        "情景平均七年利润_万元"; ...
        "七年利润中位数_万元"; ...
        "七年利润标准差_万元"; ...
        "最差情景七年利润_万元"; ...
        "最好情景七年利润_万元"; ...
        "下行CVaR利润_万元"];

    q2Value = [ ...
        expectedProfit2;medianProfit2;stdProfit2; ...
        minProfit2;maxProfit2;lcvar2]/1e4;

    q3Value = [ ...
        expectedProfit3;medianProfit3;stdProfit3; ...
        minProfit3;maxProfit3;lcvarModel3]/1e4;

    Tcompare = table( ...
        compareMetric,q2Value,q3Value,q3Value-q2Value, ...
        'VariableNames',{ ...
        '指标','Q2方案_同Q3情景','Q3方案_同Q3情景','Q3减Q2'});

    writetable(Tcompare,outAnalysis,'Sheet','Q2Q3风险比较');

    expectedYearProfit2 = mean(scenarioYearProfit2,1)';

    TyearCompare = table( ...
        years(:), ...
        expectedYearProfit2/1e4, ...
        expectedYearProfit3/1e4, ...
        (expectedYearProfit3-expectedYearProfit2)/1e4, ...
        'VariableNames',{ ...
        '年份','Q2期望利润_万元','Q3期望利润_万元','Q3减Q2_万元'});

    writetable(TyearCompare,outAnalysis,'Sheet','Q2Q3年度比较');
end

% ------------------------------------------------------------
% 16.7 作物累计面积及变化
% -------------------------------------------------------------
cropArea3 = zeros(nJ,1);

for j = 1:nJ
    temp = X3(:,j,:,:);
    cropArea3(j) = sum(temp(:));
end

Tcrop3 = table( ...
    cropIds(:),cropNames(:),cropArea3, ...
    'VariableNames',{ ...
    '作物编号','作物名称','Q3_2024至2030累计种植面积_亩'});

Tcrop3 = sortrows(Tcrop3, ...
    'Q3_2024至2030累计种植面积_亩','descend');

writetable(Tcrop3,outAnalysis,'Sheet','Q3作物累计面积');

if hasQ2

    cropArea2 = zeros(nJ,1);

    for j = 1:nJ
        temp = X2(:,j,:,:);
        cropArea2(j) = sum(temp(:));
    end

    cropAreaDiff = cropArea3-cropArea2;

    TcropDiff = table( ...
        cropIds(:),cropNames(:), ...
        cropArea2,cropArea3,cropAreaDiff,abs(cropAreaDiff), ...
        'VariableNames',{ ...
        '作物编号','作物名称','Q2累计面积_亩','Q3累计面积_亩', ...
        '面积变化_Q3减Q2_亩','绝对变化_亩'});

    TcropDiff = sortrows(TcropDiff,'绝对变化_亩','descend');

    writetable(TcropDiff,outAnalysis,'Sheet','Q2Q3作物面积变化');
end

% ------------------------------------------------------------
% 16.8 作物关联矩阵A
% -------------------------------------------------------------
assocCell = cell(nJ+1,nJ+1);
assocCell{1,1} = '作物';

for j = 1:nJ
    assocCell{1,j+1} = char(cropNames(j));
    assocCell{j+1,1} = char(cropNames(j));
end

for j = 1:nJ
    for l = 1:nJ
        assocCell{j+1,l+1} = Aassoc(j,l);
    end
end

writecell(assocCell,outAnalysis,'Sheet','作物关联矩阵');

fprintf('[Step 16] 已生成分析Excel：\n%s\n',outAnalysis);

%% ============================================================
% Step 17. 绘制必要图像
% =============================================================

% ------------------------------------------------------------
% 图1：相关驱动变量样本相关矩阵
% -------------------------------------------------------------
figure('Color','w','Position',[100 80 720 620]);

imagesc(empCorrZ,[-1,1]);
axis square;
colorbar;

set(gca, ...
    'XTick',1:3, ...
    'YTick',1:3, ...
    'XTickLabel',{'销量','价格','成本'}, ...
    'YTickLabel',{'销量','价格','成本'});

for r = 1:3
    for c = 1:3
        text(c,r,sprintf('%.2f',empCorrZ(r,c)), ...
            'HorizontalAlignment','center', ...
            'FontSize',12);
    end
end

title('Gaussian Copula驱动变量样本相关矩阵');
saveFig(figDir,'图1_Copula样本相关矩阵.png');

% ------------------------------------------------------------
% 图2：Q3相关情景利润分布
% -------------------------------------------------------------
figure('Color','w','Position',[100 80 920 560]);

histogram(scenarioProfit3/1e4,10);
hold on;

xline(expectedProfit3/1e4,'--','平均利润','LineWidth',1.5);
xline(lcvarModel3/1e4,'-.','下行CVaR利润','LineWidth',1.5);

grid on;
xlabel('2024—2030七年总利润/万元');
ylabel('情景数量');
title(sprintf('问题三相关情景利润分布（K=%d，\\beta=%.2f）',K,beta));

saveFig(figDir,'图2_Q3相关情景利润分布.png');

% ------------------------------------------------------------
% 图3：Q2/Q3同一相关情景下利润排序比较
% -------------------------------------------------------------
if hasQ2
    sorted2 = sort(scenarioProfit2,'ascend');
    sorted3 = sort(scenarioProfit3,'ascend');

    figure('Color','w','Position',[100 80 980 570]);

    plot(1:K,sorted2/1e4,'--s', ...
        'LineWidth',1.3,'MarkerSize',5);
    hold on;

    plot(1:K,sorted3/1e4,'-o', ...
        'LineWidth',1.6,'MarkerSize',5);

    yline(lcvar2/1e4,':','Q2下行CVaR','LineWidth',1.2);
    yline(lcvarModel3/1e4,'-.','Q3下行CVaR','LineWidth',1.2);

    grid on;
    xlabel('情景排序（由低利润到高利润）');
    ylabel('七年总利润/万元');
    title('问题二与问题三方案在同一相关情景下的利润比较');
    legend({'问题二方案','问题三方案','Q2下行CVaR','Q3下行CVaR'}, ...
        'Location','best');

    saveFig(figDir,'图3_Q2Q3同情景利润排序比较.png');
end

% ------------------------------------------------------------
% 图4：年度期望利润与Q3不确定性区间
% -------------------------------------------------------------
figure('Color','w','Position',[100 80 980 570]);

xYear = years(:);
low = p05YearProfit3/1e4;
high = p95YearProfit3/1e4;

fill([xYear;flipud(xYear)],[low;flipud(high)], ...
    [0.85 0.85 0.85], ...
    'EdgeColor','none','FaceAlpha',0.45);
hold on;

plot(years,expectedYearProfit3/1e4,'-o', ...
    'LineWidth',1.8,'MarkerSize',7);

if hasQ2
    expectedYearProfit2 = mean(scenarioYearProfit2,1)';

    plot(years,expectedYearProfit2/1e4,'--s', ...
        'LineWidth',1.4,'MarkerSize',6);

    legend({'Q3的5%-95%情景区间','Q3期望利润','Q2期望利润'}, ...
        'Location','best');
else
    legend({'Q3的5%-95%情景区间','Q3期望利润'}, ...
        'Location','best');
end

grid on;
xlabel('年份');
ylabel('利润/万元');
title('问题三年度利润与相关情景不确定性');
xticks(years);

saveFig(figDir,'图4_年度利润与不确定性区间.png');

% ------------------------------------------------------------
% 图5：Q2/Q3作物累计种植面积变化TOP15
% -------------------------------------------------------------
if hasQ2

    cropArea2 = zeros(nJ,1);

    for j = 1:nJ
        temp = X2(:,j,:,:);
        cropArea2(j) = sum(temp(:));
    end

    cropDiff = cropArea3-cropArea2;

    [~,ordDiff] = sort(abs(cropDiff),'descend');
    topN = min(15,nJ);
    top = ordDiff(1:topN);

    figure('Color','w','Position',[100 80 1000 650]);

    barh(1:topN,cropDiff(top));
    set(gca, ...
        'YTick',1:topN, ...
        'YTickLabel',cropNames(top), ...
        'YDir','reverse');

    xline(0,'-');
    grid on;

    xlabel('累计种植面积变化（Q3-Q2）/亩');
    ylabel('作物');
    title('考虑相关性和作物关联后种植面积变化TOP15');

    saveFig(figDir,'图5_Q2Q3作物面积变化TOP15.png');

else

    [sortedArea,ord] = sort(cropArea3,'descend');
    topN = min(12,nJ);
    top = ord(1:topN);

    figure('Color','w','Position',[100 80 1000 620]);

    barh(1:topN,sortedArea(1:topN));
    set(gca, ...
        'YTick',1:topN, ...
        'YTickLabel',cropNames(top), ...
        'YDir','reverse');

    grid on;
    xlabel('2024—2030累计种植面积/亩');
    ylabel('作物');
    title('问题三主要作物累计种植面积');

    saveFig(figDir,'图5_Q3主要作物累计面积.png');
end

% ------------------------------------------------------------
% 图6：Q3作物类别年度种植结构
% -------------------------------------------------------------
catNames = ["粮食非豆类","粮食豆类","蔬菜非豆类","蔬菜豆类","食用菌"];
catCrop = {6:16,1:5,20:37,17:19,38:41};

catArea3 = zeros(nT,5);

for cc = 1:5
    ids = catCrop{cc};

    for tt = 1:nT
        temp = X3(:,ids,:,tt);
        catArea3(tt,cc) = sum(temp(:));
    end
end

figure('Color','w','Position',[100 80 1000 580]);

bar(years,catArea3,'stacked');
grid on;

xlabel('年份');
ylabel('种植面积/亩次');
title('问题三各类作物年度种植结构');

legend(cellstr(catNames),'Location','bestoutside');

saveFig(figDir,'图6_Q3作物类别年度种植结构.png');

fprintf('[Step 17] 图像已保存到：\n%s\n',figDir);

%% ============================================================
% Step 18. 最终说明
% =============================================================
fprintf('\n============================================================\n');
fprintf('问题三程序运行完成。\n');
fprintf('1) result3_MATLAB_Copula_CVaR.xlsx：问题三种植方案。\n');
fprintf('2) Q3_相关性风险分析.xlsx：风险、相关性及Q2/Q3比较表。\n');
fprintf('3) Q3_figures：相关矩阵、利润风险和种植结构图。\n');

fprintf('\n结果解释：\n');
fprintf('- 平均利润：同一Q3种植方案在%d个相关未来情景中的平均七年利润；\n',K);
fprintf('- 标准差：相关情景改变后，七年总利润的波动程度；\n');
fprintf('- 最差情景利润：本次%d个模拟样本中最不利情景的表现；\n',K);
fprintf('- 下行CVaR利润：低收益尾部情景的综合利润水平，越高越好；\n');
fprintf('- Q2/Q3比较：若读取到Q2结果，则把两套方案放入同一组Q3相关情景中评价，\n');
fprintf('  从而避免因情景不同而造成不公平比较；\n');
fprintf('- 作物面积变化：体现加入相关性、替代性和互补性后种植结构的调整方向。\n');

fprintf('\n特别注意：\n');
fprintf('本版本已启用Q2 warm start（若找到Q2结果）并把Gap收紧到0.5%%。\n');
fprintf('rho、价格/成本扰动幅度、alpha和作物关联强度均属于模拟情景参数，\n');
fprintf('不是附件直接统计得到的参数；正式论文如需说明其合理性，应进行敏感性分析。\n');
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

function [A,info] = buildAssociationMatrix(nJ,subTotal,compTotal)
% 构造“基准作物关联情景”。
%
% 同类内部设替代关系（交叉价格系数为正）：
%   1:5   粮食豆类
%   6:16  粮食非豆类（含水稻）
%   17:19 蔬菜豆类
%   20:37 其他蔬菜
%   38:41 食用菌
%
% 弱互补关系：
%   粮食豆类 <-> 粮食非豆类
%   蔬菜豆类 <-> 其他蔬菜
%
% 为避免组内作物数量越多总影响越强，
% subTotal / compTotal 按每一行的关联对象数量均分。

A = zeros(nJ,nJ);

groups = { ...
    1:5, ...
    6:16, ...
    17:19, ...
    20:37, ...
    38:41};

% 同类替代
for gg = 1:numel(groups)

    g = groups{gg};

    if numel(g)<=1
        continue;
    end

    coeff = subTotal/(numel(g)-1);

    for a = 1:numel(g)
        j = g(a);

        others = g;
        others(a) = [];

        A(j,others) = coeff;
    end
end

% 粮食豆类与粮食非豆类弱互补
gBean = 1:5;
gGrain = 6:16;

for j = gBean
    A(j,gGrain) = compTotal/numel(gGrain);
end

for j = gGrain
    A(j,gBean) = compTotal/numel(gBean);
end

% 蔬菜豆类与其他蔬菜弱互补
gVegBean = 17:19;
gVeg = 20:37;

for j = gVegBean
    A(j,gVeg) = compTotal/numel(gVeg);
end

for j = gVeg
    A(j,gVegBean) = compTotal/numel(gVegBean);
end

% 对角线严格为0
A(1:nJ+1:end) = 0;

info = table( ...
    ["同类作物";"粮食豆类-非豆粮食";"蔬菜豆类-其他蔬菜"], ...
    ["替代";"互补";"互补"], ...
    [subTotal;compTotal;compTotal], ...
    'VariableNames',{'关系组','关系类型','每行总作用强度'});
end

function [revYear,costYear,profitYear,profitTotal] = evaluatePlan( ...
    X,Yield0,YieldScale,PriceScenario,CostScenario,DAdjusted, ...
    pairJ,pairS,K,nT,nI)
% 在给定的同一组Q3相关情景下评价一套固定种植方案。
%
% 这里不需要优化销售变量，因为价格均为正，
% 实际销售量直接为 min(产量,关联修正后需求)。

nPair = numel(pairJ);

revYear = zeros(K,nT);
costYear = zeros(K,nT);
profitYear = zeros(K,nT);

for k = 1:K
    for tt = 1:nT

        revenue = 0;

        for pp = 1:nPair
            j = pairJ(pp);
            s = pairS(pp);

            production = 0;
            scale = YieldScale(j,tt,k);

            for i = 1:nI
                if isfinite(Yield0(i,j,s))
                    production = production + ...
                        Yield0(i,j,s)*scale*X(i,j,s,tt);
                end
            end

            sold = min(production,DAdjusted(j,tt,k));
            p = PriceScenario(j,s,tt,k);

            revenue = revenue + p*sold;
        end

        cost = 0;

        [nI2,nJ2,nS2,~] = size(X);

        for i = 1:nI2
            for j = 1:nJ2
                for s = 1:nS2

                    area = X(i,j,s,tt);

                    if area==0
                        continue;
                    end

                    c = CostScenario(i,j,s,tt,k);

                    if isfinite(c)
                        cost = cost + c*area;
                    end
                end
            end
        end

        revYear(k,tt) = revenue;
        costYear(k,tt) = cost;
        profitYear(k,tt) = revenue-cost;
    end
end

profitTotal = sum(profitYear,2);
end

function [etaBest,lcvarBest] = computeLowerCVaR(profit,beta)
% 计算离散等概率利润样本的下行CVaR：
%
% max_eta eta - 1/((1-beta)K)*sum max(eta-profit_k,0)
%
% 最优eta一定可以取在样本利润值处，因此枚举全部候选值即可。

profit = profit(:);
K = numel(profit);

coef = 1/((1-beta)*K);

cand = unique(profit);
bestVal = -inf;
bestEta = NaN;

for ii = 1:numel(cand)

    eta = cand(ii);

    val = eta - ...
        coef*sum(max(eta-profit,0));

    if val>bestVal
        bestVal = val;
        bestEta = eta;
    end
end

etaBest = bestEta;
lcvarBest = bestVal;
end

function X = readResultWorkbook( ...
    resultFile,nI,nJ,nS,nT,plotTypes,years)
% 读取问题二result2格式的种植面积。
%
% 第一季：
% C2:AQ55，共54行×41列
%
% 第二季：
% C56:AQ83，共28行×41列
% 对应水浇地、普通大棚、智慧大棚。

X = zeros(nI,nJ,nS,nT);

secondPlotIdx = find( ...
    plotTypes=="水浇地" | ...
    plotTypes=="普通大棚" | ...
    plotTypes=="智慧大棚");

for tt = 1:nT

    sh = num2str(years(tt));

    M1 = readmatrix( ...
        resultFile,'Sheet',sh,'Range','C2:AQ55');

    M2 = readmatrix( ...
        resultFile,'Sheet',sh,'Range','C56:AQ83');

    % 防止Excel空白读成NaN
    M1(~isfinite(M1)) = 0;
    M2(~isfinite(M2)) = 0;

    if size(M1,1)~=nI || size(M1,2)~=nJ
        error('问题二结果表%s第一季区域尺寸异常。',sh);
    end

    if size(M2,1)~=numel(secondPlotIdx) || size(M2,2)~=nJ
        error('问题二结果表%s第二季区域尺寸异常。',sh);
    end

    X(:,:,1,tt) = M1;
    X(secondPlotIdx,:,2,tt) = M2;
end
end

function filePath = findOneFile(dataDir,patterns,excludeNames)
% 必需文件自动查找。

filePath = "";

for kk = 1:numel(patterns)

    pattern = patterns{kk};

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

            filePath = string( ...
                fullfile(d(idx).folder,d(idx).name));

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

    error('未找到所需Excel文件，请检查文件名和程序目录。');
end

filePath = char(filePath);
end

function filePath = findOptionalFile(dataDir,patterns,excludeNames)
% 可选文件自动查找。找不到时返回空字符串，不报错。

filePath = "";

for kk = 1:numel(patterns)

    pattern = patterns{kk};

    if ~contains(pattern,'*') && ~contains(pattern,'?')
        p = fullfile(dataDir,pattern);

        if isfile(p)
            filePath = string(p);
            break;
        end
    end

    d = dir(fullfile(dataDir,pattern));
    d = d(~[d.isdir]);

    if isempty(d)
        continue;
    end

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

        filePath = string( ...
            fullfile(d(idx).folder,d(idx).name));

        break;
    end
end

filePath = char(filePath);
end

function s = cleanString(x)
% 安全地把单元格内容转成string

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
% 单元格内容转double

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
% 单季和第一季统一记为1，第二季记为2

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
% 价格区间取中点，例如“2.50-4.00”

txt = char(cleanString(x));
nums = regexp(txt,'\d+(\.\d+)?','match');

if isempty(nums)
    p = NaN;

elseif numel(nums)==1
    p = str2double(nums{1});

else
    p = ...
        (str2double(nums{1}) + ...
         str2double(nums{2}))/2;
end
end

function [M,rhs] = packRows(colsCell,valsCell,rhsIn,nVar)
% 把逐条约束打包为稀疏矩阵

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
% 复制result2模板并写入问题三种植面积。
% 问题3题目没有单独result3提交模板，此文件仅供分析/论文使用。

copyfile(templateFile,outFile,'f');

secondPlotIdx = find( ...
    plotTypes=="水浇地" | ...
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
% 不依赖Statistics Toolbox的经验分位数

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
    q = (1-w)*x(lo) + w*x(hi);
end
end

function saveFig(figDir,fileName)
% 以300 dpi PNG保存图像

drawnow;
exportgraphics( ...
    gcf, ...
    fullfile(figDir,fileName), ...
    'Resolution',300);
end
