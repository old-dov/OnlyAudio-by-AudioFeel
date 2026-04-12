import 'package:flutter_test/flutter_test.dart';
import 'package:onlyaudio_by_audiofeel/core/models/player_state.dart';

void main() {
  test('player state json roundtrip keeps key values', () {
    final state = PlayerStateModel(
      currentIndex: 2,
      volume: 0.7,
      positionMs: 12345,
      isRepeat: true,
      isShuffled: true,
      searchQuery: 'rock',
      sortMode: 'title',
    );

    final decoded = PlayerStateModel.fromJson(state.toJson());
    expect(decoded.currentIndex, 2);
    expect(decoded.volume, 0.7);
    expect(decoded.positionMs, 12345);
    expect(decoded.isRepeat, true);
    expect(decoded.isShuffled, true);
    expect(decoded.searchQuery, 'rock');
    expect(decoded.sortMode, 'title');
  });
}
