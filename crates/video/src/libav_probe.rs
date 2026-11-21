//! In-process media metadata probe.
//!
//! Library import, relink and codec refresh need duration, picture size,
//! frame rate and whether an audio stream exists. Release builds ship the
//! LGPL libav libraries (beside `syndocal.exe` on Windows, inside the app
//! bundle on macOS) but no `ffprobe` executable, so probing through libav is
//! what makes drag-and-drop import work on a machine without FFmpeg tools.

use std::path::Path;

use ffmpeg_next as ffmpeg;
use protocol::VideoMediaMetadata;

use super::VideoProbeSummary;

pub(crate) fn probe_with_libav(path: &Path) -> Result<VideoProbeSummary, String> {
    use ffmpeg::{format::stream::Disposition, media::Type};

    ffmpeg::init().map_err(|error| error.to_string())?;
    let input = ffmpeg::format::input(path).map_err(|error| error.to_string())?;
    let has_audio = input
        .streams()
        .any(|stream| stream.parameters().medium() == Type::Audio);
    // Embedded cover art (MP3/M4A/FLAC artwork) is a one-frame "video"
    // stream; it must not turn an audio file into a video clip.
    let video = input
        .streams()
        .filter(|stream| {
            stream.parameters().medium() == Type::Video
                && !stream.disposition().contains(Disposition::ATTACHED_PIC)
        })
        .max_by_key(|stream| {
            // Same preference as av_find_best_stream: the largest picture.
            // SAFETY: the parameters pointer is owned by the open input and
            // stays valid for this borrow.
            let parameters = stream.parameters();
            let (width, height) = unsafe {
                let raw = parameters.as_ptr();
                ((*raw).width.max(0) as u64, (*raw).height.max(0) as u64)
            };
            width * height
        });

    let mut codec = None;
    let mut width = None;
    let mut height = None;
    let mut frame_rate = None;
    let mut stream_duration_ms = None;
    if let Some(stream) = &video {
        let parameters = stream.parameters();
        let name = parameters.id().name();
        if !name.trim().is_empty() && name != "none" {
            codec = Some(name.to_string());
        }
        // SAFETY: see above; plain integer reads from AVCodecParameters.
        let (raw_width, raw_height) = unsafe {
            let raw = parameters.as_ptr();
            ((*raw).width, (*raw).height)
        };
        width = u32::try_from(raw_width).ok().filter(|value| *value > 0);
        height = u32::try_from(raw_height).ok().filter(|value| *value > 0);
        frame_rate =
            rational_rate(stream.avg_frame_rate()).or_else(|| rational_rate(stream.rate()));
        stream_duration_ms = stream_duration(stream.duration(), stream.time_base());
    }
    let duration_ms = (input.duration() > 0)
        .then(|| u64::try_from(input.duration() / 1_000).ok())
        .flatten()
        .filter(|duration| *duration > 0)
        .or(stream_duration_ms)
        .or_else(|| {
            input
                .streams()
                .filter_map(|stream| stream_duration(stream.duration(), stream.time_base()))
                .max()
        });

    let metadata = VideoMediaMetadata {
        duration_ms,
        width,
        height,
        frame_rate,
        has_audio,
    };
    let metadata = (metadata.duration_ms.is_some()
        || metadata.width.is_some()
        || metadata.height.is_some()
        || metadata.frame_rate.is_some())
    .then_some(metadata);
    Ok(VideoProbeSummary { codec, metadata })
}

fn rational_rate(rate: ffmpeg::Rational) -> Option<f32> {
    let (numerator, denominator) = (rate.numerator(), rate.denominator());
    if numerator <= 0 || denominator <= 0 {
        return None;
    }
    let value = f64::from(numerator) / f64::from(denominator);
    (value.is_finite() && value > 0.0).then_some(value as f32)
}

fn stream_duration(duration: i64, time_base: ffmpeg::Rational) -> Option<u64> {
    if duration <= 0 || time_base.numerator() <= 0 || time_base.denominator() <= 0 {
        return None;
    }
    let ms = i128::from(duration) * i128::from(time_base.numerator()) * 1_000
        / i128::from(time_base.denominator());
    u64::try_from(ms).ok().filter(|ms| *ms > 0)
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;

    fn fixture(name: &str) -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests")
            .join("fixtures")
            .join(name)
    }

    fn audio_fixture(name: &str) -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../audio/tests/fixtures")
            .join(name)
    }

    fn missing_ffprobe() -> PathBuf {
        std::env::temp_dir().join(format!(
            "syndocal-video-missing-ffprobe-{}{}",
            std::process::id(),
            std::env::consts::EXE_SUFFIX
        ))
    }

    fn probe(path: &Path) -> VideoMediaMetadata {
        // Regression: Library import probed only through an `ffprobe`
        // executable, which release builds (and macOS machines) do not have.
        crate::probe_video_file_metadata_with_fallback_binary(path, missing_ffprobe())
            .unwrap_or_else(|error| panic!("{}: {error:?}", path.display()))
            .metadata
            .unwrap_or_else(|| panic!("{} has no metadata", path.display()))
    }

    #[test]
    fn video_with_audio_reports_picture_rate_duration_and_audio() {
        let summary = probe_with_libav(&fixture("av.mp4")).unwrap();
        assert_eq!(summary.codec.as_deref(), Some("mpeg4"));
        let metadata = probe(&fixture("av.mp4"));
        assert_eq!((metadata.width, metadata.height), (Some(32), Some(18)));
        assert_eq!(metadata.frame_rate, Some(25.0));
        assert!(metadata.has_audio);
        assert!((950..=1_100).contains(&metadata.duration_ms.unwrap()));
    }

    #[test]
    fn video_only_file_has_no_audio() {
        let metadata = probe(&fixture("video-only.mov"));
        assert_eq!((metadata.width, metadata.height), (Some(32), Some(18)));
        assert!(!metadata.has_audio);
        assert!(metadata.duration_ms.is_some_and(|duration| duration > 0));
    }

    #[test]
    fn audio_files_are_audio_only_with_a_duration() {
        for name in [
            "tone.mp3",
            "tone.flac",
            "tone.ogg",
            "tone.m4a",
            "tone.aac",
            "tone.aiff",
            "tone.aifc",
        ] {
            let metadata = probe(&audio_fixture(name));
            assert!(metadata.has_audio, "{name}");
            assert_eq!((metadata.width, metadata.height), (None, None), "{name}");
            assert!(
                metadata.duration_ms.is_some_and(|duration| duration >= 400),
                "{name}"
            );
        }
    }

    #[test]
    fn embedded_cover_art_does_not_make_an_audio_file_a_video() {
        let metadata = probe(&fixture("cover.mp3"));
        assert!(metadata.has_audio);
        assert_eq!((metadata.width, metadata.height), (None, None));
        assert_eq!(metadata.frame_rate, None);
    }

    #[test]
    fn gif_probes_as_a_placeable_video() {
        // GIF is imported as a video file (libav's native GIF demuxer); a
        // Timeline placement needs a known non-zero duration.
        for name in ["anim.gif", "still.gif"] {
            let metadata = probe(&fixture(name));
            assert_eq!(
                (metadata.width, metadata.height),
                (Some(16), Some(16)),
                "{name}"
            );
            assert!(!metadata.has_audio, "{name}");
            assert!(
                metadata.duration_ms.is_some_and(|duration| duration > 0),
                "{name}: {metadata:?}"
            );
        }
    }

    #[test]
    fn unreadable_file_reports_the_libav_error_not_a_missing_ffprobe() {
        let path = std::env::temp_dir().join(format!(
            "syndocal-video-probe-garbage-{}.mp4",
            std::process::id()
        ));
        std::fs::write(&path, [0x5A_u8; 2_048]).unwrap();
        let error = crate::probe_video_file_metadata_with_fallback_binary(&path, missing_ffprobe())
            .unwrap_err();
        let _ = std::fs::remove_file(&path);
        let crate::VideoProbeError::Probe { message, .. } = error else {
            panic!("unexpected error {error:?}");
        };
        assert!(
            !message.to_ascii_lowercase().contains("ffprobe"),
            "{message}"
        );
        assert!(!message.contains("os error 2"), "{message}");
    }
}
