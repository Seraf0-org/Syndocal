import { isVideoPerformFirstShowDropTarget } from "./videoPerformFirstShow";
import { videoClipSlotDropTarget } from "./videoClipSlotBankModel";
import { unsupportedFileDropMessage } from "./nativeFileDrop";
import { timelineVisibleRatioToTimeMs } from "./timelineViewport";
import { mediaFileName, mediaFileType } from "./mediaFileTypes";

export const isVisualMediaFilePath = (path: string) => {
  const type = mediaFileType(path);
  return type === "video" || type === "still";
};
export const isTimelineAudioFilePath = (path: string) => mediaFileType(path) === "audio";
export const isSyndocalProjectPath = (path: string) => path.trim().toLowerCase().endsWith(".sdc");

/** The Timeline lane under the drop point, when it is a media lane. */
export interface TimelineFileDropLane {
  id: number;
  kind: "Video" | "Audio";
}

export function routeFileDrop(paths: string[], target: Element | null, clientX: number, actions: {
  firstShow: (paths: string[]) => unknown;
  /** Library import of every supported video/audio/still file. */
  importMedia: (paths: string[]) => unknown;
  assignSlots: (paths: string[], layerId: number, beforeSlotId: number | null) => unknown;
  openProject: (path: string) => unknown;
  /** Library import first, then placement on the Timeline. */
  placeOnTimeline: (paths: string[], lane: TimelineFileDropLane | null, timeMs?: number) => unknown;
  message: (message: string) => void;
}): void {
  if (paths.length === 0) return;
  const project = paths.find(isSyndocalProjectPath);
  if (project && target?.closest("[data-project-drop-surface]")) {
    void actions.openProject(project);
    return;
  }
  const media = paths.filter((path) => mediaFileType(path) !== null);
  const skipped = paths.filter((path) => mediaFileType(path) === null && !isSyndocalProjectPath(path));
  // Import what is supported and say exactly which files were left out,
  // rather than rejecting a whole multi-file gesture for one stray file.
  const run = (action: () => unknown) => {
    void Promise.resolve(action()).then(() => {
      if (skipped.length > 0) {
        actions.message(`Skipped unsupported files: ${skipped.map(mediaFileName).join(", ")}`);
      }
    });
  };
  if (media.length === 0) {
    actions.message(project ? "Drop .sdc projects on the Project menu button." : unsupportedFileDropMessage);
    return;
  }

  if (isVideoPerformFirstShowDropTarget(target)) {
    const visual = media.filter(isVisualMediaFilePath);
    if (visual.length === 0) actions.message("Drop video or image files to start a show.");
    else run(() => actions.firstShow(visual));
    return;
  }
  if (target?.closest("[data-media-library-rail]")) {
    run(() => actions.importMedia(media));
    return;
  }

  // Timeline: any lane, the Audio section header / Sources shelf, or the
  // Timeline frame itself. The lane under the pointer is a placement hint;
  // App resolves (or creates) the lanes each file actually needs.
  const laneElement = target?.closest("[data-timeline-layer-kind][data-timeline-layer-id]");
  const onTimeline = Boolean(laneElement)
    || Boolean(target?.closest("[data-timeline-audio-drop], [data-timeline-file-drop]"));
  if (onTimeline) {
    const kind = laneElement?.getAttribute("data-timeline-layer-kind");
    const id = Number(laneElement?.getAttribute("data-timeline-layer-id"));
    const lane = (kind === "Video" || kind === "Audio") && Number.isSafeInteger(id) && id > 0
      ? { id, kind } as TimelineFileDropLane
      : null;
    // SVG lane backgrounds and clips expose attributes, not HTMLElement.dataset.
    const canvas = laneElement?.closest("svg.timelineOverview");
    const bounds = canvas?.getBoundingClientRect();
    const timeMs = canvas && bounds && bounds.width > 0
      ? timelineVisibleRatioToTimeMs((clientX - bounds.left) / bounds.width, {
        start_ms: Number(canvas.getAttribute("data-visible-start-ms")),
        end_ms: Number(canvas.getAttribute("data-visible-end-ms")),
      })
      : undefined;
    run(() => actions.placeOnTimeline(media, lane, timeMs));
    return;
  }

  const visual = media.filter(isVisualMediaFilePath);
  const slot = videoClipSlotDropTarget(target);
  if (slot && visual.length > 0) {
    run(() => actions.assignSlots(visual, slot.layerId, slot.beforeSlotId));
    return;
  }
  actions.message(slot
    ? "Clip Slots take video or image files. Drop audio on the Timeline or the Media Library."
    : "Drop media on the Media Library, the Timeline, or a Clip Slot.");
}
