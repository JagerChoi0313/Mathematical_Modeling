function stop=pso_record(optimValues,state)

global PSO_history

stop=false;

if strcmp(state,'iter')
    PSO_history{end}(end+1)=optimValues.bestfval;
end

end
