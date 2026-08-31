function data = prepare_data_case4(projectRoot)
%PREPARE_DATA_CASE4 整理第四关参数、地图和保证型天气设定

if nargin < 1
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

% 基本参数
data.caseID = 4;
data.numRegions = 25;
data.startRegion = 1;
data.endRegion = 25;
data.mineRegions = 18;
data.villageRegions = 14;

data.deadline = 30;
data.maxLoad = 1200;
data.initialCash = 10000;
data.mineIncome = 1000;

% 资源参数
data.waterWeight = 3;
data.foodWeight = 2;
data.waterPrice = 5;
data.foodPrice = 10;

data.weatherNames = ["晴朗", "高温", "沙暴"];
data.waterBaseUse = [3, 9, 10];
data.foodBaseUse = [4, 9, 10];

data.stayMultiplier = 1;
data.moveMultiplier = 2;
data.mineMultiplier = 3;

% 村庄和终点价格
data.villageWaterPrice = 2 * data.waterPrice;
data.villageFoodPrice = 2 * data.foodPrice;
data.refundWaterPrice = 0.5 * data.waterPrice;
data.refundFoodPrice = 0.5 * data.foodPrice;

% 第四关只说明“较少出现沙暴”，没有给出概率或准确次数。
% 为使保证型动态规划可计算，这里显式采用“30天内最多3个沙暴日”的量化口径。
% 若论文最终采用其他口径，只需修改此处一个参数，其他代码无需改变。
data.maxStormDays = 3;

% 在保证型目标下，晴朗天气的资源消耗严格低于高温，行动限制相同，
% 因而最不利非沙暴天气一定是高温。求保证值时只需考虑高温和沙暴。
data.robustWeatherNames = ["高温", "沙暴"];
data.robustHighID = 1;
data.robustStormID = 2;

% 高温和沙暴下，水与食物的基础消耗相同。
% 因此保证型计算可以用“一箱水+一箱食物”为一个资源对。
data.pairWeight = data.waterWeight + data.foodWeight;
data.startPairPrice = data.waterPrice + data.foodPrice;
data.villagePairPrice = data.villageWaterPrice + data.villageFoodPrice;
data.refundPairPrice = data.refundWaterPrice + data.refundFoodPrice;
data.maxPairs = floor(data.maxLoad / data.pairWeight);

% 资源对消耗量：行表示高温、沙暴；列依次为停留、行走、挖矿
% 沙暴不能行走，第二行的行走数值只保留形式，不会被调用。
data.pairUse = [ ...
     9, 18, 27; ...
    10, 20, 30];

% 第四关地图是5×5方格，相邻格之间均有通道。
edges = zeros(0, 2);
for r = 1:5
    for c = 1:5
        i = (r-1) * 5 + c;

        if c < 5
            edges(end+1, :) = [i, i+1]; %#ok<AGROW>
        end

        if r < 5
            edges(end+1, :) = [i, i+5]; %#ok<AGROW>
        end
    end
end

data.edges = edges;
data.neighbors = cell(data.numRegions, 1);

for k = 1:size(edges, 1)
    i = edges(k, 1);
    j = edges(k, 2);

    data.neighbors{i}(end+1) = j;
    data.neighbors{j}(end+1) = i;
end

for i = 1:data.numRegions
    data.neighbors{i} = sort(unique(data.neighbors{i}));
end

% 绘图坐标，与附件5×5地图一致
plotX = zeros(data.numRegions, 1);
plotY = zeros(data.numRegions, 1);
for r = 1:5
    for c = 1:5
        i = (r-1) * 5 + c;
        plotX(i) = c;
        plotY(i) = 6 - r;
    end
end

data.plotX = plotX;
data.plotY = plotY;
data.projectRoot = projectRoot;

end
