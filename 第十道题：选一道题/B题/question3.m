clear;
clc;
close all;

%% =========================================================
% 第三问：硅晶圆多光束干涉模型
%
% 流程：
% 1. 读取附件3、附件4
% 2. 光谱清洗与101点移动平均
% 3. 三次样条精化峰谷位置
% 4. 由上下包络线反演多光束模型中的 A、B
% 5. 求外延层折射率 n(sigma) 与衬底折射率 ns(sigma)
% 6. 在稳定波段内构造多组极值组合
% 7. 根据相位差公式计算硅外延层厚度
%% =========================================================

smooth_num = 101;
min_dist = 250;
min_prom = 0.20;

fit_min = 500;
calc_min = 1000;
calc_max = 3800;

%% 1. 自动读取附件3、附件4

f3 = dir('附件3*.xlsx');
f4 = dir('附件4*.xlsx');

if isempty(f3) || isempty(f4)
    error('未找到附件3或附件4，请把Excel文件和question3.m放在同一文件夹。');
end

data3 = readmatrix(f3(1).name);
data4 = readmatrix(f4(1).name);

%% 2. 光谱预处理

[s3,r3,rs3] = preprocess_spectrum(data3,smooth_num,fit_min);
[s4,r4,rs4] = preprocess_spectrum(data4,smooth_num,fit_min);

%% 3. 峰谷识别与精确定位

ext3 = find_extrema(s3,rs3,min_dist,min_prom);
ext4 = find_extrema(s4,rs4,min_dist,min_prom);

%% 4. 多光束模型反演折射率

model3 = multibeam_model(ext3);
model4 = multibeam_model(ext4);

%% 5. 硅外延层厚度计算

res3 = calc_thickness(ext3,model3,10,calc_min,calc_max);
res4 = calc_thickness(ext4,model4,15,calc_min,calc_max);

%% 6. 输出主要结果

fprintf('\n');
fprintf('====================================================\n');
fprintf('第三问：硅晶圆多光束干涉计算结果\n');
fprintf('====================================================\n');

fprintf('\n附件3（10°）\n');
fprintf('识别峰数：%d\n',length(ext3.peak_sigma));
fprintf('识别谷数：%d\n',length(ext3.valley_sigma));
fprintf('稳定波段有效极值数：%d\n',length(res3.sigma));
fprintf('厚度组合数：%d\n',length(res3.d));
fprintf('平均厚度 = %.6f um\n',res3.mean_d);
fprintf('标准差   = %.6f um\n',res3.std_d);
fprintf('中位数   = %.6f um\n',res3.median_d);
fprintf('CV       = %.4f %%\n',res3.cv);

fprintf('\n附件4（15°）\n');
fprintf('识别峰数：%d\n',length(ext4.peak_sigma));
fprintf('识别谷数：%d\n',length(ext4.valley_sigma));
fprintf('稳定波段有效极值数：%d\n',length(res4.sigma));
fprintf('厚度组合数：%d\n',length(res4.d));
fprintf('平均厚度 = %.6f um\n',res4.mean_d);
fprintf('标准差   = %.6f um\n',res4.std_d);
fprintf('中位数   = %.6f um\n',res4.median_d);
fprintf('CV       = %.4f %%\n',res4.cv);

fprintf('\n两组厚度简单平均 = %.6f um\n',...
    (res3.mean_d+res4.mean_d)/2);

%% 7. 输出典型波数处折射率

sample_sigma = [1500 2000 2500 3000 3500];

fprintf('\n附件3折射率参考值\n');

for k = 1:length(sample_sigma)

    x = sample_sigma(k);

    if x >= model3.sigma(1) && x <= model3.sigma(end)

        n1 = interp1(model3.sigma,model3.n,x,'pchip');
        ns1 = interp1(model3.sigma,model3.ns,x,'pchip');

        fprintf('%4d cm^-1: n = %.6f, ns = %.6f\n',...
            x,n1,ns1);
    end
end

fprintf('\n附件4折射率参考值\n');

for k = 1:length(sample_sigma)

    x = sample_sigma(k);

    if x >= model4.sigma(1) && x <= model4.sigma(end)

        n1 = interp1(model4.sigma,model4.n,x,'pchip');
        ns1 = interp1(model4.sigma,model4.ns,x,'pchip');

        fprintf('%4d cm^-1: n = %.6f, ns = %.6f\n',...
            x,n1,ns1);
    end
end

fprintf('====================================================\n');


%% =========================================================
%                    本地函数1：光谱预处理
%% =========================================================

function [sigma,R,R_smooth] = preprocess_spectrum(data,smooth_num,sigma_min)

% 第1列为波数，第2列为反射率
sigma = data(:,1);
R = data(:,2);

% 删除NaN和Inf
id = isfinite(sigma) & isfinite(R);
sigma = sigma(id);
R = R(id);

% 波数升序排列
[sigma,id] = sort(sigma);
R = R(id);

% 删除可能存在的首个异常0值
if ~isempty(R) && R(1)==0
    sigma(1) = [];
    R(1) = [];
end

% 截取需要分析的波段
id = sigma >= sigma_min;
sigma = sigma(id);
R = R(id);

% 101点中心移动平均
R_smooth = movmean(R,smooth_num,'Endpoints','shrink');

end


%% =========================================================
%                 本地函数2：峰谷识别与精化
%% =========================================================

function ext = find_extrema(sigma,R,min_dist,min_prom)

% 先在离散数据上寻找主要峰
[peak_sigma0,~] = local_peaks(...
    sigma,R,min_dist,min_prom);

% 对负反射率寻找峰，相当于寻找原光谱的谷
[valley_sigma0,~] = local_peaks(...
    sigma,-R,min_dist,min_prom);

% 建立连续三次样条
pp = spline(sigma,R);

% 在候选极值附近进一步精确搜索
[peak_sigma,peak_R] = refine_all(...
    pp,sigma,peak_sigma0,min_dist,1);

[valley_sigma,valley_R] = refine_all(...
    pp,sigma,valley_sigma0,min_dist,-1);

% 删除极少数重复极值
[peak_sigma,peak_R] = remove_close(...
    peak_sigma,peak_R,1);

[valley_sigma,valley_R] = remove_close(...
    valley_sigma,valley_R,-1);

ext.peak_sigma = peak_sigma;
ext.peak_R = peak_R;

ext.valley_sigma = valley_sigma;
ext.valley_R = valley_R;

end


function [px,py] = local_peaks(x,y,min_dist,min_prom)

x = x(:);
y = y(:);

% 局部极大值候选
cand = find(...
    y(2:end-1)>y(1:end-2) & ...
    y(2:end-1)>=y(3:end)) + 1;

if isempty(cand)
    px = [];
    py = [];
    return
end

% 将波数距离换算为数据点窗口
dx = median(diff(x));
w = max(round(min_dist/dx),1);

prom = zeros(size(cand));

% 计算局部显著度
for i = 1:length(cand)

    k = cand(i);

    a = max(1,k-w);
    b = min(length(y),k+w);

    left_min = min(y(a:k));
    right_min = min(y(k:b));

    prom(i) = y(k)-max(left_min,right_min);
end

% 显著度筛选
id = prom >= min_prom;

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

    if x(k)-x(selected(end)) >= min_dist

        selected(end+1,1) = k;
        selected_prom(end+1,1) = prom(i);

    elseif prom(i)>selected_prom(end)

        selected(end) = k;
        selected_prom(end) = prom(i);
    end
end

px = x(selected);
py = y(selected);

end


function [xr,yr] = refine_all(pp,x,x0,min_dist,mode)

x0 = x0(:);

xr = zeros(size(x0));
yr = zeros(size(x0));

for i = 1:length(x0)

    a = max(x(1),x0(i)-min_dist/2);
    b = min(x(end),x0(i)+min_dist/2);

    if mode==1
        % 求极大值等价于求负函数极小值
        fun = @(z) -ppval(pp,z);
    else
        fun = @(z) ppval(pp,z);
    end

    xr(i) = golden_search(fun,a,b,1e-7,150);
    yr(i) = ppval(pp,xr(i));
end

[xr,id] = sort(xr);
yr = yr(id);

end


function xmin = golden_search(fun,a,b,tol,max_iter)

% 黄金分割法求一维函数极小值

g = (sqrt(5)-1)/2;

c = b-g*(b-a);
d = a+g*(b-a);

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

        c = b-g*(b-a);
        fc = fun(c);

    else

        a = c;

        c = d;
        fc = fd;

        d = a+g*(b-a);
        fd = fun(d);

    end
end

xmin = (a+b)/2;

end


function [x2,y2] = remove_close(x,y,mode)

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

    if x(i)-x2(end)<2

        if (mode==1 && y(i)>y2(end)) || ...
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
%              本地函数3：多光束模型反演折射率
%% =========================================================

function model = multibeam_model(ext)

% 峰和谷反射率由百分数转换为0~1
px = ext.peak_sigma(:);
py = ext.peak_R(:)/100;

vx = ext.valley_sigma(:);
vy = ext.valley_R(:)/100;

% 上、下包络都存在的共同波段
lo = max(min(px),min(vx));
hi = min(max(px),max(vx));

sigma = linspace(lo,hi,3000)';

% 构造上下包络线
Rmax = interp1(...
    px,py,sigma,'pchip');

Rmin = interp1(...
    vx,vy,sigma,'pchip');

% 数值范围限制
Rmax = min(max(Rmax,0),0.999999);
Rmin = min(max(Rmin,0),0.999999);

% 多光束公式中的 C、D
C = sqrt(Rmax);
D = sqrt(Rmin);

% 公共根式
q = sqrt(...
    max(...
    (1-C.^2).*(1-D.^2),...
    0));

% 反演 A
A = ...
    (1+C.*D-q) ./ ...
    (C+D);

% 反演 B
denB = C-D;

denB(abs(denB)<1e-10) = NaN;

B = ...
    (1-C.*D-q) ./ ...
    denB;

% 限制在物理合理范围
A = min(max(A,0),0.999999);
B = min(max(B,0),0.999999);

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
%                 本地函数4：厚度计算
%% =========================================================

function res = calc_thickness(...
    ext,model,alpha,sigma_min,sigma_max)

% 只保留指定波段内的峰和谷
p_id = ...
    ext.peak_sigma>=sigma_min & ...
    ext.peak_sigma<=sigma_max;

v_id = ...
    ext.valley_sigma>=sigma_min & ...
    ext.valley_sigma<=sigma_max;

sigma = [...
    ext.peak_sigma(p_id);...
    ext.valley_sigma(v_id)];

% 峰记为1，谷记为-1
type = [...
    ones(sum(p_id),1);...
    -ones(sum(v_id),1)];

R = [...
    ext.peak_R(p_id);...
    ext.valley_R(v_id)];

% 按波数排序
[sigma,id] = sort(sigma);

type = type(id);
R = R(id);

% 保证峰谷交替
[sigma,type,R] = keep_alternating(...
    sigma,type,R);

% 只保留折射率曲线有效范围
valid = ...
    sigma>=model.sigma(1) & ...
    sigma<=model.sigma(end);

sigma = sigma(valid);
type = type(valid);
R = R(valid);

% 在每个极值位置获得对应折射率
n = interp1(...
    model.sigma,...
    model.n,...
    sigma,...
    'pchip');

%% 构造所有 N>=1 的组合

d = [];
N_list = [];

s1_list = [];
s2_list = [];

n1_list = [];
n2_list = [];

for i = 1:length(sigma)-2

    % j=i+1时 N=0.5，这里主动舍弃
    for j = i+2:length(sigma)

        N = (j-i)/2;

        % 相位项：
        % sigma*sqrt(n^2-sin^2(alpha))
        g1 = ...
            sigma(i) * ...
            sqrt(...
            n(i)^2-sind(alpha)^2);

        g2 = ...
            sigma(j) * ...
            sqrt(...
            n(j)^2-sind(alpha)^2);

        den = ...
            2*(g2-g1);

        if den>0

            % 波数为 cm^-1，
            % 因此计算得到 cm 后乘1e4转换为um
            dij = ...
                N/den*1e4;

            if isfinite(dij) && dij>0

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
    error('没有得到有效厚度组合，请检查峰谷识别参数。');
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

% 厚度统计
res.mean_d = mean(d);
res.std_d = std(d);
res.median_d = median(d);

res.cv = ...
    res.std_d / ...
    res.mean_d * 100;

end


function [x2,t2,y2] = keep_alternating(x,t,y)

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

    if t(i)~=t2(end)

        x2(end+1,1) = x(i);
        t2(end+1,1) = t(i);
        y2(end+1,1) = y(i);

    else

        if t(i)==1

            % 连续两个峰时保留更高者
            if y(i)>y2(end)

                x2(end) = x(i);
                y2(end) = y(i);

            end

        else

            % 连续两个谷时保留更低者
            if y(i)<y2(end)

                x2(end) = x(i);
                y2(end) = y(i);

            end

        end
    end
end

end
