# Full cast voice production

## Intended result

Replace the older Piper dialogue with more natural synthetic speech for the full speaking cast. Preserve exact story text, distinct character identity and player-controlled conversations. Include supporting characters and nearby village remarks. Build, push and deploy without tests, listening reviews or gameplay verification, following the user's instructions.

## Production approach

Use Kokoro-82M v1.0 through kokoro-onnx 0.6.1. The full-precision model and inference dependencies remain local build tools. Fixed voice blends and modest per-character speaking rates establish 28 cast recipes. Scene cadence slows slightly for intimate exchanges; it does not pretend to provide emotional prompting, which this model does not support. Existing character direction and story content determine the casting.

The production tool covers the three dialogue catalogs independently, every variant, optional conversation topics and authored village remark pools. It retains the runtime's exact speaker/text key. Previously missing aliases cover the smith, farmer, widow, named court officials, guards and servant. Narration and written objects remain text-led.

Each recording is mastered with bounded gain and short edge ramps, retaining internal breaths and pauses. Speech-motion envelopes are regenerated from the delivered Ogg audio. Model, cast, text and mastering recipes invalidate the old cache, so a Piper recording cannot masquerade as a newly generated performance.

## Runtime changes

- Nearby remarks use positional voice playback, follow the speaker, and allow one local voice at a time.
- Dialogue interrupts nearby chatter. World pauses suspend it; hidden or removed speakers release it.
- Nearby captions remain visible for the recording's duration. Music ducks gently beneath chatter and more strongly during conversation.
- Supporting characters participate in the same voice-timed speaking/listening system as the principal cast.
- Ten stage directions in work and aftermath conversations are explicitly assigned to narration, so characters do not read descriptions of their own actions aloud.
- Updated in-game credits and retained model provenance identify the generated performances honestly.

## Limits

These remain synthetic recordings. The task includes no listening review or gameplay verification, so no claim of human-actor quality or verified pronunciation is made. No human voice was cloned. The game needs no speech-service credentials or inference model at runtime.

## Research

- [Kokoro model and licensing](https://huggingface.co/hexgrad/Kokoro-82M)
- [Model author's voice guidance](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)
- [kokoro-onnx inference implementation](https://github.com/thewh1teagle/kokoro-onnx)

The model author notes limitations at very short and long utterance lengths. Whole dialogue pages retain surrounding sentence context; the inference library splits text at its model limit. Voice presets and casting are selected from documented capabilities, without an audition under the user's no-verification constraint.
