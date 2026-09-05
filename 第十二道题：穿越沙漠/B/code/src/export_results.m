function export_results(result, data, projectRoot, resultFile)
%EXPORT_RESULTS 导出详细结果并填写题目 Result.xlsx

caseOutputDir = fullfile(projectRoot, 'output', ...
    sprintf('case%d', data.caseID));

if ~isfolder(caseOutputDir)
    mkdir(caseOutputDir);
end

dailyFile = fullfile(caseOutputDir, ...
    sprintf('case%d_daily_result.xlsx', data.caseID));

summaryFile = fullfile(caseOutputDir, ...
    sprintf('case%d_summary.xlsx', data.caseID));

writetable(result.dailyTable, dailyFile);
writetable(result.summaryTable, summaryFile);

n = result.arrivalDay + 1;

resultMatrix = [
    result.position(1:n), ...
    round(result.cash(1:n),2), ...
    result.water(1:n), ...
    result.food(1:n)
    ];

if data.caseID == 1
    startCell = 'B4';
else
    startCell = 'H4';
end

writematrix(resultMatrix, ...
    resultFile, ...
    'Sheet','Sheet1', ...
    'Range',startCell);

end
