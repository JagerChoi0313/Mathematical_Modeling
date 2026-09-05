clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src_case3'));

outputDir = fullfile(projectRoot, 'output', 'case3');
figureDir = fullfile(projectRoot, 'figures', 'case3');
if ~isfolder(outputDir)
    mkdir(outputDir);
end
if ~isfolder(figureDir)
    mkdir(figureDir);
end

fprintf('正在准备第三关数据...\n');
data = prepare_data_case3(projectRoot);

fprintf('正在进行第三关动态规划求解...\n');
dpResult = solve_case3(data);

fprintf('正在整理第三关结果...\n');
result = process_results_case3(dpResult, data);

export_results_case3(result, dpResult, data, projectRoot);
plot_results_case3(result, data, projectRoot);

fprintf('\n第三关计算完成。\n');
fprintf('初始购买：水 %d 箱，食物 %d 箱\n', ...
    result.summary.InitialWater, result.summary.InitialFood);
fprintf('初始负重：%.0f kg\n', result.summary.InitialLoad);
fprintf('保证型最优财富：%.2f 元\n', result.summary.GuaranteedWealth);
fprintf('共检查 %d 种允许天气序列。\n', height(result.scenarioTable));
fprintf('最不利天气序列：%s\n', result.worstWeatherText);
fprintf('最不利情形最终财富：%.2f 元\n', result.worstFinalWealth);
fprintf('结果目录：%s\n', outputDir);
