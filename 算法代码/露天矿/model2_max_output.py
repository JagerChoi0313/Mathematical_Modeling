# model2_max_output.py
# 模型2 极速版：单次求解
# 目标优先级：
# 1. 岩石产量最大
# 2. 矿石产量最大
# 3. 总运量最小

import pulp
import QuestionData as data

#
def get_value(expr):
    value = pulp.value(expr)
    if value is None:
        return 0
    return value


print("开始运行模型2极速版")

# =========================
# 建立模型
# =========================

prob = pulp.LpProblem("Model2_Max_Output_Fast", pulp.LpMaximize)

# x[i,j]：铲位 i 到卸点 j 的运输趟数
x = pulp.LpVariable.dicts(
    "x",
    [(i, j) for i in data.I for j in data.J],
    lowBound=0,
    cat="Integer"
)

# y[i]：铲位 i 是否布置电铲
y = pulp.LpVariable.dicts(
    "y",
    [i for i in data.I],
    lowBound=0,
    upBound=1,
    cat="Binary"
)

# n[i,j]：路线 i -> j 上安排的车辆数
n = pulp.LpVariable.dicts(
    "n",
    [(i, j) for i in data.I for j in data.J],
    lowBound=0,
    upBound=data.num_trucks,
    cat="Integer"
)

# =========================
# 表达式
# =========================

rock_trips = pulp.lpSum(
    x[(i, j)]
    for i in data.I
    for j in data.rock_dumps
)

ore_trips = pulp.lpSum(
    x[(i, j)]
    for i in data.I
    for j in data.ore_dumps
)

total_trips = rock_trips + ore_trips

total_trucks = pulp.lpSum(
    n[(i, j)]
    for i in data.I
    for j in data.J
)

total_transport = pulp.lpSum(
    data.ton_km_per_trip[i][j] * x[(i, j)]
    for i in data.I
    for j in data.J
)

# =========================
# 目标函数
# =========================
# 岩石优先级最高，其次矿石，最后总运量小
# total_transport 除以100，避免目标系数过大

prob += (
    10000000 * rock_trips
    + 10000 * ore_trips
    - total_transport / 100
    - 0.01 * total_trucks
)

# =========================
# 约束1：最多使用7台电铲
# =========================

prob += pulp.lpSum(y[i] for i in data.I) <= data.num_excavators

# =========================
# 约束2：没有电铲的铲位不能运输
# 一台电铲最多装96车
# =========================

for i in data.I:
    prob += pulp.lpSum(x[(i, j)] for j in data.J) <= data.max_trips_per_shovel * y[i]

# =========================
# 约束3：铲位矿石、岩石储量限制
# =========================

for i in data.I:
    prob += data.truck_load * pulp.lpSum(
        x[(i, j)] for j in data.ore_dumps
    ) <= data.ore[i]

    prob += data.truck_load * pulp.lpSum(
        x[(i, j)] for j in data.rock_dumps
    ) <= data.rock[i]

# =========================
# 约束4：各卸点至少满足原始产量要求
# =========================

for j in data.J:
    prob += data.truck_load * pulp.lpSum(
        x[(i, j)] for i in data.I
    ) >= data.demand[j]

# =========================
# 约束5：矿石卸点品位限制
# 28.5% <= 平均品位 <= 30.5%
# =========================

for j in data.ore_dumps:
    prob += pulp.lpSum(
        (data.grade[i] - data.grade_low) * x[(i, j)]
        for i in data.I
    ) >= 0

    prob += pulp.lpSum(
        (data.grade[i] - data.grade_high) * x[(i, j)]
        for i in data.I
    ) <= 0

# =========================
# 约束6：每个卸点最多卸160车
# =========================

for j in data.J:
    prob += pulp.lpSum(
        x[(i, j)] for i in data.I
    ) <= data.max_trips_per_dump

# =========================
# 约束7：车辆运输能力约束
# =========================

for i in data.I:
    for j in data.J:
        prob += x[(i, j)] <= data.max_trips_per_truck[i][j] * n[(i, j)]

        # 如果一条路线没有运输，就不安排车
        prob += n[(i, j)] <= x[(i, j)]

# =========================
# 约束8：同一路线不等待约束
# =========================

for i in data.I:
    for j in data.J:
        no_wait_limit = int(data.cycle_time[i][j] // data.load_time)
        prob += n[(i, j)] <= no_wait_limit

# =========================
# 约束9：总卡车数不超过20辆
# =========================

prob += total_trucks <= data.num_trucks

# =========================
# 求解
# =========================

print("模型建立完成，开始求解...")

solver = pulp.PULP_CBC_CMD(msg=True, timeLimit=60)
prob.solve(solver)

print("\n========== 模型2 求解结果 ==========")
print("求解状态：", pulp.LpStatus[prob.status])

if pulp.LpStatus[prob.status] not in ["Optimal", "Not Solved"]:
    print("模型未正常求解，请检查约束。")
    exit()

# =========================
# 汇总结果
# =========================

rock_trips_value = round(get_value(rock_trips))
ore_trips_value = round(get_value(ore_trips))
total_trips_value = round(get_value(total_trips))

rock_amount = rock_trips_value * data.truck_load
ore_amount = ore_trips_value * data.truck_load
total_amount = total_trips_value * data.truck_load

print("岩石运输趟数：", rock_trips_value, "趟")
print("矿石运输趟数：", ore_trips_value, "趟")
print("总运输趟数：", total_trips_value, "趟")

print("岩石产量：", round(rock_amount, 4), "万吨")
print("矿石产量：", round(ore_amount, 4), "万吨")
print("总产量：", round(total_amount, 4), "万吨")

print("总运量：", round(get_value(total_transport), 2), "吨公里")
print("使用卡车数：", round(get_value(total_trucks)), "辆")

# =========================
# 电铲布置方案
# =========================

print("\n========== 电铲布置方案 ==========")

for i in data.I:
    total_i_trips = sum(
        round(get_value(x[(i, j)]))
        for j in data.J
    )

    if total_i_trips > 0:
        print(
            data.shovel_names[i],
            "布置电铲，总运输",
            total_i_trips,
            "趟"
        )

# =========================
# 运输路线方案
# =========================

print("\n========== 运输路线方案 ==========")

for i in data.I:
    for j in data.J:
        trips = round(get_value(x[(i, j)]))
        truck_num = round(get_value(n[(i, j)]))

        if trips > 0:
            amount = trips * data.truck_load
            route_transport = trips * data.ton_km_per_trip[i][j]

            print(
                data.shovel_names[i],
                "->",
                data.dump_names[j],
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

# =========================
# 各卸点实际产量
# =========================

print("\n========== 各卸点实际产量 ==========")

for j in data.J:
    total_trips_j = sum(
        round(get_value(x[(i, j)]))
        for i in data.I
    )

    actual_amount = total_trips_j * data.truck_load

    print(
        data.dump_names[j],
        "：实际产量",
        round(actual_amount, 4),
        "万吨，原要求",
        data.demand[j],
        "万吨"
    )

# =========================
# 矿石卸点平均品位
# =========================

print("\n========== 矿石卸点平均品位 ==========")

for j in data.ore_dumps:
    total_trips_j = sum(
        round(get_value(x[(i, j)]))
        for i in data.I
    )

    if total_trips_j > 0:
        avg_grade = sum(
            data.grade[i] * round(get_value(x[(i, j)]))
            for i in data.I
        ) / total_trips_j

        print(
            data.dump_names[j],
            "：平均品位",
            round(avg_grade * 100, 4),
            "%"
        )

# =========================
# 铲位资源使用情况
# =========================

print("\n========== 铲位资源使用情况 ==========")

for i in data.I:
    used_ore = data.truck_load * sum(
        round(get_value(x[(i, j)]))
        for j in data.ore_dumps
    )

    used_rock = data.truck_load * sum(
        round(get_value(x[(i, j)]))
        for j in data.rock_dumps
    )

    if used_ore > 0 or used_rock > 0:
        print(
            data.shovel_names[i],
            "：使用矿石",
            round(used_ore, 4),
            "/",
            data.ore[i],
            "万吨；使用岩石",
            round(used_rock, 4),
            "/",
            data.rock[i],
            "万吨"
        )