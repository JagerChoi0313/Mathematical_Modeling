function result = process_results_case5(solution, data)
%PROCESS_RESULTS_CASE5 将MILP输出整理成逐日表格

sol = solution.sol;
P = data.numPlayers;
T = data.deadline;

dailyTables = cell(P,1);

summary = table((1:P)', zeros(P,1), zeros(P,1), zeros(P,1), ...
    zeros(P,1), zeros(P,1), zeros(P,1), ...
    'VariableNames', {'Player','InitialWater','InitialFood','InitialLoad', ...
    'ArrivalDay','MineDays','FinalWealth'});

for p = 1:P
    rows = cell(T+1,11);

    rows(1,:) = {0,"",data.startRegion,"初始购买",data.startRegion, ...
        sol.buyWater(p),sol.buyFood(p),sol.cash(p,1),0,1,0};

    arrivalDay = NaN;
    mineDays = 0;

    for t = 1:T
        aIdx = find(squeeze(sol.act(p,:,t)) > 0.5, 1);
        a = data.actions(aIdx);

        if a.type == "move"
            groupSize = 1;
            for q = 1:P
                if q == p, continue; end
                aq = find(squeeze(sol.act(q,:,t)) > 0.5,1);
                b = data.actions(aq);
                if b.type == "move" && b.from == a.from && b.to == a.to
                    groupSize = groupSize + 1;
                end
            end
        elseif a.type == "mine"
            groupSize = sum(squeeze(sol.act(:,data.mineActionIndex,t)) > 0.5);
            mineDays = mineDays + 1;
        else
            groupSize = 1;
        end

        if a.type == "mine"
            actionText = "挖矿";
        elseif a.type == "move"
            actionText = "行走";
        elseif a.type == "terminal"
            actionText = "已到终点";
        else
            actionText = "停留";
        end

        rows(t+1,:) = {t,data.weatherNames(data.weather(t)),a.from,actionText,a.to, ...
            sol.water(p,t+1),sol.food(p,t+1),sol.cash(p,t+1), ...
            double(a.type=="mine"),groupSize,aIdx};

        if isnan(arrivalDay) && a.to == data.endRegion && a.from ~= data.endRegion
            arrivalDay = t;
        end
    end

    dailyTables{p} = cell2table(rows, ...
        'VariableNames', {'Day','Weather','StartRegion','Action','EndRegion', ...
        'WaterLeft','FoodLeft','CashLeft','Mine','GroupSize','ActionIndex'});

    finalWealth = sol.cash(p,T+1) ...
        + data.refundWaterPrice*sol.water(p,T+1) ...
        + data.refundFoodPrice*sol.food(p,T+1);

    summary.InitialWater(p) = round(sol.buyWater(p));
    summary.InitialFood(p) = round(sol.buyFood(p));
    summary.InitialLoad(p) = data.waterWeight*sol.buyWater(p) ...
        + data.foodWeight*sol.buyFood(p);
    summary.ArrivalDay(p) = arrivalDay;
    summary.MineDays(p) = mineDays;
    summary.FinalWealth(p) = finalWealth;
end

result.dailyTables = dailyTables;
result.summary = summary;
result.objective = solution.objective;

outputDir = fullfile(data.projectRoot,'output','case5');
if ~isfolder(outputDir), mkdir(outputDir); end

writetable(summary, fullfile(outputDir,'case5_summary.xlsx'));
for p = 1:P
    writetable(dailyTables{p}, ...
        fullfile(outputDir,sprintf('case5_player%d_daily.xlsx',p)));
end

save(fullfile(outputDir,'case5_solution.mat'),'solution','result','data');
end
