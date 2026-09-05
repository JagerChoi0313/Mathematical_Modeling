clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));

addpath(fullfile(projectRoot, 'common'));
addpath(fullfile(projectRoot, 'case5'));
addpath(fullfile(projectRoot, 'case6'));

fprintf('开始求解第三问：第五关与第六关。\n\n');

fprintf('正在求解第五关（2名玩家、天气全部已知）...\n');
data5 = prepare_data_case5(projectRoot);
model5 = build_model_case5(data5);
solution5 = solve_model_case5(model5, data5);
result5 = process_results_case5(solution5, data5);
check_solution(result5, data5);
plot_results_case5(result5, data5, projectRoot);

fprintf('\n第五关完成。\n');
fprintf('两名玩家最终资金（含终点退回）：%.2f 元，%.2f 元\n', ...
    result5.summary.FinalWealth(1), result5.summary.FinalWealth(2));
fprintf('总最终资金：%.2f 元\n', sum(result5.summary.FinalWealth));

fprintf('\n正在求解第六关（3名玩家、只知当天天气）...\n');
data6 = prepare_data_case6(projectRoot);
value6 = build_single_player_value_case6(data6);
solution6 = solve_policy_case6(value6, data6);
result6 = process_results_case6(solution6, data6);
check_solution(result6, data6);
plot_results_case6(result6, data6, projectRoot);

fprintf('\n第六关完成。\n');
fprintf('初始购买（水/食物箱数）：\n');
disp(result6.summary(:, {'Player','InitialWater','InitialFood'}));
fprintf('代表性最不利情形总最终资金：%.2f 元\n', ...
    sum(result6.summary.FinalWealth));
fprintf('代表性最不利天气：%s\n', solution6.weatherText);

fprintf('\n所有结果已保存到：\n%s\n', fullfile(projectRoot, 'output'));
