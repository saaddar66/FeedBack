
/// Value class for stats data to enable proper equality comparison in Selectors
/// Prevents unnecessary rebuilds by comparing actual values instead of Map references
class StatsData {
  final int totalFeedback;
  final double averageRating;

  const StatsData(this.totalFeedback, this.averageRating);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsData &&
          runtimeType == other.runtimeType &&
          totalFeedback == other.totalFeedback &&
          averageRating == other.averageRating;

  @override
  int get hashCode => Object.hash(totalFeedback, averageRating);
}

/// Value class for chart data to enable proper equality comparison in Selectors
class ChartData {
  final Map<int, int> ratingDistribution;
  final List<Map<String, dynamic>> trendsData;

  const ChartData(this.ratingDistribution, this.trendsData);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartData &&
          runtimeType == other.runtimeType &&
          _mapsEqual(ratingDistribution, other.ratingDistribution) &&
          _listsEqual(trendsData, other.trendsData);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(ratingDistribution.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAll(trendsData.map((e) => Object.hashAll(e.values))),
      );

  bool _mapsEqual(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['date'] != b[i]['date'] ||
          a[i]['count'] != b[i]['count'] ||
          a[i]['avg_rating'] != b[i]['avg_rating']) {
        return false;
      }
    }
    return true;
  }
}

/// Value class for filter data to enable proper equality comparison in Selectors
class FilterData {
  final int? selectedMinRating;
  final int? selectedMaxRating;
  final DateTime? startDate;
  final DateTime? endDate;

  const FilterData({
    this.selectedMinRating,
    this.selectedMaxRating,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterData &&
          runtimeType == other.runtimeType &&
          selectedMinRating == other.selectedMinRating &&
          selectedMaxRating == other.selectedMaxRating &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => Object.hash(
        selectedMinRating,
        selectedMaxRating,
        startDate,
        endDate,
      );
}
