function stop = save_pso(optimValues,state)

global PSO_history


stop=false;


switch state

    case 'init'

        PSO_history=[];


    case 'iter'

        PSO_history(end+1)=optimValues.bestfval;


    case 'done'

        % 不处理

end


end