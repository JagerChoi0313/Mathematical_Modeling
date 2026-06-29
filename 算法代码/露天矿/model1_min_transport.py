#混合整数规划模型（总运量最小模型）

import pulp
from QuestionData import *

# =========================
# 模型1：总运量最小 + 卡车数最少
# =========================

def build_model_1(objective_type="min_transport", transport_limit=None):
    """
    objective_type:
        "min_transport" 表示第一阶段：总运量最小
        "min_trucks" 表示第二阶段：在总运量最优的前提下，卡车数最少
    transport_limit:
        第一阶段得到的最优总运量
    """

    prob = pulp.LpProblem("Open_Pit_Mine_Model_1", pulp.LpMinimize)

    # -------------------------
    # 决策变量
    # -------------------------

    # x[i,j]：铲位 i 到卸点 j 的运输趟数
    x = pulp.LpVariable.dicts(
        "x",
        [(i, j) for i in I for j in J],
        lowBound=0,
        cat="Integer"
    )

    # y[i]：铲位 i 是否布置电铲
    y = pulp.LpVariable.dicts(
        "y",
        [i for i in I],
        lowBound=0,
        upBound=1,
        cat="Binary"
    )

    # z[i,j,k]：第 k 辆车是否安排在 i -> j 这条路线
    z = pulp.LpVariable.dicts(
        "z",
        [(i, j, k) for i in I for j in J for k in K],
        lowBound=0,
        upBound=1,
        cat="Binary"
    )

    # n[i,j]：路线 i -> j 上的车辆数
    n = {
        (i, j): pulp.lpSum(z[(i, j, k)] for k in K)
        for i in I for j in J
    }

    # -------------------------
    # 目标函数相关表达式
    # -------------------------

    # 总运量，单位：吨公里
    total_transport = pulp.lpSum(
        ton_km_per_trip[i][j] * x[(i, j)]
        for i in I for j in J
    )
#
    # 总用车数
    total_trucks = pulp.lpSum(
        z[(i, j, k)]
        for i in I for j in J for k in K
    )

    # 如果是第二阶段，需要固定第一阶段的最优总运量
    if transport_limit is not None:
        prob += total_transport <= transport_limit + 1e-5

    if objective_type == "min_transport":
        prob += total_transport
    elif objective_type == "min_trucks":
        prob += total_trucks
    else:
        raise ValueError("objective_type 只能是 min_transport 或 min_trucks")

    # -------------------------
    # 约束1：最多使用7台电铲
    # -------------------------
    prob += pulp.lpSum(y[i] for i in I) <= num_excavators

    # -------------------------
    # 约束2：没有电铲的铲位不能运输
    # 每台电铲一个班次最多装 96 车
    # -------------------------
    for i in I:
        prob += pulp.lpSum(x[(i, j)] for j in J) <= max_trips_per_shovel * y[i]

    # -------------------------
    # 约束3：铲位矿石、岩石储量限制
    # -------------------------
    for i in I:
        # 运往矿石卸点的货来自该铲位矿石
        prob += truck_load * pulp.lpSum(x[(i, j)] for j in ore_dumps) <= ore[i]

        # 运往岩石卸点的货来自该铲位岩石
        prob += truck_load * pulp.lpSum(x[(i, j)] for j in rock_dumps) <= rock[i]

    # -------------------------
    # 约束4：各卸点产量要求
    # -------------------------
    for j in J:
        prob += truck_load * pulp.lpSum(x[(i, j)] for i in I) >= demand[j]

    # -------------------------
    # 约束5：矿石卸点品位限制
    # 29.5% ± 1%，即 28.5% 到 30.5%
    # -------------------------
    for j in ore_dumps:
        prob += pulp.lpSum((grade[i] - grade_low) * x[(i, j)] for i in I) >= 0
        prob += pulp.lpSum((grade[i] - grade_high) * x[(i, j)] for i in I) <= 0

    # -------------------------
    # 约束6：卸点卸车能力
    # 每个卸点一个班次最多卸 160 车
    # -------------------------
    for j in J:
        prob += pulp.lpSum(x[(i, j)] for i in I) <= max_trips_per_dump

    # -------------------------
    # 约束7：车辆运输时间约束
    # 路线 i->j 的总运输趟数不能超过该路线车辆的总能力
    # -------------------------
    for i in I:
        for j in J:
            prob += x[(i, j)] <= max_trips_per_truck[i][j] * n[(i, j)]

    # -------------------------
    # 约束8：同一路线不等待约束
    # 简化处理：同一路线车辆数不能过多
    # -------------------------
    for i in I:
        for j in J:
            no_wait_limit = int(cycle_time[i][j] // load_time)
            prob += n[(i, j)] <= no_wait_limit

    # -------------------------
    # 约束9：每辆卡车最多安排一条路线
    # -------------------------
    for k in K:
        prob += pulp.lpSum(z[(i, j, k)] for i in I for j in J) <= 1

    # -------------------------
    # 约束10：总卡车数不超过20辆
    # -------------------------
    prob += total_trucks <= num_trucks

    return prob, x, y, z, total_transport, total_trucks


# =========================
# 第一阶段：总运量最小
# =========================

prob1, x1, y1, z1, total_transport1, total_trucks1 = build_model_1(
    objective_type="min_transport"
)

solver = pulp.PULP_CBC_CMD(msg=False)
prob1.solve(solver)

print("\n========== 模型1 第一阶段：总运量最小 ==========")
print("求解状态：", pulp.LpStatus[prob1.status])

if pulp.LpStatus[prob1.status] != "Optimal":
    print("模型没有找到最优解，请检查约束或数据。")
    exit()

best_transport = pulp.value(total_transport1)
print("最小总运量：", best_transport, "吨公里")


# =========================
# 第二阶段：在总运量最小前提下，用车数最少
# =========================

prob2, x2, y2, z2, total_transport2, total_trucks2 = build_model_1(
    objective_type="min_trucks",
    transport_limit=best_transport
)

prob2.solve(solver)

print("\n========== 模型1 第二阶段：用车数最少 ==========")
print("求解状态：", pulp.LpStatus[prob2.status])

if pulp.LpStatus[prob2.status] != "Optimal":
    print("第二阶段没有找到最优解。")
    exit()

print("总运量：", pulp.value(total_transport2), "吨公里")
print("使用卡车数：", pulp.value(total_trucks2), "辆")


# =========================
# 输出生产计划
# =========================

print("\n========== 电铲布置方案 ==========")
for i in I:
    if pulp.value(y2[i]) > 0.5:
        print(shovel_names[i], "布置电铲")


print("\n========== 运输路线方案 ==========")

for i in I:
    for j in J:
        trips = round(pulp.value(x2[(i, j)]))

        truck_num = 0
        for k in K:
            if pulp.value(z2[(i, j, k)]) > 0.5:
                truck_num += 1

        if trips > 0:
            amount = trips * truck_load
            route_transport = trips * ton_km_per_trip[i][j]

            print(
                shovel_names[i],
                "->",
                dump_names[j],
                "：车辆数",
                truck_num,
                "辆，运输",
                trips,
                "趟，运输量",
                round(amount, 4),
                "万吨，总运量",
                round(route_transport, 2),
                "吨公里"
            )


print("\n========== 各卸点实际产量 ==========")

for j in J:
    total_trips_j = sum(round(pulp.value(x2[(i, j)])) for i in I)
    actual_amount = total_trips_j * truck_load

    print(
        dump_names[j],
        "：实际产量",
        round(actual_amount, 4),
        "万吨，要求",
        demand[j],
        "万吨"
    )


print("\n========== 矿石卸点平均品位 ==========")

for j in ore_dumps:
    total_trips_j = sum(round(pulp.value(x2[(i, j)])) for i in I)

    if total_trips_j > 0:
        avg_grade = sum(
            grade[i] * round(pulp.value(x2[(i, j)]))
            for i in I
        ) / total_trips_j

        print(
            dump_names[j],
            "：平均品位",
            round(avg_grade * 100, 4),
            "%"
        )


print("\n========== 铲位资源使用情况 ==========")

for i in I:
    used_ore = truck_load * sum(
        round(pulp.value(x2[(i, j)]))
        for j in ore_dumps
    )

    used_rock = truck_load * sum(
        round(pulp.value(x2[(i, j)]))
        for j in rock_dumps
    )

    if used_ore > 0 or used_rock > 0:
        print(
            shovel_names[i],
            "：使用矿石",
            round(used_ore, 4),
            "/",
            ore[i],
            "万吨；使用岩石",
            round(used_rock, 4),
            "/",
            rock[i],
            "万吨"
        )