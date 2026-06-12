import numpy as np
import pandas as pd
from typing import List, Dict, Any
from sklearn.cluster import KMeans

class HotspotClusterer:
    def __init__(self, default_clusters: int = 3):
        self.default_clusters = default_clusters

    def detect_hotspots(self, coordinates: List[Dict[str, float]]) -> List[Dict[str, Any]]:
        """
        Groups reports by their latitude/longitude coordinates to identify high-density hotspots.
        Input:
            coordinates: A list of dicts with {'lat': float, 'lng': float}
        Returns:
            A list of clusters, each with 'center' (lat, lng), 'weight' (count), and 'district_bounds'.
        """
        if not coordinates or len(coordinates) < 2:
            # Not enough data to cluster, return coordinates as single hotspots
            return [
                {
                    "lat": coord["lat"],
                    "lng": coord["lng"],
                    "weight": 1,
                    "label": f"Incident Spot {idx + 1}"
                }
                for idx, coord in enumerate(coordinates)
            ]

        # Extract features into a numpy array
        df = pd.DataFrame(coordinates)
        points = df[['lat', 'lng']].values

        # Decide K (number of clusters) dynamically
        n_samples = len(points)
        k = min(self.default_clusters, n_samples)
        if k < 1:
            k = 1

        try:
            # Perform K-Means clustering
            kmeans = KMeans(n_clusters=k, random_state=42, n_init="auto")
            kmeans.fit(points)

            labels = kmeans.labels_
            centroids = kmeans.cluster_centers_

            # Process clusters
            clusters = []
            for i in range(k):
                # Find all points assigned to this cluster
                cluster_points = points[labels == i]
                weight = len(cluster_points)
                
                # Get the centroid coordinates
                lat, lng = centroids[i]

                # Generate label depending on weight
                severity = "Low"
                if weight > 10:
                    severity = "Critical"
                elif weight > 4:
                    severity = "High"
                elif weight > 2:
                    severity = "Moderate"

                clusters.append({
                    "lat": float(lat),
                    "lng": float(lng),
                    "weight": int(weight),
                    "severity": severity,
                    "label": f"Corruption Hub ({weight} reports) - Severity: {severity}"
                })

            # Sort clusters by weight descending
            clusters.sort(key=lambda x: x["weight"], reverse=True)
            return clusters

        except Exception as e:
            print(f"Error during K-Means clustering: {e}")
            # Fallback: group identical coordinates or return simple list
            return [
                {
                    "lat": float(coord["lat"]),
                    "lng": float(coord["lng"]),
                    "weight": 1,
                    "severity": "Low",
                    "label": "Incident Spot"
                }
                for coord in coordinates
            ]

clusterer = HotspotClusterer()
