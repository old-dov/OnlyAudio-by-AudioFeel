class PlayerStateModel {
  PlayerStateModel({
    this.currentIndex = 0,
    this.volume = 0.5,
    this.positionMs = 0,
    this.isShuffled = false,
    this.isRepeat = false,
    this.sortMode = 'added',
    this.searchQuery = '',
  });

  int currentIndex;
  double volume;
  int positionMs;
  bool isShuffled;
  bool isRepeat;
  String sortMode;
  String searchQuery;

  Map<String, dynamic> toJson() => {
        'currentIndex': currentIndex,
        'volume': volume,
        'positionMs': positionMs,
        'isShuffled': isShuffled,
        'isRepeat': isRepeat,
        'sortMode': sortMode,
        'searchQuery': searchQuery,
      };

  factory PlayerStateModel.fromJson(Map<String, dynamic> json) {
    return PlayerStateModel(
      currentIndex: json['currentIndex'] as int? ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.5,
      positionMs: json['positionMs'] as int? ?? 0,
      isShuffled: json['isShuffled'] as bool? ?? false,
      isRepeat: json['isRepeat'] as bool? ?? false,
      sortMode: json['sortMode'] as String? ?? 'added',
      searchQuery: json['searchQuery'] as String? ?? '',
    );
  }
}
