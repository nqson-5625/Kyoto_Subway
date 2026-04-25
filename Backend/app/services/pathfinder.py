import heapq


graph = {
    "Kyoto": {
        "Kujo": 2
    },
    "Kujo": {
        "Kyoto": 2,
        "Jujo": 2
    },
    "Jujo": {
        "Kujo": 2,
        "Jujo Station": 1
    },
    "Jujo Station": {
        "Jujo": 1
    }
}


def shortest_path(start, end):
    queue = [(0, start, [])]
    visited = set()

    while queue:
        cost, node, path = heapq.heappop(queue)

        if node in visited:
            continue

        visited.add(node)
        path = path + [node]

        if node == end:
            return {
                "path": path,
                "total_time": cost
            }

        for neighbor, weight in graph.get(node, {}).items():
            if neighbor not in visited:
                heapq.heappush(queue, (cost + weight, neighbor, path))

    return {
        "path": [],
        "total_time": -1
    }