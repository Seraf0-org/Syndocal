//! Every still type the Media Library accepts (app/src/mediaFileTypes.ts
//! STILL_IMAGE_EXTENSIONS) must probe and decode through the `image` features
//! enabled in the workspace Cargo.toml.

use std::path::Path;

#[test]
fn bmp_and_webp_stills_probe_and_decode() {
    for name in ["still.bmp", "still.webp"] {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests")
            .join("fixtures")
            .join(name);
        let metadata = video::probe_still_image_metadata(&path)
            .unwrap_or_else(|error| panic!("{name} probe: {error:?}"));
        assert_eq!(
            (metadata.width, metadata.height),
            (Some(24), Some(10)),
            "{name}"
        );
        let frame = video::load_still_image_frame(1, &path, 0)
            .unwrap_or_else(|error| panic!("{name} decode: {error:?}"));
        assert_eq!((frame.width, frame.height), (24, 10), "{name}");
        assert_eq!(frame.data.len(), 24 * 10 * 4, "{name}");
        assert!(
            frame
                .data
                .chunks_exact(4)
                .any(|pixel| pixel[..3] != [0, 0, 0]),
            "{name} is blank"
        );
    }
}
