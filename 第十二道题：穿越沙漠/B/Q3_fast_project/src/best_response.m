function bestStrategy = best_response(playerID, strategies, data)
%BEST_RESPONSE 第三问统一最优响应入口

if data.caseID == 5
    bestStrategy = best_response_case5(playerID, strategies, data);
else
    bestStrategy = best_response_case6_fast(playerID, strategies, data);
end
end
