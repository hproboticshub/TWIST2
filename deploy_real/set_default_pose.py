"""Write the default standing pose to Redis so the low-level controller starts from a safe target."""
import argparse
import json

import redis

from data_utils.params import DEFAULT_MIMIC_OBS_G1

parser = argparse.ArgumentParser()
parser.add_argument("--redis_ip", type=str, default="localhost")
args = parser.parse_args()

r = redis.Redis(host=args.redis_ip)
r.set("action_body_unitree_g1_with_hands", json.dumps(DEFAULT_MIMIC_OBS_G1.tolist()))
r.set("action_hand_left_unitree_g1_with_hands", json.dumps([0.0] * 7))
r.set("action_hand_right_unitree_g1_with_hands", json.dumps([0.0] * 7))
r.set("action_neck_unitree_g1_with_hands", json.dumps([0.0, 0.0]))
print(f"Default standing pose written to Redis ({args.redis_ip})")
