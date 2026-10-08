---
name: complete-hx4s20c-hdmi-project
description: Complete, extend, diagnose, synthesize, and verify the HX4S20C/EG4S20 FPGA HDMI multimedia competition project in lab_ex5_i2s. Use when Codex must implement any basic or extended competition requirement, modify the Verilog/constraints/Tang Dynasty project, add BMP playback, double buffering, HDMI audio, OSD/Alpha layers, image transitions, image scaling, brightness or contrast controls, audio visualization, generate a bitstream, or assess whether the submission satisfies 赛题解析一.
---

# Complete the HX4S20C HDMI project

Treat the supplied project and board documentation as the source of truth. Implement working HDL, integrate it into the Tang Dynasty project, and verify it. Do not stop at a design proposal when the user asks to complete or modify the project.

## Load only the needed references

- Always read [competition-requirements.md](references/competition-requirements.md) before deciding scope or claiming compliance.
- Read [project-map.md](references/project-map.md) before editing HDL, clocks, constraints, or project files.
- Read [acceptance-checklist.md](references/acceptance-checklist.md) before verification or handoff.
- Read [master-prompt.md](references/master-prompt.md) only when the user asks for a reusable prompt, delegation prompt, or full-project execution request.

## Workflow

1. Resolve the project root from the current workspace. Confirm that `赛题解析一.pptx`, `src/user_source`, and the `.al` project exist.
2. Inspect the actual HDL and project file before relying on the status described in the references. Existing files may have changed since this skill was created.
3. Build a requirement matrix with four states: implemented, partially implemented, missing, or blocked by unavailable hardware information.
4. Preserve working basic functions while implementing the requested items. Work in dependency order:
   - TF/BMP ingestion and SDRAM frame buffering.
   - Stable HDMI video and manual/automatic image switching.
   - HDMI 48 kHz audio.
   - OSD and transitions.
   - Scaling and live display controls.
   - Audio visualization and optional creative extensions.
5. Edit source files with minimal, reviewable changes. Add every new HDL file to the `.al` project and generated `.prj` files used by the active synthesis/implementation runs.
6. Run `scripts/verify_project.ps1` after structural changes. Run it with `-RunSynthesis` after HDL changes and `-RunImplementation` before final handoff when the TD toolchain is available.
7. Inspect synthesis and implementation output. Separate new failures from pre-existing warnings or timing exceptions. Never call a build successful merely because a `.bit` file already existed.
8. Report what is proven in tools and what still requires board testing. Never claim physical HDMI, TF-card, key, audio, or power-cycle behavior without an on-board test.
9. Save each completed iteration with `scripts/save_iteration.ps1`. The script verifies the project, creates a local Git commit, and attempts to push `origin/main`. If direct Git push fails, preserve the local commit and use the connected GitHub connector to upload the checkpoint to `gezhe1012/lab_ex5_i2s`; confirm the remote commit before claiming success. Read [versioning.md](references/versioning.md) for the exact command and commit conventions.

## HDL design rules

- Keep the established clock plan unless a requirement forces a change: 50 MHz board input, 100 MHz SD domain, 125 MHz SDRAM domain, 25 MHz 640x480 video domain, and 12.288 MHz audio master clock.
- Cross clock domains with FIFOs, toggle handshakes, or properly synchronized level signals. Do not pass one-cycle pulses directly between unrelated clocks.
- Change the displayed SDRAM buffer only at a frame boundary and only after the destination frame has been completely written.
- Keep active video RGB, DE, VS, and AXI-stream framing aligned. Pipeline them together whenever a new registered pixel stage is inserted.
- Keep the first display frame black until valid image data is committed.
- Implement OSD after image processing and before HDMI AXI-stream packing unless the requested composition order requires otherwise.
- Use bounded fixed-point arithmetic. State coefficient widths, rounding or truncation behavior, and saturation behavior for scaling, brightness, contrast, Alpha blending, FFT/DFT, and waveform rendering.
- Avoid inferred division by variable values in per-pixel paths. Use constants, reciprocal multiplication, phase accumulators, or staged address generators.
- Do not invent FPGA pins. Read the board manual/schematic or existing `.adc` constraints first. If the required switch or external interface pin is unavailable, stop only that hardware-dependent part and identify the exact missing mapping.
- Preserve synthesizable Verilog compatibility with the installed Anlogic TD version. Do not introduce SystemVerilog-only constructs unless the project is configured for them.
- Keep IP wrapper files and encrypted vendor sources unchanged unless the user explicitly requests an IP reconfiguration.

## Implementation expectations by feature

### Basic image playback

- Accept genuine 640x480, 24-bit RGB, uncompressed BMP files for the baseline path.
- Parse and validate headers before committing image data.
- Use SDRAM double buffering so a new image is written away from the displayed buffer.
- Keep KEY1 manual next-image behavior and KEY2 automatic-play enable behavior debounced.
- Prevent damaged or unsupported files from permanently blocking the scan/load state machine.

### HDMI audio

- Generate or receive 24-bit PCM at 48 kHz.
- Keep the I2S receiver, ACR CTS/N generation, HDMI transmitter audio ports, and reset/PLL-lock behavior consistent.
- Verify the selected HDMI connector and DDC pins from project constraints.

### OSD and transitions

- Provide visible dynamic content, not only a static rectangle. Suitable evidence includes a running timestamp, moving caption, image number, or changing parameter value.
- Use explicit Alpha blending for at least one layer.
- Perform transitions only after a complete destination frame is available. A fade-to-black, frame-boundary buffer switch, and fade-in is acceptable when simultaneous dual-frame reads are impractical.

### Scaling and live controls

- Parse source width, height, orientation, pixel offset, bit depth, and compression from the BMP header.
- Define the aspect-ratio policy: stretch, fit with letterbox/pillarbox, or crop.
- Prefer a phase-accumulator scaler. Add line buffering for bilinear interpolation; use nearest-neighbor only when the user accepts the quality tradeoff.
- Saturate brightness/contrast output to 0..255 and overlay current values on screen.

### Audio visualization

- Tap stable 24-bit PCM samples before HDMI packetization.
- Use a waveform renderer for the lowest-risk implementation. Add FFT/DFT bars when resources and schedule permit.
- Cross audio-domain measurements into the video domain through stable snapshots or a handshake; do not read changing multi-bit values asynchronously.

## Verification and handoff

- Use the acceptance checklist and retain the full competition requirement matrix.
- Run the structural checker from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\complete-hx4s20c-hdmi-project\scripts\verify_project.ps1
```

- For synthesis or implementation, use the corresponding switch. The script locates the configured TD command tool and invokes the existing run directories.
- Confirm that the output bitstream timestamp is newer than the edited HDL files.
- In the final response, link the modified HDL, project file, and generated `.bit`. State resource usage and timing results when available. List any board tests still required.
