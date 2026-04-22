from pathlib import Path
import osmnx as ox

BASE_DIR = Path(__file__).resolve().parents[1]
CURRENT_DIR = BASE_DIR / "data" / "current"
CURRENT_DIR.mkdir(parents=True, exist_ok=True)

OUTPUT_GRAPH_PATH = CURRENT_DIR / "walking_graph.graphml"

# bbox Kyoto
NORTH = 35.10
SOUTH = 34.90
EAST = 135.88
WEST = 135.62


def main() -> None:
    print("Downloading walking network for Kyoto...")
    G = ox.graph_from_bbox(
        bbox=(WEST, SOUTH, EAST, NORTH),
        network_type="walk",
        simplify=True,
    )

    print(f"Graph built: {len(G.nodes):,} nodes / {len(G.edges):,} edges")
    ox.save_graphml(G, OUTPUT_GRAPH_PATH)
    print(f"Saved to: {OUTPUT_GRAPH_PATH}")


if __name__ == "__main__":
    main()