clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));
srcDir = fullfile(projectRoot, 'src');

addpath(srcDir);

runCases = [5 6];

for caseID = runCases

    fprintf('\n');
    fprintf('正在计算第三问第 %d 关...\n', caseID);

    outputDir = fullfile(projectRoot, 'output', ...
        sprintf('case%d', caseID));

    figureDir = fullfile(projectRoot, 'figures', ...
        sprintf('case%d', caseID));

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    if ~isfolder(figureDir)
        mkdir(figureDir);
    end

    fprintf('正在准备题目数据...\n');
    data = prepare_data(caseID, projectRoot);

    fprintf('正在进行多人最优响应求解...\n');
    gameResult = solve_game(data);

    fprintf('正在正向还原稳定策略...\n');
    simulation = simulate_strategy( ...
        gameResult.strategies, data);

    fprintf('正在复核题目约束...\n');
    validation = validate_results( ...
        simulation, gameResult, data);

    export_results( ...
        simulation, ...
        gameResult, ...
        validation, ...
        data, ...
        projectRoot);

    plot_results( ...
        simulation, ...
        gameResult, ...
        data, ...
        projectRoot);

    fprintf('\n第 %d 关计算完成。\n', caseID);

    if gameResult.converged
        fprintf('多人策略状态：已达到稳定策略。\n');
    elseif gameResult.cycleDetected
        fprintf('多人策略状态：最优响应发生循环。\n');
    else
        fprintf('多人策略状态：达到最大迭代次数后停止。\n');
    end

    fprintf('最优响应迭代轮数：%d\n', ...
        gameResult.iterations);

    for playerID = 1:data.numPlayers

        fprintf(['玩家 %d：初始水 %d 箱，食物 %d 箱，' ...
                 '第 %d 天到达终点，最终资金 %.2f 元。\n'], ...
            playerID, ...
            simulation.players(playerID).initialWater, ...
            simulation.players(playerID).initialFood, ...
            simulation.players(playerID).arrivalDay, ...
            simulation.players(playerID).finalWealth);
    end

    fprintf('逐日规则复核：%s\n', ...
        pass_text(validation.allPassed));

    fprintf('结果目录：%s\n', outputDir);
    fprintf('图片目录：%s\n', figureDir);

end


function textValue = pass_text(flag)

if flag
    textValue = '通过';
else
    textValue = '未通过';
end

end