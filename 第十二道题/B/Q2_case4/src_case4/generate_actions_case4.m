function actions = generate_actions_case4(region, weatherID, data)
%GENERATE_ACTIONS_CASE4 生成第四关某区域、某天气下的可选行动

if region == data.endRegion
    actions = struct( ...
        'type', {}, ...
        'nextRegion', {}, ...
        'pairUse', {}, ...
        'reward', {}, ...
        'code', {});
    return;
end

actions = struct( ...
    'type', {}, ...
    'nextRegion', {}, ...
    'pairUse', {}, ...
    'reward', {}, ...
    'code', {});

% 普通停留
n = 1;
actions(n).type = "停留";
actions(n).nextRegion = region;
actions(n).pairUse = data.pairUse(weatherID, 1);
actions(n).reward = 0;
actions(n).code = uint8(1);

% 位于矿山且当天原地停留时可挖矿
if ismember(region, data.mineRegions)
    n = numel(actions) + 1;
    actions(n).type = "挖矿";
    actions(n).nextRegion = region;
    actions(n).pairUse = data.pairUse(weatherID, 3);
    actions(n).reward = data.mineIncome;
    actions(n).code = uint8(2);
end

% 高温日可向相邻区域移动；沙暴日必须原地停留
if weatherID == data.robustHighID
    nextRegions = data.neighbors{region};

    for k = 1:numel(nextRegions)
        j = nextRegions(k);

        n = numel(actions) + 1;
        actions(n).type = "行走";
        actions(n).nextRegion = j;
        actions(n).pairUse = data.pairUse(weatherID, 2);
        actions(n).reward = 0;

        % 3~27分别表示移动到1~25号区域
        actions(n).code = uint8(j + 2);
    end
end

end
