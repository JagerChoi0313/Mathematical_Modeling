function export_results(simulation,gameResult,validation,data,projectRoot)
%EXPORT_RESULTS 将第三问结果集中导出到一个Excel工作簿

outDir=fullfile(projectRoot,'output',sprintf('case%d',data.caseID));
if ~isfolder(outDir),mkdir(outDir);end
file=fullfile(outDir,sprintf('case%d_results.xlsx',data.caseID));
if isfile(file),delete(file);end

n=data.numPlayers;
player=(1:n)'; initialWater=zeros(n,1); initialFood=zeros(n,1); arrival=zeros(n,1); mineDays=zeros(n,1); finalWealth=zeros(n,1);
for p=1:n
    P=simulation.players(p);
    initialWater(p)=P.initialWater; initialFood(p)=P.initialFood;
    arrival(p)=P.arrivalDay; mineDays(p)=P.mineDays; finalWealth(p)=P.finalWealth;
end
T=table(player,initialWater,initialFood,arrival,mineDays,finalWealth, ...
    'VariableNames',{'Player','InitialWater','InitialFood','ArrivalDay','MineDays','FinalWealth'});
writetable(T,file,'Sheet','Summary');

for p=1:n
    P=simulation.players(p); day=(0:data.deadline)'; region=P.region'; water=P.water'; food=P.food'; cash=P.cash'; loadKg=3*water+2*food;
    action=strings(data.deadline+1,1); action(1)="初始购买"; action(2:end)=P.action';
    weather=strings(data.deadline+1,1); weather(1)="第0天";
    for t=1:data.deadline,weather(t+1)=data.weatherNames(simulation.weather(t));end
    D=table(day,weather,region,action,water,food,cash,loadKg, ...
        'VariableNames',{'Day','Weather','Region','Action','Water','Food','Cash','LoadKg'});
    writetable(D,file,'Sheet',sprintf('Player%d',p));
end

day=(1:data.deadline)'; events=simulation.interactions;
writetable(table(day,events,'VariableNames',{'Day','Interactions'}),file,'Sheet','Interactions');

if ~isempty(gameResult.iterationHistory)
    H=array2table(gameResult.iterationHistory);
    names=strings(1,n);for p=1:n,names(p)=sprintf('Player%dWealth',p);end
    H.Properties.VariableNames=cellstr(names);
    H=addvars(H,(1:height(H))','Before',1,'NewVariableNames','Iteration');
    writetable(H,file,'Sheet','Iterations');
end

item=["负重";"资源非负";"现金非负";"路线邻接";"沙暴不移动";"截止日期"];
passed=[validation.loadPassed;validation.resourcePassed;validation.cashPassed;validation.pathPassed;validation.stormPassed;validation.deadlinePassed];
writetable(table(item,passed,'VariableNames',{'CheckItem','Passed'}),file,'Sheet','Validation');
if ~isempty(validation.messages)
    writetable(table(validation.messages,'VariableNames',{'Message'}),file,'Sheet','Messages');
end
end
