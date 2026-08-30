function export_results_case3(result, dpResult, data, projectRoot)
%EXPORT_RESULTS_CASE3 导出第三关表格和完整策略

outputDir = fullfile(projectRoot, 'output', 'case3');
if ~isfolder(outputDir)
    mkdir(outputDir);
end

writetable(result.summary, ...
    fullfile(outputDir, 'case3_summary.xlsx'));
writetable(result.policyTable, ...
    fullfile(outputDir, 'case3_policy_table.xlsx'));
writetable(result.scenarioTable, ...
    fullfile(outputDir, 'case3_scenario_summary.xlsx'));
writetable(result.worstDaily, ...
    fullfile(outputDir, 'case3_worst_case_daily.xlsx'));
writetable(result.bestDaily, ...
    fullfile(outputDir, 'case3_best_case_daily.xlsx'));

policyFile = fullfile(outputDir, 'case3_policy.mat');
save(policyFile, 'dpResult', 'data', '-v7.3');
end
