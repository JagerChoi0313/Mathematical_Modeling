%% CUMCM 2021 B题 第一问：论文专用图片生成脚本
% 说明：
% 本脚本不改变 V3 的建模与模型筛选结果，只负责根据已经得到的最终模型
% 重新绘制适合放入论文正文的简洁图像。
%
% 使用前请保证同一文件夹内有：
%   1) 附件1.xlsx
%   2) 附件2.xlsx
%   3) Q1_output_v3/temperature_regression_results_v3.xlsx
%   4) generate_paper_figures_v4.m
%
% 运行本文件后，图片输出到：
%   Q1_output_v3/figures_paper/
%
% 每张图同时保存 PNG（300 dpi）和 PDF（矢量）两个版本。

clear; clc; close all;

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end

file1 = fullfile(baseDir, '附件1.xlsx');
file2 = fullfile(baseDir, '附件2.xlsx');
regFile = fullfile(baseDir, 'Q1_output_v3', 'temperature_regression_results_v3.xlsx');
paperFigDir = fullfile(baseDir, 'Q1_output_v3', 'figures_paper');

assert(isfile(file1), '找不到附件1.xlsx。');
assert(isfile(file2), '找不到附件2.xlsx。');
assert(isfile(regFile), ...
    ['找不到 V3 温度回归结果文件：\n', regFile, '\n', ...
     '请先运行 Q1_main_v3.m。']);

if ~exist(paperFigDir, 'dir')
    mkdir(paperFigDir);
end

generate_paper_figures_v4(file1, file2, regFile, paperFigDir);

fprintf('\n==============================================\n');
fprintf('论文专用图片已生成。\n');
fprintf('输出目录：%s\n', paperFigDir);
fprintf('==============================================\n');
