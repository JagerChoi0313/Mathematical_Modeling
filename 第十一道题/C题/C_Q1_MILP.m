function C_Q1_MILP()
% C_Q1_MILP
% 2024 C题 第一问：基于混合整数线性规划（MILP）的农作物种植优化
%
% 模型：
%   x(i,j,s,t)  连续变量：地块i、作物j、季节s、年份t的种植面积
%   y(i,j,s,t)  0-1变量：是否种植
%   z(i,t)      0-1变量：水浇地是否选择“单季水稻”模式
%   u(j,s,t)    正常价格销售量
%   v(j,s,t)    超过预期销售量的产量
%
% 两种情形：
%   alpha = 0   ：超产部分完全滞销
%   alpha = 0.5 ：超产部分按正常价格50%出售
%
% 运行要求：
%   1) MATLAB Optimization Toolbox（intlinprog）
%   2) 将本文件与附件1、附件2、result1_1、result1_2模板放在同一目录
%
% 注意：
%   minAreaRatio 与 maxPlotsPerCropSeason 是对题目“面积不宜太小、
%   种植地不宜太分散”的量化假设，不是题目直接给出的数值。
%   论文中必须说明，并建议进行敏感性分析。

clc;
close all;

%% ============================================================
% 0. 文件路径与模型参数
% =============================================================
dataDir = fileparts(mfilename('fullpath'));
if isempty(dataDir)
    dataDir = pwd;
end

file1 = fullfile(dataDir, '附件1(20260827-120155).xlsx');
file2 = fullfile(dataDir, '附件2(20260827-120154).xlsx');

template11 = fullfile(dataDir, 'result1_1(1).xlsx');
template12 = fullfile(dataDir, 'result1_2(1).xlsx');

out11 = fullfile(dataDir, 'result1_1_MATLAB.xlsx');
out12 = fullfile(dataDir, 'result1_2_MATLAB.xlsx');

assert(isfile(file1), '找不到附件1：%s', file1);
assert(isfile(file2), '找不到附件2：%s', file2);
assert(isfile(template11), '找不到result1_1模板：%s', template11);
assert(isfile(template12), '找不到result1_2模板：%s', template12);

years = 2024:2030;
nT = numel(years);
nS = 2;

% -------- 管理性量化假设（可修改） --------
minAreaRatio = 0.10;          % 一旦种植，面积至少为该地块面积的10%
maxPlotsPerCropSeason = 6;    % 同一作物同一季每年最多分布在6个地块
tol = 1e-7;

% -------- 求解参数 --------
maxSolveTime = 600;           % 每种情形最多求解600秒
relativeGap = 0.01;           % 允许1%相对最优间隙

fprintf('============================================================\n');
fprintf('2024 C题 第一问 MILP\n');
fprintf('最小种植面积比例 = %.1f%%\n', 100*minAreaRatio);
fprintf('单作物单季最大地块数 = %d\n', maxPlotsPerCropSeason);
fprintf('============================================================\n\n');

%% ============================================================
% 1. 读取附件1：地块、作物信息
% =============================================================
landRaw = readcell(file1, 'Sheet', '乡村的现有耕地');
cropRaw = readcell(file1, 'Sheet', '乡村种植的农作物');

% 地块数据：从第2行开始，保留地块名称非空的行
landRows = landRaw(2:end, :);
landNameAll = strings(size(landRows,1),1);
for r = 1:size(landRows,1)
    landNameAll(r) = cleanString(landRows{r,1});
end
validLand = strlength(landNameAll) > 0;
landRows = landRows(validLand, :);

nI = size(landRows,1);
plotNames = strings(nI,1);
plotTypes = strings(nI,1);
plotArea  = zeros(nI,1);

for i = 1:nI
    plotNames(i) = cleanString(landRows{i,1});
    plotTypes(i) = cleanString(landRows{i,2});
    plotArea(i)  = cellToDouble(landRows{i,3});
end

% 作物数据：按作物编号筛选
cropRows = cropRaw(2:end, :);
cropIdAll = nan(size(cropRows,1),1);
for r = 1:size(cropRows,1)
    cropIdAll(r) = cellToDouble(cropRows{r,1});
end
validCrop = ~isnan(cropIdAll);
cropRows = cropRows(validCrop, :);
cropIds = cropIdAll(validCrop);

nJ = numel(cropIds);
cropNames = strings(nJ,1);
cropTypes = strings(nJ,1);

for j = 1:nJ
    cropNames(j) = cleanString(cropRows{j,2});
    cropTypes(j) = cleanString(cropRows{j,3});
end

assert(nI == 54, '地块数量应为54，当前读到%d。', nI);
assert(nJ == 41, '作物数量应为41，当前读到%d。', nJ);

fprintf('[步骤1] 数据读取完成：%d个地块，%d种作物。\n', nI, nJ);

%% ============================================================
% 2. 读取附件2：2023统计数据，构造亩产量、成本、价格参数
% =============================================================
plantRaw = readcell(file2, 'Sheet', '2023年的农作物种植情况');
statRaw  = readcell(file2, 'Sheet', '2023年统计的相关数据');

% Yield(i,j,s) ：亩产量
% Cost(i,j,s)  ：种植成本
% PriceCell(i,j,s)：销售价格（区间中点）
Yield = nan(nI,nJ,nS);
Cost = nan(nI,nJ,nS);
PriceCell = nan(nI,nJ,nS);

statRows = statRaw(2:end, :);

for r = 1:size(statRows,1)
    cropId = cellToDouble(statRows{r,2});
    if isnan(cropId)
        continue;
    end

    j = find(cropIds == cropId, 1);
    if isempty(j)
        continue;
    end

    landType = cleanString(statRows{r,4});
    season = seasonCode(statRows{r,5});
    if season == 0
        continue;
    end

    yieldVal = cellToDouble(statRows{r,6});
    costVal  = cellToDouble(statRows{r,7});
    priceVal = priceMidpoint(statRows{r,8});

    idxPlot = find(plotTypes == landType);
    for k = 1:numel(idxPlot)
        i = idxPlot(k);
        Yield(i,j,season) = yieldVal;
        Cost(i,j,season) = costVal;
        PriceCell(i,j,season) = priceVal;
    end
end

% 附件注释：智慧大棚第一季参数与普通大棚第一季相同，表中省略
iOrd = find(plotTypes == "普通大棚", 1);
smartPlots = find(plotTypes == "智慧大棚");

for j = 17:34
    for kk = 1:numel(smartPlots)
        i = smartPlots(kk);
        Yield(i,j,1) = Yield(iOrd,j,1);
        Cost(i,j,1) = Cost(iOrd,j,1);
        PriceCell(i,j,1) = PriceCell(iOrd,j,1);
    end
end

% 只为存在统计参数的“地块-作物-季节”组合建立变量
feasible = isfinite(Yield) & isfinite(Cost) & isfinite(PriceCell);
nFeasibleCells = nnz(feasible);

% 每个作物-季节对应一个销售单价。
% 当前附件中，同一作物同一季的允许地块价格一致。
PriceJS = nan(nJ,nS);
for j = 1:nJ
    for s = 1:nS
        vals = PriceCell(:,j,s);
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            if max(vals)-min(vals) > 1e-8
                warning('作物%d第%d季存在多个价格，代码暂取均值。', j, s);
            end
            PriceJS(j,s) = mean(vals);
        end
    end
end

fprintf('[步骤2] 参数构造完成：每年可行“地块-作物-季节”单元 = %d。\n', nFeasibleCells);

%% ============================================================
% 3. 利用2023种植数据计算预期销售量D_j，并记录2023轮作状态
% =============================================================
% 按“上面的数学模型”采用 D_j：
%   D_j = 2023年该作物的总产量
% 并将D_j作为未来每一季该作物的正常销售上限。
%
% 若你的论文决定采用“分季销售量D_{j,s}”，应在这里改为二维D(j,s)。

histX = zeros(nI,nJ,nS);     % 2023历史种植面积
expectedSales = zeros(nJ,1); % D_j，单位：斤

plantRows = plantRaw(2:end, :);
currentPlot = "";

for r = 1:size(plantRows,1)
    pName = cleanString(plantRows{r,1});
    if strlength(pName) > 0
        currentPlot = pName;
    end

    cropId = cellToDouble(plantRows{r,2});
    areaVal = cellToDouble(plantRows{r,5});

    if strlength(currentPlot)==0 || isnan(cropId) || isnan(areaVal)
        continue;
    end

    i = find(plotNames == currentPlot, 1);
    j = find(cropIds == cropId, 1);
    s = seasonCode(plantRows{r,6});

    if isempty(i) || isempty(j) || s==0
        continue;
    end

    if ~isfinite(Yield(i,j,s))
        error('2023历史种植组合在统计参数中找不到：地块%s，作物%d，第%d季。', ...
              currentPlot, cropId, s);
    end

    histX(i,j,s) = histX(i,j,s) + areaVal;
    expectedSales(j) = expectedSales(j) + areaVal * Yield(i,j,s);
end

fprintf('[步骤3] 2023预期销售量计算完成。\n');
fprintf('         小麦D = %.0f斤，玉米D = %.0f斤，水稻D = %.0f斤。\n', ...
    expectedSales(6), expectedSales(7), expectedSales(16));

%% ============================================================
% 4. 建立变量编号
% =============================================================
% 变量顺序：
%   [所有x] -> [所有y] -> [所有水浇地z] -> [所有u] -> [所有v]

Xidx = zeros(nI,nJ,nS,nT,'uint32');
Yidx = zeros(nI,nJ,nS,nT,'uint32');
Zidx = zeros(nI,nT,'uint32');
Uidx = zeros(nJ,nS,nT,'uint32');
Vidx = zeros(nJ,nS,nT,'uint32');

[fi,fj,fs] = ind2sub([nI,nJ,nS], find(feasible));
nCell = numel(fi);

nVar = 0;

% x变量
for tt = 1:nT
    for k = 1:nCell
        nVar = nVar + 1;
        Xidx(fi(k),fj(k),fs(k),tt) = uint32(nVar);
    end
end
nX = nVar;

% y变量
for tt = 1:nT
    for k = 1:nCell
        nVar = nVar + 1;
        Yidx(fi(k),fj(k),fs(k),tt) = uint32(nVar);
    end
end
nY = nVar - nX;

% 水浇地模式z
waterPlots = find(plotTypes == "水浇地");
for tt = 1:nT
    for kk = 1:numel(waterPlots)
        i = waterPlots(kk);
        nVar = nVar + 1;
        Zidx(i,tt) = uint32(nVar);
    end
end
nZ = numel(waterPlots)*nT;

% 存在生产可能的作物-季节对
pairMask = squeeze(any(feasible,1)); % nJ x nS
[pj,ps] = find(pairMask);
nPair = numel(pj);

% u变量
for tt = 1:nT
    for k = 1:nPair
        nVar = nVar + 1;
        Uidx(pj(k),ps(k),tt) = uint32(nVar);
    end
end
nU = nPair*nT;

% v变量
for tt = 1:nT
    for k = 1:nPair
        nVar = nVar + 1;
        Vidx(pj(k),ps(k),tt) = uint32(nVar);
    end
end
nV = nPair*nT;

fprintf('[步骤4] 变量编号完成：\n');
fprintf('         X连续变量 = %d\n', nX);
fprintf('         Y二进制变量 = %d\n', nY);
fprintf('         Z二进制变量 = %d\n', nZ);
fprintf('         U销售变量 = %d\n', nU);
fprintf('         V超产变量 = %d\n', nV);
fprintf('         总变量数 = %d\n', nVar);

%% ============================================================
% 5. 变量上下界、整数变量集合
% =============================================================
lb = zeros(nVar,1);
ub = inf(nVar,1);

% x上界：不能超过地块面积
for tt = 1:nT
    for k = 1:nCell
        i = fi(k); j = fj(k); s = fs(k);
        ub(double(Xidx(i,j,s,tt))) = plotArea(i);
    end
end

% y为0-1
yLinear = double(Yidx(Yidx>0));
ub(yLinear) = 1;

% z为0-1
zLinear = double(Zidx(Zidx>0));
ub(zLinear) = 1;

% u正常售价销量不超过D_j
for tt = 1:nT
    for k = 1:nPair
        j = pj(k); s = ps(k);
        ub(double(Uidx(j,s,tt))) = expectedSales(j);
    end
end

intcon = sort([yLinear; zLinear]);

%% ============================================================
% 6. 构造MILP约束
% =============================================================
ineqCols = cell(0,1);
ineqVals = cell(0,1);
ineqRhs  = zeros(0,1);
eqCols   = cell(0,1);
eqVals   = cell(0,1);
eqRhs    = zeros(0,1);

% ------------------------------------------------------------
% 6.1 x-y关联：L_i*y <= x <= A_i*y
% -------------------------------------------------------------
for tt = 1:nT
    for k = 1:nCell
        i = fi(k); j = fj(k); s = fs(k);
        x = double(Xidx(i,j,s,tt));
        y = double(Yidx(i,j,s,tt));

        A_i = plotArea(i);
        L_i = minAreaRatio*A_i;

        % x - A_i*y <= 0
        addIneq([x,y], [1,-A_i], 0);

        % -x + L_i*y <= 0  <=> x >= L_i*y
        addIneq([x,y], [-1,L_i], 0);
    end
end

% 地块类型集合
dryPlots = find(plotTypes=="平旱地" | plotTypes=="梯田" | plotTypes=="山坡地");
ordinaryPlots = find(plotTypes=="普通大棚");
smartPlots = find(plotTypes=="智慧大棚");

% ------------------------------------------------------------
% 6.2 平旱地、梯田、山坡地：一年一季粮食，面积用满
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(dryPlots)
        i = dryPlots(kk);
        idx = squeeze(Xidx(i,:,1,tt));
        idx = double(idx(idx>0));
        addEq(idx, ones(size(idx)), plotArea(i));
    end
end

% ------------------------------------------------------------
% 6.3 水浇地模式：
% z=1 -> 单季水稻
% z=0 -> 两季蔬菜
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(waterPlots)
        i = waterPlots(kk);
        z = double(Zidx(i,tt));

        % 水稻：x_rice = A_i*z
        xRice = double(Xidx(i,16,1,tt));
        addEq([xRice,z], [1,-plotArea(i)], 0);

        % 第一季普通蔬菜：sum x + A_i*z = A_i
        idxS1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idxS1 = idxS1(idxS1>0);
        addEq([idxS1(:);z], [ones(numel(idxS1),1);plotArea(i)], plotArea(i));

        % 第二季大白菜/白萝卜/红萝卜：sum x + A_i*z = A_i
        idxS2 = double(squeeze(Xidx(i,35:37,2,tt)));
        idxS2 = idxS2(idxS2>0);
        addEq([idxS2(:);z], [ones(numel(idxS2),1);plotArea(i)], plotArea(i));

        % 第二季只能选择一种：sum y + z = 1
        yS2 = double(squeeze(Yidx(i,35:37,2,tt)));
        yS2 = yS2(yS2>0);
        addEq([yS2(:);z], [ones(numel(yS2),1);1], 1);
    end
end

% ------------------------------------------------------------
% 6.4 普通大棚：
% 第一季17-34蔬菜，第二季38-41食用菌
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(ordinaryPlots)
        i = ordinaryPlots(kk);

        idx1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idx1 = idx1(idx1>0);
        addEq(idx1, ones(size(idx1)), plotArea(i));

        idx2 = double(squeeze(Xidx(i,38:41,2,tt)));
        idx2 = idx2(idx2>0);
        addEq(idx2, ones(size(idx2)), plotArea(i));
    end
end

% ------------------------------------------------------------
% 6.5 智慧大棚：两季都种17-34蔬菜
% -------------------------------------------------------------
for tt = 1:nT
    for kk = 1:numel(smartPlots)
        i = smartPlots(kk);

        idx1 = double(squeeze(Xidx(i,17:34,1,tt)));
        idx1 = idx1(idx1>0);
        addEq(idx1, ones(size(idx1)), plotArea(i));

        idx2 = double(squeeze(Xidx(i,17:34,2,tt)));
        idx2 = idx2(idx2>0);
        addEq(idx2, ones(size(idx2)), plotArea(i));
    end
end

% ------------------------------------------------------------
% 6.6 同一种作物同一季的地块数量不能太分散
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
                addIneq(idx, ones(size(idx)), maxPlotsPerCropSeason);
            end
        end
    end
end

% ------------------------------------------------------------
% 6.7 禁止连续重茬
% -------------------------------------------------------------
% (a) 平旱地/梯田/山坡地：相邻年份不能同作物
for kk = 1:numel(dryPlots)
    i = dryPlots(kk);
    for j = 1:15
        for tt = 1:nT-1
            y1 = double(Yidx(i,j,1,tt));
            y2 = double(Yidx(i,j,1,tt+1));
            addIneq([y1,y2], [1,1], 1);
        end

        % 2023 -> 2024边界
        if histX(i,j,1) > tol
            y2024 = double(Yidx(i,j,1,1));
            addIneq(y2024, 1, 0);
        end
    end
end

% (b) 水浇地：连续两年不能都种水稻
for kk = 1:numel(waterPlots)
    i = waterPlots(kk);
    for tt = 1:nT-1
        z1 = double(Zidx(i,tt));
        z2 = double(Zidx(i,tt+1));
        addIneq([z1,z2], [1,1], 1);
    end
    if histX(i,16,1) > tol
        addIneq(double(Zidx(i,1)), 1, 0);
    end
end

% (c) 智慧大棚：
%     同一年第一季与第二季不能种同一种菜；
%     上一年第二季与下一年第一季不能连续种同一种菜。
for kk = 1:numel(smartPlots)
    i = smartPlots(kk);
    for j = 17:34
        for tt = 1:nT
            y1 = double(Yidx(i,j,1,tt));
            y2 = double(Yidx(i,j,2,tt));
            addIneq([y1,y2], [1,1], 1);
        end

        for tt = 1:nT-1
            y2 = double(Yidx(i,j,2,tt));
            yNext1 = double(Yidx(i,j,1,tt+1));
            addIneq([y2,yNext1], [1,1], 1);
        end

        % 2023第二季 -> 2024第一季
        if histX(i,j,2) > tol
            addIneq(double(Yidx(i,j,1,1)), 1, 0);
        end
    end
end

% ------------------------------------------------------------
% 6.8 三年内每块地的所有土地至少轮作一次豆类
% 用面积累计约束近似：
% 三年窗口内豆类累计种植面积 >= 地块面积
% -------------------------------------------------------------
beanCrops = [1:5,17:19];

for i = 1:nI
    histBeanArea = sum(histX(i,beanCrops,:), 'all');

    % 窗口1：2023-2025
    cols = [];
    vals = [];
    for tt = 1:2  % 2024,2025
        for s = 1:nS
            for jj = beanCrops
                x = double(Xidx(i,jj,s,tt));
                if x > 0
                    cols(end+1,1) = x; %#ok<AGROW>
                    vals(end+1,1) = -1; %#ok<AGROW>
                end
            end
        end
    end
    % hist + future >= A  <=> -future <= -(A-hist)
    addIneq(cols, vals, -(plotArea(i)-histBeanArea));

    % 窗口2~6：2024-2026, ..., 2028-2030
    for startT = 1:5
        cols = [];
        vals = [];
        for tt = startT:startT+2
            for s = 1:nS
                for jj = beanCrops
                    x = double(Xidx(i,jj,s,tt));
                    if x > 0
                        cols(end+1,1) = x; %#ok<AGROW>
                        vals(end+1,1) = -1; %#ok<AGROW>
                    end
                end
            end
        end
        addIneq(cols, vals, -plotArea(i));
    end
end

% ------------------------------------------------------------
% 6.9 产量分解：
% Q_{j,s,t} = u_{j,s,t} + v_{j,s,t}
% 即 sum_i q_ijs*x_ijst - u - v = 0
% -------------------------------------------------------------
for tt = 1:nT
    for k = 1:nPair
        j = pj(k);
        s = ps(k);

        cols = [];
        vals = [];

        for i = 1:nI
            x = double(Xidx(i,j,s,tt));
            if x > 0
                cols(end+1,1) = x; %#ok<AGROW>
                vals(end+1,1) = Yield(i,j,s); %#ok<AGROW>
            end
        end

        u = double(Uidx(j,s,tt));
        v = double(Vidx(j,s,tt));

        cols = [cols;u;v];
        vals = [vals;-1;-1];

        addEq(cols, vals, 0);
    end
end

% 打包为稀疏矩阵
[A,b] = packRows(ineqCols, ineqVals, ineqRhs, nVar);
[Aeq,beq] = packRows(eqCols, eqVals, eqRhs, nVar);

fprintf('[步骤6] 约束构造完成：\n');
fprintf('         不等式约束 = %d\n', size(A,1));
fprintf('         等式约束 = %d\n', size(Aeq,1));
fprintf('         nnz(A) = %d\n', nnz(A));
fprintf('         nnz(Aeq) = %d\n\n', nnz(Aeq));

%% ============================================================
% 7. 分别求解两种销售情形
% =============================================================
options = optimoptions('intlinprog', ...
    'Display','iter', ...
    'MaxTime',maxSolveTime, ...
    'RelativeGapTolerance',relativeGap);

alphas = [0,0.5];
caseNames = ["超产完全滞销","超产按50%出售"];

solutions = cell(2,1);
caseSummary = struct([]);

for cc = 1:2
    alpha = alphas(cc);

    % intlinprog默认“最小化”，因此：
    % f = 成本 - 正常销售收入 - alpha*超产销售收入
    f = zeros(nVar,1);

    % x：种植成本
    for tt = 1:nT
        for k = 1:nCell
            i = fi(k); j = fj(k); s = fs(k);
            f(double(Xidx(i,j,s,tt))) = Cost(i,j,s);
        end
    end

    % u、v：销售收入取负号
    for tt = 1:nT
        for k = 1:nPair
            j = pj(k); s = ps(k);
            p = PriceJS(j,s);
            f(double(Uidx(j,s,tt))) = -p;
            f(double(Vidx(j,s,tt))) = -alpha*p;
        end
    end

    fprintf('\n============================================================\n');
    fprintf('开始求解情形%d：%s\n', cc, caseNames(cc));
    fprintf('alpha = %.1f\n', alpha);
    fprintf('============================================================\n');

    [sol,fval,exitflag,output] = intlinprog( ...
        f,intcon,A,b,Aeq,beq,lb,ub,options);

    if isempty(sol)
        error('情形%d没有得到可行解。exitflag=%d', cc, exitflag);
    end

    solutions{cc} = sol;
    totalProfit = -fval;

    % 解读结果
    result = decodeSolution(sol, alpha);

    caseSummary(cc).alpha = alpha;
    caseSummary(cc).name = caseNames(cc);
    caseSummary(cc).exitflag = exitflag;
    caseSummary(cc).output = output;
    caseSummary(cc).totalProfit = totalProfit;
    caseSummary(cc).result = result;

    fprintf('\n---------------- 求解结果 ----------------\n');
    fprintf('情形：%s\n', caseNames(cc));
    fprintf('总利润 = %.2f 元 = %.4f 万元\n', totalProfit, totalProfit/1e4);
    fprintf('exitflag = %d\n', exitflag);

    if isfield(output,'relativegap')
        fprintf('relative gap = %.4f%%\n', 100*output.relativegap);
    end
    if isfield(output,'numnodes')
        fprintf('分支定界节点数 = %d\n', output.numnodes);
    end

    yearlyTable = table(years(:), ...
        result.yearRevenue(:), ...
        result.yearCost(:), ...
        result.yearProfit(:), ...
        result.yearPlantedArea(:), ...
        'VariableNames',{'Year','Revenue','Cost','Profit','PlantedArea'});
    disp(yearlyTable);

    % 输出累计种植面积前10的作物
    [sortedArea,ord] = sort(result.cropArea,'descend');
    topN = min(10,nJ);
    topTable = table(cropIds(ord(1:topN)), cropNames(ord(1:topN)), ...
        sortedArea(1:topN), ...
        'VariableNames',{'CropID','CropName','SevenYearArea'});
    fprintf('七年累计种植面积前%d的作物：\n', topN);
    disp(topTable);
end

%% ============================================================
% 8. 写入题目给定result1_1、result1_2模板
% =============================================================
writeResultWorkbook(template11, out11, caseSummary(1).result.X);
writeResultWorkbook(template12, out12, caseSummary(2).result.X);

fprintf('\n[步骤8] 结果文件已写出：\n');
fprintf('         %s\n', out11);
fprintf('         %s\n', out12);

%% ============================================================
% 9. 画图：年度利润对比
% =============================================================
profit1 = caseSummary(1).result.yearProfit(:);
profit2 = caseSummary(2).result.yearProfit(:);

figure('Name','年度利润对比','Position',[100 100 900 520]);
plot(years,profit1/1e4,'-o','LineWidth',1.6,'MarkerSize',6);
hold on;
plot(years,profit2/1e4,'-s','LineWidth',1.6,'MarkerSize',6);
grid on;
xlabel('年份');
ylabel('利润/万元');
title('问题1两种销售情形下的年度利润');
legend(caseNames,'Location','best');
xticks(years);

fig1 = fullfile(dataDir,'Q1_年度利润对比.png');
exportgraphics(gcf,fig1,'Resolution',200);

%% ============================================================
% 10. 画图：两种情形累计种植面积最大的作物
% =============================================================
area1 = caseSummary(1).result.cropArea(:);
area2 = caseSummary(2).result.cropArea(:);
score = max([area1,area2],[],2);
[~,ord] = sort(score,'descend');

topN = min(10,nJ);
top = ord(1:topN);

figure('Name','主要作物累计种植面积','Position',[100 100 1000 560]);
bar([area1(top),area2(top)],'grouped');
grid on;
xticks(1:topN);
xticklabels(cropNames(top));
xtickangle(35);
ylabel('2024-2030累计种植面积/亩');
title('两种销售情形下主要作物累计种植面积');
legend(caseNames,'Location','best');

fig2 = fullfile(dataDir,'Q1_主要作物种植面积对比.png');
exportgraphics(gcf,fig2,'Resolution',200);

fprintf('[步骤9-10] 图像已保存：\n');
fprintf('           %s\n', fig1);
fprintf('           %s\n', fig2);

%% ============================================================
% 11. 最终汇总输出
% =============================================================
summaryTable = table(caseNames(:), ...
    [caseSummary.totalProfit]'/1e4, ...
    'VariableNames',{'Case','TotalProfit_10kYuan'});
disp('================ 第一问最终汇总 ================');
disp(summaryTable);

fprintf('\n解释：\n');
fprintf('1) result1_1_MATLAB.xlsx 对应“超产完全滞销”的最优种植方案。\n');
fprintf('2) result1_2_MATLAB.xlsx 对应“超产部分按50%%价格出售”的最优种植方案。\n');
fprintf('3) 每个年份工作表中填写的是各地块、各作物、各季的最优种植面积（亩）。\n');
fprintf('4) 年度利润=当年销售收入-当年种植成本；七年总利润为2024-2030利润之和。\n');
fprintf('5) 若利润与你参考结果差异明显，首先核对：价格区间取值、D_j销量口径、\n');
fprintf('   minAreaRatio、maxPlotsPerCropSeason，以及是否将2023历史轮作正确纳入。\n');

%% ============================================================
%                   嵌套辅助函数
% =============================================================

    function addIneq(cols,vals,rhs)
        % 增加一条 A*x <= b
        cols = double(cols(:));
        vals = double(vals(:));
        keep = cols > 0 & abs(vals) > 0;
        cols = cols(keep);
        vals = vals(keep);

        ineqCols{end+1,1} = cols;
        ineqVals{end+1,1} = vals;
        ineqRhs(end+1,1) = rhs;
    end

    function addEq(cols,vals,rhs)
        % 增加一条 Aeq*x = beq
        cols = double(cols(:));
        vals = double(vals(:));
        keep = cols > 0 & abs(vals) > 0;
        cols = cols(keep);
        vals = vals(keep);

        eqCols{end+1,1} = cols;
        eqVals{end+1,1} = vals;
        eqRhs(end+1,1) = rhs;
    end

    function result = decodeSolution(sol,alpha)
        % 将一维解向量恢复为种植面积、销售量，并计算利润

        X = zeros(nI,nJ,nS,nT);
        U = zeros(nJ,nS,nT);
        V = zeros(nJ,nS,nT);

        for tt2 = 1:nT
            for kk2 = 1:nCell
                ii = fi(kk2); jj = fj(kk2); ss = fs(kk2);
                val = sol(double(Xidx(ii,jj,ss,tt2)));
                if abs(val) < 1e-6
                    val = 0;
                end
                X(ii,jj,ss,tt2) = val;
            end
        end

        for tt2 = 1:nT
            for kk2 = 1:nPair
                jj = pj(kk2); ss = ps(kk2);
                U(jj,ss,tt2) = sol(double(Uidx(jj,ss,tt2)));
                V(jj,ss,tt2) = sol(double(Vidx(jj,ss,tt2)));
            end
        end

        Cost0 = Cost;
        Cost0(~isfinite(Cost0)) = 0;

        yearRevenue = zeros(nT,1);
        yearCost = zeros(nT,1);
        yearProfit = zeros(nT,1);
        yearPlantedArea = zeros(nT,1);

        for tt2 = 1:nT
            rev = 0;
            for jj = 1:nJ
                for ss = 1:nS
                    if pairMask(jj,ss)
                        rev = rev + PriceJS(jj,ss) * ...
                            (U(jj,ss,tt2) + alpha*V(jj,ss,tt2));
                    end
                end
            end

            tmpCost = X(:,:,:,tt2).*Cost0;
            cst = sum(tmpCost(:));

            tmpArea = X(:,:,:,tt2);
            planted = sum(tmpArea(:));

            yearRevenue(tt2) = rev;
            yearCost(tt2) = cst;
            yearProfit(tt2) = rev-cst;
            yearPlantedArea(tt2) = planted;
        end

        cropArea = zeros(nJ,1);
        for jj = 1:nJ
            tmp = X(:,jj,:,:);
            cropArea(jj) = sum(tmp(:));
        end

        result.X = X;
        result.U = U;
        result.V = V;
        result.yearRevenue = yearRevenue;
        result.yearCost = yearCost;
        result.yearProfit = yearProfit;
        result.yearPlantedArea = yearPlantedArea;
        result.cropArea = cropArea;
    end

    function writeResultWorkbook(templateFile,outFile,X)
        % 保留模板格式，只向规定区域写入种植面积
        copyfile(templateFile,outFile,'f');

        % 第一季模板为54个地块：A1-F4，写入C2:AQ55
        % 第二季模板为28个地块：D1-D8,E1-E16,F1-F4，写入C56:AQ83
        secondPlotIdx = find(plotTypes=="水浇地" | ...
                             plotTypes=="普通大棚" | ...
                             plotTypes=="智慧大棚");

        for tt2 = 1:nT
            sh = num2str(years(tt2));

            M1 = squeeze(X(:,:,1,tt2));
            M1(abs(M1)<1e-6) = 0;

            M2 = squeeze(X(secondPlotIdx,:,2,tt2));
            M2(abs(M2)<1e-6) = 0;

            writematrix(M1,outFile,'Sheet',sh,'Range','C2');
            writematrix(M2,outFile,'Sheet',sh,'Range','C56');
        end
    end

end

% ============================================================
%                     本文件局部函数
% ============================================================

function s = cleanString(x)
% 将readcell读取出的各种文本安全转换为去除首尾空格的string
    if isempty(x)
        s = "";
    elseif ismissingValue(x)
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

function tf = ismissingValue(x)
    tf = false;
    try
        if isstring(x)
            tf = ismissing(x);
        elseif iscategorical(x)
            tf = isundefined(x);
        end
    catch
        tf = false;
    end
end

function v = cellToDouble(x)
% 将readcell中的数值或数值文本转为double；无法转换时返回NaN
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
% “单季”和“第一季”统一映射到1，“第二季”映射到2
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
        p = (str2double(nums{1}) + str2double(nums{2}))/2;
    end
end

function [M,rhs] = packRows(colsCell,valsCell,rhsIn,nVar)
% 将逐行保存的稀疏系数打包成MATLAB sparse矩阵
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
