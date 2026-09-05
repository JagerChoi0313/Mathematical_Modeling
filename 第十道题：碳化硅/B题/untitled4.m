%% problem2_thickness_inversion.m
% =========================================================================
% 问题2：碳化硅外延层厚度计算 —— 基于问题1模型的完整反演算法
% （本版本仅使用 MATLAB 基础函数，不依赖 Signal Processing / Statistics
%  等任何附加工具箱：平滑用 movmean 实现，极值检测为手写函数）
%
% 算法流程：
%   步骤1：读取附件1（10°）、附件2（15°）真实光谱数据
%   步骤2：滑动窗口扫描整个波数范围，在每个窗口内对光谱做平滑去噪，
%          提取"同类型"干涉极值（波峰、波谷分别处理），
%          对极值波数做线性回归，得到该窗口的平均条纹间距 dnu 及回归优度 R^2
%   步骤3：对每个窗口，尝试用双角度联立公式同时解出折射率 n 与厚度 d，
%          若解出 n^2<=1（无物理意义），标记为无效，如实记录
%   步骤4：改用碳化硅折射率的文献典型值，对每个窗口分别用附件1、附件2
%          独立反演厚度 d10、d15，计算二者相对偏差，作为交叉验证指标
%   步骤5：综合极值点数量、两角度厚度相对偏差，自动挑选"最可靠"的窗口，
%          给出最终推荐厚度结果
%   步骤6：可视化：全谱图（标出剩余射线带等不可用区域与最优窗口）、
%          最优窗口内的条纹提取效果图、各窗口厚度结果对比图
% =========================================================================

clear; clc; close all;

%% ===================== 步骤1：读取真实光谱数据 =====================

T1 = readtable('附件1.xlsx');   % 10° 入射角
T2 = readtable('附件2.xlsx');   % 15° 入射角

nu1 = T1{:,1};  R1 = T1{:,2};   % 波数 (cm^-1)，反射率 (%)
nu2 = T2{:,1};  R2 = T2{:,2};

theta1_deg = 10;                % 附件1对应入射角
theta2_deg = 15;                % 附件2对应入射角

n_lit = 2.55;                   % 碳化硅红外波段折射率文献典型值（用于交叉验证方案）

fprintf('数据读取完成：附件1 %d 个点，附件2 %d 个点\n', length(nu1), length(nu2));
fprintf('波数范围：%.1f ~ %.1f cm^-1\n\n', min(nu1), max(nu1));


%% ===================== 步骤2-4：滑动窗口扫描 =====================
% 说明：碳化硅在约 800~1000 cm^-1 附近存在"剩余射线带"（强吸收/近全反射区），
% 该区域不满足弱反射两光束干涉的简化假设，因此窗口起点从 1000 cm^-1 开始，
% 主动避开该区域，避免引入系统性错误。

width = 1000;    % 每个窗口的宽度 (cm^-1)
step  = 300;     % 窗口滑动步长 (cm^-1)
lo_list = 1000:step:(4000-width);

nWin = numel(lo_list);
results = struct('lo',{},'hi',{},'dnu10',{},'dnu15',{},'npk10',{},'npk15',{}, ...
                  'n_joint',{},'d_joint10',{},'d_joint15',{}, ...
                  'd_lit10',{},'d_lit15',{},'rel_dev',{});

fprintf('%-14s %8s %6s %8s %6s %10s %12s %12s %8s\n', ...
    '窗口(cm^-1)','dnu10','#pk10','dnu15','#pk15','n(联立)','d_lit10(um)','d_lit15(um)','偏差(%)');

for i = 1:nWin
    lo = lo_list(i); hi = lo + width;

    [dnu10, npk10] = extractExtremaSpacing(nu1, R1, lo, hi);
    [dnu15, npk15] = extractExtremaSpacing(nu2, R2, lo, hi);

    r = struct('lo',lo,'hi',hi,'dnu10',dnu10,'dnu15',dnu15,'npk10',npk10,'npk15',npk15, ...
               'n_joint',NaN,'d_joint10',NaN,'d_joint15',NaN, ...
               'd_lit10',NaN,'d_lit15',NaN,'rel_dev',NaN);

    if ~isnan(dnu10) && ~isnan(dnu15)
        % ---- 尝试双角度联立解 n, d（可能无物理解）----
        [n_j, d_j10, d_j15] = solveNandD(dnu10, dnu15, theta1_deg, theta2_deg);
        r.n_joint = n_j; r.d_joint10 = d_j10; r.d_joint15 = d_j15;

        % ---- 改用文献折射率分别反演厚度，作为主方案 ----
        d10 = computeThickness(dnu10, n_lit, theta1_deg);
        d15 = computeThickness(dnu15, n_lit, theta2_deg);
        r.d_lit10 = d10; r.d_lit15 = d15;
        r.rel_dev = abs(d10-d15) / mean([d10 d15]) * 100;   % 两角度相对偏差(%)

        fprintf('[%4d,%4d]  %8.2f %6d %8.2f %6d %10s %12.4f %12.4f %8.3f\n', ...
            lo, hi, dnu10, npk10, dnu15, npk15, ...
            fmtN(n_j), d10, d15, r.rel_dev);
    else
        fprintf('[%4d,%4d]  极值点不足，跳过该窗口\n', lo, hi);
    end

    results(i) = r;
end


%% ===================== 步骤5：自动筛选最优窗口 =====================
% 筛选准则：两角度厚度相对偏差最小，且极值点数量充足（>=3），
% 才具备统计意义，作为最终推荐结果

valid_idx = find(~isnan([results.rel_dev]) & [results.npk10] >= 3 & [results.npk15] >= 3);

if isempty(valid_idx)
    error('未找到满足条件的有效窗口，请调整窗口宽度或极值检测参数。');
end

[~, best_local] = min([results(valid_idx).rel_dev]);
best_idx = valid_idx(best_local);
best = results(best_idx);

d_final = mean([best.d_lit10, best.d_lit15]);

fprintf('\n========== 最终推荐结果 ==========\n');
fprintf('最优窗口：[%d, %d] cm^-1\n', best.lo, best.hi);
fprintf('附件1(10°) 反演厚度 = %.4f um\n', best.d_lit10);
fprintf('附件2(15°) 反演厚度 = %.4f um\n', best.d_lit15);
fprintf('两角度相对偏差       = %.3f %%\n', best.rel_dev);
fprintf('推荐外延层厚度  d  = %.4f um  (取两角度平均)\n', d_final);
fprintf('====================================\n');

if ~isnan(best.n_joint)
    fprintf('\n（补充说明）该窗口下双角度联立法解出 n = %.4f，可与文献值 %.2f 对比。\n', ...
        best.n_joint, n_lit);
else
    fprintf('\n（补充说明）该窗口下双角度联立法未能解出物理有效的 n（10°与15°角度差过小，\n');
    fprintf('导致该反演方程病态），故本算法改用文献折射率典型值完成主计算，\n');
    fprintf('并以两角度独立结果的交叉验证作为可靠性依据。\n');
end


%% ===================== 步骤6：可视化 =====================

% (a) 全谱图，标出剩余射线带与最优窗口
figure('Position',[100 100 950 400]);
plot(nu1, R1, 'b-', 'LineWidth', 0.8); hold on;
xline(800, 'k--'); xline(1000, 'k--');
text(870, max(R1)*0.9, '剩余射线带(不可用)', 'FontSize', 8);
patch([best.lo best.hi best.hi best.lo], ...
      [0 0 max(R1) max(R1)], 'g', 'FaceAlpha', 0.12, 'EdgeColor','none');
text(best.lo+20, max(R1)*0.75, '最优窗口', 'FontSize', 9, 'Color', [0 0.5 0]);
xlabel('波数 (cm^{-1})'); ylabel('反射率 (%)');
title('附件1全谱：剩余射线带与最优反演窗口标注');
grid on;

% (b) 最优窗口内的条纹提取效果（附件1、附件2）
figure('Position',[100 550 950 350]);
subplot(1,2,1);
plotExtremaWindow(nu1, R1, best.lo, best.hi, '附件1 (10°)');
subplot(1,2,2);
plotExtremaWindow(nu2, R2, best.lo, best.hi, '附件2 (15°)');

% (c) 各窗口厚度结果对比图，展示交叉验证的整体稳定性
figure('Position',[1080 100 700 400]);
lo_valid = [results(valid_idx).lo];
d10_valid = [results(valid_idx).d_lit10];
d15_valid = [results(valid_idx).d_lit15];
plot(lo_valid, d10_valid, 'bo-', 'LineWidth', 1.2); hold on;
plot(lo_valid, d15_valid, 'rs-', 'LineWidth', 1.2);
yline(d_final, 'k--', sprintf('推荐值 %.2f um', d_final));
xlabel('窗口起始波数 (cm^{-1})'); ylabel('反演厚度 (um)');
legend('附件1(10°)反演厚度','附件2(15°)反演厚度','Location','best');
title('各窗口厚度反演结果对比（交叉验证稳定性）');
grid on;


%% ===================== 局部函数定义 =====================

function [dnu, npk] = extractExtremaSpacing(nu, R, lo, hi)
% 在 [lo,hi] 波数窗口内，平滑后分别提取波峰、波谷，
% 各自做"波数-序号"线性回归得到间距，再取两者平均，提高稳健性
% 注：仅使用 MATLAB 基础函数（movmean + 手写极值检测），不依赖任何工具箱
    mask = nu >= lo & nu <= hi;
    x = nu(mask); y = R(mask);
    if numel(x) < 30
        dnu = NaN; npk = 0; return;
    end

    y_s = movmean(y, 15);                 % 滑动平均平滑去噪（窗口15点）
    y_range = max(y_s) - min(y_s);

    dx = mean(diff(x));                   % 数据点的平均波数间隔
    min_dist_samples = max(1, round(5/dx));   % 相邻极值最小间隔对应的样本数（约5 cm^-1）

    [pk_val_idx] = findLocalExtrema(y_s,  0.05*y_range, min_dist_samples);
    [tr_val_idx] = findLocalExtrema(-y_s, 0.05*y_range, min_dist_samples);

    locs_pk = x(pk_val_idx);
    locs_tr = x(tr_val_idx);

    slopes = [];
    npk = 0;
    if numel(locs_pk) >= 3
        p = polyfit((0:numel(locs_pk)-1)', locs_pk, 1);
        slopes(end+1) = p(1);
        npk = npk + numel(locs_pk);
    end
    if numel(locs_tr) >= 3
        p = polyfit((0:numel(locs_tr)-1)', locs_tr, 1);
        slopes(end+1) = p(1);
        npk = npk + numel(locs_tr);
    end

    if isempty(slopes)
        dnu = NaN; npk = 0;
    else
        dnu = mean(slopes);
    end
end


function idx_out = findLocalExtrema(y, prom_thresh, min_dist)
% 手写局部极大值检测函数（替代 findpeaks，不依赖 Signal Processing Toolbox）
% 步骤：1) 找严格局部极大值候选点
%       2) 计算每个候选点的"突出度"（简化版地形凸起度，思路与 findpeaks 的
%          Prominence 概念一致：向两侧搜索直到遇到更高的点，取两侧遇到的
%          最低谷值中较大的一个作为参照）
%       3) 按突出度阈值筛选，再按最小间隔做非极大值抑制（保留局部最高者）
    y = y(:);
    n = length(y);
    idx_out = [];
    if n < 3
        return;
    end

    % 1) 严格局部极大值候选
    cand = find(y(2:end-1) > y(1:end-2) & y(2:end-1) > y(3:end)) + 1;
    if isempty(cand)
        return;
    end

    % 2) 计算突出度
    proms = zeros(size(cand));
    for k = 1:numel(cand)
        idx = cand(k);
        leftMin = y(idx);
        i = idx - 1;
        while i >= 1 && y(i) < y(idx)
            if y(i) < leftMin, leftMin = y(i); end
            i = i - 1;
        end
        rightMin = y(idx);
        i = idx + 1;
        while i <= n && y(i) < y(idx)
            if y(i) < rightMin, rightMin = y(i); end
            i = i + 1;
        end
        proms(k) = y(idx) - max(leftMin, rightMin);
    end

    keep = proms >= prom_thresh;
    cand = cand(keep);
    if isempty(cand)
        return;
    end

    % 3) 按高度降序做非极大值抑制，保证相邻保留点间隔 >= min_dist
    [~, order] = sort(y(cand), 'descend');
    cand_sorted = cand(order);
    kept = [];
    for k = 1:numel(cand_sorted)
        c = cand_sorted(k);
        if isempty(kept) || all(abs(c - kept) >= min_dist)
            kept(end+1) = c; %#ok<AGROW>
        end
    end

    idx_out = sort(kept);
end


function [n, d1, d2] = solveNandD(dnu1, dnu2, theta1_deg, theta2_deg)
% 双角度联立求解折射率 n 与厚度 d
% 依据模型： 1/(2*dnu) = d*sqrt(n^2 - sin(theta)^2)
% 若解出 n^2 <= 1（无物理意义），返回 NaN，由主程序如实记录该情形
    s1 = sind(theta1_deg)^2;
    s2 = sind(theta2_deg)^2;
    a1 = 1/(2*dnu1);
    a2 = 1/(2*dnu2);
    r  = (a1/a2)^2;

    if abs(r-1) < 1e-8
        n = NaN; d1 = NaN; d2 = NaN; return;   % 分母接近零，退化情形
    end

    n2 = (r*s2 - s1) / (r-1);
    if n2 <= 1
        n = NaN; d1 = NaN; d2 = NaN;           % 无物理意义的解，如实标记
    else
        n = sqrt(n2);
        d1 = a1/sqrt(n2-s1) * 1e4;   % cm -> um
        d2 = a2/sqrt(n2-s2) * 1e4;
    end
end


function d = computeThickness(dnu, n, theta_deg)
% 已知折射率 n，由条纹间距 dnu 反算厚度（单位：um）
    s = sind(theta_deg)^2;
    d = 1/(2*dnu*sqrt(n^2 - s)) * 1e4;   % cm -> um
end


function s = fmtN(n)
% 格式化可能为 NaN 的 n 值，便于表格打印（NaN 表示该窗口联立法无物理解）
    if isnan(n)
        s = 'NaN';
    else
        s = sprintf('%.4f', n);
    end
end


function plotExtremaWindow(nu, R, lo, hi, label)
% 绘制指定窗口内平滑曲线及提取到的波峰、波谷，用于结果可视化核查
    mask = nu >= lo & nu <= hi;
    x = nu(mask); y = R(mask);
    y_s = movmean(y, 15);
    y_range = max(y_s) - min(y_s);
    dx = mean(diff(x));
    min_dist_samples = max(1, round(5/dx));

    pk_idx = findLocalExtrema(y_s,  0.05*y_range, min_dist_samples);
    tr_idx = findLocalExtrema(-y_s, 0.05*y_range, min_dist_samples);

    plot(x, y, 'Color', [0.7 0.7 0.7]); hold on;
    plot(x, y_s, 'b-', 'LineWidth', 1.2);
    plot(x(pk_idx), y_s(pk_idx), 'r^', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
    plot(x(tr_idx), y_s(tr_idx), 'gv', 'MarkerFaceColor', 'g', 'MarkerSize', 5);
    xlabel('波数 (cm^{-1})'); ylabel('反射率 (%)');
    title(label);
    legend('原始数据','平滑曲线','波峰','波谷', 'Location','best');
    grid on;
end