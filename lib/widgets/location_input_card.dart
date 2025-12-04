import 'package:flutter/material.dart';

class LocationInputCard extends StatelessWidget {
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        ],
      ),
    );
  }
}
