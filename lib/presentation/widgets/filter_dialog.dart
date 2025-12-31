import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/feedback_provider.dart';

/// Dialog widget for filtering feedback by rating range and date range
/// Allows users to set minimum/maximum ratings and start/end dates
/// Filters are applied when user clicks "Apply" button
class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  // Local state for filter values (not applied until "Apply" is clicked)
  int? _minRating;
  int? _maxRating;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Initialize with current filter values from provider
    final provider = context.read<FeedbackProvider>();
    _minRating = provider.selectedMinRating;
    _maxRating = provider.selectedMaxRating;
    _startDate = provider.startDate;
    _endDate = provider.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Feedback'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating range filter section
            const Text(
              'Rating Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Minimum rating dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _minRating,
                    decoration: const InputDecoration(
                      labelText: 'Min Rating',
                      border: OutlineInputBorder(),
                    ),
                    items: [null, 1, 2, 3, 4, 5]
                        .map((rating) => DropdownMenuItem(
                              value: rating,
                              child: Text(rating == null ? 'Any' : rating.toString()),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _minRating = value),
                  ),
                ),
                const SizedBox(width: 8),
                // Maximum rating dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _maxRating,
                    decoration: const InputDecoration(
                      labelText: 'Max Rating',
                      border: OutlineInputBorder(),
                    ),
                    items: [null, 1, 2, 3, 4, 5]
                        .map((rating) => DropdownMenuItem(
                              value: rating,
                              child: Text(rating == null ? 'Any' : rating.toString()),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _maxRating = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Date range filter section
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Start date picker button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020), // Earliest selectable date
                        lastDate: DateTime.now(), // Latest selectable date (today)
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: Text(
                      _startDate == null
                          ? 'Start Date'
                          : DateFormat('MMM d, y').format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // End date picker button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020), // Can't be before start date
                        lastDate: DateTime.now(), // Latest selectable date (today)
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: Text(
                      _endDate == null
                          ? 'End Date'
                          : DateFormat('MMM d, y').format(_endDate!),
                    ),
                  ),
                ),
              ],
            ),
            // Show "Clear Dates" button only if dates are selected
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
                child: const Text('Clear Dates'),
              ),
          ],
        ),
      ),
      actions: [
        // Clear all filters button
        TextButton(
          onPressed: () {
            setState(() {
              _minRating = null;
              _maxRating = null;
              _startDate = null;
              _endDate = null;
            });
          },
          child: const Text('Clear All'),
        ),
        // Cancel button - closes dialog without applying filters
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // Apply button - applies filters and closes dialog
        ElevatedButton(
          onPressed: () {
            // Apply rating filters
            context.read<FeedbackProvider>().setRatingFilter(_minRating, _maxRating);
            // Apply date filters
            context.read<FeedbackProvider>().setDateFilter(_startDate, _endDate);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
