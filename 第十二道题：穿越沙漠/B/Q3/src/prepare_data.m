function data = prepare_data(caseID, projectRoot)
%PREPARE_DATA 整理第三问第五关或第六关的数据

if nargin < 2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

data.caseID = caseID;
data.projectRoot = projectRoot;


% 基础资源参数
data.maxLoad = 1200;
data.initialCash = 10000;

data.waterWeight = 3;
data.foodWeight = 2;

data.waterPrice = 5;
data.foodPrice = 10;

data.returnWaterPrice = 0.5 * data.waterPrice;
data.returnFoodPrice = 0.5 * data.foodPrice;

data.singleMoveFactor = 2;
data.singleMineFactor = 3;
data.singleVillagePriceFactor = 2;


% 天气编号：1-晴朗，2-高温，3-沙暴
data.weatherNames = ["晴朗", "高温", "沙暴"];

data.waterBaseUse = [3, 9, 10];
data.foodBaseUse = [4, 9, 10];


% 多人规则
% k人同向行走：2k倍基础消耗
% k人同矿挖矿：3k倍基础消耗，每人获得1/k基础收益
% k>=2人在同一村庄购买：4k倍基准价格
data.multiplayer.moveFactorPerPlayer = 2;
data.multiplayer.mineFactorPerPlayer = 3;
data.multiplayer.buyFactorPerPlayer = 4;


switch caseID

    case 5
        data = prepare_case5(data);

    case 6
        data = prepare_case6(data);

    otherwise
        error('caseID 只能取 5 或 6。');

end


% 邻接列表
data.neighbors = build_neighbors( ...
    data.numRegions, data.edges);


% 最优响应迭代中的数值设置
data.algorithm.maxGameIterations = 50;
data.algorithm.wealthTolerance = 1e-8;

% 多个策略最终资金相同时：
% 先选较早到达终点的方案，再选初始购买较少的方案。
data.algorithm.tieBreakEarlierArrival = true;
data.algorithm.tieBreakLowerInitialLoad = true;

end



function data = prepare_case5(data)
% 第三问(1)：第五关

data.numPlayers = 2;

data.numRegions = 13;

data.deadline = 10;

data.startRegion = 1;
data.endRegion = 13;

data.mineRegions = 9;
data.villageRegions = [];

data.mineIncome = 200;


% 附件给出的10天天气
% 1-晴朗，2-高温，3-沙暴
data.weather = [ ...
    1, 2, 1, 1, 1, ...
    1, 2, 2, 2, 2];


% 第五关地图邻接关系
% 每一行表示两个区域具有公共边界。
edges = [ ...
     1  2
     1  4
     1  5
     2  3
     2  4
     3  4
     3  8
     3  9
     4  5
     4  6
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
    10 13
    11 12
    11 13
    12 13
    ];

data.edges = edges;


% 绘图用坐标，仅用于让网络图外形接近附件地图。
% 不参与模型计算和邻接判断。
data.plotX = [ ...
    1.25
    0.70
    2.00
    2.40
    2.25
    4.35
    3.45
    2.35
    3.30
    4.35
    4.35
    4.75
    5.35
    ];

data.plotY = [ ...
    1.50
    2.90
    3.70
    2.50
    0.85
    1.05
    2.60
    4.45
    4.45
    4.85
    3.70
    2.85
    3.05
    ];


% 第五关天气全部提前已知，因此不需要沙暴预算状态。
data.maxStormDays = 0;
data.robustWeather = false;

end



function data = prepare_case6(data)
% 第三问(2)：第六关

data.numPlayers = 3;

data.numRegions = 25;

data.deadline = 30;

data.startRegion = 1;
data.endRegion = 25;

data.villageRegions = 14;
data.mineRegions = 18;

data.mineIncome = 1000;


% 第六关未来完整天气没有给出。
% 实际逐日执行时只使用当天已观测天气。
data.weather = [];


% "30天内较少出现沙暴"的量化假设。
% 这不是附件直接给出的数值。
data.maxStormDays = 3;
data.robustWeather = true;


% 第六关是5×5区域图。
% 具有公共水平或竖直边界的两个格子视为相邻。
edges = zeros(0, 2);

for row = 1:5

    for col = 1:5

        region = (row - 1) * 5 + col;

        if col < 5
            edges(end+1, :) = [region, region + 1]; %#ok<AGROW>
        end

        if row < 5
            edges(end+1, :) = [region, region + 5]; %#ok<AGROW>
        end

    end

end

data.edges = edges;


% 与附件5×5地图一致的绘图坐标
data.plotX = zeros(data.numRegions, 1);
data.plotY = zeros(data.numRegions, 1);

for row = 1:5

    for col = 1:5

        region = (row - 1) * 5 + col;

        data.plotX(region) = col;
        data.plotY(region) = 6 - row;

    end

end

end



function neighbors = build_neighbors(numRegions, edges)
% 根据无向边表生成邻接列表

neighbors = cell(numRegions, 1);

for edgeID = 1:size(edges, 1)

    regionA = edges(edgeID, 1);
    regionB = edges(edgeID, 2);

    neighbors{regionA}(end+1) = regionB;
    neighbors{regionB}(end+1) = regionA;

end

for region = 1:numRegions
    neighbors{region} = sort(unique(neighbors{region}));
end

end