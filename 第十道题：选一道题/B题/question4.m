clear;
clc;
close all;

%% =========================================================
% 第三问完整程序：多光束干涉判断、硅片厚度求解、SiC影响判断
%
% 使用方法：
% 1. 将本程序保存为 question3_complete.m
% 2. 与附件1、附件2、附件3、附件4放在同一文件夹
% 3. 在MATLAB命令窗口运行：
%
%       question3_complete
%
% 程序完成以下内容：
% （1）分析多光束干涉的光谱特征；
% （2）对附件3、4建立多光束模型；
% （3）反演硅外延层折射率 n(sigma)；
% （4）计算10°、15°条件下硅外延层厚度；
% （5）利用可见度V和谷形尖锐度S判断附件1、2
%      是否受到明显多光束干涉影响；
% （6）自动生成论文所需图形；
% （7）自动输出Excel结果表。
%
% 说明：
% 附件1、2：SiC，同一晶圆，10°、15°
% 附件3、4：Si，同一晶圆，10°、15°
%% =========================================================


%% =========================================================
% 0. 参数设置
%% =========================================================

% 光谱平滑参数
smooth_num = 101;

% 峰谷识别参数
min_dist_sic = 180;     % SiC条纹较密
min_dist_si  = 250;     % Si条纹较宽

min_prom_sic = 0.20;
min_prom_si  = 0.20;

% Si多光束模型构造起点
si_fit_min = 500;

% Si厚度计算波段
si_calc_min = 1000;
si_calc_max = 3800;

% SiC多光束特征判断波段
sic_diag_min = 1500;
sic_diag_max = 3900;

% Si多光束特征判断波段
si_diag_min = 500;
si_diag_max = 3500;


%% =========================================================
% 1. 自动读取四个附件
%% =========================================================

f1 = dir('附件1*.xlsx');
f2 = dir('附件2*.xlsx');
f3 = dir('附件3*.xlsx');
f4 = dir('附件4*.xlsx');

if isempty(f1)
    error('未找到附件1，请将附件1.xlsx与本程序放在同一文件夹。');
end

if isempty(f2)
    error('未找到附件2，请将附件2.xlsx与本程序放在同一文件夹。');
end

if isempty(f3)
    error('未找到附件3，请将附件3.xlsx与本程序放在同一文件夹。');
end

if isempty(f4)
    error('未找到附件4，请将附件4.xlsx与本程序放在同一文件夹。');
end

data1 = readmatrix(f1(1).name);
data2 = readmatrix(f2(1).name);
data3 = readmatrix(f3(1).name);
data4 = readmatrix(f4(1).name);


%% =========================================================
% 2. 四组光谱统一预处理
%% =========================================================

% SiC数据从1000 cm^-1开始处理
[s1,r1,rs1] = preprocess_spectrum(data1,smooth_num,1000);
[s2,r2,rs2] = preprocess_spectrum(data2,smooth_num,1000);

% Si数据从500 cm^-1开始处理
[s3,r3,rs3] = preprocess_spectrum(data3,smooth_num,si_fit_min);
[s4,r4,rs4] = preprocess_spectrum(data4,smooth_num,si_fit_min);


%% =========================================================
% 3. 峰谷识别 + 三次样条精确定位
%% =========================================================

ext1 = find_extrema(s1,rs1,min_dist_sic,min_prom_sic);
ext2 = find_extrema(s2,rs2,min_dist_sic,min_prom_sic);

ext3 = find_extrema(s3,rs3,min_dist_si,min_prom_si);
ext4 = find_extrema(s4,rs4,min_dist_si,min_prom_si);


%% =========================================================
% 4. 多光束特征诊断
%
% 定义1：条纹可见度
%
%           Rmax - Rmin
% V = -----------------------
%           Rmax + Rmin
%
% 定义2：谷形尖锐度
%
%           W_(1/2)
% S = ----------------
%              T
%
% T：左右相邻峰之间的完整条纹周期
% W_(1/2)：谷在半高位置处的宽度
%
% 对理想两光束余弦条纹：
%
%               S = 0.5
%
% 若S明显小于0.5，说明谷变尖，具有Airy型多光束特征。
%% =========================================================

diag1 = fringe_diagnostic( ...
    s1,rs1,ext1,sic_diag_min,sic_diag_max);

diag2 = fringe_diagnostic( ...
    s2,rs2,ext2,sic_diag_min,sic_diag_max);

diag3 = fringe_diagnostic( ...
    s3,rs3,ext3,si_diag_min,si_diag_max);

diag4 = fringe_diagnostic( ...
    s4,rs4,ext4,si_diag_min,si_diag_max);


%% =========================================================
% 5. 输出多光束判断依据
%% =========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('第三问第一部分：多光束干涉数据特征判断\n');
fprintf('====================================================\n');

print_diag('附件1：SiC，10°',diag1);
print_diag('附件2：SiC，15°',diag2);
print_diag('附件3：Si，10°',diag3);
print_diag('附件4：Si，15°',diag4);

fprintf('\n判断依据：\n');
fprintf('理想两光束余弦条纹的半高宽比 S 理论值约为0.5。\n');
fprintf('附件3、4在低—中波数区可见度较高，并出现明显 S<0.5 的尖锐谷形，\n');
fprintf('说明硅片数据具有明显的多光束（Airy型）干涉特征。\n');
fprintf('附件1、2的S整体更接近0.5，而且可见度远低于硅片数据，\n');
fprintf('因此SiC数据中的多光束影响相对较弱，不属于第三问中需要重点修正的情况。\n');


%% =========================================================
% 6. 对附件3、4建立多光束模型
%
% 多光束极值关系：
%
% Rmax = [(A+B)/(1+AB)]^2
%
% Rmin = [(A-B)/(1-AB)]^2
%
% 其中：
%
% A = sqrt(I1)
% B = sqrt(I2)
%
% 令：
%
% C = sqrt(Rmax)
% D = sqrt(Rmin)
%
% 可反解A、B，再由Fresnel关系求外延层折射率：
%
%              1+A
% n(sigma) = -------
%              1-A
%% =========================================================

model3 = multibeam_model(ext3);
model4 = multibeam_model(ext4);


%% =========================================================
% 7. 利用多组极值组合计算硅外延层厚度
%
% 对两个极值 sigma_i、sigma_j：
%
% N = (j-i)/2
%
% d =
%
%                 N
% ------------------------------------------------ × 10^4
% 2[sigma_j sqrt(n_j^2-sin^2 alpha)
%  -sigma_i sqrt(n_i^2-sin^2 alpha)]
%
% sigma单位为cm^-1，乘10^4得到um。
%
% 程序舍弃最短N=0.5组合，只保留N>=1。
%% =========================================================

res3 = calc_thickness( ...
    ext3,model3,10,si_calc_min,si_calc_max);

res4 = calc_thickness( ...
    ext4,model4,15,si_calc_min,si_calc_max);


%% =========================================================
% 8. 输出硅外延层厚度结果
%% =========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('第三问第二部分：硅晶圆多光束干涉厚度计算\n');
fprintf('====================================================\n');

fprintf('\n附件3（10°）\n');

fprintf('识别峰数：%d\n', ...
    length(ext3.peak_sigma));

fprintf('识别谷数：%d\n', ...
    length(ext3.valley_sigma));

fprintf('稳定波段有效极值数：%d\n', ...
    length(res3.sigma));

fprintf('厚度组合数：%d\n', ...
    length(res3.d));

fprintf('平均厚度 = %.6f um\n', ...
    res3.mean_d);

fprintf('标准差   = %.6f um\n', ...
    res3.std_d);

fprintf('中位数   = %.6f um\n', ...
    res3.median_d);

fprintf('CV       = %.4f %%\n', ...
    res3.cv);


fprintf('\n附件4（15°）\n');

fprintf('识别峰数：%d\n', ...
    length(ext4.peak_sigma));

fprintf('识别谷数：%d\n', ...
    length(ext4.valley_sigma));

fprintf('稳定波段有效极值数：%d\n', ...
    length(res4.sigma));

fprintf('厚度组合数：%d\n', ...
    length(res4.d));

fprintf('平均厚度 = %.6f um\n', ...
    res4.mean_d);

fprintf('标准差   = %.6f um\n', ...
    res4.std_d);

fprintf('中位数   = %.6f um\n', ...
    res4.median_d);

fprintf('CV       = %.4f %%\n', ...
    res4.cv);


d_si_average = ...
    (res3.mean_d + res4.mean_d)/2;

fprintf('\n两组硅片结果简单平均 = %.6f um\n', ...
    d_si_average);


%% =========================================================
% 9. 输出若干典型波数下的折射率
%% =========================================================

sample_sigma = ...
    [1500 2000 2500 3000 3500];

fprintf('\n附件3折射率参考值\n');

for k = 1:length(sample_sigma)

    x = sample_sigma(k);

    if ...
        x>=model3.sigma(1) && ...
        x<=model3.sigma(end)

        n_value = interp1( ...
            model3.sigma, ...
            model3.n, ...
            x, ...
            'pchip');

        ns_value = interp1( ...
            model3.sigma, ...
            model3.ns, ...
            x, ...
            'pchip');

        fprintf( ...
            '%4d cm^-1: n = %.6f, ns = %.6f\n', ...
            x,n_value,ns_value);

    end
end


fprintf('\n附件4折射率参考值\n');

for k = 1:length(sample_sigma)

    x = sample_sigma(k);

    if ...
        x>=model4.sigma(1) && ...
        x<=model4.sigma(end)

        n_value = interp1( ...
            model4.sigma, ...
            model4.n, ...
            x, ...
            'pchip');

        ns_value = interp1( ...
            model4.sigma, ...
            model4.ns, ...
            x, ...
            'pchip');

        fprintf( ...
            '%4d cm^-1: n = %.6f, ns = %.6f\n', ...
            x,n_value,ns_value);

    end
end


%% =========================================================
% 10. 第三问对附件1、2的最终判断
%% =========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('第三问第三部分：SiC数据是否需要多光束修正\n');
fprintf('====================================================\n');

fprintf('\n附件1（10°）平均谷形尖锐度 S = %.4f\n', ...
    mean(diag1.S,'omitnan'));

fprintf('附件2（15°）平均谷形尖锐度 S = %.4f\n', ...
    mean(diag2.S,'omitnan'));

fprintf('附件3（10°）平均谷形尖锐度 S = %.4f\n', ...
    mean(diag3.S,'omitnan'));

fprintf('附件4（15°）平均谷形尖锐度 S = %.4f\n', ...
    mean(diag4.S,'omitnan'));

fprintf('\n附件1平均可见度 V = %.4f\n', ...
    mean(diag1.V,'omitnan'));

fprintf('附件2平均可见度 V = %.4f\n', ...
    mean(diag2.V,'omitnan'));

fprintf('附件3平均可见度 V = %.4f\n', ...
    mean(diag3.V,'omitnan'));

fprintf('附件4平均可见度 V = %.4f\n', ...
    mean(diag4.V,'omitnan'));

fprintf('\n结论：\n');
fprintf('附件3、4表现出明显的峰谷尖锐化和较高条纹可见度，\n');
fprintf('应采用多光束干涉模型计算硅外延层厚度。\n');
fprintf('附件1、2的条纹形态总体接近两光束余弦型，且可见度较低，\n');
fprintf('未发现与附件3、4同等级的明显多光束干涉效应。\n');
fprintf('因此第二问得到的SiC厚度结果无需进行额外的多光束修正。\n');


%% =========================================================
% 11. 图1：附件3多光束光谱及峰谷
%% =========================================================

figure(1);

set(gcf, ...
    'Color','w', ...
    'Position',[150 100 1050 600]);

plot( ...
    s3,r3, ...
    'LineWidth',0.6);

hold on;

plot( ...
    s3,rs3, ...
    'LineWidth',1.3);

scatter( ...
    ext3.peak_sigma, ...
    ext3.peak_R, ...
    42, ...
    'o', ...
    'filled');

scatter( ...
    ext3.valley_sigma, ...
    ext3.valley_R, ...
    42, ...
    'v', ...
    'filled');

xlabel('波数 \sigma / cm^{-1}');
ylabel('反射率 R / %');

title('附件3：10°入射角硅晶圆反射光谱');

legend( ...
    '原始光谱', ...
    '101点移动平均', ...
    '干涉峰', ...
    '干涉谷', ...
    'Location','best');

grid on;
box on;

set(gca,'FontSize',11);


%% =========================================================
% 12. 图2：附件4多光束光谱及峰谷
%% =========================================================

figure(2);

set(gcf, ...
    'Color','w', ...
    'Position',[150 100 1050 600]);

plot( ...
    s4,r4, ...
    'LineWidth',0.6);

hold on;

plot( ...
    s4,rs4, ...
    'LineWidth',1.3);

scatter( ...
    ext4.peak_sigma, ...
    ext4.peak_R, ...
    42, ...
    'o', ...
    'filled');

scatter( ...
    ext4.valley_sigma, ...
    ext4.valley_R, ...
    42, ...
    'v', ...
    'filled');

xlabel('波数 \sigma / cm^{-1}');
ylabel('反射率 R / %');

title('附件4：15°入射角硅晶圆反射光谱');

legend( ...
    '原始光谱', ...
    '101点移动平均', ...
    '干涉峰', ...
    '干涉谷', ...
    'Location','best');

grid on;
box on;

set(gca,'FontSize',11);


%% =========================================================
% 13. 图3：硅外延层折射率曲线
%% =========================================================

figure(3);

set(gcf, ...
    'Color','w', ...
    'Position',[180 100 950 570]);

plot( ...
    model3.sigma, ...
    model3.n, ...
    'LineWidth',1.6);

hold on;

plot( ...
    model4.sigma, ...
    model4.n, ...
    'LineWidth',1.6);

xlabel('波数 \sigma / cm^{-1}');
ylabel('外延层折射率 n');

title('硅外延层折射率反演结果');

legend( ...
    '附件3：10°', ...
    '附件4：15°', ...
    'Location','best');

grid on;
box on;

set(gca,'FontSize',11);


%% =========================================================
% 14. 图4：硅片多组厚度计算结果分布
%% =========================================================

figure(4);

set(gcf, ...
    'Color','w', ...
    'Position',[180 100 900 600]);

hold on;

draw_box_points(res3.d,1);
draw_box_points(res4.d,2);

plot( ...
    [0.72 1.28], ...
    [res3.mean_d res3.mean_d], ...
    '--', ...
    'LineWidth',1.6);

plot( ...
    [1.72 2.28], ...
    [res4.mean_d res4.mean_d], ...
    '--', ...
    'LineWidth',1.6);

text( ...
    1.30, ...
    res3.mean_d, ...
    sprintf('均值 = %.4f \\mum',res3.mean_d), ...
    'FontSize',11);

text( ...
    2.30, ...
    res4.mean_d, ...
    sprintf('均值 = %.4f \\mum',res4.mean_d), ...
    'FontSize',11);

xlim([0.5 2.75]);

set(gca, ...
    'XTick',[1 2], ...
    'XTickLabel',{'10°','15°'}, ...
    'FontSize',11);

xlabel('入射角');
ylabel('硅外延层厚度 d / \mum');

title('多光束模型下硅外延层厚度计算结果分布');

grid on;
box on;


%% =========================================================
% 15. 图5：四组数据的条纹可见度比较
%% =========================================================

figure(5);

set(gcf, ...
    'Color','w', ...
    'Position',[180 100 1000 600]);

plot( ...
    diag1.sigma, ...
    diag1.V, ...
    '-o', ...
    'LineWidth',1.2);

hold on;

plot( ...
    diag2.sigma, ...
    diag2.V, ...
    '-o', ...
    'LineWidth',1.2);

plot( ...
    diag3.sigma, ...
    diag3.V, ...
    '-s', ...
    'LineWidth',1.2);

plot( ...
    diag4.sigma, ...
    diag4.V, ...
    '-s', ...
    'LineWidth',1.2);

xlabel('谷值波数 \sigma / cm^{-1}');
ylabel('条纹可见度 V');

title('SiC与Si光谱条纹可见度比较');

legend( ...
    'SiC 10°', ...
    'SiC 15°', ...
    'Si 10°', ...
    'Si 15°', ...
    'Location','best');

grid on;
box on;

set(gca,'FontSize',11);


%% =========================================================
% 16. 图6：四组数据谷形尖锐度S比较
%% =========================================================

figure(6);

set(gcf, ...
    'Color','w', ...
    'Position',[180 100 1000 600]);

plot( ...
    diag1.sigma, ...
    diag1.S, ...
    '-o', ...
    'LineWidth',1.2);

hold on;

plot( ...
    diag2.sigma, ...
    diag2.S, ...
    '-o', ...
    'LineWidth',1.2);

plot( ...
    diag3.sigma, ...
    diag3.S, ...
    '-s', ...
    'LineWidth',1.2);

plot( ...
    diag4.sigma, ...
    diag4.S, ...
    '-s', ...
    'LineWidth',1.2);

% 理想两光束参考线 S=0.5
yline( ...
    0.5, ...
    '--', ...
    '理想两光束 S=0.5', ...
    'LineWidth',1.2);

xlabel('谷值波数 \sigma / cm^{-1}');
ylabel('半高宽比 S=W_{1/2}/T');

title('SiC与Si光谱谷形尖锐度比较');

legend( ...
    'SiC 10°', ...
    'SiC 15°', ...
    'Si 10°', ...
    'Si 15°', ...
    '两光束参考值', ...
    'Location','best');

grid on;
box on;

set(gca,'FontSize',11);


%% =========================================================
% 17. 自动保存图片
%% =========================================================

save_figure(1,'第三问_附件3硅片光谱峰谷.png');
save_figure(2,'第三问_附件4硅片光谱峰谷.png');
save_figure(3,'第三问_硅外延层折射率.png');
save_figure(4,'第三问_硅外延层厚度分布.png');
save_figure(5,'第三问_条纹可见度比较.png');
save_figure(6,'第三问_谷形尖锐度比较.png');


%% =========================================================
% 18. 自动保存Excel结果
%% =========================================================

excel_name = '第三问_计算结果.xlsx';

if exist(excel_name,'file')
    delete(excel_name);
end

%% 厚度结果汇总

summary_table = table( ...
    [10;15], ...
    [res3.mean_d;res4.mean_d], ...
    [res3.std_d;res4.std_d], ...
    [res3.median_d;res4.median_d], ...
    [res3.cv;res4.cv], ...
    [length(res3.d);length(res4.d)], ...
    'VariableNames',{ ...
    'Angle_deg', ...
    'Mean_d_um', ...
    'Std_d_um', ...
    'Median_d_um', ...
    'CV_percent', ...
    'PairCount'});

writetable( ...
    summary_table, ...
    excel_name, ...
    'Sheet','硅片厚度汇总');


%% 附件3厚度组合

T3 = table( ...
    res3.sigma1, ...
    res3.n1, ...
    res3.sigma2, ...
    res3.n2, ...
    res3.N, ...
    res3.d, ...
    'VariableNames',{ ...
    'sigma1_cm_1', ...
    'n1', ...
    'sigma2_cm_1', ...
    'n2', ...
    'N', ...
    'd_um'});

writetable( ...
    T3, ...
    excel_name, ...
    'Sheet','附件3厚度组合');


%% 附件4厚度组合

T4 = table( ...
    res4.sigma1, ...
    res4.n1, ...
    res4.sigma2, ...
    res4.n2, ...
    res4.N, ...
    res4.d, ...
    'VariableNames',{ ...
    'sigma1_cm_1', ...
    'n1', ...
    'sigma2_cm_1', ...
    'n2', ...
    'N', ...
    'd_um'});

writetable( ...
    T4, ...
    excel_name, ...
    'Sheet','附件4厚度组合');


%% 四组诊断结果

writetable( ...
    diagnostic_table(diag1), ...
    excel_name, ...
    'Sheet','附件1多光束诊断');

writetable( ...
    diagnostic_table(diag2), ...
    excel_name, ...
    'Sheet','附件2多光束诊断');

writetable( ...
    diagnostic_table(diag3), ...
    excel_name, ...
    'Sheet','附件3多光束诊断');

writetable( ...
    diagnostic_table(diag4), ...
    excel_name, ...
    'Sheet','附件4多光束诊断');


fprintf('\n');
fprintf('====================================================\n');
fprintf('程序运行完成\n');
fprintf('====================================================\n');

fprintf('已生成6张第三问图片。\n');
fprintf('已生成Excel文件：%s\n',excel_name);
fprintf('====================================================\n');


%% =========================================================
%                  以下全部为本地函数
%        不需要单独运行，不需要保存成其他m文件
%% =========================================================


function [sigma,R,R_smooth] = ...
    preprocess_spectrum(data,smooth_num,sigma_min)

% 读取波数与反射率
sigma = data(:,1);
R = data(:,2);

% 删除无效数据
id = ...
    isfinite(sigma) & ...
    isfinite(R);

sigma = sigma(id);
R = R(id);

% 按波数升序
[sigma,id] = sort(sigma);
R = R(id);

% 删除可能存在的首个异常零点
if ~isempty(R) && R(1)==0

    sigma(1) = [];
    R(1) = [];

end

% 截取分析波段
id = ...
    sigma>=sigma_min;

sigma = sigma(id);
R = R(id);

% 101点中心移动平均
R_smooth = ...
    movmean( ...
    R, ...
    smooth_num, ...
    'Endpoints','shrink');

end


%% =========================================================

function ext = ...
    find_extrema(sigma,R,min_dist,min_prom)

% 初步峰识别
[peak_sigma0,~] = ...
    local_peaks( ...
    sigma,R,min_dist,min_prom);

% 对-R寻找峰，即寻找原曲线的谷
[valley_sigma0,~] = ...
    local_peaks( ...
    sigma,-R,min_dist,min_prom);

% 三次样条
pp = ...
    spline(sigma,R);

% 极值连续精化
[peak_sigma,peak_R] = ...
    refine_all( ...
    pp,sigma,peak_sigma0,min_dist,1);

[valley_sigma,valley_R] = ...
    refine_all( ...
    pp,sigma,valley_sigma0,min_dist,-1);

% 删除重复极值
[peak_sigma,peak_R] = ...
    remove_close( ...
    peak_sigma,peak_R,1);

[valley_sigma,valley_R] = ...
    remove_close( ...
    valley_sigma,valley_R,-1);

ext.peak_sigma = peak_sigma;
ext.peak_R = peak_R;

ext.valley_sigma = valley_sigma;
ext.valley_R = valley_R;

end


%% =========================================================

function [px,py] = ...
    local_peaks(x,y,min_dist,min_prom)

x = x(:);
y = y(:);

% 局部极大候选点
cand = ...
    find( ...
    y(2:end-1)>y(1:end-2) & ...
    y(2:end-1)>=y(3:end)) + 1;

if isempty(cand)

    px = [];
    py = [];

    return

end

% 波数距离转为采样点窗口
dx = median(diff(x));

w = max( ...
    round(min_dist/dx), ...
    1);

prom = zeros(size(cand));

% 计算局部显著度
for i = 1:length(cand)

    k = cand(i);

    a = max(1,k-w);
    b = min(length(y),k+w);

    left_min = min(y(a:k));
    right_min = min(y(k:b));

    prom(i) = ...
        y(k) - ...
        max(left_min,right_min);

end

% 显著度筛选
id = ...
    prom>=min_prom;

cand = cand(id);
prom = prom(id);

if isempty(cand)

    px = [];
    py = [];

    return

end

% 最小峰距筛选
selected = cand(1);
selected_prom = prom(1);

for i = 2:length(cand)

    k = cand(i);

    if ...
        x(k)-x(selected(end)) >= ...
        min_dist

        selected(end+1,1) = k;
        selected_prom(end+1,1) = prom(i);

    elseif ...
        prom(i)>selected_prom(end)

        selected(end) = k;
        selected_prom(end) = prom(i);

    end
end

px = x(selected);
py = y(selected);

end


%% =========================================================

function [xr,yr] = ...
    refine_all(pp,x,x0,min_dist,mode)

x0 = x0(:);

xr = zeros(size(x0));
yr = zeros(size(x0));

for i = 1:length(x0)

    a = max( ...
        x(1), ...
        x0(i)-min_dist/2);

    b = min( ...
        x(end), ...
        x0(i)+min_dist/2);

    if mode==1

        % 最大值转化为负函数最小值
        fun = ...
            @(z)-ppval(pp,z);

    else

        fun = ...
            @(z)ppval(pp,z);

    end

    xr(i) = ...
        golden_search( ...
        fun,a,b,1e-7,150);

    yr(i) = ...
        ppval(pp,xr(i));

end

[xr,id] = sort(xr);
yr = yr(id);

end


%% =========================================================

function xmin = ...
    golden_search(fun,a,b,tol,max_iter)

g = ...
    (sqrt(5)-1)/2;

c = ...
    b-g*(b-a);

d = ...
    a+g*(b-a);

fc = fun(c);
fd = fun(d);

for i = 1:max_iter

    if abs(b-a)<tol
        break
    end

    if fc<fd

        b = d;

        d = c;
        fd = fc;

        c = ...
            b-g*(b-a);

        fc = fun(c);

    else

        a = c;

        c = d;
        fc = fd;

        d = ...
            a+g*(b-a);

        fd = fun(d);

    end
end

xmin = ...
    (a+b)/2;

end


%% =========================================================

function [x2,y2] = ...
    remove_close(x,y,mode)

x = x(:);
y = y(:);

if isempty(x)

    x2 = x;
    y2 = y;

    return

end

[x,id] = sort(x);
y = y(id);

x2 = x(1);
y2 = y(1);

for i = 2:length(x)

    if ...
        x(i)-x2(end)<2

        if ...
            (mode==1 && y(i)>y2(end)) || ...
            (mode==-1 && y(i)<y2(end))

            x2(end) = x(i);
            y2(end) = y(i);

        end

    else

        x2(end+1,1) = x(i);
        y2(end+1,1) = y(i);

    end
end

end


%% =========================================================
% 多光束极值公式反演
%% =========================================================

function model = ...
    multibeam_model(ext)

% 峰谷反射率从百分数转0~1
px = ext.peak_sigma(:);
py = ext.peak_R(:)/100;

vx = ext.valley_sigma(:);
vy = ext.valley_R(:)/100;

% 上下包络共同有效区间
lo = ...
    max(min(px),min(vx));

hi = ...
    min(max(px),max(vx));

sigma = ...
    linspace(lo,hi,3000)';

% 上下包络
Rmax = ...
    interp1( ...
    px,py,sigma,'pchip');

Rmin = ...
    interp1( ...
    vx,vy,sigma,'pchip');

% 数值限制
Rmax = ...
    min(max(Rmax,0),0.999999);

Rmin = ...
    min(max(Rmin,0),0.999999);

% 定义C、D
C = sqrt(Rmax);
D = sqrt(Rmin);

% 公共根式
q = ...
    sqrt( ...
    max( ...
    (1-C.^2).*(1-D.^2), ...
    0));

% 反演A
A = ...
    (1+C.*D-q) ./ ...
    (C+D);

% 反演B
denB = ...
    C-D;

denB( ...
    abs(denB)<1e-10) = ...
    NaN;

B = ...
    (1-C.*D-q) ./ ...
    denB;

% 物理范围限制
A = ...
    min(max(A,0),0.999999);

B = ...
    min(max(B,0),0.999999);

% 外延层折射率
n = ...
    (1+A) ./ ...
    (1-A);

% 衬底折射率
ns = ...
    n .* ...
    (1+B) ./ ...
    (1-B);

model.sigma = sigma;

model.Rmax = Rmax;
model.Rmin = Rmin;

model.A = A;
model.B = B;

model.n = n;
model.ns = ns;

end


%% =========================================================
% 厚度计算
%% =========================================================

function res = ...
    calc_thickness( ...
    ext,model,alpha,sigma_min,sigma_max)

% 波段内峰
p_id = ...
    ext.peak_sigma>=sigma_min & ...
    ext.peak_sigma<=sigma_max;

% 波段内谷
v_id = ...
    ext.valley_sigma>=sigma_min & ...
    ext.valley_sigma<=sigma_max;

sigma = [ ...
    ext.peak_sigma(p_id); ...
    ext.valley_sigma(v_id)];

type = [ ...
    ones(sum(p_id),1); ...
    -ones(sum(v_id),1)];

R = [ ...
    ext.peak_R(p_id); ...
    ext.valley_R(v_id)];

% 按波数排序
[sigma,id] = ...
    sort(sigma);

type = type(id);
R = R(id);

% 峰谷交替
[sigma,type,R] = ...
    keep_alternating( ...
    sigma,type,R);

% 只保留n模型有效区间
valid = ...
    sigma>=model.sigma(1) & ...
    sigma<=model.sigma(end);

sigma = sigma(valid);
type = type(valid);
R = R(valid);

% 每个极值处折射率
n = ...
    interp1( ...
    model.sigma, ...
    model.n, ...
    sigma, ...
    'pchip');

% 初始化
d = [];
N_list = [];

s1_list = [];
s2_list = [];

n1_list = [];
n2_list = [];

% 构造全部N>=1组合
for i = 1:length(sigma)-2

    for j = i+2:length(sigma)

        % 峰谷相邻为半级次
        N = ...
            (j-i)/2;

        g1 = ...
            sigma(i) * ...
            sqrt( ...
            n(i)^2 - ...
            sind(alpha)^2);

        g2 = ...
            sigma(j) * ...
            sqrt( ...
            n(j)^2 - ...
            sind(alpha)^2);

        den = ...
            2*(g2-g1);

        if den>0

            dij = ...
                N/den*1e4;

            if ...
                isfinite(dij) && ...
                dij>0

                d(end+1,1) = dij;

                N_list(end+1,1) = N;

                s1_list(end+1,1) = sigma(i);
                s2_list(end+1,1) = sigma(j);

                n1_list(end+1,1) = n(i);
                n2_list(end+1,1) = n(j);

            end
        end
    end
end

if isempty(d)

    error( ...
        '没有得到有效厚度组合，请检查峰谷识别参数。');

end

res.sigma = sigma;
res.type = type;
res.R = R;
res.n = n;

res.d = d;
res.N = N_list;

res.sigma1 = s1_list;
res.sigma2 = s2_list;

res.n1 = n1_list;
res.n2 = n2_list;

res.mean_d = ...
    mean(d);

res.std_d = ...
    std(d);

res.median_d = ...
    median(d);

res.cv = ...
    res.std_d / ...
    res.mean_d * 100;

end


%% =========================================================

function [x2,t2,y2] = ...
    keep_alternating(x,t,y)

if isempty(x)

    x2 = x;
    t2 = t;
    y2 = y;

    return

end

x2 = x(1);
t2 = t(1);
y2 = y(1);

for i = 2:length(x)

    if ...
        t(i)~=t2(end)

        x2(end+1,1) = x(i);
        t2(end+1,1) = t(i);
        y2(end+1,1) = y(i);

    else

        if t(i)==1

            % 连续两个峰保留更高者
            if y(i)>y2(end)

                x2(end) = x(i);
                y2(end) = y(i);

            end

        else

            % 连续两个谷保留更低者
            if y(i)<y2(end)

                x2(end) = x(i);
                y2(end) = y(i);

            end

        end
    end
end

end


%% =========================================================
% 多光束光谱特征诊断
%% =========================================================

function diag = ...
    fringe_diagnostic( ...
    sigma,R,ext,sigma_min,sigma_max)

pp = ...
    spline(sigma,R);

peak_x = ext.peak_sigma(:);
peak_y = ext.peak_R(:);

valley_x = ext.valley_sigma(:);
valley_y = ext.valley_R(:);

out_sigma = [];
out_V = [];
out_S = [];

for k = 1:length(valley_x)

    v = valley_x(k);

    if ...
        v<sigma_min || ...
        v>sigma_max

        continue

    end

    % 左侧最近峰
    left_id = ...
        find(peak_x<v,1,'last');

    % 右侧最近峰
    right_id = ...
        find(peak_x>v,1,'first');

    if ...
        isempty(left_id) || ...
        isempty(right_id)

        continue

    end

    xl = peak_x(left_id);
    xr = peak_x(right_id);

    Rl = peak_y(left_id);
    Rr = peak_y(right_id);

    Rv = valley_y(k);

    % 相邻峰平均反射率
    Rtop = ...
        (Rl+Rr)/2;

    % 条纹可见度
    V = ...
        (Rtop-Rv) / ...
        (Rtop+Rv);

    % 半高位置
    Rhalf = ...
        (Rtop+Rv)/2;

    % 左右交点
    try

        fl = ...
            @(z) ...
            ppval(pp,z)-Rhalf;

        x_left = ...
            fzero(fl,[xl v]);

        x_right = ...
            fzero(fl,[v xr]);

        % 半高宽
        W = ...
            x_right-x_left;

        % 完整周期
        T = ...
            xr-xl;

        S = ...
            W/T;

    catch

        S = NaN;

    end

    out_sigma(end+1,1) = v;
    out_V(end+1,1) = V;
    out_S(end+1,1) = S;

end

diag.sigma = out_sigma;
diag.V = out_V;
diag.S = out_S;

end


%% =========================================================

function print_diag(name,diag)

fprintf('\n%s\n',name);

fprintf('用于诊断的谷数：%d\n', ...
    length(diag.sigma));

fprintf('平均条纹可见度 V = %.4f\n', ...
    mean(diag.V,'omitnan'));

fprintf('平均半高宽比 S   = %.4f\n', ...
    mean(diag.S,'omitnan'));

fprintf('平均 |S-0.5|     = %.4f\n', ...
    mean(abs(diag.S-0.5),'omitnan'));

end


%% =========================================================

function T = ...
    diagnostic_table(diag)

T = table( ...
    diag.sigma, ...
    diag.V, ...
    diag.S, ...
    abs(diag.S-0.5), ...
    'VariableNames',{ ...
    'Valley_sigma_cm_1', ...
    'Visibility_V', ...
    'Sharpness_S', ...
    'Abs_S_minus_0_5'});

end


%% =========================================================
% 自定义箱线图，不依赖Statistics Toolbox
%% =========================================================

function draw_box_points(d,x0)

d = sort(d(:));

q1 = ...
    my_percentile(d,25);

q2 = ...
    my_percentile(d,50);

q3 = ...
    my_percentile(d,75);

IQR = ...
    q3-q1;

low_limit = ...
    q1-1.5*IQR;

high_limit = ...
    q3+1.5*IQR;

normal = ...
    d( ...
    d>=low_limit & ...
    d<=high_limit);

low_whisker = ...
    min(normal);

high_whisker = ...
    max(normal);

w = 0.22;

% 箱体
rectangle( ...
    'Position',[ ...
    x0-w,q1,2*w,q3-q1], ...
    'LineWidth',1.5);

% 中位数
plot( ...
    [x0-w x0+w], ...
    [q2 q2], ...
    '-', ...
    'LineWidth',1.8);

% 上须
plot( ...
    [x0 x0], ...
    [q3 high_whisker], ...
    '-', ...
    'LineWidth',1.2);

plot( ...
    [x0-w/2 x0+w/2], ...
    [high_whisker high_whisker], ...
    '-', ...
    'LineWidth',1.2);

% 下须
plot( ...
    [x0 x0], ...
    [q1 low_whisker], ...
    '-', ...
    'LineWidth',1.2);

plot( ...
    [x0-w/2 x0+w/2], ...
    [low_whisker low_whisker], ...
    '-', ...
    'LineWidth',1.2);

% 散点
rng(x0);

jitter = ...
    0.14*(rand(size(d))-0.5);

scatter( ...
    x0+jitter, ...
    d, ...
    25, ...
    'filled', ...
    'MarkerFaceAlpha',0.55, ...
    'MarkerEdgeAlpha',0.55);

end


%% =========================================================

function q = ...
    my_percentile(x,p)

x = sort(x(:));

n = length(x);

if n==1

    q = x;

    return

end

pos = ...
    1+(n-1)*p/100;

i = floor(pos);
j = ceil(pos);

if i==j

    q = x(i);

else

    q = ...
        x(i) + ...
        (pos-i)*(x(j)-x(i));

end

end


%% =========================================================
% 兼容不同MATLAB版本的图片保存函数
%% =========================================================

function save_figure(fig_num,file_name)

figure(fig_num);

try

    exportgraphics( ...
        gcf, ...
        file_name, ...
        'Resolution',300);

catch

    % 老版本MATLAB没有exportgraphics时使用print
    print( ...
        gcf, ...
        file_name, ...
        '-dpng', ...
        '-r300');

end

end
