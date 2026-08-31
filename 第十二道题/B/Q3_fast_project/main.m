clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));

% 调试时可改成 5 或 6；最终可使用 [5 6]
runCases = [5 6];

for caseID = runCases
    fprintf('\n正在计算第三问第 %d 关...\n', caseID);

    data = prepare_data(caseID, projectRoot);
    gameResult = solve_game(data);
    simulation = simulate_strategy(gameResult.strategies, gameResult, data);
    validation = validate_results(simulation, gameResult, data);

    export_results(simulation, gameResult, validation, data, projectRoot);
    plot_results(simulation, gameResult, data, projectRoot);

    fprintf('\n第 %d 关完成。\n', caseID);
    fprintf('策略状态：%s\n', status_text(gameResult));
    fprintf('最优响应迭代轮数：%d\n', gameResult.iterations);

    for i = 1:data.numPlayers
        P = simulation.players(i);
        fprintf(['玩家%d：初始水%d箱，食物%d箱，第%d天到达终点，' ...
                 '挖矿%d天，最终资金%.2f元。\n'], ...
            i, P.initialWater, P.initialFood, P.arrivalDay, ...
            P.mineDays, P.finalWealth);
    end

    if validation.allPassed
        fprintf('逐日规则复核：通过\n');
    else
        fprintf('逐日规则复核：未通过，请查看输出检查表。\n');
    end
end

function txt = status_text(gameResult)
if gameResult.converged
    txt = '已达到稳定策略';
elseif gameResult.cycleDetected
    txt = '检测到最优响应循环';
else
    txt = '达到最大迭代次数';
end
end
