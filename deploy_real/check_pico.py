"""Diagnose what the PICO is streaming via XRoboToolkit (body trackers, headset, buttons)."""
import time

import xrobotoolkit_sdk as xrt

xrt.init()
print("Waiting for data... (Ctrl+C to stop)")
try:
    while True:
        body = xrt.is_body_data_available()
        head = xrt.get_headset_pose()
        a = xrt.get_A_button()
        line = f"body_available={body}  headset_xyz={[round(v, 2) for v in head[:3]]}  A={a}"
        if body:
            joints = xrt.get_body_joints_pose()
            pelvis = joints[0]
            line += f"  n_joints={len(joints)}  pelvis_xyz={[round(v, 2) for v in pelvis[:3]]}"
        print(line, flush=True)
        time.sleep(0.5)
except KeyboardInterrupt:
    pass
finally:
    if hasattr(xrt, "close"):
        xrt.close()
