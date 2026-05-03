import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_service.dart';

/// "From" field is read-only — always shows user's current address or "My Location".
/// "To" field has Places autocomplete with nearby bias.
class LocationInputCard extends StatefulWidget {
  final TextEditingController fromController;
  final TextEditingController toController;

  const LocationInputCard({
    super.key,
    required this.fromController,
    required this.toController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.red.shade400, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: fromController,
                  decoration: const InputDecoration(
                    hintText: "Your location",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 10),

          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red.shade600, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: toController,
                  decoration: const InputDecoration(
                    hintText: "Enter your destination",
                    border: InputBorder.none,
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
