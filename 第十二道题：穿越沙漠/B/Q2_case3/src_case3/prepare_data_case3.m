function data = prepare_data_case3(projectRoot)
%PREPARE_DATA_CASE3 整理第三关参数与地图邻接关系

if nargin < 1
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

% 关卡基本参数
data.caseID = 3;
data.numRegions = 13;
data.startRegion = 1;
data.endRegion = 13;
data.mineRegions = 9;
data.villageRegions = [];
data.deadline = 10;

data.maxLoad = 1200;
data.initialCash = 10000;
data.mineIncome = 200;

% 资源参数：晴朗、高温、沙暴
data.waterWeight = 3;
data.foodWeight = 2;
data.waterPrice = 5;
data.foodPrice = 10;
data.waterBaseUse = [3, 9, 10];
data.foodBaseUse = [4, 9, 10];
data.weatherNames = ["晴朗", "高温", "沙暴"];

% 第三关明确说明10天内不会出现沙暴
data.allowedWeather = [1, 2];

% 行动倍率
data.stayMultiplier = 1;
data.moveMultiplier = 2;
data.mineMultiplier = 3;

% 可由题目参数直接得到的量
data.villageWaterPrice = 2 * data.waterPrice;
data.villageFoodPrice = 2 * data.foodPrice;
data.refundWaterPrice = 0.5 * data.waterPrice;
data.refundFoodPrice = 0.5 * data.foodPrice;
data.maxWater = floor(data.maxLoad / data.waterWeight);
data.maxFood = floor(data.maxLoad / data.foodWeight);

% 根据附件第三关地图按"有公共边界才相邻"整理的无向边
edges = [
     1  2
     1  4
     1  5
     2  3
     2  4
     3  4
     3  8
     3  9
     4  5
     4  7
     5  6
     6  7
     6 12
     6 13
     7 11
     7 12
     8  9
     9 10
     9 11
    10 11
    11 12
    11 13
    12 13
    ];

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

% 仅用于绘图的相对坐标，不参与动态规划计算
data.plotX = [2.1, 1.1, 2.7, 3.3, 3.1, 5.3, 4.6, 3.1, 4.5, 6.0, 5.5, 6.3, 7.4];
data.plotY = [1.2, 2.8, 4.2, 2.7, 0.7, 0.8, 2.8, 5.2, 4.8, 5.4, 4.0, 2.9, 2.9];

data.projectRoot = projectRoot;
end
