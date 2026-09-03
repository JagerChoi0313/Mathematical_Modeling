
function plot_Q3_results(T)

figure;
bar(T.C4_Yield);
grid on;
xlabel('优化方案');
ylabel('预测C4收率');
title('不同约束条件下最优方案比较');

saveas(gcf,'Q3_scheme_compare.png');


figure;
plot(1:length(T.C4_Yield),T.C4_Yield,'-o','LineWidth',2);
grid on;
xlabel('方案编号');
ylabel('C4收率');
title('优化结果比较');

saveas(gcf,'Q3_result_compare.png');

end
