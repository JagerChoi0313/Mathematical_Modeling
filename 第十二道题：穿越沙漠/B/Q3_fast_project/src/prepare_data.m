function data = prepare_data(caseID, projectRoot)
%PREPARE_DATA 整理第三问第五关或第六关的题目参数

if nargin < 2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

data.caseID = caseID;
data.projectRoot = projectRoot;

data.maxLoad = 1200;
data.initialCash = 10000;
data.waterWeight = 3;
data.foodWeight = 2;
data.waterPrice = 5;
data.foodPrice = 10;
data.returnWaterPrice = 0.5 * data.waterPrice;
data.returnFoodPrice = 0.5 * data.foodPrice;

data.weatherNames = ["晴朗", "高温", "沙暴"];
data.waterBaseUse = [3, 9, 10];
data.foodBaseUse = [4, 9, 10];

% 多人规则：同行2k倍、同矿3k倍、多人购买4k倍基准价格
% 单人购买仍按题目单人规则：2倍基准价格。
data.multiplayer.moveFactor = 2;
data.multiplayer.mineFactor = 3;
data.multiplayer.buyFactor = 4;

switch caseID
    case 5
        data = prepare_case5(data);
    case 6
        data = prepare_case6(data);
    otherwise
        error('caseID只能为5或6。');
end

data.neighbors = build_neighbors(data.numRegions, data.edges);

% 外层最优响应参数
if caseID == 5
    data.algorithm.maxGameIterations = 20;
else
    data.algorithm.maxGameIterations = 3;
end

data.algorithm.wealthTolerance = 1e-8;

% 第六关快速滚动/场景鲁棒近似的候选规模
% 这些是算法离散化设置，不是题目参数。
data.algorithm.case6InitialPairStep = 20;
data.algorithm.case6MineDayMax = 6;
data.algorithm.case6VillageTargets = [200 240];

data.outputDir = fullfile(projectRoot, 'output', sprintf('case%d', caseID));
data.figureDir = fullfile(projectRoot, 'figures', sprintf('case%d', caseID));
if ~isfolder(data.outputDir), mkdir(data.outputDir); end
if ~isfolder(data.figureDir), mkdir(data.figureDir); end
end


function data = prepare_case5(data)
data.numPlayers = 2;
data.numRegions = 13;
data.deadline = 10;
data.startRegion = 1;
data.endRegion = 13;
data.mineRegions = 9;
data.villageRegions = [];
data.mineIncome = 200;
data.weather = [1 2 1 1 1 1 2 2 2 2];
data.maxStormDays = 0;
data.robustWeather = false;

% 第五关地图公共边界邻接表
% 如果你之后重新人工核对附件地图，只需修改这里。
data.edges = [ ...
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
    12 13];

% 仅用于画图，不参与模型计算
[data.plotX, data.plotY] = deal([ ...
    1.2; 0.5; 1.7; 2.0; 2.2; 3.4; 3.0; 1.8; 3.4; 4.0; 4.4; 4.8; 5.3], ...
    [1.1; 2.8; 3.7; 2.5; 0.7; 1.0; 2.5; 4.5; 4.4; 4.9; 3.6; 2.8; 3.0]);
end


function data = prepare_case6(data)
data.numPlayers = 3;
data.numRegions = 25;
data.deadline = 30;
data.startRegion = 1;
data.endRegion = 25;
data.villageRegions = 14;
data.mineRegions = 18;
data.mineIncome = 1000;
data.weather = [];
data.robustWeather = true;

% “较少沙暴”的量化假设：最多3天沙暴。
data.maxStormDays = 3;

edges = zeros(0, 2);
for r = 1:5
    for c = 1:5
        u = (r - 1) * 5 + c;
        if c < 5
            edges(end + 1, :) = [u, u + 1]; %#ok<AGROW>
        end
        if r < 5
            edges(end + 1, :) = [u, u + 5]; %#ok<AGROW>
        end
    end
end

data.edges = edges;
data.plotX = zeros(25, 1);
data.plotY = zeros(25, 1);
for r = 1:5
    for c = 1:5
        u = (r - 1) * 5 + c;
        data.plotX(u) = c;
        data.plotY(u) = 6 - r;
    end
end
end


function neighbors = build_neighbors(n, edges)
neighbors = cell(n, 1);
for e = 1:size(edges, 1)
    a = edges(e, 1);
    b = edges(e, 2);
    neighbors{a}(end + 1) = b;
    neighbors{b}(end + 1) = a;
end
for i = 1:n
    neighbors{i} = sort(unique(neighbors{i}));
end
end
