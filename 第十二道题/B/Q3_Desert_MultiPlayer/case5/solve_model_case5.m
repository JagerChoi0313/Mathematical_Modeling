function solution = solve_model_case5(model, data)
%SOLVE_MODEL_CASE5 调用intlinprog求解第五关MILP

opts = optimoptions('intlinprog', ...
    'Display','iter', ...
    'AbsoluteGapTolerance',1e-6, ...
    'RelativeGapTolerance',1e-6);

[sol,fval,exitflag,output] = solve(model.problem, ...
    'Options',opts, ...
    'Solver','intlinprog');

if exitflag <= 0
    error('第五关MILP未得到可接受解，exitflag=%d。', exitflag);
end

solution.sol = sol;
solution.objective = fval;
solution.exitflag = exitflag;
solution.output = output;

fprintf('第五关找到可行最优解。\n');
fprintf('目标函数（两名玩家总最终资金）：%.2f 元\n', fval);

for p = 1:data.numPlayers
    fprintf('玩家%d初始购买：水 %.0f 箱，食物 %.0f 箱\n', ...
        p, sol.buyWater(p), sol.buyFood(p));
end
end
