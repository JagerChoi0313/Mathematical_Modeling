function check_solution(result, data)
%CHECK_SOLUTION 对输出结果进行基本规则复核

tol = 1e-6;

if isfield(result, 'dailyTables')
    dailyTables = result.dailyTables;
else
    return;
end

for p = 1:numel(dailyTables)
    T = dailyTables{p};

    if isempty(T)
        error('玩家 %d 没有日结果。', p);
    end

    if any(T.WaterLeft < -tol) || any(T.FoodLeft < -tol)
        error('玩家 %d 出现负资源。', p);
    end

    if any(T.CashLeft < -tol)
        error('玩家 %d 出现负现金。', p);
    end

    if any(3*T.WaterLeft + 2*T.FoodLeft > data.maxLoad + tol)
        error('玩家 %d 出现超重。', p);
    end

    lastRegion = T.EndRegion(end);
    if lastRegion ~= data.endRegion
        error('玩家 %d 未到达终点。', p);
    end
end

fprintf('规则复核：通过。\n');
end
