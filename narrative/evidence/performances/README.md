# Novel field performances

Local art milestone `a6ca1fa`, parent `e601b4a`. The project was rendered in Godot 4.6.3 using prepared licensed human rigs. The test host supplies a private story state and active station in each sector. Camera, floor and lights are from the study. Oren is a covered child-sized form made for this sequence.

`field-performances.jpg` shows six stages. The willow, gallery and culvert directories include the closer art studies. `willow-full-carry.png` and `culvert-full-carry.png` include Kael with both the load and rear bearer. The observations about wrist position refer to measured joint targets, not individual fingers.

`field-runtime.json` and `render-runtime.json` record the same 36 checks in headless and rendered modes. The retained `verify_fields.gd` fixture extends the baseline cast verifier. The pose measurements are in `field-cast-render.log`. `field-files.json` identifies the 29 runtime files checked against the render project and the five authoring sources.

In the campaign owner's `NovelScenes.refresh()`, after reconciling station visibility and interaction, call:

```gdscript
preload("res://scripts/novel/field_performances.gd").project(self)
```

The scenery root is `res://assets/narrative_props/field/`. The runtime role-pack requests use the existing manifest and manager. The campaign owner still needs to check figure placement against the published levels, real station progression and archive availability across region changes.
