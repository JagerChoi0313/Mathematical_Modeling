function data = prepare_data_case5(projectRoot)
%PREPARE_DATA_CASE5 第五关参数和地图

data.caseID = 5;
data.numPlayers = 2;
data.numRegions = 13;

data.startRegion = 1;
data.mineRegion = 9;
data.endRegion = 13;
data.villageRegion = [];

data.deadline = 10;
data.maxLoad = 1200;
data.initialCash = 10000;
data.baseIncome = 200;

data.waterWeight = 3;
data.foodWeight = 2;
data.waterPrice = 5;
data.foodPrice = 10;

data.weatherNames = ["晴朗","高温","沙暴"];
data.weather = [1,2,1,1,1,1,2,2,2,2];

data.waterBaseUse = [3,9,10];
data.foodBaseUse = [4,9,10];

data.refundWaterPrice = 0.5 * data.waterPrice;
data.refundFoodPrice = 0.5 * data.foodPrice;

% 根据附件第五关地图的公共边界建立邻接关系
data.edges = [
    1 2
    1 4
    1 5
    2 3
    2 4
    3 4
    3 8
    3 9
    4 5
    4 7
    5 6
    6 7
    6 12
    6 13
    7 11
    7 12
    8 9
    9 10
    9 11
    10 11
    11 12
    11 13
    12 13
    ];

data.neighbors = cell(data.numRegions,1);
for e = 1:size(data.edges,1)
    i = data.edges(e,1);
    j = data.edges(e,2);
    data.neighbors{i}(end+1) = j;
    data.neighbors{j}(end+1) = i;
end
for i = 1:data.numRegions
    data.neighbors{i} = sort(unique(data.neighbors{i}));
end

% 绘图坐标仅用于显示，不参与优化
data.plotX = [1.2,0.2,2.0,2.6,2.1,5.1,4.0,2.6,3.9,5.5,5.0,6.0,7.2];
data.plotY = [0.6,2.1,3.3,2.0,0.2,0.3,2.1,4.3,3.7,4.6,3.0,2.2,2.2];

actions = struct('from',{},'to',{},'type',{},'multiplier',{},'label',{});

% 普通停留
for i = 1:data.numRegions
    a.from = i;
    a.to = i;
    if i == data.endRegion
        a.type = "terminal";
        a.multiplier = 0;
        a.label = "终点停留";
    else
        a.type = "stay";
        a.multiplier = 1;
        a.label = "停留";
    end
    actions(end+1) = a; %#ok<AGROW>
end

% 挖矿是矿山上的独立行动
a.from = data.mineRegion;
a.to = data.mineRegion;
a.type = "mine";
a.multiplier = 3;
a.label = "挖矿";
actions(end+1) = a;
data.mineActionIndex = numel(actions);

% 每条无向边生成两个有向移动动作
moveActionIndices = [];
for e = 1:size(data.edges,1)
    i = data.edges(e,1);
    j = data.edges(e,2);

    if i ~= data.endRegion
        a.from = i; a.to = j; a.type = "move";
        a.multiplier = 2; a.label = "行走";
        actions(end+1) = a;
        moveActionIndices(end+1) = numel(actions); %#ok<AGROW>
    end

    if j ~= data.endRegion
        a.from = j; a.to = i; a.type = "move";
        a.multiplier = 2; a.label = "行走";
        actions(end+1) = a;
        moveActionIndices(end+1) = numel(actions); %#ok<AGROW>
    end
end

data.actions = actions;
data.numActions = numel(actions);
data.moveActionIndices = moveActionIndices;
data.actionMultiplier = [actions.multiplier];

data.projectRoot = projectRoot;
end
