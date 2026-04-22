from pathlib import Path
import sys

import osmnx as ox
import pandas as pd
from sqlalchemy import create_engine, text

BASE_DIR = Path(__file__).resolve().parents[1]
sys.path.append(str(BASE_DIR))

from app.core.config import settings

GRAPH_PATH = BASE_DIR / "data" / "current" / "walking_graph.graphml"
OUTPUT_PATH = BASE_DIR / "data" / "current" / "station_access_links.parquet"


def main() -> None:
    if not GRAPH_PATH.exists():
        raise FileNotFoundError(f"Graph file not found: {GRAPH_PATH}")

    print(f"Loading graph from: {GRAPH_PATH}")
    G = ox.load_graphml(GRAPH_PATH)

    print("Connecting to database...")
    engine = create_engine(settings.database_url)

    query = text("""
        SELECT
            station_id,
            station_name,
            ST_X(geom) AS lon,
            ST_Y(geom) AS lat
        FROM stations
        WHERE geom IS NOT NULL
          AND is_active = TRUE
        ORDER BY station_id
    """)

    with engine.connect() as conn:
        rows = conn.execute(query).mappings().all()

    if not rows:
        raise RuntimeError("No stations with non-null geom were found in the database.")

    records = []

    print("Finding nearest walking-graph node for each station...")
    for row in rows:
        station_id = row["station_id"]
        station_name = row["station_name"]
        lon = float(row["lon"])
        lat = float(row["lat"])

        nearest_node = ox.distance.nearest_nodes(G, X=lon, Y=lat)

        node_data = G.nodes[nearest_node]
        node_lon = float(node_data["x"])
        node_lat = float(node_data["y"])

        distance_m = ox.distance.great_circle(lat, lon, node_lat, node_lon)

        records.append(
            {
                "station_id": station_id,
                "station_name": station_name,
                "graph_node_id": nearest_node,
                "distance_m": float(distance_m),
                "access_type": "nearest_walk_node",
            }
        )

    df = pd.DataFrame(records)

    print(f"Saving station access links to: {OUTPUT_PATH}")
    df.to_parquet(OUTPUT_PATH, index=False)

    print(f"Done. Saved {len(df):,} station access links.")
    print(df.head())


if __name__ == "__main__":
    main()