function export_results_case4(result, dpResult, data, projectRoot)
%EXPORT_RESULTS_CASE4 导出第四关汇总、情景、逐日结果与策略

outputDir = fullfile(projectRoot, 'output', 'case4');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

writetable(result.summary, ...
    fullfile(outputDir, 'case4_summary.xlsx'));

writetable(result.scenarioTable, ...
    fullfile(outputDir, 'case4_scenario_summary.xlsx'));

writetable(result.worstDaily, ...
    fullfile(outputDir, 'case4_worst_case_daily.xlsx'));

writetable(result.bestDaily, ...
    fullfile(outputDir, 'case4_best_case_daily.xlsx'));

save(fullfile(outputDir, 'case4_policy.mat'), ...
    'dpResult', 'data', '-v7.3');

end
