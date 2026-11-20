import { isVideoPerformFirstShowDropTarget } from "./videoPerformFirstShow";
import { videoClipSlotDropTarget } from "./videoClipSlotBankModel";
import { unsupportedFileDropMessage } from "./nativeFileDrop";
import { timelineVisibleRatioToTimeMs } from "./timelineViewport";

const visualExtensions = ["mp4", "mov", "mxf", "avi", "mkv", "webm", "gif", "png", "jpg", "jpeg", "webp", "bmp", "tif", "tiff"];
const audioExtensions = ["wav", "mp3", "m4a", "aac", "flac", "aiff", "aif", "ogg", "opus"];
export const isVisualMediaFilePath = (path: string) => visualExtensions.some(extension => path.trim().toLowerCase().endsWith(`.${extension}`));
export const isTimelineAudioFilePath = (path: string) => audioExtensions.some(extension => path.trim().toLowerCase().endsWith(`.${extension}`));
export const isSyndocalProjectPath = (path: string) => path.trim().toLowerCase().endsWith(".sdc");

export function routeFileDrop(paths: string[], target: Element | null, clientX: number, actions: {
  firstShow: (paths: string[]) => unknown;
  importMedia: (paths: string[]) => unknown;
  assignSlots: (paths: string[], layerId: number, beforeSlotId: number | null) => unknown;
  openProject: (path: string) => unknown;
  addAudio: (layerId: number | null, path: string, timeMs?: number) => unknown;
  message: (message: string) => void;
}): void {
  if (paths.length === 0) return;
  const project = paths.find(isSyndocalProjectPath);
  if (project && target?.closest("[data-project-drop-surface]")) {
    void actions.openProject(project);
    return;
  }
  const firstShow = isVideoPerformFirstShowDropTarget(target);
  const library = Boolean(target?.closest("[data-media-library-rail]"));
  // Match the visual picker filter. Reject unsupported/mixed gestures instead
  // of silently importing a subset or sending Audio/SDC to the media engine.
  if (firstShow || library) {
    if (!paths.every(isVisualMediaFilePath)) actions.message(unsupportedFileDropMessage);
    else if (firstShow) void actions.firstShow(paths);
    else void actions.importMedia(paths);
    return;
  }
  const audio = paths.find(isTimelineAudioFilePath);
  if (audio) {
    if (paths.length !== 1) {
      actions.message("Drop one audio file at a time.");
      return;
    }
    // SVG lane backgrounds and clips expose attributes, not HTMLElement.dataset.
    const lane = target?.closest("[data-timeline-layer-kind='Audio'][data-timeline-layer-id]");
    const id = lane ? Number(lane.getAttribute("data-timeline-layer-id")) : null;
    if (id !== null && Number.isSafeInteger(id)) {
      const canvas = lane?.closest("svg.timelineOverview");
      const bounds = canvas?.getBoundingClientRect();
      const timeMs = canvas && bounds && bounds.width > 0
        ? timelineVisibleRatioToTimeMs((clientX - bounds.left) / bounds.width, {
          start_ms: Number(canvas.getAttribute("data-visible-start-ms")),
          end_ms: Number(canvas.getAttribute("data-visible-end-ms")),
        })
        : undefined;
      void actions.addAudio(id, audio, timeMs);
    } else if (target?.closest("[data-timeline-audio-drop]")) {
      void actions.addAudio(null, audio);
    } else {
      actions.message("Drop audio on Sources, the Audio section header, or an Audio lane.");
    }
    return;
  }
  const visual = paths.filter(isVisualMediaFilePath);
  if (visual.length > 0) {
    const slot = videoClipSlotDropTarget(target);
    if (slot) void actions.assignSlots(visual, slot.layerId, slot.beforeSlotId);
    else actions.message("Drop visual media on Media Library, a Video layer, or an exact Clip Slot.");
    return;
  }
  actions.message(project ? "Drop .sdc projects on the Project menu button." : unsupportedFileDropMessage);
}
