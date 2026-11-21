/**
 * The one list of media file types Syndocal imports.
 *
 * Every entry must actually decode on both Windows and macOS release builds:
 * - video: the bundled LGPL libav (native demuxers/decoders);
 * - audio: symphonia, which both timeline analysis and rodio playback use;
 * - still: the `image` crate features enabled in the workspace Cargo.toml.
 *
 * Keep in sync with `VIDEO_ONLY_FILE_EXTENSIONS`, `AUDIO_FILE_EXTENSIONS` and
 * `STILL_IMAGE_EXTENSIONS` in app/src-tauri/src/main.rs; the
 * `media_file_type_lists_match_the_frontend` test enforces it.
 * Deliberately absent: opus/wma/mka (no symphonia decoder, so a clip would
 * import but stay silent), tif/tiff (no `image` TIFF decoder enabled).
 */
export const VIDEO_FILE_EXTENSIONS = [
  "mp4", "m4v", "mov", "qt", "mkv", "avi", "webm", "mxf", "mpg", "mpeg", "m2v", "m2ts", "mts", "ts",
  "wmv", "asf", "flv", "f4v", "3gp", "3g2", "ogv", "dv", "gif", "hap", "hapq",
] as const;
export const AUDIO_FILE_EXTENSIONS = [
  "wav", "wave", "mp3", "m4a", "aac", "flac", "aiff", "aif", "aifc", "ogg", "oga",
] as const;
export const STILL_IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "bmp", "webp"] as const;

export type MediaFileType = "video" | "audio" | "still";

const extensionOf = (path: string) => {
  const name = path.trim().replace(/[\\/]+$/, "").split(/[\\/]/).pop() ?? "";
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
};

const has = (list: readonly string[], extension: string) => list.includes(extension);

export const mediaFileType = (path: string): MediaFileType | null => {
  const extension = extensionOf(path);
  if (has(VIDEO_FILE_EXTENSIONS, extension)) return "video";
  if (has(AUDIO_FILE_EXTENSIONS, extension)) return "audio";
  if (has(STILL_IMAGE_EXTENSIONS, extension)) return "still";
  return null;
};

export const isMediaFilePath = (path: string) => mediaFileType(path) !== null;

/** File name for operator messages. */
export const mediaFileName = (path: string) =>
  path.trim().replace(/[\\/]+$/, "").split(/[\\/]/).pop() || path;
