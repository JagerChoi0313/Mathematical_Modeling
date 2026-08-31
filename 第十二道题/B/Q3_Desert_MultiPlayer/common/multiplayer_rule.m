function rule = multiplayer_rule(actionType, groupSize, data)
%MULTIPLAYER_RULE 返回题目给定的多人作用规则
%
% 同一有向边同时行走 k 人：每人消耗倍率为 2k；
% 同一矿山同时挖矿 k 人：每人消耗倍率为 3，收益为基础收益/k；
% 同一村庄同日购买 k>=2 人：购买价格为基准价格4倍。

switch string(actionType)
    case "move"
        rule.resourceMultiplier = 2 * groupSize;
        rule.income = 0;
        rule.villagePriceMultiplier = NaN;

    case "mine"
        rule.resourceMultiplier = 3;
        rule.income = data.baseIncome / groupSize;
        rule.villagePriceMultiplier = NaN;

    case "buy"
        rule.resourceMultiplier = 0;
        rule.income = 0;
        if groupSize >= 2
            rule.villagePriceMultiplier = 4;
        else
            rule.villagePriceMultiplier = 2;
        end

    otherwise
        rule.resourceMultiplier = 1;
        rule.income = 0;
        rule.villagePriceMultiplier = NaN;
end
end
