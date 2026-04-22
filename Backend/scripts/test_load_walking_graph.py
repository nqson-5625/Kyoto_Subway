from pathlib import Path
import osmnx as ox

BASE_DIR = Path(__file__).resolve().parents[1]
GRAPH_PATH = BASE_DIR / "data" / "current" / "walking_graph.graphml"


def main() -> None:
    G = ox.load_graphml(GRAPH_PATH)
    print("Graph loaded successfully")
    print(f"Nodes: {len(G.nodes):,}")
    print(f"Edges: {len(G.edges):,}")


if __name__ == "__main__":
    main()