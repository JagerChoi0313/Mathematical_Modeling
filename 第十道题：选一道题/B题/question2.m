clear; clc; close all;

sigma_min = 1500;
sigma_max = 4000;
smooth_window = 61;
sgolay_order = 3;
min_peak_distance = 180;
min_peak_prominence = 0.25;

data1 = readmatrix('附件1.xlsx');
data2 = readmatrix('附件2.xlsx');

[sigma1,R1] = clean_data(data1);
[sigma2,R2] = clean_data(data2);

id1 = sigma1 >= sigma_min & sigma1 <= sigma_max;
id2 = sigma2 >= sigma_min & sigma2 <= sigma_max;

s1 = sigma1(id1);
r1 = R1(id1);
s2 = sigma2(id2);
r2 = R2(id2);

rs1 = my_sgolay(r1,smooth_window,sgolay_order);
rs2 = my_sgolay(r2,smooth_window,sgolay_order);

[~,peak1] = my_findpeaks(s1,rs1,min_peak_distance,min_peak_prominence);
[~,valley1] = my_findpeaks(s1,-rs1,min_peak_distance,min_peak_prominence);

[~,peak2] = my_findpeaks(s2,rs2,min_peak_distance,min_peak_prominence);
[~,valley2] = my_findpeaks(s2,-rs2,min_peak_distance,min_peak_prominence);

[dp10,Rp10] = period_fit(peak1);
[dv10,Rv10] = period_fit(valley1);
[dp15,Rp15] = period_fit(peak2);
[dv15,Rv15] = period_fit(valley2);

[d10,R10] = common_period_fit(peak1,valley1);
[d15,R15] = common_period_fit(peak2,valley2);

n = inverse_n(d10,d15);

h10 = thickness_period(d10,n,10);
h15 = thickness_period(d15,n,15);
h = (h10+h15)/2;

n_peak = inverse_n(dp10,dp15);
h_peak = thickness_period(dp10,n_peak,10);

n_valley = inverse_n(dv10,dv15);
h_valley = thickness_period(dv10,n_valley,10);

Np10 = length(peak1)-1;
Nv10 = length(valley1)-1;
Np15 = length(peak2)-1;
Nv15 = length(valley2)-1;

hNp10 = thickness_N(Np10,peak1(1),peak1(end),n,10);
hNv10 = thickness_N(Nv10,valley1(1),valley1(end),n,10);
hNp15 = thickness_N(Np15,peak2(1),peak2(end),n,15);
hNv15 = thickness_N(Nv15,valley2(1),valley2(end),n,15);

he_p10 = thickness_period(diff(peak1),n,10);
he_v10 = thickness_period(diff(valley1),n,10);
he_p15 = thickness_period(diff(peak2),n,15);
he_v15 = thickness_period(diff(valley2),n,15);

all_h = [he_p10(:);he_v10(:);he_p15(:);he_v15(:)];

fprintf('\n========== 第二问计算结果 ==========\n');
fprintf('附件1：峰 %d 个，谷 %d 个\n',length(peak1),length(valley1));
fprintf('附件2：峰 %d 个，谷 %d 个\n',length(peak2),length(valley2));

fprintf('\n10°峰周期：%.6f cm^-1，R^2=%.8f\n',dp10,Rp10);
fprintf('10°谷周期：%.6f cm^-1，R^2=%.8f\n',dv10,Rv10);
fprintf('10°共同周期：%.6f cm^-1，R^2=%.8f\n',d10,R10);

fprintf('\n15°峰周期：%.6f cm^-1，R^2=%.8f\n',dp15,Rp15);
fprintf('15°谷周期：%.6f cm^-1，R^2=%.8f\n',dv15,Rv15);
fprintf('15°共同周期：%.6f cm^-1，R^2=%.8f\n',d15,R15);

fprintf('\n等效折射率 n = %.8f\n',n);
fprintf('10°厚度 d = %.8f um\n',h10);
fprintf('15°厚度 d = %.8f um\n',h15);
fprintf('最终厚度 d = %.8f um\n',h);

fprintf('\n仅峰反演：n=%.8f，d=%.8f um\n',n_peak,h_peak);
fprintf('仅谷反演：n=%.8f，d=%.8f um\n',n_valley,h_valley);

fprintf('\n跨N周期结果：\n');
fprintf('10°峰：%.8f um\n',hNp10);
fprintf('10°谷：%.8f um\n',hNv10);
fprintf('15°峰：%.8f um\n',hNp15);
fprintf('15°谷：%.8f um\n',hNv15);

fprintf('\n逐周期统计：\n');
show_stat('10°峰',he_p10);
show_stat('10°谷',he_v10);
show_stat('15°峰',he_p15);
show_stat('15°谷',he_v15);
show_stat('全部',all_h);

den = d10^2-d15^2;
if abs(den)/((d10^2+d15^2)/2) < 0.02
    fprintf('\n提示：两组条纹周期较接近，折射率反演对周期误差较敏感。\n');
end


function [sigma,R] = clean_data(data)
sigma = data(:,1);
R = data(:,2);

id = isfinite(sigma) & isfinite(R);
sigma = sigma(id);
R = R(id);

if ~isempty(R) && R(1)==0
    sigma(1) = [];
    R(1) = [];
end

[sigma,id] = sort(sigma);
R = R(id);
end


function y2 = my_sgolay(y,window,order)
y = y(:);
m = (window-1)/2;
x = (-m:m)';

A = zeros(window,order+1);
for k = 0:order
    A(:,k+1) = x.^k;
end

G = (A'*A)\A';
h = G(1,:);

left = flipud(y(2:m+1));
right = flipud(y(end-m:end-1));
y2 = conv([left;y;right],h,'valid');
end


function [py,px] = my_findpeaks(x,y,min_distance,min_prominence)
x = x(:);
y = y(:);

cand = find(y(2:end-1)>y(1:end-2) & y(2:end-1)>=y(3:end))+1;

if isempty(cand)
    py = [];
    px = [];
    return
end

dx = median(diff(x));
w = max(round(min_distance/dx),1);
prom = zeros(size(cand));

for i = 1:length(cand)
    k = cand(i);
    a = max(1,k-w);
    b = min(length(y),k+w);
    base = max(min(y(a:k)),min(y(k:b)));
    prom(i) = y(k)-base;
end

id = prom >= min_prominence;
cand = cand(id);
prom = prom(id);

if isempty(cand)
    py = [];
    px = [];
    return
end

selected = cand(1);
selprom = prom(1);

for i = 2:length(cand)
    k = cand(i);
    if x(k)-x(selected(end)) >= min_distance
        selected(end+1,1) = k;
        selprom(end+1,1) = prom(i);
    elseif prom(i) > selprom(end)
        selected(end) = k;
        selprom(end) = prom(i);
    end
end

px = x(selected);
py = y(selected);
end


function [delta,R2] = period_fit(s)
s = s(:);
k = (0:length(s)-1)';
p = polyfit(k,s,1);
delta = p(1);

sf = polyval(p,k);
SSE = sum((s-sf).^2);
SST = sum((s-mean(s)).^2);
R2 = 1-SSE/SST;
end


function [delta,R2] = common_period_fit(peak,valley)
peak = peak(:);
valley = valley(:);

kp = (0:length(peak)-1)';
kv = (0:length(valley)-1)';

A1 = [kp,ones(length(kp),1),zeros(length(kp),1)];
A2 = [kv,zeros(length(kv),1),ones(length(kv),1)];

A = [A1;A2];
y = [peak;valley];

b = A\y;
delta = b(1);

yf = A*b;
SSE = sum((y-yf).^2);
SST = sum((y-mean(y)).^2);
R2 = 1-SSE/SST;
end


function n = inverse_n(d10,d15)
num = d10^2*sind(10)^2-d15^2*sind(15)^2;
den = d10^2-d15^2;

if abs(den)<1e-12
    error('两组周期过于接近，无法反演折射率。');
end

v = num/den;
if v<=0
    error('折射率反演结果异常。');
end

n = sqrt(v);
end


function d = thickness_period(delta,n,alpha)
v = n^2-sind(alpha)^2;

if v<=0
    error('厚度计算参数异常。');
end

d = 1./(2*sqrt(v).*delta)*1e4;
end


function d = thickness_N(N,s1,s2,n,alpha)
v = n^2-sind(alpha)^2;
d = N/(2*sqrt(v)*(s2-s1))*1e4;
end


function show_stat(name,d)
d = d(:);
m = mean(d);
s = std(d);
cv = s/m*100;

fprintf('%s：均值 %.6f um，标准差 %.6f um，CV %.4f%%\n',...
    name,m,s,cv);
end
