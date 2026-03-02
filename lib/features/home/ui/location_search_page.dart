import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSearchPage extends StatefulWidget {
  final String title; // "Departure Location" or "Destination"
  final LatLng? currentLocation; // User's current location for bias

  const LocationSearchPage({
    super.key,
    required this.title,
    this.currentLocation,
  });

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  // Replace with your actual Google API key
  static const String _apiKey = 'AIzaSyDVirZDobXhBxW_4AubQoatswHMuIPmzuc';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field when page opens
    Future.delayed(Duration(milliseconds: 300), () {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Get autocomplete suggestions from Google Places API
  Future<void> _getPlaceSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build location bias based on user's current location
      String locationBias = '';
      if (widget.currentLocation != null) {
        locationBias =
            '&location=${widget.currentLocation!.latitude},${widget.currentLocation!.longitude}&radius=50000';
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_apiKey'
        '$locationBias'
        '&components=country:pk', // Bias to Pakistan, remove if worldwide
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;

          setState(() {
            _suggestions = predictions.map((p) {
              return PlaceSuggestion(
                placeId: p['place_id'],
                description: p['description'],
                mainText: p['structured_formatting']['main_text'],
                secondaryText: p['structured_formatting']['secondary_text'] ?? '',
              );
            }).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _suggestions = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get place details (lat/lng) from place_id
  Future<LatLng?> _getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
    return null;
  }

  // Handle text input with debouncing
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _getPlaceSuggestions(value);
    });
  }

  // Handle suggestion selection
  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Get coordinates
    final location = await _getPlaceDetails(suggestion.placeId);

    // Close loading
    if (mounted) Navigator.pop(context);

    if (location != null) {
      // Return selected location to previous page
      if (mounted) {
        Navigator.pop(context, {
          'name': suggestion.description,
          'location': location,
        });
      }
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location details'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search location...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Suggestions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _suggestions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Start typing to search locations'
                                  : 'No locations found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.green[700],
                                size: 24,
                              ),
                            ),
                            title: Text(
                              suggestion.mainText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: suggestion.secondaryText.isNotEmpty
                                ? Text(
                                    suggestion.secondaryText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                            onTap: () => _onSuggestionSelected(suggestion),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Model class for place suggestions
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}