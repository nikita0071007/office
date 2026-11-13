# Office Agents 3D Preview

This Godot project opens a real-time 3D office scene with an interactive camera, a photo-based view of Lisa, and a selectable roster for the office's 11 agents.

Open the `godot` folder in Godot 4 and run `Main.tscn`. Select an agent in the left roster to see its role, status, and current task. Drag with the left mouse button to orbit, use the wheel to zoom, and use the reset button to restore the starting view.

The room uses low-poly box meshes and Godot's Compatibility renderer. Agent data is read from the local `status.json` snapshot when the scene starts; it does not refresh from the network yet. Lisa is currently a transparent billboard image, so the project remains lightweight while a true 3D character model is unavailable.
