function actions = generate_actions_case3(region, weatherID, data)
%GENERATE_ACTIONS_CASE3 生成给定区域和天气下允许考虑的行动

if region == data.endRegion
    actions = struct('type', {}, 'nextRegion', {}, 'multiplier', {}, ...
        'reward', {}, 'code', {});
    return;
end

actions = struct('type', {}, 'nextRegion', {}, 'multiplier', {}, ...
    'reward', {}, 'code', {});

% 普通停留
n = numel(actions) + 1;
actions(n).type = "停留";
actions(n).nextRegion = region;
actions(n).multiplier = data.stayMultiplier;
actions(n).reward = 0;
actions(n).code = uint8(1);

% 在矿山原地停留时可以挖矿
if ismember(region, data.mineRegions)
    n = numel(actions) + 1;
    actions(n).type = "挖矿";
    actions(n).nextRegion = region;
    actions(n).multiplier = data.mineMultiplier;
    actions(n).reward = data.mineIncome;
    actions(n).code = uint8(2);
end

% 沙暴日不能跨区域行走
if weatherID ~= 3
    nextRegions = data.neighbors{region};
    for k = 1:numel(nextRegions)
        j = nextRegions(k);
        n = numel(actions) + 1;
        actions(n).type = "行走";
        actions(n).nextRegion = j;
        actions(n).multiplier = data.moveMultiplier;
        % 3~15分别表示移动至1~13号区域
        actions(n).reward = 0;
        actions(n).code = uint8(j + 2);
    end
end
end
