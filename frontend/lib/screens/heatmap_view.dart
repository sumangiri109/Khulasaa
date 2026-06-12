import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatmapView extends StatefulWidget {
  const HeatmapView({super.key});

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  late GoogleMapController _mapController;

  static const LatLng _nepalCenter = LatLng(28.1000, 84.1500);

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Custom Dark Mode Map styling
  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#121214"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#74748b"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#121214"
        }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#334155"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#09090b"
        }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadHotspots();
  }

  void _loadHotspots() {
    setState(() {
      // Pin Marker Kathmandu Malpot default
      _markers.add(
        const Marker(
          markerId: MarkerId("incident_pin"),
          position: LatLng(27.7007, 85.3001),
          draggable: true,
          infoWindow: InfoWindow(title: "Report Location Pin"),
        ),
      );

      // Clustered spatial hotspots overlays
      _circles.add(
        Circle(
          circleId: const CircleId("cluster_1"),
          center: const LatLng(27.7007, 85.3001),
          radius: 4000,
          fillColor: const Color(0xFFEF4444).withOpacity(0.35),
          strokeColor: const Color(0xFFEF4444),
          strokeWidth: 1,
        ),
      );

      _circles.add(
        Circle(
          circleId: const CircleId("cluster_2"),
          center: const LatLng(27.6710, 85.3240),
          radius: 3000,
          fillColor: const Color(0xFFF59E0B).withOpacity(0.35),
          strokeColor: const Color(0xFFF59E0B),
          strokeWidth: 1,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    Text(
                      "Interactive Heatmap",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildLegendDot(const Color(0xFFEF4444), "Critical"),
                    const SizedBox(width: 8),
                    _buildLegendDot(const Color(0xFFF59E0B), "High"),
                    const SizedBox(width: 8),
                    _buildLegendDot(const Color(0xFF06B6D4), "Medium"),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _nepalCenter,
                  zoom: 7,
                ),
                markers: _markers,
                circles: _circles,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController.setMapStyle(_darkMapStyle);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }
}
