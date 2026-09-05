clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src_case4'));

outputDir = fullfile(projectRoot, 'output', 'case4');
figureDir = fullfile(projectRoot, 'figures', 'case4');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

if ~isfolder(figureDir)
    mkdir(figureDir);
end

fprintf('正在准备第四关数据...\n');
data = prepare_data_case4(projectRoot);

fprintf('第四关“较少沙暴”按最多 %d 天沙暴处理。\n', ...
    data.maxStormDays);

fprintf('正在进行第四关保证型动态规划求解...\n');
dpResult = solve_case4(data);

fprintf('正在整理第四关结果...\n');
result = process_results_case4(dpResult, data);

export_results_case4(result, dpResult, data, projectRoot);
plot_results_case4(result, data, projectRoot);

fprintf('\n第四关计算完成。\n');
fprintf('初始购买：水 %d 箱，食物 %d 箱\n', ...
    result.summary.InitialWater, ...
    result.summary.InitialFood);
fprintf('初始负重：%.0f kg\n', result.summary.InitialLoad);
fprintf('保证型最优财富：%.2f 元\n', result.summary.GuaranteedWealth);
fprintf('共检查 %d 种高温/沙暴情景。\n', height(result.scenarioTable));
fprintf('最不利沙暴日：%s\n', result.worstStormDaysText);
fprintf('最不利情形最终财富：%.2f 元\n', result.worstFinalWealth);
fprintf('所有情景现金非负：%d\n', result.summary.AllCashFeasible);
fprintf('动态规划与情景复核差值：%.6f 元\n', result.summary.ConsistencyGap);
fprintf('结果目录：%s\n', outputDir);
