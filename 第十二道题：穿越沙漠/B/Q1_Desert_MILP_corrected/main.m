clear;
clc;

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));

outputDir = fullfile(projectRoot, 'output');
figureDir = fullfile(projectRoot, 'figures');

if ~isfolder(outputDir)
    mkdir(outputDir);
end
if ~isfolder(figureDir)
    mkdir(figureDir);
end

templateFile = fullfile(projectRoot, 'data', 'Result.xlsx');
resultFile = fullfile(outputDir, 'Result_Q1.xlsx');

if ~isfile(templateFile)
    error('未找到 data/Result.xlsx，请把题目给出的 Result.xlsx 放入 data 文件夹。');
end

if isfile(resultFile)
    delete(resultFile);
end
copyfile(templateFile, resultFile);

runCases = [1, 2];

for caseID = runCases

    fprintf('\n正在求解第 %d 关...\n', caseID);

    data = prepare_data(caseID, projectRoot);
    [model, index] = build_model(data);
    solution = solve_model(model);
    result = process_results(solution, data, index);

    export_results(result, data, projectRoot, resultFile);
    plot_results(result, data, projectRoot);

    caseOutputDir = fullfile(outputDir, sprintf('case%d', caseID));
    if ~isfolder(caseOutputDir)
        mkdir(caseOutputDir);
    end

    save(fullfile(caseOutputDir, sprintf('case%d_result.mat', caseID)), ...
        'data', 'solution', 'result');

    fprintf('第 %d 关求解完成。\n', caseID);
    fprintf('到达终点日期：第 %d 天\n', result.arrivalDay);
    fprintf('初始购买：水 %d 箱，食物 %d 箱\n', ...
        result.initialWater, result.initialFood);
    fprintf('挖矿天数：%d 天\n', result.mineDays);
    fprintf('计入终点退回后的最终资金：%.2f 元\n', result.finalWealth);

    if result.checkPassed
        fprintf('逐日规则复核：通过\n');
    else
        fprintf('逐日规则复核：未通过\n');
        disp(result.checkMessages);
    end
end

fprintf('\n两关计算完成。\n');
fprintf('结果文件：%s\n', resultFile);
