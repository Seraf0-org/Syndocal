import { Index, Show } from "solid-js";
import type { VisualizerFixtureBeam } from "../mappingRuntime";

export interface MappingBeamFixture {
  id: number;
  beamPoints: string;
  beamDescription?: string;
  beams?: VisualizerFixtureBeam[];
  intensity: number;
  color: string;
}

type MappingBeamsLayerProps = {
  fixtures: MappingBeamFixture[];
};

export function MappingBeamsLayer(props: MappingBeamsLayerProps) {
  return (
    <Index each={props.fixtures}>
      {(fixture) => {
        const beams = () => fixture().beams ?? [{
          cellIndex: 1,
          points: fixture().beamPoints,
          intensity: fixture().intensity,
          color: fixture().color,
        }];
        return (
          <Show when={fixture().intensity > 0}>
            <Index each={beams()}>
              {(beam) => (
                <polygon
                  class="stageBeam"
                  data-stage-beam-fixture-id={fixture().id}
                  data-stage-beam-cell={beam().cellIndex}
                  points={beam().points}
                  fill={beam().color}
                  opacity={Math.max(0.08, beam().intensity * 0.55)}
                ><title>{fixture().beamDescription}</title></polygon>
              )}
            </Index>
          </Show>
        );
      }}
    </Index>
  );
}
