//! Timeline audio is analyzed by `audio::analyze_audio_file` and played by
//! `rodio::Decoder`. A format that only one of them reads shows up as a clip
//! that imports but stays silent (or the reverse), so keep them in lockstep.

use std::{fs, path::Path};

use rodio::Source;

#[test]
fn every_analyzed_fixture_also_decodes_for_playback() {
    for name in [
        "tone.mp3",
        "tone.flac",
        "tone.ogg",
        "tone.m4a",
        "tone.aac",
        "tone.aiff",
        "tone.aifc",
    ] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests")
            .join("fixtures")
            .join(name);
        let analysis = audio::analyze_audio_file(&path)
            .unwrap_or_else(|error| panic!("{name} analysis: {error}"));
        let decoder = rodio::Decoder::try_from(fs::File::open(&path).unwrap())
            .unwrap_or_else(|error| panic!("{name} playback decode: {error}"));
        assert_eq!(decoder.sample_rate(), analysis.sample_rate, "{name}");
        assert_eq!(decoder.channels(), analysis.channels, "{name}");
        // AAC starts with ~1-2k priming samples of silence.
        assert!(
            decoder.take(16_384).any(|sample| sample.abs() > 0.1),
            "{name}"
        );
    }
}
