function data = prepare_data(caseID, projectRoot)
%PREPARE_DATA 读取并整理第一问第一关或第二关的数据

if nargin < 2 || isempty(projectRoot)
    srcDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(srcDir);
end

if ~ismember(caseID, [1, 2])
    error('caseID 只能取 1 或 2。');
end

dataDir = fullfile(projectRoot, 'data');

% 两关共用参数
data.caseID       = caseID;
data.T            = 30;
data.capacity     = 1200;
data.initialMoney = 10000;
data.mineIncome   = 1000;

data.waterWeight = 3;
data.foodWeight  = 2;
data.waterPrice  = 5;
data.foodPrice   = 10;

data.villageWaterPrice = 2 * data.waterPrice;
data.villageFoodPrice  = 2 * data.foodPrice;
data.refundWaterPrice  = 0.5 * data.waterPrice;
data.refundFoodPrice   = 0.5 * data.foodPrice;

data.maxWaterBoxes = floor(data.capacity / data.waterWeight);
data.maxFoodBoxes  = floor(data.capacity / data.foodWeight);

switch caseID
    case 1
        data.caseName = "第一关";
        data.numNodes = 27;
        data.startNode = 1;
        data.endNode = 27;

        % 第一关附件：矿山12，村庄15
        data.mineNodes = 12;
        data.villageNodes = 15;

        edgeFile = fullfile(dataDir, 'adjacency_case1.xlsx');

    case 2
        data.caseName = "第二关";
        data.numNodes = 64;
        data.startNode = 1;
        data.endNode = 64;

        % 第二关附件：矿山30、55，村庄39、62
        data.mineNodes = [30, 55];
        data.villageNodes = [39, 62];

        edgeFile = fullfile(dataDir, 'adjacency_case2.xlsx');
end

% 1=晴朗，2=高温，3=沙暴
weatherCode = [ ...
    2 2 1 3 1 2 3 1 2 2 ...
    3 2 1 2 2 2 3 3 2 2 ...
    1 1 2 1 3 2 1 1 2 2];

weatherLabels = ["晴朗", "高温", "沙暴"];

data.weatherCode = weatherCode;
data.weatherName = weatherLabels(weatherCode);
data.isStorm = weatherCode == 3;

% 普通停留时的基础消耗量
waterConsumption = [5, 8, 10];
foodConsumption  = [7, 6, 10];

data.waterBase = waterConsumption(weatherCode);
data.foodBase  = foodConsumption(weatherCode);

if ~isfile(edgeFile)
    error('找不到地图邻接文件：%s', edgeFile);
end

edgeTable = readtable(edgeFile, 'VariableNamingRule', 'preserve');

if width(edgeTable) < 2
    error('邻接表至少需要两列 From、To。');
end

rawEdges = double(edgeTable{:, 1:2});

if any(~isfinite(rawEdges), 'all') || any(mod(rawEdges, 1) ~= 0, 'all')
    error('邻接表中存在空值或非整数区域编号。');
end

if any(rawEdges(:) < 1) || any(rawEdges(:) > data.numNodes)
    error('邻接表中存在超出当前关卡范围的区域编号。');
end

if any(rawEdges(:, 1) == rawEdges(:, 2))
    error('邻接表中不需要填写原地停留边。');
end

% 每条无向边只保留一次
undirectedEdges = sort(rawEdges, 2);
undirectedEdges = unique(undirectedEdges, 'rows', 'stable');

% 原图相邻边可双向通行
directedEdges = [
    undirectedEdges
    undirectedEdges(:, [2, 1])
    ];
directedEdges = unique(directedEdges, 'rows', 'stable');

% 每个区域允许原地停留
selfLoops = [(1:data.numNodes)', (1:data.numNodes)'];

data.undirectedEdges = undirectedEdges;
data.directedEdges = directedEdges;
data.selfLoops = selfLoops;
data.allowedMoves = [directedEdges; selfLoops];

adjacency = sparse( ...
    undirectedEdges(:,1), undirectedEdges(:,2), 1, ...
    data.numNodes, data.numNodes);

data.adjacency = adjacency + adjacency';

data.projectRoot = projectRoot;
data.dataDir = dataDir;
data.edgeFile = edgeFile;

end
