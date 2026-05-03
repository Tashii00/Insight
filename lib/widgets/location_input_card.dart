import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_service.dart';

/// "From" field is read-only — always shows user's current address or "My Location".
/// "To" field has Places autocomplete with nearby bias.
class LocationInputCard extends StatefulWidget {
  final TextEditingController fromController;
  final TextEditingController toController;
  final LatLng? userLocation; // for autocomplete bias
  final void Function(PlaceSuggestion) onToSelected;
  final VoidCallback onSearch;
  final bool isLoading;

  const LocationInputCard({
    super.key,
    required this.fromController,
    required this.toController,
    required this.onToSelected,
    required this.onSearch,
    this.userLocation,
    this.isLoading = false,
  });

  @override
  State<LocationInputCard> createState() => _LocationInputCardState();
}

class _LocationInputCardState extends State<LocationInputCard> {
  final _uuid = const Uuid();
  String? _sessionToken;
  List<PlaceSuggestion> _suggestions = [];
  bool _showDropdown = false;
  final FocusNode _toFocus = FocusNode();

  void _onToChanged(String value) {
    _sessionToken ??= _uuid.v4();

    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      return;
    }

    MapService.getAutocompleteSuggestions(
      value,
      sessionToken: _sessionToken,
      locationBias: widget.userLocation,
    ).then((results) {
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showDropdown = results.isNotEmpty;
        });
      }
    });
  }

  void _onSuggestionTap(PlaceSuggestion s) {
    widget.toController.text = s.description;
    setState(() {
      _showDropdown = false;
      _suggestions = [];
    });
    _sessionToken = null;

    // Close keyboard
    _toFocus.unfocus();
    FocusScope.of(context).unfocus();

    widget.onToSelected(s);
  }

  @override
  void dispose() {
    _toFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── FROM (read-only current location) ────────────────────────────
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.fromController,
                  readOnly: true,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  decoration: const InputDecoration(
                    hintText: 'My Location',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 9),
                Column(
                  children: List.generate(
                    4,
                    (_) => Container(
                      width: 2,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── TO (autocomplete) ─────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.toController,
                  focusNode: _toFocus,
                  onChanged: _onToChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: 'Where to?',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon:
                        widget.toController.text.isNotEmpty
                            ? GestureDetector(
                              onTap: () {
                                widget.toController.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showDropdown = false;
                                });
                              },
                              child: const Icon(Icons.clear, size: 16),
                            )
                            : null,
                  ),
                ),
              ),
            ],
          ),

          // ── Dropdown suggestions ──────────────────────────────────────────
          if (_showDropdown) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder:
                    (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    title: Text(
                      s.description,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _onSuggestionTap(s),
                  );
                },
              ),
            ),
          ],

          // ── Start walking button (only shown when destination selected) ───
          if (widget.toController.text.isNotEmpty && !_showDropdown) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isLoading ? null : widget.onSearch,
                icon:
                    widget.isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.directions_walk),
                label: Text(
                  widget.isLoading ? 'Finding route…' : 'Start Walking',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
