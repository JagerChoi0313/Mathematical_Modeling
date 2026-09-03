function model = fit_response_surface_q2_v2( ...
    Z, D, ZM, y, responseName, includeMassControl, factorNames)
%FIT_RESPONSE_SURFACE_Q2
% 多元二次响应面模型求解。
%
% 核心连续因素：
%   z1 = Co负载量
%   z2 = CoSiO2-HAP装料比例
%   z3 = 乙醇浓度
%   z4 = 温度
%
% 控制变量：
%   D       = 装料方式虚拟变量（A=0,B=1）
%   M_total = 标准化总装料量（仅敏感性控制模型）
%
% 完整候选模型：
% Y = b0 + sum(bi*zi) + sum(bii*zi^2)
%     + sum(bij*zi*zj) + gamma*D [+ delta*M_total] + e
%
% 主要处理：
% 1. 保护四个核心主效应和控制变量；
% 2. 自动识别设计矩阵中不可独立估计的高阶项；
% 3. 对二次项、交互项进行层级约简；
% 4. 评价R2、Adjusted R2、RMSE、LOOCV-RMSE、残差和VIF；
% 5. 用“删除某因素全部相关项后的SSE增量”评价因素综合影响；
% 6. 计算响应面对各因素的边际影响。

y = y(:);
D = D(:);
ZM = ZM(:);

assert(size(Z,2)==4, 'Z必须包含4个标准化核心因素。');
assert(size(Z,1)==numel(y), 'Z与响应变量样本数不一致。');

%% Step A  构造候选项
terms = make_terms(includeMassControl);
Xall = build_design(Z, D, ZM, terms);

% 强制保留：
% 截距、四个核心一次项、D，以及可选M_total。
mandatory = false(1,numel(terms));
for i = 1:numel(terms)
    mandatory(i) = any(strcmp(terms(i).type, ...
        {'intercept','main','controlD','controlM'}));
end
mandatoryCols = find(mandatory);

%% Step B  处理设计矩阵秩亏
% 只允许从高阶候选项中删除不可独立估计列，
% 绝不牺牲四个核心主效应。
[startCols, aliasDropped] = ...
    select_estimable_terms(Xall, terms, mandatoryCols);

%% Step C  层级约简
% 高阶项若p>=0.10，并且删除后：
%   LOOCV-RMSE不恶化超过2%
%   Adjusted R2下降不超过0.01
% 则删除。
%
% 四个核心主效应和控制项始终保留。
[selectedCols, finalFit, historyTable] = ...
    hierarchical_reduce(Xall, terms, startCols, y);

%% Step D  系数表、方程及因素影响度
coefTable = make_coefficient_table( ...
    terms, selectedCols, finalFit, factorNames);

importanceTable = factor_importance( ...
    Xall, Z, terms, selectedCols, y, finalFit, factorNames);

equation = equation_string(terms, selectedCols, finalFit.b);

%% Step E  输出结构体
model.responseName = string(responseName);
model.includeMassControl = includeMassControl;
model.terms = terms;
model.Xall = Xall;
model.selectedCols = selectedCols;
model.fit = finalFit;
model.coefTable = coefTable;
model.importanceTable = importanceTable;
model.equation = equation;
model.aliasDropped = aliasDropped;
model.historyTable = historyTable;

model.stats.N = numel(y);
model.stats.NumParameters = numel(selectedCols);
model.stats.R2 = finalFit.R2;
model.stats.AdjR2 = finalFit.AdjR2;
model.stats.RMSE = finalFit.RMSE;
model.stats.LOOCV_RMSE = finalFit.LOOCV_RMSE;
model.stats.SSE = finalFit.SSE;
model.stats.ModelF = finalFit.ModelF;
model.stats.ModelPValue = finalFit.ModelPValue;
model.stats.MaxAbsStdResidual = finalFit.MaxAbsStdResidual;
model.stats.MaxVIF = finalFit.MaxVIF;
end

%% ========================================================================
function terms = make_terms(includeMassControl)
    terms = struct('name',{},'type',{},'factors',{});

    terms(end+1) = new_term("Intercept","intercept",[]);

    for j = 1:4
        terms(end+1) = new_term("z"+j,"main",j);
    end

    for j = 1:4
        terms(end+1) = new_term("z"+j+"^2","square",j);
    end

    for i = 1:4
        for j = i+1:4
            terms(end+1) = new_term( ...
                "z"+i+"*z"+j,"interaction",[i j]);
        end
    end

    terms(end+1) = new_term("D","controlD",[]);

    if includeMassControl
        terms(end+1) = new_term("M_total","controlM",[]);
    end
end

function t = new_term(name,type,factors)
    t.name = string(name);
    t.type = char(type);
    t.factors = factors;
end

%% ========================================================================
function X = build_design(Z,D,ZM,terms)
    n = size(Z,1);
    X = zeros(n,numel(terms));

    for k = 1:numel(terms)
        typ = terms(k).type;
        f = terms(k).factors;

        switch typ
            case 'intercept'
                X(:,k) = 1;

            case 'main'
                X(:,k) = Z(:,f(1));

            case 'square'
                X(:,k) = Z(:,f(1)).^2;

            case 'interaction'
                X(:,k) = Z(:,f(1)).*Z(:,f(2));

            case 'controlD'
                X(:,k) = D;

            case 'controlM'
                X(:,k) = ZM;

            otherwise
                error('未知模型项类型：%s',typ);
        end
    end
end

%% ========================================================================
function [selectedCols, aliasDropped] = ...
    select_estimable_terms(Xall,terms,mandatoryCols)
%SELECT_ESTIMABLE_TERMS
% 从“必须保留项”开始逐列加入高阶候选项。
% 只有当加入新列后设计矩阵秩增加时才保留该项，
% 否则说明该项可由已有列线性表示，记为不可独立估计项。
%
% 这种逐列秩检验比依赖QR置换索引更稳健，尤其适用于本题这种
% 非标准响应面试验设计。

    allCols = 1:size(Xall,2);
    candidateCols = setdiff(allCols,mandatoryCols,'stable');

    % 必须保留项：
    % Intercept + z1~z4 + D [+ M_total]
    selectedCols = mandatoryCols(:)';

    Xsel = Xall(:,selectedCols);
    r0 = rank(Xsel);

    assert(r0 == numel(selectedCols), ...
        ['核心主效应/控制变量本身存在完全共线。', ...
         '请检查数据提取或变量定义。']);

    aliasDropped = strings(0,1);

    % 依次尝试加入二次项与交互项
    for kk = 1:numel(candidateCols)
        c = candidateCols(kk);

        testCols = [selectedCols, c];
        Xtest = Xall(:,testCols);

        if rank(Xtest) == numel(testCols)
            selectedCols = testCols;
        else
            aliasDropped(end+1,1) = terms(c).name; %#ok<AGROW>
        end
    end

    % 最终安全检查：
    % 理论上上面的逐列检验已经保证满秩。
    % 为防止浮点精度使最终rank判定发生变化，再做一次冗余列清理。
    while rank(Xall(:,selectedCols)) < numel(selectedCols)

        currentRank = rank(Xall(:,selectedCols));
        removablePos = [];

        % 只能删高阶项，不能删Intercept、主效应和控制项
        for pos = numel(selectedCols):-1:1
            c = selectedCols(pos);
            typ = terms(c).type;

            if any(strcmp(typ,{'square','interaction'}))
                testCols = selectedCols;
                testCols(pos) = [];

                % 如果删除此列并不降低秩，则此列是冗余列
                if rank(Xall(:,testCols)) == currentRank
                    removablePos = pos;
                    break;
                end
            end
        end

        if isempty(removablePos)
            error(['设计矩阵仍然秩亏，但已找不到可删除的高阶冗余项。', ...
                   '请检查核心因素之间是否存在完全共线。']);
        end

        c = selectedCols(removablePos);
        aliasDropped(end+1,1) = terms(c).name; %#ok<AGROW>
        selectedCols(removablePos) = [];
    end

    % 去重，保持记录整洁
    aliasDropped = unique(aliasDropped,'stable');

    fprintf('  候选设计矩阵：%d列，满秩可估计项：%d列。\n', ...
        size(Xall,2), numel(selectedCols));

    if isempty(aliasDropped)
        fprintf('  未发现不可独立估计的高阶项。\n');
    else
        fprintf('  自动删除不可独立估计项：%s\n', ...
            strjoin(cellstr(aliasDropped), ', '));
    end
end

%% ========================================================================
function [cols, fitFinal, historyTable] = ...
    hierarchical_reduce(Xall,terms,startCols,y)

    cols = startCols(:)';
    removedTerm = strings(0,1);
    pBefore = zeros(0,1);
    cvBefore = zeros(0,1);
    cvAfter = zeros(0,1);
    adjAfter = zeros(0,1);

    while true
        currentFit = fit_ols(Xall(:,cols),y);

        % 只对二次项和交互项做删除。
        % 四个主效应、D及M_total（若存在）始终保留，
        % 以保证问题二的因素解释完整。
        candidatePos = [];
        candidateP = [];

        for pos = 1:numel(cols)
            termType = terms(cols(pos)).type;

            if any(strcmp(termType,{'square','interaction'}))
                if currentFit.pValue(pos) >= 0.10
                    candidatePos(end+1) = pos; %#ok<AGROW>
                    candidateP(end+1) = currentFit.pValue(pos); %#ok<AGROW>
                end
            end
        end

        if isempty(candidatePos)
            break;
        end

        % 优先尝试删除p值最大的高阶项
        [~,order] = sort(candidateP,'descend');
        deleted = false;

        for ii = 1:numel(order)
            pos = candidatePos(order(ii));
            termCol = cols(pos);

            reducedCols = cols;
            reducedCols(pos) = [];

            reducedFit = fit_ols(Xall(:,reducedCols),y);

            cvOK = reducedFit.LOOCV_RMSE <= ...
                1.02*currentFit.LOOCV_RMSE;

            adjOK = reducedFit.AdjR2 >= ...
                currentFit.AdjR2 - 0.01;

            if cvOK && adjOK
                removedTerm(end+1,1) = terms(termCol).name; %#ok<AGROW>
                pBefore(end+1,1) = currentFit.pValue(pos); %#ok<AGROW>
                cvBefore(end+1,1) = currentFit.LOOCV_RMSE; %#ok<AGROW>
                cvAfter(end+1,1) = reducedFit.LOOCV_RMSE; %#ok<AGROW>
                adjAfter(end+1,1) = reducedFit.AdjR2; %#ok<AGROW>

                cols = reducedCols;
                deleted = true;
                break;
            end
        end

        if ~deleted
            break;
        end
    end

    fitFinal = fit_ols(Xall(:,cols),y);

    historyTable = table( ...
        removedTerm,pBefore,cvBefore,cvAfter,adjAfter, ...
        'VariableNames', ...
        {'RemovedTerm','PValueBefore','LOOCV_Before', ...
         'LOOCV_After','AdjR2_After'});
end

%% ========================================================================
function fit = fit_ols(X,y)
    y = y(:);
    [n,p] = size(X);

    assert(rank(X)==p, ...
        '进入OLS求解的设计矩阵不是满列秩，请检查不可估计项筛选。');

    b = X\y;
    yhat = X*b;
    e = y-yhat;

    SSE = sum(e.^2);
    SST = sum((y-mean(y)).^2);

    if SST > 0
        R2 = 1-SSE/SST;
    else
        R2 = NaN;
    end

    if n > p
        AdjR2 = 1-(1-R2)*(n-1)/(n-p);
        MSE = SSE/(n-p);
    else
        AdjR2 = NaN;
        MSE = NaN;
    end

    RMSE = sqrt(mean(e.^2));

    % 协方差、系数t检验
    XtXInv = pinv(X'*X);
    covB = MSE*XtXInv;
    SE = sqrt(max(diag(covB),0));

    tStat = b./SE;
    pValue = zeros(size(tStat));

    df = n-p;
    for i = 1:numel(tStat)
        pValue(i) = t_two_sided_p(abs(tStat(i)),df);
    end

    % 杠杆值、标准化残差、PRESS/LOOCV
    H = X*XtXInv*X';
    h = diag(H);

    denom = sqrt(MSE).*sqrt(max(1-h,eps));
    stdResidual = e./denom;

    % 线性回归中LOOCV预测残差可用PRESS残差精确计算
    pressResidual = e./max(1-h,1e-10);
    LOOCV_RMSE = sqrt(mean(pressResidual.^2));

    % 整体F检验
    if p > 1 && n > p
        ModelF = ((SST-SSE)/(p-1))/(SSE/(n-p));
        ModelPValue = 1-f_cdf(ModelF,p-1,n-p);
    else
        ModelF = NaN;
        ModelPValue = NaN;
    end

    % VIF（去除截距后逐列计算）
    vif = compute_vif(X);
    if isempty(vif)
        MaxVIF = NaN;
    else
        MaxVIF = max(vif(isfinite(vif)));
        if isempty(MaxVIF), MaxVIF = NaN; end
    end

    fit.b = b;
    fit.SE = SE;
    fit.tStat = tStat;
    fit.pValue = pValue;
    fit.yhat = yhat;
    fit.residual = e;
    fit.stdResidual = stdResidual;
    fit.SSE = SSE;
    fit.R2 = R2;
    fit.AdjR2 = AdjR2;
    fit.RMSE = RMSE;
    fit.LOOCV_RMSE = LOOCV_RMSE;
    fit.ModelF = ModelF;
    fit.ModelPValue = ModelPValue;
    fit.MaxAbsStdResidual = max(abs(stdResidual));
    fit.VIF = vif;
    fit.MaxVIF = MaxVIF;
end

%% ========================================================================
function vif = compute_vif(X)
    % 假定第1列为截距
    if size(X,2) <= 2
        vif = [];
        return;
    end

    p = size(X,2);
    vif = nan(p,1);
    vif(1) = NaN;

    for j = 2:p
        xj = X(:,j);
        others = setdiff(1:p,j);
        Xo = X(:,others);

        bhat = Xo\xj;
        pred = Xo*bhat;

        SSEj = sum((xj-pred).^2);
        SSTj = sum((xj-mean(xj)).^2);

        if SSTj <= eps
            vif(j) = NaN;
        else
            R2j = 1-SSEj/SSTj;
            vif(j) = 1/max(1-R2j,1e-12);
        end
    end
end

%% ========================================================================
function tbl = make_coefficient_table(terms,cols,fit,factorNames)
    m = numel(cols);

    Term = strings(m,1);
    Meaning = strings(m,1);

    for i = 1:m
        Term(i) = terms(cols(i)).name;
        Meaning(i) = term_meaning(terms(cols(i)),factorNames);
    end

    Coefficient = fit.b;
    StdError = fit.SE;
    TStatistic = fit.tStat;
    PValue = fit.pValue;

    VIF = nan(m,1);
    if numel(fit.VIF)==m
        VIF = fit.VIF;
    end

    Significant_005 = PValue < 0.05;

    tbl = table(Term,Meaning,Coefficient,StdError, ...
        TStatistic,PValue,VIF,Significant_005);
end

function s = term_meaning(term,factorNames)
    switch term.type
        case 'intercept'
            s = "截距";

        case 'main'
            s = factorNames(term.factors(1))+"主效应";

        case 'square'
            s = factorNames(term.factors(1))+"二次效应";

        case 'interaction'
            s = factorNames(term.factors(1))+" × "+ ...
                factorNames(term.factors(2))+"交互作用";

        case 'controlD'
            s = "装料方式控制项";

        case 'controlM'
            s = "总装料量控制项";

        otherwise
            s = "";
    end
end

%% ========================================================================
function tbl = factor_importance( ...
    Xall,Z,terms,cols,y,fullFit,factorNames)

    n = numel(y);
    pFull = numel(cols);

    Factor = factorNames(:);
    SSEIncrease = zeros(4,1);
    RelativeInfluence = zeros(4,1);
    GroupF = zeros(4,1);
    GroupPValue = ones(4,1);
    MeanMarginalEffect = zeros(4,1);
    MeanAbsMarginalEffect = zeros(4,1);
    PositivePercent = zeros(4,1);

    for j = 1:4
        relatedMask = false(size(cols));

        for pos = 1:numel(cols)
            relatedMask(pos) = any(terms(cols(pos)).factors == j);
        end

        relatedCols = cols(relatedMask);

        if isempty(relatedCols)
            SSEIncrease(j) = 0;
            GroupF(j) = 0;
            GroupPValue(j) = 1;
        else
            reducedCols = cols(~relatedMask);
            reducedFit = fit_ols(Xall(:,reducedCols),y);

            inc = max(reducedFit.SSE-fullFit.SSE,0);
            SSEIncrease(j) = inc;

            q = pFull-numel(reducedCols);

            if q > 0
                Fval = (inc/q)/(fullFit.SSE/(n-pFull));
                GroupF(j) = Fval;
                GroupPValue(j) = ...
                    1-f_cdf(Fval,q,n-pFull);
            end
        end

        % 根据响应面的偏导计算每个样本处的边际作用
        derivative = response_derivative( ...
            Z,terms,cols,fullFit.b,j);

        MeanMarginalEffect(j) = mean(derivative);
        MeanAbsMarginalEffect(j) = mean(abs(derivative));
        PositivePercent(j) = 100*mean(derivative > 0);
    end

    totalI = sum(SSEIncrease);
    if totalI > 0
        RelativeInfluence = SSEIncrease/totalI;
    else
        RelativeInfluence(:) = NaN;
    end

    % 按相对影响度从大到小生成排名
    [~,order] = sort(RelativeInfluence,'descend');
    Rank = zeros(4,1);
    for k = 1:4
        Rank(order(k)) = k;
    end

    tbl = table(Factor,SSEIncrease,RelativeInfluence,Rank, ...
        GroupF,GroupPValue,MeanMarginalEffect, ...
        MeanAbsMarginalEffect,PositivePercent);
end

%% ========================================================================
function der = response_derivative(Z,terms,cols,b,j)
    n = size(Z,1);
    der = zeros(n,1);

    for pos = 1:numel(cols)
        term = terms(cols(pos));
        beta = b(pos);

        switch term.type
            case 'main'
                if term.factors(1)==j
                    der = der + beta;
                end

            case 'square'
                if term.factors(1)==j
                    der = der + 2*beta*Z(:,j);
                end

            case 'interaction'
                if any(term.factors==j)
                    if term.factors(1)==j
                        other = term.factors(2);
                    else
                        other = term.factors(1);
                    end
                    der = der + beta*Z(:,other);
                end
        end
    end
end

%% ========================================================================
function eq = equation_string(terms,cols,b)
    eq = sprintf('Y = %.6g',b(1));

    for pos = 2:numel(cols)
        coef = b(pos);
        name = char(terms(cols(pos)).name);

        if coef >= 0
            eq = sprintf('%s + %.6g*%s',eq,abs(coef),name);
        else
            eq = sprintf('%s - %.6g*%s',eq,abs(coef),name);
        end
    end
end

%% ========================================================================
function p = t_two_sided_p(t,v)
    if ~isfinite(t) || v <= 0
        p = NaN;
        return;
    end
    x = v/(v+t^2);
    p = betainc(x,v/2,1/2);
end

function p = f_cdf(x,d1,d2)
    if x < 0
        p = 0;
        return;
    end
    q = (d1*x)/(d1*x+d2);
    p = betainc(q,d1/2,d2/2);
end
