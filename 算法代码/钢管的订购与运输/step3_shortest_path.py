

# 建立运输网络

import networkx as nx

T = nx.Graph()

# 铁路
railway = [
    ("R1", "R2", 450),
    ("R2", "R3", 306),
    ("R3", "R4", 720),
    ("R4", "R5", 690),
    ("R5", "R6", 520),
    ("R6", "R7", 170),
    ("R7", "R8", 690),
    ("R8", "R9", 462),
    ("R9", "R10", 160),
    ("R10", "R11", 320),
    ("R11", "R12", 160),
    ("R12", "R13", 110),
    ("R13", "R14", 290),
    ("R14", "R15", 1150)
]


for u,v,d in railway:
    T.add_edge(
        u,
        v,
        weight=d,
        kind="rail"
    )


# 加入钢厂

factory = [
    ("S1", "R1", 0),
    ("S2", "R3", 0),
    ("S3", "R5", 0),
    ("S4", "R7", 0),
    ("S5", "R9", 0),
    ("S6", "R11", 0),
    ("S7", "R15", 0)
]


for u,v,d in factory:
    T.add_edge(
        u,
        v,
        weight=d,
        kind="factory"
    )


road = [
    ("R2","A1",80),
    ("R2","A2",10),
    ("R3","A3",20),
    ("R4","A4",30),
    ("R5","A5",20),
    ("R6","A6",20),
    ("R7","A7",30),
    ("R8","A8",70),
    ("R9","A9",62),
    ("R10","A10",70),
    ("R11","A11",88),
    ("R12","A12",10),
    ("R13","A13",70),
    ("R14","A14",10),
    ("R15","A15",80)
]

for u,v,d in road:
    T.add_edge(
        u,
        v,
        weight=d,
        kind="road"
    )


print("运输网络节点数：",T.number_of_nodes())
print("运输网络边数：",T.number_of_edges())

print()

for u,v,data in T.edges(data=True):
    print(u,v,data)



# ========================================
# 铁路运费函数
# ========================================
def rail_cost(distance):
    """
    根据题目中的铁路分段运价计算铁路运输费用
    输入：铁路距离(km)
    输出：铁路运输费用(万元)
    """

    if distance <= 300:
        return 20
    elif distance <= 350:
        return 23
    elif distance <= 400:
        return 26
    elif distance <= 450:
        return 29
    elif distance <= 500:
        return 32
    elif distance <= 600:
        return 37
    elif distance <= 700:
        return 44
    elif distance <= 800:
        return 50
    elif distance <= 900:
        return 55
    elif distance <= 1000:
        return 60
    else:
        import math
        return 60 + math.ceil((distance - 1000) / 100) * 5


# ========================================
# 公路费用
# ========================================
def road_cost(distance):
    return distance * 0.1


# ========================================
# 输出所有钢厂到所有管道节点的最短距离
# ========================================

print("=" * 60)
print("钢厂到各管道节点最短距离")
print("=" * 60)

distance_matrix = {}

for s in range(1, 8):

    source = f"S{s}"
    distance_matrix[source] = {}

    print(f"\n------ {source} ------")

    for a in range(1, 16):

        target = f"A{a}"

        try:

            distance = nx.shortest_path_length(
                T,
                source=source,
                target=target,
                weight="weight"
            )

            path = nx.shortest_path(
                T,
                source=source,
                target=target,
                weight="weight"
            )

            distance_matrix[source][target] = distance

            print(
                f"{source:>2} -> {target:<3}"
                f" 距离 = {distance:>6} km"
                f"   路径 = {path}"
            )

        except nx.NetworkXNoPath:

            print(f"{source} -> {target} 无路径")


print("\n")
print("=" * 60)
print("距离矩阵")
print("=" * 60)

print("      ", end="")

for a in range(1, 16):
    print(f"A{a:>6}", end="")

print()

for s in range(1, 8):

    print(f"S{s:<3}", end="")

    for a in range(1, 16):

        d = distance_matrix[f"S{s}"][f"A{a}"]

        print(f"{d:>7}", end="")

    print()

