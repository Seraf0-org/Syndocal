//! Bounded snapshot synchronization service; no Tauri or engine ownership dependencies.
//! Revisions identify captured snapshots globally. Keep a small recent history so
//! independent windows can diff against their own last response without forcing full payloads.
use protocol::{
    AttributeValueSummary, ClockSnapshot, CueId, DmxOutputConfig, EffectSummary, EngineSnapshot,
    EngineTelemetry, FixtureId, NodeGraphSummary, PatchedFixtureSummary, StageMapConfig,
    StageMapPresetSummary, StageObjectSummary, TimelineSnapshot,
};
use serde::Serialize;
use std::{
    collections::{BTreeMap, VecDeque},
    sync::Arc,
};

const SNAPSHOT_HISTORY_CAPACITY: usize = 4;

#[derive(Debug, Default)]
pub(crate) struct SnapshotSyncState {
    revision: u64,
    history: VecDeque<(u64, Arc<EngineSnapshot>)>,
}

#[derive(Debug, Serialize)]
pub(crate) struct SnapshotSyncPayload {
    pub(crate) revision: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) full: Option<Arc<EngineSnapshot>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) delta: Option<EngineSnapshotDelta>,
}

impl SnapshotSyncState {
    /// The caller serializes capture and publication together. A revision must
    /// never describe a sample captured before a previously published sample.
    pub(crate) fn publish(
        &mut self,
        client_revision: Option<u64>,
        current: EngineSnapshot,
    ) -> Result<SnapshotSyncPayload, String> {
        let revision = self.revision.checked_add(1).ok_or_else(||
            "Snapshot synchronization revision exhausted; restart Syndocal to establish a new session".to_string())?;
        // A full response and its retained base share one immutable captured image.
        // Eviction can release the history's ownership before response serialization.
        let current = Arc::new(current);
        let before = client_revision.and_then(|requested| {
            self.history
                .iter()
                .find(|(revision, _)| *revision == requested)
                .map(|(_, snapshot)| snapshot)
        });
        let payload = match before {
            Some(before) => SnapshotSyncPayload {
                revision,
                full: None,
                delta: Some(engine_snapshot_delta(before, &current)),
            },
            None => SnapshotSyncPayload {
                revision,
                full: Some(Arc::clone(&current)),
                delta: None,
            },
        };
        // Retain at most four complete snapshots, regardless of client count.
        if self.history.len() == SNAPSHOT_HISTORY_CAPACITY {
            self.history.pop_front();
        }
        self.history.push_back((revision, current));
        self.revision = revision;
        Ok(payload)
    }
}

#[derive(Debug, Clone, Default, Serialize, PartialEq)]
pub(crate) struct EngineSnapshotDelta {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) fixtures: Option<Vec<PatchedFixtureSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) fixture_attribute_values: Option<Vec<(FixtureId, Vec<AttributeValueSummary>)>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) cues: Option<Vec<protocol::CueSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) cue_lists: Option<Vec<protocol::CueListSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) palettes: Option<Vec<protocol::ReferencePaletteSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) playback_executors: Option<Vec<protocol::PlaybackExecutorSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) playback_master: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) active_cue_id: Option<Option<CueId>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) direct_child_timeline_transports:
        Option<Vec<protocol::DirectChildTimelineTransportSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) active_group_cue_ids: Option<BTreeMap<String, CueId>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) cue_live_modifiers: Option<Vec<protocol::CueLiveModifierState>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) group_colors: Option<BTreeMap<String, String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) active_fade: Option<Option<protocol::ActiveFadeSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) programmer: Option<protocol::ProgrammerSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) timeline: Option<protocol::TimelineSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) timeline_position_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) video: Option<protocol::VideoSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) effects: Option<Vec<EffectSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) node_graphs: Option<Vec<NodeGraphSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) output: Option<DmxOutputConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) dmx_outputs: Option<Vec<DmxOutputConfig>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) lighting_master: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) submasters: Option<Vec<protocol::SubmasterSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) blackout: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) authored_blackout: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) safety_blackout_engaged: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) clock: Option<ClockSnapshot>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) stage_map: Option<StageMapConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) stage_map_presets: Option<Vec<StageMapPresetSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) stage_objects: Option<Vec<StageObjectSummary>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) dmx_preview: Option<Vec<u8>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) dmx_previews: Option<Vec<protocol::DmxUniversePreview>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) telemetry: Option<EngineTelemetry>,
}

fn fixture_structure_equal(before: &PatchedFixtureSummary, after: &PatchedFixtureSummary) -> bool {
    let PatchedFixtureSummary {
        id: b_id,
        label: b_label,
        profile_source_path: b_profile_source_path,
        profile_name: b_profile_name,
        manufacturer: b_manufacturer,
        mode_name: b_mode_name,
        universe: b_universe,
        address: b_address,
        group_ids: b_group_ids,
        position: b_position,
        rotation: b_rotation,
        geometries: b_geometries,
        controls: b_controls,
        stage_layout: b_stage_layout,
        attribute_values: _,
        limits: b_limits,
        highlighted: b_highlighted,
        soloed: b_soloed,
        parked: b_parked,
    } = before;
    let PatchedFixtureSummary {
        id: a_id,
        label: a_label,
        profile_source_path: a_profile_source_path,
        profile_name: a_profile_name,
        manufacturer: a_manufacturer,
        mode_name: a_mode_name,
        universe: a_universe,
        address: a_address,
        group_ids: a_group_ids,
        position: a_position,
        rotation: a_rotation,
        geometries: a_geometries,
        controls: a_controls,
        stage_layout: a_stage_layout,
        attribute_values: _,
        limits: a_limits,
        highlighted: a_highlighted,
        soloed: a_soloed,
        parked: a_parked,
    } = after;
    b_id == a_id
        && b_label == a_label
        && b_profile_source_path == a_profile_source_path
        && b_profile_name == a_profile_name
        && b_manufacturer == a_manufacturer
        && b_mode_name == a_mode_name
        && b_universe == a_universe
        && b_address == a_address
        && b_group_ids == a_group_ids
        && b_position == a_position
        && b_rotation == a_rotation
        && b_geometries == a_geometries
        && b_controls == a_controls
        && b_stage_layout == a_stage_layout
        && b_limits == a_limits
        && b_highlighted == a_highlighted
        && b_soloed == a_soloed
        && b_parked == a_parked
}

fn diff_fixtures(
    before: &[PatchedFixtureSummary],
    after: &[PatchedFixtureSummary],
) -> (
    Option<Vec<PatchedFixtureSummary>>,
    Option<Vec<(FixtureId, Vec<AttributeValueSummary>)>>,
) {
    if before.len() != after.len() {
        return (Some(after.to_vec()), None);
    }
    let mut changed_values = Vec::new();
    for (left, right) in before.iter().zip(after.iter()) {
        if !fixture_structure_equal(left, right) {
            return (Some(after.to_vec()), None);
        }
        if left.attribute_values != right.attribute_values {
            changed_values.push((right.id, right.attribute_values.clone()));
        }
    }
    if changed_values.is_empty() {
        (None, None)
    } else {
        (None, Some(changed_values))
    }
}

fn timeline_serialized_structure_equal(
    before: &TimelineSnapshot,
    after: &TimelineSnapshot,
) -> bool {
    let TimelineSnapshot {
        id: b_id,
        label: b_label,
        layers: b_layers,
        events: b_events,
        automations: b_automations,
        video_automations: b_video_automations,
        audio: b_audio,
        audio_clips: b_audio_clips,
        audio_policy: b_audio_policy,
        video_clips: b_video_clips,
        phases: b_phases,
        item_groups: b_item_groups,
        loop_region: b_loop_region,
        follow: b_follow,
        guide_enabled: b_guide_enabled,
        audio_offset_ms: b_audio_offset_ms,
        audio_muted: b_audio_muted,
        metronome_enabled: b_metronome_enabled,
        count_in_beats: b_count_in_beats,
        tempo_meter_map: b_tempo_meter_map,
        tempo_meter_map_version: b_tempo_meter_map_version,
        count_in_remaining_ms: _,
        audio_transport_revision: _,
        transport_epoch: _,
        transport_generation: _,
        active_child_transports: _,
        loop_runtime: _,
        follow_runtime: _,
        guide_cues: _,
        click_events: _,
        click_schedule_generation: _,
        click_queue_overflow: _,
        playing: b_playing,
        position_ms: _,
        duration_ms: b_duration_ms,
    } = before;
    let TimelineSnapshot {
        id: a_id,
        label: a_label,
        layers: a_layers,
        events: a_events,
        automations: a_automations,
        video_automations: a_video_automations,
        audio: a_audio,
        audio_clips: a_audio_clips,
        audio_policy: a_audio_policy,
        video_clips: a_video_clips,
        phases: a_phases,
        item_groups: a_item_groups,
        loop_region: a_loop_region,
        follow: a_follow,
        guide_enabled: a_guide_enabled,
        audio_offset_ms: a_audio_offset_ms,
        audio_muted: a_audio_muted,
        metronome_enabled: a_metronome_enabled,
        count_in_beats: a_count_in_beats,
        tempo_meter_map: a_tempo_meter_map,
        tempo_meter_map_version: a_tempo_meter_map_version,
        count_in_remaining_ms: _,
        audio_transport_revision: _,
        transport_epoch: _,
        transport_generation: _,
        active_child_transports: _,
        loop_runtime: _,
        follow_runtime: _,
        guide_cues: _,
        click_events: _,
        click_schedule_generation: _,
        click_queue_overflow: _,
        playing: a_playing,
        position_ms: _,
        duration_ms: a_duration_ms,
    } = after;
    b_id == a_id
        && b_label == a_label
        && b_layers == a_layers
        && b_events == a_events
        && b_automations == a_automations
        && b_video_automations == a_video_automations
        && b_audio == a_audio
        && b_audio_clips == a_audio_clips
        && b_audio_policy == a_audio_policy
        && b_video_clips == a_video_clips
        && b_phases == a_phases
        && b_item_groups == a_item_groups
        && b_loop_region == a_loop_region
        && b_follow == a_follow
        && b_guide_enabled == a_guide_enabled
        && b_audio_offset_ms == a_audio_offset_ms
        && b_audio_muted == a_audio_muted
        && b_metronome_enabled == a_metronome_enabled
        && b_count_in_beats == a_count_in_beats
        && b_tempo_meter_map == a_tempo_meter_map
        && b_tempo_meter_map_version == a_tempo_meter_map_version
        && b_playing == a_playing
        && b_duration_ms == a_duration_ms
}

fn diff_timeline(
    before: &TimelineSnapshot,
    after: &TimelineSnapshot,
) -> (Option<TimelineSnapshot>, Option<u64>) {
    if !timeline_serialized_structure_equal(before, after) {
        (Some(after.clone()), None)
    } else if before.position_ms != after.position_ms {
        (None, Some(after.position_ms))
    } else {
        (None, None)
    }
}

pub(crate) fn engine_snapshot_delta(
    before: &EngineSnapshot,
    after: &EngineSnapshot,
) -> EngineSnapshotDelta {
    macro_rules! changed {
        ($field:ident) => {
            (before.$field != after.$field).then(|| after.$field.clone())
        };
    }
    let (fixtures, fixture_attribute_values) = diff_fixtures(&before.fixtures, &after.fixtures);
    let (timeline, timeline_position_ms) = diff_timeline(&before.timeline, &after.timeline);
    EngineSnapshotDelta {
        fixtures,
        fixture_attribute_values,
        cues: changed!(cues),
        cue_lists: changed!(cue_lists),
        palettes: changed!(palettes),
        playback_executors: changed!(playback_executors),
        playback_master: (before.playback_master != after.playback_master)
            .then_some(after.playback_master),
        active_cue_id: (before.active_cue_id != after.active_cue_id).then_some(after.active_cue_id),
        direct_child_timeline_transports: changed!(direct_child_timeline_transports),
        active_group_cue_ids: changed!(active_group_cue_ids),
        cue_live_modifiers: changed!(cue_live_modifiers),
        group_colors: changed!(group_colors),
        active_fade: (before.active_fade != after.active_fade).then(|| after.active_fade.clone()),
        programmer: changed!(programmer),
        timeline,
        timeline_position_ms,
        video: changed!(video),
        effects: changed!(effects),
        node_graphs: changed!(node_graphs),
        output: changed!(output),
        dmx_outputs: changed!(dmx_outputs),
        lighting_master: (before.lighting_master != after.lighting_master)
            .then_some(after.lighting_master),
        submasters: changed!(submasters),
        blackout: (before.blackout != after.blackout).then_some(after.blackout),
        authored_blackout: (before.authored_blackout != after.authored_blackout)
            .then_some(after.authored_blackout),
        safety_blackout_engaged: (before.safety_blackout_engaged != after.safety_blackout_engaged)
            .then_some(after.safety_blackout_engaged),
        clock: changed!(clock),
        stage_map: changed!(stage_map),
        stage_map_presets: changed!(stage_map_presets),
        stage_objects: changed!(stage_objects),
        dmx_preview: changed!(dmx_preview),
        dmx_previews: changed!(dmx_previews),
        telemetry: changed!(telemetry),
    }
}

#[cfg(test)]
#[path = "snapshot_sync_tests.rs"]
mod tests;
