function validation = validate_results(simulation, gameResult, data)
%VALIDATE_RESULTS 对最终正向执行结果进行规则复核

n=data.numPlayers; T=data.deadline;
validation.loadPassed=true;
validation.resourcePassed=true;
validation.cashPassed=true;
validation.pathPassed=true;
validation.stormPassed=true;
validation.deadlinePassed=true;
validation.messages=strings(0,1);

for p=1:n
    P=simulation.players(p);
    for t=0:T
        idx=t+1;
        loadKg=3*P.water(idx)+2*P.food(idx);
        if loadKg>data.maxLoad+1e-8
            validation.loadPassed=false;
            validation.messages(end+1)=sprintf('玩家%d第%d天负重超过1200kg。',p,t); %#ok<AGROW>
        end
        if P.water(idx)<-1e-8 || P.food(idx)<-1e-8
            validation.resourcePassed=false;
            validation.messages(end+1)=sprintf('玩家%d第%d天资源出现负数。',p,t); %#ok<AGROW>
        end
        if P.cash(idx)<-1e-8
            validation.cashPassed=false;
            validation.messages(end+1)=sprintf('玩家%d第%d天现金为负。',p,t); %#ok<AGROW>
        end
    end

    for t=1:T
        a=P.region(t); b=P.region(t+1);
        if a~=b && ~ismember(b,data.neighbors{a})
            validation.pathPassed=false;
            validation.messages(end+1)=sprintf('玩家%d第%d天存在非法移动%d→%d。',p,t,a,b); %#ok<AGROW>
        end
        if simulation.weather(t)==3 && a~=b
            validation.stormPassed=false;
            validation.messages(end+1)=sprintf('玩家%d第%d天沙暴期间移动。',p,t); %#ok<AGROW>
        end
    end

    if ~isfinite(P.arrivalDay) || P.arrivalDay>data.deadline
        validation.deadlinePassed=false;
        validation.messages(end+1)=sprintf('玩家%d未在截止日前到达终点。',p); %#ok<AGROW>
    end
end

validation.strategyConverged=gameResult.converged;
validation.cycleDetected=gameResult.cycleDetected;
validation.allPassed=validation.loadPassed && validation.resourcePassed ...
    && validation.cashPassed && validation.pathPassed ...
    && validation.stormPassed && validation.deadlinePassed;
end
