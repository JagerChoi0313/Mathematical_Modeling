clear;
clc;
close all;

%% =========================================================
% 第二问：完整图表生成程序
%
% 模型依据：
%
% 问题一厚度公式
%
%       N
% d = -----------------------------------------
%     2*sqrt(n^2-sin^2(alpha))*(sigma_(m+N)-sigma_m)
%
% 双角度反演等效折射率
%
%             Delta10^2*sin^2(10°)-Delta15^2*sin^2(15°)
% n = sqrt( ------------------------------------------------ )
%                     Delta10^2-Delta15^2
%
%
% 本程序功能：
% 1. 读取附件1、附件2
% 2. 数据清洗
% 3. 截取 1500~4000 cm^-1 分析波段
% 4. 自定义 Savitzky-Golay 平滑
% 5. 自动识别干涉峰、干涉谷
% 6. 峰/谷单独周期拟合
% 7. 峰谷共同周期拟合
% 8. 双角度反演 n
% 9. 计算最终厚度 d
% 10. 峰谷独立反演
% 11. 跨 N 周期厚度计算
% 12. 逐周期稳定性分析
% 13. 自动生成论文所需全部主要图片
% 14. 自动生成 Excel 汇总表
%
% 不需要 Signal Processing Toolbox
%
% 请将本程序和：
%   附件1.xlsx
%   附件2.xlsx
% 放在同一文件夹中运行。
%% =========================================================


%% 1. 参数设置

sigma_min = 1500;
sigma_max = 4000;

smooth_window = 61;
sgolay_order  = 3;

min_peak_distance   = 180;   % cm^-1
min_peak_prominence = 0.25;  % %

% 输出文件夹
output_dir = '第二问_图表结果';

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

excel_file = fullfile(output_dir,'第二问_图表数据汇总.xlsx');

% 若之前已经存在汇总文件，则删除，避免旧内容残留
if exist(excel_file,'file')
    delete(excel_file);
end


%% =========================================================
% 2. 读取数据
%% =========================================================

data1 = readmatrix('附件1.xlsx');
data2 = readmatrix('附件2.xlsx');

sigma1 = data1(:,1);
R1     = data1(:,2);

sigma2 = data2(:,1);
R2     = data2(:,2);


%% =========================================================
% 3. 数据清洗
%% =========================================================

valid1 = isfinite(sigma1) & isfinite(R1);
sigma1 = sigma1(valid1);
R1     = R1(valid1);

valid2 = isfinite(sigma2) & isfinite(R2);
sigma2 = sigma2(valid2);
R2     = R2(valid2);

% 删除最前面的孤立零反射率边界点
if ~isempty(R1) && R1(1) == 0
    sigma1(1) = [];
    R1(1) = [];
end

if ~isempty(R2) && R2(1) == 0
    sigma2(1) = [];
    R2(1) = [];
end

% 按波数升序排序
[sigma1,idx1] = sort(sigma1);
R1 = R1(idx1);

[sigma2,idx2] = sort(sigma2);
R2 = R2(idx2);


%% =========================================================
% 4. 截取分析波段
%% =========================================================

band1 = sigma1 >= sigma_min & sigma1 <= sigma_max;
band2 = sigma2 >= sigma_min & sigma2 <= sigma_max;

sigma_band1 = sigma1(band1);
R_band1     = R1(band1);

sigma_band2 = sigma2(band2);
R_band2     = R2(band2);


%% =========================================================
% 5. SG 平滑
%% =========================================================

R_smooth1 = my_sgolay(...
    R_band1,...
    smooth_window,...
    sgolay_order);

R_smooth2 = my_sgolay(...
    R_band2,...
    smooth_window,...
    sgolay_order);


%% =========================================================
% 6. 自动检测峰谷
%% =========================================================

% ---------- 附件1 ----------
[peak_R1,peak_sigma1] = my_findpeaks(...
    sigma_band1,...
    R_smooth1,...
    min_peak_distance,...
    min_peak_prominence);

[neg_trough_R1,trough_sigma1] = my_findpeaks(...
    sigma_band1,...
    -R_smooth1,...
    min_peak_distance,...
    min_peak_prominence);

trough_R1 = -neg_trough_R1;


% ---------- 附件2 ----------
[peak_R2,peak_sigma2] = my_findpeaks(...
    sigma_band2,...
    R_smooth2,...
    min_peak_distance,...
    min_peak_prominence);

[neg_trough_R2,trough_sigma2] = my_findpeaks(...
    sigma_band2,...
    -R_smooth2,...
    min_peak_distance,...
    min_peak_prominence);

trough_R2 = -neg_trough_R2;


%% =========================================================
% 7. 峰、谷单独周期拟合
%% =========================================================

[Delta_peak_10,R2_peak_10,fit_peak_10] = ...
    period_fit(peak_sigma1);

[Delta_trough_10,R2_trough_10,fit_trough_10] = ...
    period_fit(trough_sigma1);

[Delta_peak_15,R2_peak_15,fit_peak_15] = ...
    period_fit(peak_sigma2);

[Delta_trough_15,R2_trough_15,fit_trough_15] = ...
    period_fit(trough_sigma2);


%% =========================================================
% 8. 峰谷共同周期拟合
%% =========================================================

[Delta_10,R2_joint_10,bp10,bv10] = ...
    common_period_fit(...
    peak_sigma1,trough_sigma1);

[Delta_15,R2_joint_15,bp15,bv15] = ...
    common_period_fit(...
    peak_sigma2,trough_sigma2);


%% =========================================================
% 9. 双角度反演等效折射率
%% =========================================================

[n_eff,ratio_n,den_n] = ...
    inverse_n_from_two_angles(...
    Delta_10,Delta_15);


%% =========================================================
% 10. 代回问题一公式计算厚度
%% =========================================================

d10_um = thickness_from_period(...
    Delta_10,n_eff,10);

d15_um = thickness_from_period(...
    Delta_15,n_eff,15);

d_final_um = (d10_um+d15_um)/2;


%% =========================================================
% 11. 峰、谷独立反演
%% =========================================================

[n_peak,~,~] = inverse_n_from_two_angles(...
    Delta_peak_10,...
    Delta_peak_15);

d_peak_10 = thickness_from_period(...
    Delta_peak_10,...
    n_peak,...
    10);

d_peak_15 = thickness_from_period(...
    Delta_peak_15,...
    n_peak,...
    15);


[n_trough,~,~] = inverse_n_from_two_angles(...
    Delta_trough_10,...
    Delta_trough_15);

d_trough_10 = thickness_from_period(...
    Delta_trough_10,...
    n_trough,...
    10);

d_trough_15 = thickness_from_period(...
    Delta_trough_15,...
    n_trough,...
    15);


%% =========================================================
% 12. 按问题一跨 N 周期公式计算厚度
%% =========================================================

N_peak_10   = length(peak_sigma1)-1;
N_trough_10 = length(trough_sigma1)-1;

N_peak_15   = length(peak_sigma2)-1;
N_trough_15 = length(trough_sigma2)-1;

dN_peak_10 = thickness_from_N(...
    N_peak_10,...
    peak_sigma1(1),...
    peak_sigma1(end),...
    n_eff,...
    10);

dN_trough_10 = thickness_from_N(...
    N_trough_10,...
    trough_sigma1(1),...
    trough_sigma1(end),...
    n_eff,...
    10);

dN_peak_15 = thickness_from_N(...
    N_peak_15,...
    peak_sigma2(1),...
    peak_sigma2(end),...
    n_eff,...
    15);

dN_trough_15 = thickness_from_N(...
    N_trough_15,...
    trough_sigma2(1),...
    trough_sigma2(end),...
    n_eff,...
    15);


%% =========================================================
% 13. 逐周期厚度稳定性
%% =========================================================

delta_peak_10   = diff(peak_sigma1);
delta_trough_10 = diff(trough_sigma1);

delta_peak_15   = diff(peak_sigma2);
delta_trough_15 = diff(trough_sigma2);

d_each_peak_10 = thickness_from_period(...
    delta_peak_10,...
    n_eff,...
    10);

d_each_trough_10 = thickness_from_period(...
    delta_trough_10,...
    n_eff,...
    10);

d_each_peak_15 = thickness_from_period(...
    delta_peak_15,...
    n_eff,...
    15);

d_each_trough_15 = thickness_from_period(...
    delta_trough_15,...
    n_eff,...
    15);

all_d = [
    d_each_peak_10(:)
    d_each_trough_10(:)
    d_each_peak_15(:)
    d_each_trough_15(:)
    ];


%% =========================================================
% 14. 统计量
%% =========================================================

mean_peak_10 = mean(d_each_peak_10);
std_peak_10  = std(d_each_peak_10);
cv_peak_10   = std_peak_10/mean_peak_10*100;

mean_trough_10 = mean(d_each_trough_10);
std_trough_10  = std(d_each_trough_10);
cv_trough_10   = std_trough_10/mean_trough_10*100;

mean_peak_15 = mean(d_each_peak_15);
std_peak_15  = std(d_each_peak_15);
cv_peak_15   = std_peak_15/mean_peak_15*100;

mean_trough_15 = mean(d_each_trough_15);
std_trough_15  = std(d_each_trough_15);
cv_trough_15   = std_trough_15/mean_trough_15*100;

mean_all = mean(all_d);
std_all  = std(all_d);
cv_all   = std_all/mean_all*100;


%% =========================================================
% 15. 图1：原始光谱对比
%% =========================================================

figure('Position',[150 80 1100 620]);

plot(sigma1,R1,'LineWidth',1.0);
hold on;

plot(sigma2,R2,'LineWidth',1.0);

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('不同入射角下碳化硅晶圆片红外反射光谱对比',...
    'FontSize',13);

legend(...
    '附件1：10°',...
    '附件2：15°',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;

print(gcf,...
    fullfile(output_dir,'图1_原始反射光谱对比'),...
    '-dpng','-r300');

hold off;


%% =========================================================
% 16. 图2：附件1峰谷识别
%% =========================================================

figure('Position',[150 80 1100 620]);

plot(sigma_band1,R_band1,...
    'LineWidth',0.8);

hold on;

plot(sigma_band1,R_smooth1,...
    'LineWidth',1.5);

scatter(peak_sigma1,peak_R1,...
    55,'o','filled');

scatter(trough_sigma1,trough_R1,...
    55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件1：10°入射角干涉峰谷识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    '平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;

print(gcf,...
    fullfile(output_dir,'图2_附件1_10度峰谷识别'),...
    '-dpng','-r300');

hold off;


%% =========================================================
% 17. 图3：附件2峰谷识别
%% =========================================================

figure('Position',[150 80 1100 620]);

plot(sigma_band2,R_band2,...
    'LineWidth',0.8);

hold on;

plot(sigma_band2,R_smooth2,...
    'LineWidth',1.5);

scatter(peak_sigma2,peak_R2,...
    55,'o','filled');

scatter(trough_sigma2,trough_R2,...
    55,'v','filled');

xlabel('波数 \sigma / cm^{-1}','FontSize',12);
ylabel('反射率 R / %','FontSize',12);

title('附件2：15°入射角干涉峰谷识别',...
    'FontSize',13);

legend(...
    '原始光谱',...
    '平滑光谱',...
    '干涉峰',...
    '干涉谷',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);
xlim([sigma_min sigma_max]);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;

print(gcf,...
    fullfile(output_dir,'图3_附件2_15度峰谷识别'),...
    '-dpng','-r300');

hold off;


%% =========================================================
% 18. 图4：10°峰谷共同周期拟合
%% =========================================================

plot_common_period_figure(...
    peak_sigma1,...
    trough_sigma1,...
    Delta_10,...
    bp10,...
    bv10,...
    '附件1：10°峰谷共同周期拟合',...
    fullfile(output_dir,'图4_附件1_10度共同周期拟合'));


%% =========================================================
% 19. 图5：15°峰谷共同周期拟合
%% =========================================================

plot_common_period_figure(...
    peak_sigma2,...
    trough_sigma2,...
    Delta_15,...
    bp15,...
    bv15,...
    '附件2：15°峰谷共同周期拟合',...
    fullfile(output_dir,'图5_附件2_15度共同周期拟合'));


%% =========================================================
% 20. 图6：逐周期厚度结果
%% =========================================================

figure('Position',[150 80 1100 620]);

hold on;

x1 = 1:length(d_each_peak_10);

x2 = max(x1)+2 + ...
    (1:length(d_each_trough_10));

x3 = max(x2)+2 + ...
    (1:length(d_each_peak_15));

x4 = max(x3)+2 + ...
    (1:length(d_each_trough_15));

scatter(x1,d_each_peak_10,50,'o','filled');
scatter(x2,d_each_trough_10,50,'s','filled');
scatter(x3,d_each_peak_15,50,'^','filled');
scatter(x4,d_each_trough_15,50,'v','filled');

plot([min(x1) max(x4)],...
    [d_final_um d_final_um],...
    '--','LineWidth',1.5);

xlabel('逐周期计算序号','FontSize',12);
ylabel('外延层厚度 d / \mum','FontSize',12);

title('不同峰谷序列逐周期厚度计算结果',...
    'FontSize',13);

legend(...
    '10°峰',...
    '10°谷',...
    '15°峰',...
    '15°谷',...
    '共同周期中心结果',...
    'Location','best');

grid on;
box on;
set(gca,'FontSize',11);

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;

print(gcf,...
    fullfile(output_dir,'图6_逐周期厚度稳定性'),...
    '-dpng','-r300');

hold off;


%% =========================================================
% 21. 图7：不同方法厚度结果对比
%% =========================================================

method_d = [
    d_final_um
    d_peak_10
    d_trough_10
    dN_peak_10
    dN_trough_10
    dN_peak_15
    dN_trough_15
    mean_all
    ];

figure('Position',[150 80 1100 620]);

bar(method_d);

ylabel('外延层厚度 d / \mum','FontSize',12);

title('不同计算方法得到的外延层厚度对比',...
    'FontSize',13);

set(gca,...
    'XTick',1:8,...
    'XTickLabel',{...
    '共同周期',...
    '仅峰反演',...
    '仅谷反演',...
    '10°峰跨N',...
    '10°谷跨N',...
    '15°峰跨N',...
    '15°谷跨N',...
    '逐周期平均'},...
    'XTickLabelRotation',25,...
    'FontSize',10);

grid on;
box on;

try
    ax = gca;
    tb = axtoolbar(ax);
    tb.Visible = 'off';
catch
end

drawnow;

print(gcf,...
    fullfile(output_dir,'图7_不同方法厚度结果对比'),...
    '-dpng','-r300');


%% =========================================================
% 22. 表1：峰谷识别数量统计
%% =========================================================

table1 = {
    '数据附件','入射角_deg','峰数','谷数';
    '附件1',10,length(peak_sigma1),length(trough_sigma1);
    '附件2',15,length(peak_sigma2),length(trough_sigma2)
    };

writecell(table1,...
    excel_file,...
    'Sheet','表1_峰谷数量统计');


%% =========================================================
% 23. 表2：完整峰谷位置
%% =========================================================

% 附件1峰
cell_peak1 = cell(length(peak_sigma1)+1,3);

cell_peak1(1,:) = {...
    '序号',...
    '峰值波数_cm^-1',...
    '反射率_percent'};

for i = 1:length(peak_sigma1)

    cell_peak1{i+1,1} = i;
    cell_peak1{i+1,2} = peak_sigma1(i);
    cell_peak1{i+1,3} = peak_R1(i);

end

writecell(cell_peak1,...
    excel_file,...
    'Sheet','附件1_峰值');


% 附件1谷
cell_trough1 = cell(length(trough_sigma1)+1,3);

cell_trough1(1,:) = {...
    '序号',...
    '谷值波数_cm^-1',...
    '反射率_percent'};

for i = 1:length(trough_sigma1)

    cell_trough1{i+1,1} = i;
    cell_trough1{i+1,2} = trough_sigma1(i);
    cell_trough1{i+1,3} = trough_R1(i);

end

writecell(cell_trough1,...
    excel_file,...
    'Sheet','附件1_谷值');


% 附件2峰
cell_peak2 = cell(length(peak_sigma2)+1,3);

cell_peak2(1,:) = {...
    '序号',...
    '峰值波数_cm^-1',...
    '反射率_percent'};

for i = 1:length(peak_sigma2)

    cell_peak2{i+1,1} = i;
    cell_peak2{i+1,2} = peak_sigma2(i);
    cell_peak2{i+1,3} = peak_R2(i);

end

writecell(cell_peak2,...
    excel_file,...
    'Sheet','附件2_峰值');


% 附件2谷
cell_trough2 = cell(length(trough_sigma2)+1,3);

cell_trough2(1,:) = {...
    '序号',...
    '谷值波数_cm^-1',...
    '反射率_percent'};

for i = 1:length(trough_sigma2)

    cell_trough2{i+1,1} = i;
    cell_trough2{i+1,2} = trough_sigma2(i);
    cell_trough2{i+1,3} = trough_R2(i);

end

writecell(cell_trough2,...
    excel_file,...
    'Sheet','附件2_谷值');


%% =========================================================
% 24. 表3：条纹周期拟合结果
%% =========================================================

table_period = {
    '数据',...
    '峰值周期_cm^-1',...
    '峰值_R2',...
    '谷值周期_cm^-1',...
    '谷值_R2',...
    '峰谷共同周期_cm^-1',...
    '共同拟合_R2';

    '附件1_10度',...
    Delta_peak_10,...
    R2_peak_10,...
    Delta_trough_10,...
    R2_trough_10,...
    Delta_10,...
    R2_joint_10;

    '附件2_15度',...
    Delta_peak_15,...
    R2_peak_15,...
    Delta_trough_15,...
    R2_trough_15,...
    Delta_15,...
    R2_joint_15
    };

writecell(table_period,...
    excel_file,...
    'Sheet','表2_条纹周期拟合');


%% =========================================================
% 25. 表4：双角度反演结果
%% =========================================================

table_inversion = {
    '参数','数值';
    'Delta_sigma_10_cm^-1',Delta_10;
    'Delta_sigma_15_cm^-1',Delta_15;
    '等效折射率_n',n_eff;
    'd_10_um',d10_um;
    'd_15_um',d15_um;
    '最终厚度_d_um',d_final_um;
    '折射率公式分母',den_n;
    '根号内比值',ratio_n
    };

writecell(table_inversion,...
    excel_file,...
    'Sheet','表3_双角度反演');


%% =========================================================
% 26. 表5：峰谷独立反演
%% =========================================================

table_independent = {
    '方法','等效折射率_n','10度厚度_um','15度厚度_um';
    '仅使用峰值周期',n_peak,d_peak_10,d_peak_15;
    '仅使用谷值周期',n_trough,d_trough_10,d_trough_15
    };

writecell(table_independent,...
    excel_file,...
    'Sheet','表4_峰谷独立反演');


%% =========================================================
% 27. 表6：跨 N 周期厚度
%% =========================================================

table_N = {
    '数据序列','N','起始波数_cm^-1','终止波数_cm^-1','厚度_um';

    '10度峰',...
    N_peak_10,...
    peak_sigma1(1),...
    peak_sigma1(end),...
    dN_peak_10;

    '10度谷',...
    N_trough_10,...
    trough_sigma1(1),...
    trough_sigma1(end),...
    dN_trough_10;

    '15度峰',...
    N_peak_15,...
    peak_sigma2(1),...
    peak_sigma2(end),...
    dN_peak_15;

    '15度谷',...
    N_trough_15,...
    trough_sigma2(1),...
    trough_sigma2(end),...
    dN_trough_15
    };

writecell(table_N,...
    excel_file,...
    'Sheet','表5_跨N周期厚度');


%% =========================================================
% 28. 表7：逐周期稳定性统计
%% =========================================================

table_stability = {
    '数据序列','平均厚度_um','标准差_um','CV_percent';

    '10度峰周期',...
    mean_peak_10,...
    std_peak_10,...
    cv_peak_10;

    '10度谷周期',...
    mean_trough_10,...
    std_trough_10,...
    cv_trough_10;

    '15度峰周期',...
    mean_peak_15,...
    std_peak_15,...
    cv_peak_15;

    '15度谷周期',...
    mean_trough_15,...
    std_trough_15,...
    cv_trough_15;

    '全部逐周期结果',...
    mean_all,...
    std_all,...
    cv_all
    };

writecell(table_stability,...
    excel_file,...
    'Sheet','表6_逐周期稳定性');


%% =========================================================
% 29. 表8：逐周期详细结果
%% =========================================================

write_cycle_detail(...
    excel_file,...
    '逐周期_10度峰',...
    delta_peak_10,...
    d_each_peak_10);

write_cycle_detail(...
    excel_file,...
    '逐周期_10度谷',...
    delta_trough_10,...
    d_each_trough_10);

write_cycle_detail(...
    excel_file,...
    '逐周期_15度峰',...
    delta_peak_15,...
    d_each_peak_15);

write_cycle_detail(...
    excel_file,...
    '逐周期_15度谷',...
    delta_trough_15,...
    d_each_trough_15);


%% =========================================================
% 30. 命令窗口结果输出
%% =========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('              第二问完整图表生成完成\n');
fprintf('============================================================\n');

fprintf('\n峰谷数量：\n');
fprintf('附件1：峰 %d 个，谷 %d 个\n',...
    length(peak_sigma1),...
    length(trough_sigma1));

fprintf('附件2：峰 %d 个，谷 %d 个\n',...
    length(peak_sigma2),...
    length(trough_sigma2));


fprintf('\n条纹周期：\n');

fprintf('10°峰值周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_peak_10,R2_peak_10);

fprintf('10°谷值周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_trough_10,R2_trough_10);

fprintf('10°共同周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_10,R2_joint_10);

fprintf('15°峰值周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_peak_15,R2_peak_15);

fprintf('15°谷值周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_trough_15,R2_trough_15);

fprintf('15°共同周期   = %.10f cm^-1, R^2 = %.10f\n',...
    Delta_15,R2_joint_15);


fprintf('\n双角度反演：\n');
fprintf('等效折射率 n  = %.10f\n',n_eff);
fprintf('d10            = %.10f um\n',d10_um);
fprintf('d15            = %.10f um\n',d15_um);
fprintf('最终厚度 d     = %.10f um\n',d_final_um);


fprintf('\n峰谷独立反演：\n');
fprintf('仅峰：n = %.10f, d = %.10f um\n',...
    n_peak,d_peak_10);

fprintf('仅谷：n = %.10f, d = %.10f um\n',...
    n_trough,d_trough_10);


fprintf('\n跨 N 周期厚度：\n');
fprintf('10°峰 = %.10f um\n',dN_peak_10);
fprintf('10°谷 = %.10f um\n',dN_trough_10);
fprintf('15°峰 = %.10f um\n',dN_peak_15);
fprintf('15°谷 = %.10f um\n',dN_trough_15);


fprintf('\n逐周期稳定性：\n');
fprintf('10°峰：mean=%.10f, std=%.10f, CV=%.6f %%\n',...
    mean_peak_10,std_peak_10,cv_peak_10);

fprintf('10°谷：mean=%.10f, std=%.10f, CV=%.6f %%\n',...
    mean_trough_10,std_trough_10,cv_trough_10);

fprintf('15°峰：mean=%.10f, std=%.10f, CV=%.6f %%\n',...
    mean_peak_15,std_peak_15,cv_peak_15);

fprintf('15°谷：mean=%.10f, std=%.10f, CV=%.6f %%\n',...
    mean_trough_15,std_trough_15,cv_trough_15);

fprintf('全部： mean=%.10f, std=%.10f, CV=%.6f %%\n',...
    mean_all,std_all,cv_all);


fprintf('\n输出文件夹：%s\n',output_dir);
fprintf('Excel汇总文件：%s\n',excel_file);

fprintf('============================================================\n');


%% 31. 数值敏感性警告

relative_den = abs(den_n) / ...
    ((Delta_10^2+Delta_15^2)/2);

if relative_den < 0.02

    warning(['10°与15°共同周期较接近，',...
        '折射率反演公式的分母较小。',...
        '因此 n 对峰谷位置及周期误差较敏感。']);

end


%% =========================================================
%                    以下为自定义函数
%% =========================================================


%% 函数1：双角度反演 n

function [n,ratio,den] = ...
    inverse_n_from_two_angles(Delta10,Delta15)

    s10 = sind(10);
    s15 = sind(15);

    numerator = ...
        Delta10^2*s10^2 ...
        - Delta15^2*s15^2;

    den = ...
        Delta10^2 ...
        - Delta15^2;

    if abs(den) < 1e-12
        error('双角度折射率公式分母接近0，无法稳定反演。');
    end

    ratio = numerator/den;

    if ratio <= 0
        error('反演得到 n^2<=0，请检查周期数据。');
    end

    n = sqrt(ratio);

end


%% 函数2：利用平均周期求厚度

function d_um = ...
    thickness_from_period(Delta_sigma,n,alpha_deg)

    value = ...
        n^2-sind(alpha_deg)^2;

    if value <= 0
        error('n^2-sin^2(alpha)<=0。');
    end

    d_cm = ...
        1 ./ ...
        (2*sqrt(value).*Delta_sigma);

    d_um = d_cm*1e4;

end


%% 函数3：问题一跨 N 周期公式

function d_um = thickness_from_N(...
    N,...
    sigma_m,...
    sigma_mN,...
    n,...
    alpha_deg)

    delta_sigma = ...
        sigma_mN-sigma_m;

    if N <= 0 || delta_sigma <= 0
        error('跨 N 周期参数不合法。');
    end

    value = ...
        n^2-sind(alpha_deg)^2;

    d_cm = ...
        N / ...
        (2*sqrt(value)*delta_sigma);

    d_um = d_cm*1e4;

end


%% 函数4：单一峰/谷序列线性拟合

function [Delta,R2,sigma_fit] = ...
    period_fit(sigma_extrema)

    sigma_extrema = sigma_extrema(:);

    k = ...
        (0:length(sigma_extrema)-1)';

    p = ...
        polyfit(k,sigma_extrema,1);

    Delta = p(1);

    sigma_fit = ...
        polyval(p,k);

    SSE = ...
        sum(...
        (sigma_extrema-sigma_fit).^2);

    SST = ...
        sum(...
        (sigma_extrema-mean(sigma_extrema)).^2);

    R2 = ...
        1-SSE/SST;

end


%% 函数5：峰谷共同周期拟合

function [Delta,R2,bp,bv] = ...
    common_period_fit(...
    peak_sigma,...
    trough_sigma)

    peak_sigma   = peak_sigma(:);
    trough_sigma = trough_sigma(:);

    kp = ...
        (0:length(peak_sigma)-1)';

    kv = ...
        (0:length(trough_sigma)-1)';

    A_peak = [
        kp,...
        ones(length(kp),1),...
        zeros(length(kp),1)
        ];

    A_trough = [
        kv,...
        zeros(length(kv),1),...
        ones(length(kv),1)
        ];

    A = [
        A_peak
        A_trough
        ];

    y = [
        peak_sigma
        trough_sigma
        ];

    beta = ...
        A\y;

    Delta = beta(1);
    bp = beta(2);
    bv = beta(3);

    y_fit = ...
        A*beta;

    SSE = ...
        sum((y-y_fit).^2);

    SST = ...
        sum((y-mean(y)).^2);

    R2 = ...
        1-SSE/SST;

end


%% 函数6：自定义 SG 平滑

function y_smooth = ...
    my_sgolay(y,window,order)

    y = y(:);

    if mod(window,2) == 0
        error('SG平滑窗口必须为奇数。');
    end

    if order >= window
        error('多项式阶数必须小于窗口长度。');
    end

    half_window = ...
        (window-1)/2;

    x = ...
        (-half_window:half_window)';

    A = ...
        zeros(window,order+1);

    for k = 0:order

        A(:,k+1) = ...
            x.^k;

    end

    G = ...
        (A'*A)\A';

    h = ...
        G(1,:);

    y_left = ...
        flipud(...
        y(2:half_window+1));

    y_right = ...
        flipud(...
        y(end-half_window:end-1));

    y_extend = [
        y_left
        y
        y_right
        ];

    y_smooth = ...
        conv(...
        y_extend,...
        h,...
        'valid');

end


%% 函数7：自定义峰值检测

function [peak_y,peak_x] = ...
    my_findpeaks(...
    x,...
    y,...
    min_distance,...
    min_prominence)

    x = x(:);
    y = y(:);

    candidate = ...
        find(...
        y(2:end-1)>y(1:end-2) ...
        & y(2:end-1)>=y(3:end)) ...
        +1;

    if isempty(candidate)

        peak_y = [];
        peak_x = [];
        return;

    end

    dx = ...
        median(diff(x));

    window_points = ...
        round(min_distance/dx);

    window_points = ...
        max(window_points,1);

    prominence = ...
        zeros(size(candidate));

    for i = 1:length(candidate)

        idx = ...
            candidate(i);

        left = ...
            max(1,...
            idx-window_points);

        right = ...
            min(length(y),...
            idx+window_points);

        left_min = ...
            min(y(left:idx));

        right_min = ...
            min(y(idx:right));

        baseline = ...
            max(...
            left_min,...
            right_min);

        prominence(i) = ...
            y(idx)-baseline;

    end

    valid = ...
        prominence>=min_prominence;

    candidate = ...
        candidate(valid);

    prominence = ...
        prominence(valid);

    if isempty(candidate)

        peak_y = [];
        peak_x = [];
        return;

    end

    [~,order] = ...
        sort(x(candidate));

    candidate = ...
        candidate(order);

    prominence = ...
        prominence(order);

    selected = ...
        candidate(1);

    selected_prominence = ...
        prominence(1);

    for i = 2:length(candidate)

        current = ...
            candidate(i);

        if x(current)-x(selected(end)) ...
                >= min_distance

            selected(end+1,1) = ...
                current;

            selected_prominence(end+1,1) = ...
                prominence(i);

        else

            if prominence(i) ...
                    > selected_prominence(end)

                selected(end) = ...
                    current;

                selected_prominence(end) = ...
                    prominence(i);

            end

        end

    end

    peak_x = ...
        x(selected);

    peak_y = ...
        y(selected);

end


%% 函数8：共同周期拟合图

function plot_common_period_figure(...
    peak_sigma,...
    trough_sigma,...
    Delta,...
    bp,...
    bv,...
    title_text,...
    file_path)

    peak_sigma = peak_sigma(:);
    trough_sigma = trough_sigma(:);

    kp = ...
        (0:length(peak_sigma)-1)';

    kv = ...
        (0:length(trough_sigma)-1)';

    fit_peak = ...
        Delta*kp+bp;

    fit_trough = ...
        Delta*kv+bv;

    figure('Position',[150 80 1000 620]);

    scatter(...
        kp,...
        peak_sigma,...
        55,...
        'o',...
        'filled');

    hold on;

    plot(...
        kp,...
        fit_peak,...
        'LineWidth',1.6);

    scatter(...
        kv,...
        trough_sigma,...
        55,...
        'v',...
        'filled');

    plot(...
        kv,...
        fit_trough,...
        'LineWidth',1.6);

    xlabel(...
        '同类型干涉极值相对级次',...
        'FontSize',12);

    ylabel(...
        '波数 \sigma / cm^{-1}',...
        'FontSize',12);

    title(...
        title_text,...
        'FontSize',13);

    legend(...
        '峰值数据',...
        '峰值拟合',...
        '谷值数据',...
        '谷值拟合',...
        'Location','best');

    grid on;
    box on;
    set(gca,'FontSize',11);

    try
        ax = gca;
        tb = axtoolbar(ax);
        tb.Visible = 'off';
    catch
    end

    drawnow;

    print(...
        gcf,...
        file_path,...
        '-dpng',...
        '-r300');

    hold off;

end


%% 函数9：写入逐周期详细数据

function write_cycle_detail(...
    excel_file,...
    sheet_name,...
    delta_sigma,...
    d_each)

    delta_sigma = delta_sigma(:);
    d_each = d_each(:);

    out = ...
        cell(length(delta_sigma)+1,3);

    out(1,:) = {...
        '周期序号',...
        '条纹波数间隔_cm^-1',...
        '厚度_um'};

    for i = 1:length(delta_sigma)

        out{i+1,1} = i;
        out{i+1,2} = delta_sigma(i);
        out{i+1,3} = d_each(i);

    end

    writecell(...
        out,...
        excel_file,...
        'Sheet',...
        sheet_name);

end
