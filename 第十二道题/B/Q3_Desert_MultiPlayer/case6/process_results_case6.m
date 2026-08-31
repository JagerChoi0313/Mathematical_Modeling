function result = process_results_case6(solution, data)
%PROCESS_RESULTS_CASE6 整理第六关三玩家代表性最不利情形结果

dailyTables = solution.simulation.dailyTables;
P = data.numPlayers;

summary = table((1:P)',zeros(P,1),zeros(P,1),zeros(P,1), ...
    zeros(P,1),zeros(P,1),zeros(P,1), ...
    'VariableNames', {'Player','InitialWater','InitialFood','InitialLoad', ...
    'ArrivalDay','MineDays','FinalWealth'});

for p = 1:P
    T = dailyTables{p};

    arrival = find(T.EndRegion == data.endRegion & T.StartRegion ~= data.endRegion,1);
    if isempty(arrival)
        arrivalDay = NaN;
    else
        arrivalDay = T.Day(arrival);
    end

    summary.InitialWater(p) = solution.initialPairs(p);
    summary.InitialFood(p) = solution.initialPairs(p);
    summary.InitialLoad(p) = data.pairWeight*solution.initialPairs(p);
    summary.ArrivalDay(p) = arrivalDay;
    summary.MineDays(p) = sum(T.Mine);
    summary.FinalWealth(p) = solution.simulation.finalWealth(p);
end

result.summary = summary;
result.dailyTables = dailyTables;
result.weatherText = solution.weatherText;

outputDir = fullfile(data.projectRoot,'output','case6');
if ~isfolder(outputDir), mkdir(outputDir); end

writetable(summary,fullfile(outputDir,'case6_summary.xlsx'));
for p = 1:P
    writetable(dailyTables{p}, ...
        fullfile(outputDir,sprintf('case6_player%d_daily.xlsx',p)));
end

weatherTable = table((1:numel(solution.simulation.weatherNames))', ...
    solution.simulation.weatherNames', ...
    'VariableNames',{'Day','RepresentativeWorstWeather'});
writetable(weatherTable,fullfile(outputDir,'case6_weather.xlsx'));

save(fullfile(outputDir,'case6_solution.mat'),'solution','result','data');
end
