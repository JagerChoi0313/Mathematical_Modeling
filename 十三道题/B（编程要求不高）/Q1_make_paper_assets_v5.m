%% CUMCM 2021 B题 第一问：论文图片 + 表格 一键生成脚本
% 使用前请保证同一文件夹内有：
%   1) 附件1.xlsx
%   2) 附件2.xlsx
%   3) Q1_output_v3/temperature_regression_results_v3.xlsx
%   4) Q1_output_v3/stability_results_v3.xlsx
%   5) generate_paper_figures_v4.m
%   6) generate_paper_tables_v5.m
%
% 运行本文件后，会自动生成：
%   Q1_output_v3/figures_paper/
%   Q1_output_v3/tables_paper/

clear; clc; close all;

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

file1    = fullfile(baseDir, '附件1.xlsx');
file2    = fullfile(baseDir, '附件2.xlsx');
regFile  = fullfile(baseDir, 'Q1_output_v3', 'temperature_regression_results_v3.xlsx');
stabFile = fullfile(baseDir, 'Q1_output_v3', 'stability_results_v3.xlsx');
figDir   = fullfile(baseDir, 'Q1_output_v3', 'figures_paper');
tabDir   = fullfile(baseDir, 'Q1_output_v3', 'tables_paper');

assert(isfile(file1), '找不到附件1.xlsx。');
assert(isfile(file2), '找不到附件2.xlsx。');
assert(isfile(regFile), '找不到 temperature_regression_results_v3.xlsx，请先运行 Q1_main_v3.m。');
assert(isfile(stabFile), '找不到 stability_results_v3.xlsx，请先运行 Q1_main_v3.m。');

if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(tabDir, 'dir'), mkdir(tabDir); end

generate_paper_figures_v4(file1, file2, regFile, figDir);
generate_paper_tables_v5(regFile, stabFile, tabDir);

fprintf('\n==============================================\n');
fprintf('论文正文专用图片和表格已全部生成。\n');
fprintf('图片目录：%s\n', figDir);
fprintf('表格目录：%s\n', tabDir);
fprintf('==============================================\n');
