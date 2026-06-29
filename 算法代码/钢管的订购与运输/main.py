import math


# ==========================================
# 1. 核心算法与工具函数定义
# ==========================================

def calculate_rail_cost(distance):
    """铁路阶梯运费逻辑转换"""
    if distance == float('inf'): return float('inf')
    if distance == 0: return 0

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
        # math.ceil 用于向上取整
        return 60 + math.ceil((distance - 1000) / 100) * 5


def floyd_warshall(matrix, size):
    """Floyd-Warshall 最短路径算法"""
    dist = [row[:] for row in matrix]
    # 注意这里范围是从 1 到 size-1
    for k in range(1, size):
        for i in range(1, size):
            for j in range(1, size):
                if dist[i][k] + dist[k][j] < dist[i][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]
    return dist


def add_edge(matrix, u, v, w):
    """辅助函数：添加无向图的双向边，解决未定义报错"""
    matrix[u][v] = w
    matrix[v][u] = w


# ==========================================
# 2. 初始化地图数据
# ==========================================
N = 39
# 创建大小为 40 的矩阵，废弃 0 索引，让图纸的 1~39 号完全对应代码的 1~39 号
size = N + 1

inf = float('inf')
W_rail = [[inf] * size for _ in range(size)]
W_road = [[inf] * size for _ in range(size)]

# 自己到自己的距离设为 0
for i in range(1, size):
    W_rail[i][i] = 0
    W_road[i][i] = 0

# 【录入铁路数据】(粗黑线)
add_edge(W_rail, 1, 28, 202);
add_edge(W_rail, 2, 28, 1200);
add_edge(W_rail, 3, 29, 690)
add_edge(W_rail, 4, 31, 690);
add_edge(W_rail, 5, 32, 462);
add_edge(W_rail, 6, 36, 70)
add_edge(W_rail, 7, 39, 20)
add_edge(W_rail, 23, 24, 450);
add_edge(W_rail, 24, 25, 1150);
add_edge(W_rail, 24, 26, 80)
add_edge(W_rail, 25, 28, 1100);
add_edge(W_rail, 28, 29, 720);
add_edge(W_rail, 29, 30, 520)
add_edge(W_rail, 30, 31, 170);
add_edge(W_rail, 31, 33, 160);
add_edge(W_rail, 33, 34, 320)
add_edge(W_rail, 34, 35, 160);
add_edge(W_rail, 35, 36, 290);
add_edge(W_rail, 35, 37, 160)
add_edge(W_rail, 35, 39, 30);
add_edge(W_rail, 31, 32, 88)

# 【录入公路数据】(细单线与主管道双细线)
add_edge(W_road, 1, 14, 31)
add_edge(W_road, 23, 8, 3);
add_edge(W_road, 24, 9, 104);
add_edge(W_road, 26, 10, 2)
add_edge(W_road, 25, 11, 600);
add_edge(W_road, 27, 11, 10);
add_edge(W_road, 27, 12, 194)
add_edge(W_road, 27, 38, 306);
add_edge(W_road, 38, 28, 195);
add_edge(W_road, 28, 13, 20)
add_edge(W_road, 13, 14, 10);
add_edge(W_road, 28, 14, 12);
add_edge(W_road, 30, 15, 42)
add_edge(W_road, 31, 16, 70);
add_edge(W_road, 32, 17, 10);
add_edge(W_road, 33, 18, 70)
add_edge(W_road, 34, 18, 10);
add_edge(W_road, 34, 19, 62);
add_edge(W_road, 35, 20, 70)
add_edge(W_road, 36, 21, 110);
add_edge(W_road, 35, 21, 30);
add_edge(W_road, 37, 22, 20)
add_edge(W_road, 8, 9, 104);
add_edge(W_road, 9, 10, 301);
add_edge(W_road, 10, 11, 750)
add_edge(W_road, 11, 12, 606);
add_edge(W_road, 12, 13, 194);
add_edge(W_road, 13, 14, 205)
add_edge(W_road, 14, 15, 48);
add_edge(W_road, 15, 16, 201);
add_edge(W_road, 16, 17, 480)
add_edge(W_road, 17, 18, 300);
add_edge(W_road, 18, 19, 220);
add_edge(W_road, 19, 20, 210)
add_edge(W_road, 20, 21, 420);
add_edge(W_road, 21, 22, 500)

# ==========================================
# 3. 跑图与转换计算
# ==========================================
# 第一遍计算物理距离
dist_rail = floyd_warshall(W_rail, size)
dist_road = floyd_warshall(W_road, size)

cost_rail = [[inf] * size for _ in range(size)]
cost_road = [[inf] * size for _ in range(size)]
mixed_cost = [[inf] * size for _ in range(size)]

# 将距离转换为运费，并在铁、公之间取最小值
for i in range(1, size):
    for j in range(1, size):
        cost_rail[i][j] = calculate_rail_cost(dist_rail[i][j])

        if dist_road[i][j] != inf:
            cost_road[i][j] = dist_road[i][j] * 0.1

        mixed_cost[i][j] = min(cost_road[i][j], cost_rail[i][j])

# 第二遍跑 Floyd，得出联运的最优总花费
final_cost = floyd_warshall(mixed_cost, size)

# ==========================================
# 4. 格式化输出表格
# ==========================================
print("\n" + "=" * 85)
print(" 最终的 S(钢厂) 到 A(管道点) 最小综合运费矩阵 (单位：万元)")
print("=" * 85)

# 打印表头
header = [f"A{i}" for i in range(1, 16)]
print(f"{'':>4} |" + "".join([f"{h:>5}" for h in header]))
print("-" * 85)

# 打印每一行的数据
for s_idx in range(1, 8):
    row_str = f"S{s_idx:<2} |"
    for a_idx in range(8, 23):
        # 取数据并保留1位小数
        val = round(final_cost[s_idx][a_idx], 1)
        row_str += f"{val:5.1f}"
    print(row_str)
print("=" * 85 + "\n")