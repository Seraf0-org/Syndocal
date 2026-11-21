use super::*;

/// Parses one `export const NAME = [ "a", "b" ] as const;` list.
fn frontend_list(source: &str, name: &str) -> Vec<String> {
    let start = source
        .find(&format!("export const {name} = ["))
        .unwrap_or_else(|| panic!("{name} is missing from mediaFileTypes.ts"));
    let body = &source[start..];
    let body = &body[body.find('[').unwrap() + 1..body.find(']').unwrap()];
    body.split(',')
        .map(|item| item.trim().trim_matches('"').to_string())
        .filter(|item| !item.is_empty())
        .collect()
}

fn owned(list: &[&str]) -> Vec<String> {
    list.iter().map(|item| item.to_string()).collect()
}

#[test]
fn media_file_type_lists_match_the_frontend() {
    // The drop router (frontend) and the pickers/validators (here) must agree,
    // or a dropped file is accepted on one side and refused on the other.
    let source = include_str!("../../../src/mediaFileTypes.ts");
    let video = frontend_list(source, "VIDEO_FILE_EXTENSIONS");
    let audio = frontend_list(source, "AUDIO_FILE_EXTENSIONS");
    let still = frontend_list(source, "STILL_IMAGE_EXTENSIONS");
    assert_eq!(owned(VIDEO_ONLY_FILE_EXTENSIONS), video);
    assert_eq!(owned(AUDIO_FILE_EXTENSIONS), audio);
    assert_eq!(owned(STILL_IMAGE_EXTENSIONS), still);
    let mut video_and_audio = video.clone();
    video_and_audio.extend(audio.iter().cloned());
    assert_eq!(owned(VIDEO_FILE_EXTENSIONS), video_and_audio);
    for extension in ["opus", "wma", "mka", "tif", "tiff"] {
        assert!(
            !VIDEO_FILE_EXTENSIONS.contains(&extension)
                && !STILL_IMAGE_EXTENSIONS.contains(&extension),
            "{extension} has no decoder on every platform"
        );
    }
}
