function gameResult = solve_game(data)
%SOLVE_GAME 依次更新各玩家最优响应，寻找稳定策略

n = data.numPlayers;
template = strategy_template(data);
emptyProfile = repmat(template, 1, n);

fprintf('正在生成初始可行策略...\n');
base = best_response(1, emptyProfile, data);
base = standardize_strategy(base, data);
if ~base.feasible
    error('未找到初始可行策略。请核对地图邻接和题目参数。');
end

strategies = repmat(base, 1, n);
for p = 1:n
    strategies(p).playerID = p;
    strategies(p).signature = replace_player_id(base.signature, p);
end

history = zeros(0, n);
signatureHistory = strings(0,1);
signatureHistory(end+1) = joint_signature(strategies);
converged = false;
cycleDetected = false;

for iter = 1:data.algorithm.maxGameIterations
    fprintf('\n第%d轮最优响应：\n', iter);
    old = strategies;

    for p = 1:n
        fprintf('  玩家%d/%d...\n', p, n);
        S = best_response(p, strategies, data);
        S = standardize_strategy(S, data);
        if S.feasible
            strategies(p) = S;
        else
            fprintf('    未找到更换后的可行策略，保留上一策略。\n');
        end
    end

    wealth = [strategies.finalWealth];
    history(end+1,:) = wealth; %#ok<AGROW>
    fprintf('  本轮资金：');
    for p=1:n, fprintf('P%d %.2f  ', p, wealth(p)); end
    fprintf('\n');

    same = true;
    for p=1:n
        if ~strcmp(old(p).signature, strategies(p).signature)
            same = false; break;
        end
    end
    if same
        converged = true;
        fprintf('所有玩家策略均未变化，停止迭代。\n');
        break;
    end

    sig = joint_signature(strategies);
    if any(signatureHistory == sig)
        cycleDetected = true;
        fprintf('检测到重复策略组合，最优响应进入循环。\n');
        break;
    end
    signatureHistory(end+1) = sig; %#ok<AGROW>
end

gameResult.strategies = strategies;
gameResult.iterationHistory = history;
gameResult.converged = converged;
gameResult.cycleDetected = cycleDetected;
gameResult.iterations = size(history,1);

if data.caseID == 6
    W = strategies(1).representativeWeather;
    if isempty(W)
        W = 2*ones(1,data.deadline);
        W(round([data.deadline/4 data.deadline/2 3*data.deadline/4])) = 3;
    end
    gameResult.representativeWeather = W;
else
    gameResult.representativeWeather = data.weather;
end
end


function s = strategy_template(data)
a.type='none'; a.from=0; a.to=0; a.buyPairs=0;
s.playerID=0; s.feasible=false; s.initialWater=0; s.initialFood=0;
s.actions=repmat(a,1,data.deadline); s.regions=zeros(1,data.deadline+1);
s.arrivalDay=inf; s.mineDays=0; s.finalWealth=-inf; s.income=0;
s.representativeWeather=[]; s.caseID=data.caseID; s.signature='EMPTY';
s.policyRoute=[]; s.mineDaysTarget=0; s.villageTargetPairs=0;
end

function s = standardize_strategy(s, data)
t = strategy_template(data);
fn = fieldnames(t);
for i=1:numel(fn)
    if ~isfield(s,fn{i}), s.(fn{i}) = t.(fn{i}); end
end
extra = setdiff(fieldnames(s),fn);
for i=1:numel(extra), s=rmfield(s,extra{i}); end
s=orderfields(s,t);
end

function sig = joint_signature(strategies)
p=strings(1,numel(strategies));
for i=1:numel(strategies), p(i)=strategies(i).signature; end
sig=strjoin(p,'||');
end

function sig = replace_player_id(sig,p)
% 仅用于初始复制；不影响策略内容。
sig=sprintf('P%d|%s',p,sig);
end
