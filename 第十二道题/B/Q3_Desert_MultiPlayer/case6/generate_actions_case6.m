function actions = generate_actions_case6(region, weatherID, data)
%GENERATE_ACTIONS_CASE6 生成某玩家在当前天气下的可选行动

actions = struct('type',{},'from',{},'to',{});

if region == data.endRegion
    actions(1).type = "terminal";
    actions(1).from = region;
    actions(1).to = region;
    return;
end

actions(1).type = "stay";
actions(1).from = region;
actions(1).to = region;

if region == data.mineRegion
    actions(end+1).type = "mine";
    actions(end).from = region;
    actions(end).to = region;
end

% 高温日可以移动；沙暴日必须停留（矿山可挖矿）
if weatherID == data.robustHighID
    for j = data.neighbors{region}
        actions(end+1).type = "move"; %#ok<AGROW>
        actions(end).from = region;
        actions(end).to = j;
    end
end
end
