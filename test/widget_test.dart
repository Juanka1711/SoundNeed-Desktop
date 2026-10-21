import 'package:flutter_test/flutter_test.dart';
import 'package:soundneed_pc/main.dart';

void main() {
  test('Track metadata survives persistence serialization', () {
    const track = Track(
      path: r'C:\Music\song.mp3',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      coverPath: r'C:\AppData\covers\cover.img',
      durationMs: 123000,
    );

    final restored = Track.fromJson(track.toJson());

    expect(restored.path, track.path);
    expect(restored.title, track.title);
    expect(restored.artist, track.artist);
    expect(restored.album, track.album);
    expect(restored.coverPath, track.coverPath);
    expect(restored.durationMs, track.durationMs);
  });
}
