clear;
clc;

%% ==================== 参数输入 ====================

alpha = input('输入红外光的入射角 alpha（°）: ');

sigma_m = input('输入第 m 个同类型干涉极值的波数 sigma_m（cm^-1）: ');
sigma_m1 = input('输入第 m+1 个同类型干涉极值的波数 sigma_m+1（cm^-1）: ');

n_m = input('输入波数 sigma_m 对应的折射率 n(sigma_m): ');
n_m1 = input('输入波数 sigma_m+1 对应的折射率 n(sigma_m+1): ');


%% ==================== 合法性检验 ====================

% 入射角应位于 0°~90° 之间
if alpha < 0 || alpha >= 90
    error('入射角 alpha 应满足 0 <= alpha < 90°');
end

% 折射率应大于 1
if n_m <= 1 || n_m1 <= 1
    error('外延层折射率应大于 1');
end

% 两个波数必须不同
if sigma_m == sigma_m1
    error('两个相邻干涉极值的波数不能相同');
end

% 波数应为正数
if sigma_m <= 0 || sigma_m1 <= 0
    error('波数必须大于 0');
end


%% ==================== 根据 Snell 定律计算折射角 ====================

theta_m = asind(sind(alpha) / n_m);

theta_m1 = asind(sind(alpha) / n_m1);


%% ==================== 一般变折射率模型 ====================

% 根据
%
% d = 1 /
% {2[sigma_(m+1)*sqrt(n_(m+1)^2-sin^2(alpha))
%    - sigma_m*sqrt(n_m^2-sin^2(alpha))]}
%
% 计算外延层厚度

term_m = sigma_m * sqrt(n_m^2 - sind(alpha)^2);

term_m1 = sigma_m1 * sqrt(n_m1^2 - sind(alpha)^2);

delta_term = abs(term_m1 - term_m);

if delta_term <= 0
    error('计算所得有效光程差变化量异常，请检查输入参数');
end

d_cm = 1 / (2 * delta_term);


%% ==================== 单位换算 ====================

% 1 cm = 10^4 μm
d_um = d_cm * 1e4;


%% ==================== 输出结果 ====================

fprintf('\n============================================\n');
fprintf('        两光束薄膜干涉变折射率模型\n');
fprintf('============================================\n');

fprintf('入射角 alpha                  = %.4f °\n', alpha);

fprintf('\n第 m 个干涉极值：\n');
fprintf('波数 sigma_m                  = %.6f cm^-1\n', sigma_m);
fprintf('折射率 n(sigma_m)             = %.6f\n', n_m);
fprintf('折射角 theta_m                = %.6f °\n', theta_m);

fprintf('\n第 m+1 个干涉极值：\n');
fprintf('波数 sigma_m+1                = %.6f cm^-1\n', sigma_m1);
fprintf('折射率 n(sigma_m+1)           = %.6f\n', n_m1);
fprintf('折射角 theta_m+1              = %.6f °\n', theta_m1);

fprintf('\n--------------------------------------------\n');

fprintf('外延层厚度 d                  = %.10f cm\n', d_cm);
fprintf('外延层厚度 d                  = %.6f μm\n', d_um);

fprintf('============================================\n');