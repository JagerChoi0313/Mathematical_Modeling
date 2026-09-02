%% CUMCM 2021 B题 第一问：论文专用表格生成脚本
% 说明：
% 本脚本不改变 V3 的建模与模型筛选结果，只根据已经得到的结果文件
% 自动整理出适合论文正文或附录使用的表格。
%
% 使用前请保证同一文件夹内有：
%   1) Q1_output_v3/temperature_regression_results_v3.xlsx
%   2) Q1_output_v3/stability_results_v3.xlsx
%   3) generate_paper_tables_v5.m
%
% 运行后，表格输出到：
%   Q1_output_v3/tables_paper/

clear; clc;

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

regFile  = fullfile(baseDir, 'Q1_output_v3', 'temperature_regression_results_v3.xlsx');
stabFile = fullfile(baseDir, 'Q1_output_v3', 'stability_results_v3.xlsx');
outDir   = fullfile(baseDir, 'Q1_output_v3', 'tables_paper');

assert(isfile(regFile), ['找不到文件：', regFile, '。请先运行 Q1_main_v3.m。']);
assert(isfile(stabFile), ['找不到文件：', stabFile, '。请先运行 Q1_main_v3.m。']);

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

generate_paper_tables_v5(regFile, stabFile, outDir);

fprintf('\n==============================================\n');
fprintf('论文专用表格已生成。\n');
fprintf('输出目录：%s\n', outDir);
fprintf('==============================================\n');
