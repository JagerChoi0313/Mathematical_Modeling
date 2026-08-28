%% ========================================================================
%  问题1：农作物种植策略 —— 混合整数线性规划（MILP）求解代码
%  ------------------------------------------------------------------------
%  对应模型文档《问题1_MILP模型.md》中的目标函数与约束(1)~(8)。
%
%  【重要说明——请务必先读】
%  1. 【已接入真实数据】第1节现在从《真实数据_C题问题1.xlsx》读取
%     附件1、附件2整理后的真实数据：54个地块、41种作物、2024~2030共7年、
%     2季。该Excel文件需与本 .m 文件放在同一目录下。
%     （此前用5地块6作物3年的合成数据跑通过一遍逻辑，这一版是正式规模。）
%  2. 需要 MATLAB 的 Optimization Toolbox（用到 intlinprog 函数）、
%     以及能读取Excel的环境（readtable 依赖）。
%  3. 真实规模下0-1变量数量达到3万+级别，求解可能需要几分钟，请耐心等待
%     （第6节已经加了 MaxTime 限制和相关说明）。
%  4. 本代码未在真实MATLAB环境中运行验证（当前环境不含MATLAB），
%     逻辑已仔细检查，也已用小规模数据验证过整体框架能正确求解，
%     但换成真实数据规模后，如果运行报错或结果异常，请把信息发给我一起调试
%     ——这是完全正常的调试过程，数据规模变大后出现新的边界情况很常见。
%% ========================================================================

clear; clc; close all;

%% ------------------ 0. 全局参数 ------------------
gamma = 0;      % 超产处理系数：情况(1)取0（滞销浪费），情况(2)取0.5（降价出售）
                % 想求情况(2)，把这一行改成 gamma = 0.5; 其余代码完全不用动

%% ------------------ 1. 数据准备（真实数据：附件1、附件2整理版） ------------------
% 数据来源：真实数据_C题问题1.xlsx（5张表：Plots/Crops/TypeParams/Demand/Rules）
% 该文件已根据附件1（地块、作物适种规则）和附件2（2023年种植及统计数据）整理生成，
% 请将该Excel文件与本 .m 文件放在同一目录下。
dataFile = '真实数据_C题问题1.xlsx';

% ---- 1.1 地块信息 ----
plotsTbl  = readtable(dataFile, 'Sheet','Plots');
nI        = height(plotsTbl);
plotArea  = plotsTbl.Area_mu';              % 各地块面积（亩），1×54
plotTypeStr = plotsTbl.Type;                 % 各地块类型（字符串，元胞数组）
waterPlots  = find(strcmp(plotTypeStr, '水浇地'));   % 水浇地地块编号（互斥约束用）

% ---- 1.2 作物信息 ----
cropsTbl  = readtable(dataFile, 'Sheet','Crops');
nJ        = height(cropsTbl);
cropNames = cropsTbl.Name';
B         = cropsTbl.CropID(cropsTbl.IsLegume==1)';   % 豆类作物集合（粮食豆类+蔬菜豆类，共8种）
riceCrop  = 16;    % 水稻作物编号（附件1固定编号）

% ---- 1.3 年份与季次 ----
T  = num2cell(2024:2030);   % 真实题目：2024~2030，共7年
nT = numel(T);
nS = 2;                      % 季次数（1=单季/第一季，2=第二季）

% ---- 1.4 & 1.5：适种参数 a(i,j,s)、亩产量 q(i,j,s)、种植成本 c(i,j,s) ----
% TypeParams表按"地块类型-作物-季次"给出参数，同类型的所有地块共用同一组数值
% （这是真实数据的天然结构——产量成本由土地类型决定，不是由具体某块地单独决定）
typeParamsTbl = readtable(dataFile, 'Sheet','TypeParams');
a = zeros(nI,nJ,nS);  q = zeros(nI,nJ,nS);  c = zeros(nI,nJ,nS);
p = zeros(nJ,nS);                             % 销售价格：验证过真实数据中同一(作物,季次)
                                               % 在不同地块类型间价格一致，故只需 p(j,s)
for r = 1:height(typeParamsTbl)
    ltype = typeParamsTbl.LandType{r};
    cid   = typeParamsTbl.CropID(r);
    ss    = typeParamsTbl.Season(r);
    plotIdx = find(strcmp(plotTypeStr, ltype));   % 该类型对应的所有地块编号
    for ii = plotIdx'
        a(ii,cid,ss) = 1;
        q(ii,cid,ss) = typeParamsTbl.Yield_jin_per_mu(r);
        c(ii,cid,ss) = typeParamsTbl.Cost_yuan_per_mu(r);
    end
    p(cid,ss) = typeParamsTbl.PriceMid(r);   % 取价格区间中值
end

% ---- 1.6 预期销售量 D(j,s) ----
% 题目定义：预期销售量=2023年该作物全村总产量（各年不变），与季次无关，
% 故对该作物出现的每个季次都赋相同值
demandTbl = readtable(dataFile, 'Sheet','Demand');
D = zeros(nJ,nS);
for r = 1:height(demandTbl)
    cid = demandTbl.CropID(r);
    D(cid, :) = demandTbl.Demand2023_jin(r);
end

% ---- 1.7 最小管理面积 L(i,j,s)、单季最大分布地块数 K(j,s) ----
% 题目未给出具体数值，以下为建议默认值（写论文时请说明取值依据，
% 或做灵敏度分析检验结果对这两个参数是否敏感）：
L = zeros(nI,nJ,nS);
for i = 1:nI
    if plotArea(i) < 1     % 大棚类地块本身只有0.6亩，最小面积按比例调小
        Li = 0.1;
    else                    % 露天地块（平旱地/梯田/山坡地/水浇地）
        Li = 1;
    end
    for j = 1:nJ
        for s = 1:nS
            if a(i,j,s) == 1
                L(i,j,s) = Li;
            end
        end
    end
end
K = 15 * ones(nJ,nS);   % 示例：每种作物每季最多分布在15块地里，可按需调整

fprintf('数据准备完成：地块数=%d，作物数=%d，年份数=%d，季次数=%d\n', nI,nJ,nT,nS);
fprintf('豆类作物集合 B 共 %d 种，水浇地共 %d 块\n', numel(B), numel(waterPlots));

%% ------------------ 2. 决策变量索引编码 ------------------
% 五类变量按顺序拼成一个长向量：[x; y; z; h; r]
nX = nI*nJ*nT*nS;   nY = nI*nJ*nT*nS;
nZ = nJ*nT*nS;       nH = nJ*nT*nS;
nR = nI*nT;
offX = 0;  offY = offX+nX;  offZ = offY+nY;  offH = offZ+nZ;  offR = offH+nH;
nVar = offR + nR;

% 索引函数（见文件末尾local function定义）：
% xidx(i,j,t,s), yidx(i,j,t,s), zidx(j,t,s), hidx(j,t,s), ridx(i,t)

fprintf('决策变量总数 = %d（其中0-1变量约 %d 个）\n', nVar, nY+nR);

%% ------------------ 3. 目标函数：max Z  ->  min (-Z) ------------------
f = zeros(nVar,1);
for j = 1:nJ
    for t = 1:nT
        for s = 1:nS
            f(zidx(j,t,s,offZ,nJ,nT)) = f(zidx(j,t,s,offZ,nJ,nT)) - p(j,s);            % -p_js * z_jts
            f(hidx(j,t,s,offH,nJ,nT)) = f(hidx(j,t,s,offH,nJ,nT)) - gamma*p(j,s);      % -gamma*p_js * h_jts
        end
    end
end
for i = 1:nI
    for j = 1:nJ
        for t = 1:nT
            for s = 1:nS
                f(xidx(i,j,t,s,offX,nI,nJ,nT)) = f(xidx(i,j,t,s,offX,nI,nJ,nT)) + c(i,j,s); % +c_ijs * x_ijts
            end
        end
    end
end

%% ------------------ 4. 变量上下界 & 整数变量声明 ------------------
lb = zeros(nVar,1);
ub = inf(nVar,1);

% x 的上界：不适种(a=0)则为0，适种则不超过地块面积
for i = 1:nI
    for j = 1:nJ
        for t = 1:nT
            for s = 1:nS
                if a(i,j,s) == 1
                    ub(xidx(i,j,t,s,offX,nI,nJ,nT)) = plotArea(i);
                else
                    ub(xidx(i,j,t,s,offX,nI,nJ,nT)) = 0;   % 约束(3) 适种性约束
                end
            end
        end
    end
end

% y 的上下界：0-1变量；不适种组合直接锁定为0
for i = 1:nI
    for j = 1:nJ
        for t = 1:nT
            for s = 1:nS
                if a(i,j,s) == 1
                    ub(yidx(i,j,t,s,offY,nI,nJ,nT)) = 1;
                else
                    ub(yidx(i,j,t,s,offY,nI,nJ,nT)) = 0;
                end
            end
        end
    end
end

% z 的上界：约束(1)中 0<=z_jts<=D_js
for j = 1:nJ
    for t = 1:nT
        for s = 1:nS
            ub(zidx(j,t,s,offZ,nJ,nT)) = D(j,s);
        end
    end
end
% h 无显式上界（由产量拆分等式自动约束），保持 inf 即可

% r 上下界：仅水浇地地块允许为0/1，其余地块直接锁定为0（不参与互斥约束）
for i = 1:nI
    for t = 1:nT
        if ismember(i, waterPlots)
            ub(ridx(i,t,offR,nI,nT)) = 1;
        else
            ub(ridx(i,t,offR,nI,nT)) = 0;
        end
    end
end

intcon = [offY+1 : offY+nY, offR+1 : offR+nR];   % y、r 为0-1变量

%% ------------------ 5. 约束条件构建（对应模型文档约束(1)~(8)） ------------------
% 使用三元组(行,列,值)方式累积，最后统一拼成稀疏矩阵，效率更高
eqI=[]; eqJ=[]; eqV=[]; beq=[]; nEq=0;   % 等式约束 Aeq*x = beq
inI=[]; inJ=[]; inV=[]; bin=[]; nIn=0;   % 不等式约束 A*x <= b

% ---- 约束(1)：产量拆分等式  sum_i q_ijs*x_ijts - z_jts - h_jts = 0 ----
for j = 1:nJ
    for t = 1:nT
        for s = 1:nS
            nEq = nEq+1;
            for i = 1:nI
                if q(i,j,s) ~= 0
                    eqI(end+1)=nEq; eqJ(end+1)=xidx(i,j,t,s,offX,nI,nJ,nT); eqV(end+1)=q(i,j,s); %#ok<*SAGROW>
                end
            end
            eqI(end+1)=nEq; eqJ(end+1)=zidx(j,t,s,offZ,nJ,nT); eqV(end+1)=-1;
            eqI(end+1)=nEq; eqJ(end+1)=hidx(j,t,s,offH,nJ,nT); eqV(end+1)=-1;
            beq(nEq,1)=0;
        end
    end
end

% ---- 约束(2)：地块面积约束  sum_j x_ijts <= A_i ----
for i = 1:nI
    for t = 1:nT
        for s = 1:nS
            nIn = nIn+1;
            for j = 1:nJ
                inI(end+1)=nIn; inJ(end+1)=xidx(i,j,t,s,offX,nI,nJ,nT); inV(end+1)=1;
            end
            bin(nIn,1)=plotArea(i);
        end
    end
end

% ---- 约束(4)：变量联动  x<=M*y  与  x>=L*y  (M直接取地块面积，更紧) ----
for i = 1:nI
    for j = 1:nJ
        if any(a(i,j,:)==1)
            for t = 1:nT
                for s = 1:nS
                    if a(i,j,s)==1
                        xi = xidx(i,j,t,s,offX,nI,nJ,nT);
                        yi = yidx(i,j,t,s,offY,nI,nJ,nT);
                        % x - A_i*y <= 0
                        nIn=nIn+1; inI(end+1)=nIn; inJ(end+1)=xi; inV(end+1)=1;
                        inI(end+1)=nIn; inJ(end+1)=yi; inV(end+1)=-plotArea(i); bin(nIn,1)=0;
                        % -x + L*y <= 0  (即 x >= L*y)
                        nIn=nIn+1; inI(end+1)=nIn; inJ(end+1)=xi; inV(end+1)=-1;
                        inI(end+1)=nIn; inJ(end+1)=yi; inV(end+1)=L(i,j,s); bin(nIn,1)=0;
                    end
                end
            end
        end
    end
end

% ---- 约束(5)：种植分散度  sum_i y_ijts <= K_js ----
for j = 1:nJ
    for t = 1:nT
        for s = 1:nS
            nIn=nIn+1;
            for i = 1:nI
                if a(i,j,s)==1
                    inI(end+1)=nIn; inJ(end+1)=yidx(i,j,t,s,offY,nI,nJ,nT); inV(end+1)=1;
                end
            end
            bin(nIn,1)=K(j,s);
        end
    end
end

% ---- 约束(6)：不能连续重茬（同一地块同一季次，相邻两年不能种同一作物） ----
for i = 1:nI
    for j = 1:nJ
        for s = 1:nS
            if a(i,j,s)==1
                for t = 1:nT-1
                    nIn=nIn+1;
                    inI(end+1)=nIn; inJ(end+1)=yidx(i,j,t,s,offY,nI,nJ,nT);   inV(end+1)=1;
                    inI(end+1)=nIn; inJ(end+1)=yidx(i,j,t+1,s,offY,nI,nJ,nT); inV(end+1)=1;
                    bin(nIn,1)=1;
                end
            end
        end
    end
end
% 注：如需同时约束"同一地块内第二季与下一年第一季"相邻重茬，
%     可仿照上面写法，把 s 换成跨季次的相邻关系再加一组约束。

% ---- 约束(7)：豆类轮作（每地块，任意连续3年内至少种一次豆类） ----
% 注意：只有当该地块确实存在"至少一种豆类作物在某季可种"时，才添加这条约束；
% 否则（比如示例数据里水浇地/大棚都没有配置豆类选项）该约束恒无法满足，
% 会导致 intlinprog 直接判定问题不可行（这正是上一次报错 Infeasible 的原因）。
for i = 1:nI
    legumeAvailable = false;
    for s = 1:nS
        for j = B
            if a(i,j,s) == 1
                legumeAvailable = true;
            end
        end
    end
    if ~legumeAvailable
        fprintf('提示：地块%d 没有可种的豆类作物选项，已跳过其豆类轮作约束。\n', i);
        continue;   % 真实数据中若出现同样情况，也应如此处理，而不是强行要求无解的约束
    end
    for t = 1:nT-2
        nIn=nIn+1;
        for tt = t:t+2
            for s = 1:nS
                for j = B
                    if a(i,j,s)==1
                        inI(end+1)=nIn; inJ(end+1)=yidx(i,j,tt,s,offY,nI,nJ,nT); inV(end+1)=-1;
                    end
                end
            end
        end
        bin(nIn,1)=-1;   % 即 sum(y) >= 1  等价于  -sum(y) <= -1
    end
end

% ---- 约束(8)：水浇地"水稻 vs 两季蔬菜"互斥 ----
for i = waterPlots
    for t = 1:nT
        % 等式：sum_{j为水稻} y_ij1t = r_it
        nEq=nEq+1;
        eqI(end+1)=nEq; eqJ(end+1)=yidx(i,riceCrop,t,1,offY,nI,nJ,nT); eqV(end+1)=1;
        eqI(end+1)=nEq; eqJ(end+1)=ridx(i,t,offR,nI,nT);                  eqV(end+1)=-1;
        beq(nEq,1)=0;
        % 不等式：sum_j y_ij2t + r_it <= 1
        nIn=nIn+1;
        for j = 1:nJ
            if a(i,j,2)==1
                inI(end+1)=nIn; inJ(end+1)=yidx(i,j,t,2,offY,nI,nJ,nT); inV(end+1)=1;
            end
        end
        inI(end+1)=nIn; inJ(end+1)=ridx(i,t,offR,nI,nT); inV(end+1)=1;
        bin(nIn,1)=1;
    end
end

Aeq = sparse(eqI, eqJ, eqV, nEq, nVar);
Ain = sparse(inI, inJ, inV, nIn, nVar);

fprintf('约束构建完成：等式约束 %d 条，不等式约束 %d 条\n', nEq, nIn);

%% ------------------ 6. 求解（调用 intlinprog） ------------------
% 注：真实规模下变量数约为演示数据的~140倍（54地块×41作物×7年×2季），
% 0-1变量数量达到3万+级别，求解时间可能明显长于演示数据（从几秒到几分钟不等，
% 取决于电脑性能）。如果长时间无响应，可以：
%   ① 把 MaxTime 适当调大；② 把 options 里的 'Display' 改成 'iter' 观察求解进度；
%   ③ 如果学校/实验室有 Gurobi 授权，可改用 gurobi() 接口通常会快很多。
options = optimoptions('intlinprog', 'Display','final', 'MaxTime', 600);
[sol, fval, exitflag, output] = intlinprog(f, intcon, Ain, bin, Aeq, beq, lb, ub, options);

if exitflag <= 0
    error('求解失败，exitflag=%d，请检查约束是否有冲突（不可行），或增大 MaxTime 再试', exitflag);
end

totalProfit = -fval;   % 还原成 max Z（之前是求 min(-Z)）
fprintf('\n========== 求解完成 ==========\n');
fprintf('%d年（2024~2030）总利润 Z = %.2f 元\n', nT, totalProfit);

%% ------------------ 7. 结果提取与整理 ------------------
X = zeros(nI,nJ,nT,nS);  Yv = zeros(nI,nJ,nT,nS);
Zv = zeros(nJ,nT,nS);    Hv = zeros(nJ,nT,nS);
for i=1:nI, for j=1:nJ, for t=1:nT, for s=1:nS
    X(i,j,t,s)  = sol(xidx(i,j,t,s,offX,nI,nJ,nT));
    Yv(i,j,t,s) = sol(yidx(i,j,t,s,offY,nI,nJ,nT));
end, end, end, end
for j=1:nJ, for t=1:nT, for s=1:nS
    Zv(j,t,s) = sol(zidx(j,t,s,offZ,nJ,nT));
    Hv(j,t,s) = sol(hidx(j,t,s,offH,nJ,nT));
end, end, end

% 每年利润（把总目标函数按年份拆开重新计算一遍，便于画图和检查）
profitByYear = zeros(nT,1);
for t = 1:nT
    rev = 0; cost = 0;
    for j=1:nJ
        for s=1:nS
            rev = rev + p(j,s)*Zv(j,t,s) + gamma*p(j,s)*Hv(j,t,s);
        end
    end
    for i=1:nI
        for j=1:nJ
            for s=1:nS
                cost = cost + c(i,j,s)*X(i,j,t,s);
            end
        end
    end
    profitByYear(t) = rev - cost;
end

% 打印非零种植方案（论文里"种植方案表"的雏形）
fprintf('\n---- 非零种植面积明细（地块-作物-年份-季次-面积） ----\n');
for i=1:nI, for j=1:nJ, for t=1:nT, for s=1:nS
    if X(i,j,t,s) > 1e-6
        fprintf('地块%d | 作物:%-4s | 年份:%d | 季次:%d | 面积:%.2f亩\n', ...
            i, cropNames{j}, T{t}, s, X(i,j,t,s));
    end
end, end, end, end

%% ------------------ 8. 绘图 ------------------
% 图1：各年利润
figure('Name','各年利润');
bar(cell2mat(T), profitByYear);
xlabel('年份'); ylabel('年利润（元）'); title('问题1：各年最优利润');
grid on;

% 图2：各年、各作物类别的种植总面积（堆积柱状图）
areaByCropYear = zeros(nT, nJ);
for t=1:nT
    for j=1:nJ
        areaByCropYear(t,j) = sum(sum(X(:,j,t,:)));
    end
end
figure('Name','各年作物种植面积构成');
bar(cell2mat(T), areaByCropYear, 'stacked');
xlabel('年份'); ylabel('种植面积（亩）');
title('问题1：各年各作物种植面积构成');
legend(cropNames, 'Location','eastoutside');
grid on;

% 图3：各作物"正常售出量 vs 超产处理量"对比（以最后一年为例）
figure('Name','产量结构（最后一年）');
tLast = nT;
soldQty = sum(Zv(:,tLast,:), 3);
excessQty = sum(Hv(:,tLast,:), 3);
bar([soldQty, excessQty], 'stacked');
set(gca,'XTickLabel',cropNames);
xlabel('作物'); ylabel('产量（斤）');
legend({'正常售出 z','超产处理 h'}, 'Location','best');
title(sprintf('问题1：%d年各作物产量结构（正常售出 vs 超产部分）', T{tLast}));
grid on;

fprintf('\n三张图已生成：①各年利润 ②各年种植面积构成 ③最后一年产量结构\n');

%% ========================================================================
%  local functions（索引编码函数，把 (i,j,t,s) 映射成变量在长向量中的位置）
%% ========================================================================
function idx = xidx(i,j,t,s,offX,nI,nJ,nT)
    idx = offX + sub2ind([nI,nJ,nT,2], i,j,t,s);
end
function idx = yidx(i,j,t,s,offY,nI,nJ,nT)
    idx = offY + sub2ind([nI,nJ,nT,2], i,j,t,s);
end
function idx = zidx(j,t,s,offZ,nJ,nT)
    idx = offZ + sub2ind([nJ,nT,2], j,t,s);
end
function idx = hidx(j,t,s,offH,nJ,nT)
    idx = offH + sub2ind([nJ,nT,2], j,t,s);
end
function idx = ridx(i,t,offR,nI,nT)
    idx = offR + sub2ind([nI, nT], i, t);
end
