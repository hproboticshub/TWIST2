#!/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))
source ${SCRIPT_DIR}/twist2/bin/activate

ckpt_path=${SCRIPT_DIR}/assets/ckpts/twist2_1017_20k.onnx
# cpu or cuda, override with: DEVICE=cuda bash sim2sim.sh
device=${DEVICE:-cpu}

cd ${SCRIPT_DIR}/deploy_real

# always start from the default standing pose
python set_default_pose.py

python server_low_level_g1_sim.py \
    --xml ../assets/g1/g1_sim2sim_29dof.xml \
    --policy ${ckpt_path} \
    --device ${device} \
    --measure_fps 1 \
    --policy_frequency 100 \
    --limit_fps 1 \
    # --record_proprio \
