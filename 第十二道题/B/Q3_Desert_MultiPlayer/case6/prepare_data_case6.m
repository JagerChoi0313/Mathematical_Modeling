function data = prepare_data_case6(projectRoot)
%PREPARE_DATA_CASE6 第六关参数和地图

data.caseID = 6;
data.numPlayers = 3;
data.numRegions = 25;

data.startRegion = 1;
data.villageRegion = 14;
data.mineRegion = 18;
data.endRegion = 25;

data.deadline = 30;
data.maxLoad = 1200;
data.initialCash = 10000;
data.baseIncome = 1000;

data.waterWeight = 3;
data.foodWeight = 2;
data.waterPrice = 5;
data.foodPrice = 10;

data.waterBaseUse = [3,9,10];
data.foodBaseUse = [4,9,10];
data.weatherNames = ["晴朗","高温","沙暴"];

% 附件只给出“30天内较少出现沙暴”，没有给出次数。
% 延续第四关的量化假设：30天内沙暴最多3天。
data.maxStormDays = 3;

% 保证型求解时晴朗严格优于高温，因此最不利分支只保留高温和沙暴
data.robustWeatherNames = ["高温","沙暴"];
data.robustHighID = 1;
data.robustStormID = 2;
data.robustBaseUse = [9,10];

data.pairWeight = data.waterWeight + data.foodWeight;
data.startPairPrice = data.waterPrice + data.foodPrice;
data.villagePairPriceSolo = 2*(data.waterPrice + data.foodPrice);
data.villagePairPriceGroup = 4*(data.waterPrice + data.foodPrice);
data.refundPairPrice = 0.5*(data.waterPrice + data.foodPrice);
data.maxPairs = floor(data.maxLoad/data.pairWeight);

% 第六关地图为5×5网格，共享公共边界即相邻
edges = zeros(0,2);
for r = 1:5
    for c = 1:5
        i = (r-1)*5+c;
        if c < 5
            edges(end+1,:) = [i,i+1]; %#ok<AGROW>
        end
        if r < 5
            edges(end+1,:) = [i,i+5]; %#ok<AGROW>
        end
    end
end
data.edges = edges;

data.neighbors = cell(data.numRegions,1);
for e = 1:size(edges,1)
    i = edges(e,1); j = edges(e,2);
    data.neighbors{i}(end+1) = j;
    data.neighbors{j}(end+1) = i;
end
for i = 1:data.numRegions
    data.neighbors{i} = sort(unique(data.neighbors{i}));
end

plotX = zeros(data.numRegions,1);
plotY = zeros(data.numRegions,1);
for r = 1:5
    for c = 1:5
        i = (r-1)*5+c;
        plotX(i) = c;
        plotY(i) = 6-r;
    end
end
data.plotX = plotX;
data.plotY = plotY;

data.projectRoot = projectRoot;
end
