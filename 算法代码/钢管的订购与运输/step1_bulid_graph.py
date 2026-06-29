# 建立管道网络

import networkx as nx
import matplotlib.pyplot as plt

# 建立无向图
G = nx.Graph()

# 加入管道：双细线
pipeline = [
    ("A1","A2",104),
    ("A2","A3",301),
    ("A3","A4",750),
    ("A4","A5",606),
    ("A5","A6",194),
    ("A6","A7",205),
    ("A7","A8",201),
    ("A8","A9",680),
    ("A9","A10",480),
    ("A10","A11",300),
    ("A11","A12",220),
    ("A12","A13",210),
    ("A13","A14",420),
    ("A14","A15",500),
]

for u,v,d in pipeline:
    G.add_edge(u,v,weight=d,kind="pipeline")


print("节点数：",G.number_of_nodes())
print("边数：",G.number_of_edges())

print("\n所有边")

for u,v,data in G.edges(data=True):
    print(u,"--",v,data)

plt.figure(figsize=(15,4))

pos = nx.spring_layout(G, seed=1)

nx.draw(
    G,
    pos,
    with_labels=True,
    node_size=600,
    font_size=10
)

edge_labels = nx.get_edge_attributes(G,"weight")
nx.draw_networkx_edge_labels(G,pos,edge_labels=edge_labels)

plt.show()