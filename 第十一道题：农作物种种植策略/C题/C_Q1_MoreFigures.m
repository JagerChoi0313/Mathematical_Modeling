function C_Q1_MoreFigures()
% C_Q1_MoreFigures
% ------------------------------------------------------------
% 2024 C题 问题一：基于已有 result1_1_MATLAB.xlsx 和
% result1_2_MATLAB.xlsx 生成更多论文图表。
%
% 本程序不重新优化，只读取已经得到的种植方案，并按照原MILP中
% 相同的数据处理口径重新计算：
%   1) 年度销售收入、种植成本、利润
%   2) 年度种植亩次
%   3) 主要作物累计种植面积
%   4) 两方案作物面积变化
%   5) 不同土地类型的年度种植结构
%   6) 不同作物类别的年度种植结构
%   7) 主要作物逐年面积热力图
%   8) 水浇地水稻/第二季蔬菜面积变化
%   9) 年度实际种植作物种类数
%  10) 50%销售方案相对完全滞销方案的利润增量
%
% 所有图片自动保存到 Q1_figures 文件夹。
%
% 使用前请将以下文件放在本程序同一文件夹：
%   result1_1_MATLAB.xlsx
%   result1_2_MATLAB.xlsx
%   附件1(20260827-120155).xlsx
%   附件2(20260827-120154).xlsx
%
% MATLAB版本建议：R2021b及以上
% ------------------------------------------------------------

clc;
close all;

%% 0. 文件与输出目录
dataDir = fileparts(mfilename('fullpath'));
if isempty(dataDir)
    dataDir = pwd;
end

fileCase1 = fullfile(dataDir,'result1_1_MATLAB.xlsx');
fileCase2 = fullfile(dataDir,'result1_2_MATLAB.xlsx');
file1 = fullfile(dataDir,'附件1(20260827-120155).xlsx');
file2 = fullfile(dataDir,'附件2(20260827-120154).xlsx');

assert(isfile(fileCase1),'找不到 %s',fileCase1);
assert(isfile(fileCase2),'找不到 %s',fileCase2);
assert(isfile(file1),'找不到 %s',file1);
assert(isfile(file2),'找不到 %s',file2);

figDir = fullfile(dataDir,'Q1_figures');
if ~exist(figDir,'dir')
    mkdir(figDir);
end

years = 2024:2030;
nT = numel(years);
nJ = 41;
nS = 2;
tol = 1e-6;

% 中文显示（Windows一般可用）
try
    set(groot,'defaultAxesFontName','Microsoft YaHei');
    set(groot,'defaultTextFontName','Microsoft YaHei');
catch
end

%% 1. 读取附件1：地块与作物名称
landRaw = readcell(file1,'Sheet','乡村的现有耕地');
cropRaw = readcell(file1,'Sheet','乡村种植的农作物');

% 地块
plotNames = strings(54,1);
plotTypes = strings(54,1);
plotArea = zeros(54,1);
for i = 1:54
    plotNames(i) = cleanString(landRaw{i+1,1});
    plotTypes(i) = cleanString(landRaw{i+1,2});
    plotArea(i) = cellToDouble(landRaw{i+1,3});
end
nI = numel(plotNames);

% 作物名称
cropNames = strings(nJ,1);
for j = 1:nJ
    cropNames(j) = cleanString(cropRaw{j+1,2});
end

%% 2. 读取附件2：亩产量、成本、价格
statRaw = readcell(file2,'Sheet','2023年统计的相关数据');
plantRaw = readcell(file2,'Sheet','2023年的农作物种植情况');

Yield = nan(nI,nJ,nS);
Cost = nan(nI,nJ,nS);
PriceCell = nan(nI,nJ,nS);

for r = 2:size(statRaw,1)
    cropId = cellToDouble(statRaw{r,2});
    if isnan(cropId) || cropId<1 || cropId>41
        continue;
    end

    landType = cleanString(statRaw{r,4});
    s = seasonCode(statRaw{r,5});
    if s==0
        continue;
    end

    yld = cellToDouble(statRaw{r,6});
    cst = cellToDouble(statRaw{r,7});
    prc = priceMidpoint(statRaw{r,8});

    idx = find(plotTypes==landType);
    Yield(idx,cropId,s) = yld;
    Cost(idx,cropId,s) = cst;
    PriceCell(idx,cropId,s) = prc;
end

% 智慧大棚第一季采用普通大棚第一季参数
iOrd = find(plotTypes=="普通大棚",1);
smartIdx = find(plotTypes=="智慧大棚");
for j = 17:34
    for kk = 1:numel(smartIdx)
        i = smartIdx(kk);
        Yield(i,j,1) = Yield(iOrd,j,1);
        Cost(i,j,1) = Cost(iOrd,j,1);
        PriceCell(i,j,1) = PriceCell(iOrd,j,1);
    end
end

% 每个作物-季节使用统一价格中点
PriceJS = nan(nJ,nS);
for j = 1:nJ
    for s = 1:nS
        vals = PriceCell(:,j,s);
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            PriceJS(j,s) = mean(vals);
        end
    end
end

%% 3. 按原模型口径计算2023预期销售量 D_j
expectedSales = zeros(nJ,1);
currentPlot = "";

for r = 2:size(plantRaw,1)
    p = cleanString(plantRaw{r,1});
    if strlength(p)>0
        currentPlot = p;
    end

    cropId = cellToDouble(plantRaw{r,2});
    areaVal = cellToDouble(plantRaw{r,5});
    s = seasonCode(plantRaw{r,6});

    if strlength(currentPlot)==0 || isnan(cropId) || isnan(areaVal) || s==0
        continue;
    end

    i = find(plotNames==currentPlot,1);
    if isempty(i)
        continue;
    end

    expectedSales(cropId) = expectedSales(cropId) + ...
        areaVal*Yield(i,cropId,s);
end

%% 4. 从两个结果文件读取完整四维种植矩阵 X(i,j,s,t)
X1 = readResultWorkbook(fileCase1,plotNames,nJ,years);
X2 = readResultWorkbook(fileCase2,plotNames,nJ,years);

% 清除浮点残差
X1(abs(X1)<tol)=0;
X2(abs(X2)<tol)=0;

%% 5. 按原目标函数口径重新计算两方案的结果指标
M1 = calcMetrics(X1,0, Yield,Cost,PriceJS,expectedSales,plotTypes);
M2 = calcMetrics(X2,0.5,Yield,Cost,PriceJS,expectedSales,plotTypes);

fprintf('\n================= 问题一图表数据汇总 =================\n');
T = table(years(:), ...
    M1.yearRevenue(:)/1e4, M1.yearCost(:)/1e4, M1.yearProfit(:)/1e4, ...
    M2.yearRevenue(:)/1e4, M2.yearCost(:)/1e4, M2.yearProfit(:)/1e4, ...
    M1.yearArea(:), M2.yearArea(:), ...
    'VariableNames',{'Year', ...
    'Case1Revenue_万元','Case1Cost_万元','Case1Profit_万元', ...
    'Case2Revenue_万元','Case2Cost_万元','Case2Profit_万元', ...
    'Case1Area_亩次','Case2Area_亩次'});
disp(T);

%% ------------------------------------------------------------
% 图1：年度收入、成本、利润
% 用途：展示两种销售政策不仅影响利润，也影响收入和成本
% -------------------------------------------------------------
figure('Color','w','Position',[80 80 1180 520]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(years,[M1.yearRevenue,M1.yearCost,M1.yearProfit]/1e4,'grouped');
grid on;
xlabel('年份');
ylabel('金额/万元');
title('超产完全滞销：年度收入、成本与利润');
legend({'销售收入','种植成本','利润'},'Location','best');

nexttile;
bar(years,[M2.yearRevenue,M2.yearCost,M2.yearProfit]/1e4,'grouped');
grid on;
xlabel('年份');
ylabel('金额/万元');
title('超产按50%出售：年度收入、成本与利润');
legend({'销售收入','种植成本','利润'},'Location','best');

saveFig(figDir,'图1_年度收入成本利润.png');

%% ------------------------------------------------------------
% 图2：年度种植亩次及一、二季构成
% 用途：观察是否更多采用两季种植
% -------------------------------------------------------------
figure('Color','w','Position',[80 80 1180 520]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(years,[M1.seasonArea(:,1),M1.seasonArea(:,2)],'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产完全滞销：年度种植亩次');
legend({'第一季','第二季'},'Location','best');

nexttile;
bar(years,[M2.seasonArea(:,1),M2.seasonArea(:,2)],'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产按50%出售：年度种植亩次');
legend({'第一季','第二季'},'Location','best');

saveFig(figDir,'图2_年度种植亩次及季节构成.png');

%% ------------------------------------------------------------
% 图3：累计种植面积最大的前12种作物
% 用途：比较主要作物结构
% -------------------------------------------------------------
totalCrop1 = squeeze(sum(X1,[1,3,4]))';
totalCrop2 = squeeze(sum(X2,[1,3,4]))';

score = max([totalCrop1,totalCrop2],[],2);
[~,ord] = sort(score,'descend');
topN = min(12,nJ);
top = ord(1:topN);

figure('Color','w','Position',[100 80 1050 620]);
barh(1:topN,[totalCrop1(top),totalCrop2(top)],'grouped');
set(gca,'YTick',1:topN,'YTickLabel',cropNames(top),'YDir','reverse');
grid on;
xlabel('2024—2030累计种植面积/亩');
ylabel('作物');
title('两种销售情形下主要作物累计种植面积');
legend({'超产完全滞销','超产按50%出售'},'Location','best');

saveFig(figDir,'图3_主要作物累计种植面积.png');

%% ------------------------------------------------------------
% 图4：两方案累计种植面积差值
% 正值：50%销售情形种得更多；负值：完全滞销情形种得更多
% -------------------------------------------------------------
cropDiff = totalCrop2-totalCrop1;
[~,ordDiff] = sort(abs(cropDiff),'descend');
topDiff = ordDiff(1:min(15,nJ));

figure('Color','w','Position',[100 80 1050 650]);
barh(1:numel(topDiff),cropDiff(topDiff));
set(gca,'YTick',1:numel(topDiff),'YTickLabel',cropNames(topDiff),'YDir','reverse');
xline(0,'--');
grid on;
xlabel('累计种植面积差值/亩（50%出售 - 完全滞销）');
ylabel('作物');
title('销售方式变化引起的主要作物面积调整');

saveFig(figDir,'图4_作物累计面积变化.png');

%% ------------------------------------------------------------
% 图5：不同土地类型的年度种植面积构成
% 注意：这里统计的是种植亩次，一块地种两季会累计两次
% -------------------------------------------------------------
landTypeList = ["平旱地","梯田","山坡地","水浇地","普通大棚","智慧大棚"];
landArea1 = zeros(nT,numel(landTypeList));
landArea2 = zeros(nT,numel(landTypeList));

for k = 1:numel(landTypeList)
    idx = find(plotTypes==landTypeList(k));
    for tt = 1:nT
        tmp1 = X1(idx,:,:,tt);
        tmp2 = X2(idx,:,:,tt);
        landArea1(tt,k) = sum(tmp1(:));
        landArea2(tt,k) = sum(tmp2(:));
    end
end

figure('Color','w','Position',[80 80 1180 540]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(years,landArea1,'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产完全滞销：不同土地类型的利用结构');
legend(cellstr(landTypeList),'Location','bestoutside');

nexttile;
bar(years,landArea2,'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产按50%出售：不同土地类型的利用结构');
legend(cellstr(landTypeList),'Location','bestoutside');

saveFig(figDir,'图5_土地类型年度利用结构.png');

%% ------------------------------------------------------------
% 图6：作物类别年度种植结构
% 五类：粮食非豆、粮食豆类、蔬菜非豆、蔬菜豆类、食用菌
% -------------------------------------------------------------
catNames = ["粮食非豆类","粮食豆类","蔬菜非豆类","蔬菜豆类","食用菌"];
catCrop = {
    6:16, ...
    1:5, ...
    [20:37], ...
    17:19, ...
    38:41};

catArea1 = zeros(nT,5);
catArea2 = zeros(nT,5);

for c = 1:5
    ids = catCrop{c};
    for tt = 1:nT
        a1 = X1(:,ids,:,tt);
        a2 = X2(:,ids,:,tt);
        catArea1(tt,c)=sum(a1(:));
        catArea2(tt,c)=sum(a2(:));
    end
end

figure('Color','w','Position',[80 80 1180 540]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(years,catArea1,'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产完全滞销：作物类别年度种植结构');
legend(cellstr(catNames),'Location','bestoutside');

nexttile;
bar(years,catArea2,'stacked');
grid on;
xlabel('年份');
ylabel('种植面积/亩次');
title('超产按50%出售：作物类别年度种植结构');
legend(cellstr(catNames),'Location','bestoutside');

saveFig(figDir,'图6_作物类别年度种植结构.png');

%% ------------------------------------------------------------
% 图7：主要作物逐年种植面积热力图
% 用途：比柱状图更适合观察轮作造成的年份变化
% -------------------------------------------------------------
yearCrop1 = zeros(topN,nT);
yearCrop2 = zeros(topN,nT);

for rr = 1:topN
    j = top(rr);
    for tt = 1:nT
        a1 = X1(:,j,:,tt);
        a2 = X2(:,j,:,tt);
        yearCrop1(rr,tt)=sum(a1(:));
        yearCrop2(rr,tt)=sum(a2(:));
    end
end

figure('Color','w','Position',[80 60 1200 700]);
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(yearCrop1);
colorbar;
xticks(1:nT);
xticklabels(string(years));
yticks(1:topN);
yticklabels(cropNames(top));
xlabel('年份');
ylabel('作物');
title('超产完全滞销：主要作物逐年种植面积热力图');

nexttile;
imagesc(yearCrop2);
colorbar;
xticks(1:nT);
xticklabels(string(years));
yticks(1:topN);
yticklabels(cropNames(top));
xlabel('年份');
ylabel('作物');
title('超产按50%出售：主要作物逐年种植面积热力图');

saveFig(figDir,'图7_主要作物逐年面积热力图.png');

%% ------------------------------------------------------------
% 图8：水浇地种植模式变化
% 水稻面积反映单季水稻模式；
% 第二季蔬菜面积反映两季蔬菜模式的使用程度
% -------------------------------------------------------------
waterIdx = find(plotTypes=="水浇地");
rice1 = zeros(nT,1);
rice2 = zeros(nT,1);
waterVeg2_1 = zeros(nT,1);
waterVeg2_2 = zeros(nT,1);

for tt = 1:nT
    a = X1(waterIdx,16,1,tt);
    rice1(tt)=sum(a(:));
    a = X2(waterIdx,16,1,tt);
    rice2(tt)=sum(a(:));

    a = X1(waterIdx,35:37,2,tt);
    waterVeg2_1(tt)=sum(a(:));
    a = X2(waterIdx,35:37,2,tt);
    waterVeg2_2(tt)=sum(a(:));
end

figure('Color','w','Position',[80 80 1180 520]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar(years,[rice1,waterVeg2_1],'grouped');
grid on;
xlabel('年份');
ylabel('种植面积/亩');
title('超产完全滞销：水浇地种植模式');
legend({'水稻面积','第二季蔬菜面积'},'Location','best');

nexttile;
bar(years,[rice2,waterVeg2_2],'grouped');
grid on;
xlabel('年份');
ylabel('种植面积/亩');
title('超产按50%出售：水浇地种植模式');
legend({'水稻面积','第二季蔬菜面积'},'Location','best');

saveFig(figDir,'图8_水浇地种植模式变化.png');

%% ------------------------------------------------------------
% 图9：年度种植作物种类数
% 每年只要某作物总面积>0即计入一种
% 用途：观察方案是否更加集中或多样化
% -------------------------------------------------------------
div1 = zeros(nT,1);
div2 = zeros(nT,1);

for tt = 1:nT
    cropYear1 = zeros(nJ,1);
    cropYear2 = zeros(nJ,1);
    for j = 1:nJ
        a1 = X1(:,j,:,tt);
        a2 = X2(:,j,:,tt);
        cropYear1(j)=sum(a1(:));
        cropYear2(j)=sum(a2(:));
    end
    div1(tt)=sum(cropYear1>tol);
    div2(tt)=sum(cropYear2>tol);
end

figure('Color','w','Position',[120 100 900 520]);
plot(years,div1,'-o','LineWidth',1.6,'MarkerSize',7);
hold on;
plot(years,div2,'-s','LineWidth',1.6,'MarkerSize',7);
grid on;
xlabel('年份');
ylabel('实际种植作物种类数');
title('两种销售情形下年度作物种类数');
legend({'超产完全滞销','超产按50%出售'},'Location','best');
xticks(years);

saveFig(figDir,'图9_年度作物种类数.png');

%% ------------------------------------------------------------
% 图10：允许半价销售带来的年度利润增量及增幅
% -------------------------------------------------------------
profitIncrease = M2.yearProfit-M1.yearProfit;
profitRate = 100*profitIncrease./M1.yearProfit;

figure('Color','w','Position',[100 80 1050 560]);
yyaxis left
bar(years,profitIncrease/1e4);
ylabel('利润增量/万元');

yyaxis right
plot(years,profitRate,'-o','LineWidth',1.6,'MarkerSize',7);
ylabel('利润增幅/%');

grid on;
xlabel('年份');
title('超产按50%出售相对完全滞销的年度利润提升');
legend({'利润增量','利润增幅'},'Location','best');

saveFig(figDir,'图10_年度利润增量与增幅.png');

%% 6. 额外输出：图表对应的关键数据表
cropTable = table((1:nJ)',cropNames,totalCrop1,totalCrop2,cropDiff, ...
    'VariableNames',{'作物编号','作物名称','完全滞销累计面积','50%出售累计面积','面积差值'});
cropTable = sortrows(cropTable,'面积差值','descend');

fprintf('\n累计种植面积变化最大的作物（按差值从大到小）：\n');
disp(cropTable(1:min(15,height(cropTable)),:));

fprintf('\n所有图像已保存到：\n%s\n',figDir);
fprintf('\n论文中优先推荐使用：图1、图4、图5/图6、图7、图8。\n');

end

%% ============================================================
%                     辅助函数
% ============================================================

function X = readResultWorkbook(fileName,plotNames,nJ,years)
% 从题目结果模板中读取种植面积
% 第一季：B2:B55地块名，C2:AQ55面积
% 第二季：B56:B83地块名，C56:AQ83面积

nI = numel(plotNames);
nT = numel(years);
X = zeros(nI,nJ,2,nT);

for tt = 1:nT
    sh = num2str(years(tt));

    % 第一季
    p1 = string(readcell(fileName,'Sheet',sh,'Range','B2:B55'));
    M1 = readmatrix(fileName,'Sheet',sh,'Range','C2:AQ55');
    M1(isnan(M1))=0;

    for r = 1:numel(p1)
        name = strtrim(p1(r));
        i = find(plotNames==name,1);
        if ~isempty(i)
            X(i,:,1,tt)=M1(r,:);
        end
    end

    % 第二季
    p2 = string(readcell(fileName,'Sheet',sh,'Range','B56:B83'));
    M2 = readmatrix(fileName,'Sheet',sh,'Range','C56:AQ83');
    M2(isnan(M2))=0;

    for r = 1:numel(p2)
        name = strtrim(p2(r));
        i = find(plotNames==name,1);
        if ~isempty(i)
            X(i,:,2,tt)=M2(r,:);
        end
    end
end
end

function M = calcMetrics(X,alpha,Yield,Cost,PriceJS,expectedSales,plotTypes)
% 按原问题一目标函数计算收入、成本、利润等指标

[nI,nJ,nS,nT] = size(X);

yearRevenue = zeros(nT,1);
yearCost = zeros(nT,1);
yearProfit = zeros(nT,1);
yearArea = zeros(nT,1);
seasonArea = zeros(nT,nS);

Cost0 = Cost;
Cost0(~isfinite(Cost0))=0;

for tt = 1:nT
    % 成本和面积
    Xyear = X(:,:,:,tt);
    yearArea(tt)=sum(Xyear(:));

    for s = 1:nS
        xs = X(:,:,s,tt);
        seasonArea(tt,s)=sum(xs(:));
    end

    tmpCost = Xyear.*Cost0;
    yearCost(tt)=sum(tmpCost(:));

    % 收入
    rev = 0;
    for j = 1:nJ
        for s = 1:nS
            p = PriceJS(j,s);
            if ~isfinite(p)
                continue;
            end

            q = 0;
            for i = 1:nI
                if isfinite(Yield(i,j,s))
                    q = q + Yield(i,j,s)*X(i,j,s,tt);
                end
            end

            u = min(q,expectedSales(j));
            v = max(q-expectedSales(j),0);
            rev = rev + p*(u+alpha*v);
        end
    end

    yearRevenue(tt)=rev;
    yearProfit(tt)=yearRevenue(tt)-yearCost(tt);
end

M.yearRevenue=yearRevenue;
M.yearCost=yearCost;
M.yearProfit=yearProfit;
M.yearArea=yearArea;
M.seasonArea=seasonArea;
end

function s = cleanString(x)
if isempty(x)
    s="";
else
    try
        s=strtrim(string(x));
        if ismissing(s)
            s="";
        end
    catch
        s="";
    end
end
end

function v = cellToDouble(x)
if isnumeric(x) && isscalar(x)
    v=double(x);
else
    try
        v=str2double(strtrim(string(x)));
        if isempty(v) || ~isscalar(v)
            v=NaN;
        end
    catch
        v=NaN;
    end
end
end

function s = seasonCode(x)
txt=cleanString(x);
if txt=="单季" || txt=="第一季"
    s=1;
elseif txt=="第二季"
    s=2;
else
    s=0;
end
end

function p = priceMidpoint(x)
txt=char(cleanString(x));
nums=regexp(txt,'\d+(\.\d+)?','match');
if isempty(nums)
    p=NaN;
elseif numel(nums)==1
    p=str2double(nums{1});
else
    p=(str2double(nums{1})+str2double(nums{2}))/2;
end
end

function saveFig(figDir,fileName)
% 保存300dpi PNG
drawnow;
exportgraphics(gcf,fullfile(figDir,fileName),'Resolution',300);
end
