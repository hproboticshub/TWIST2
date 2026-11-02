#!/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))
source ${SCRIPT_DIR}/twist2/bin/activate

# use the CycloneDDS bundled with unitree_sdk2, not the one from ROS 2 (e.g. /opt/ros/jazzy)
# -> otherwise unitree_interface crashes with "free(): invalid pointer"
UNITREE_SDK2_PATH=${UNITREE_SDK2_PATH:-${SCRIPT_DIR}/../unitree_sdk2_twist2}
export LD_LIBRARY_PATH=${UNITREE_SDK2_PATH}/thirdparty/lib/x86_64:$LD_LIBRARY_PATH

ckpt_path=${SCRIPT_DIR}/assets/ckpts/twist2_1017_20k.onnx

# network interface connected to the robot (check with `ip -br link`), override with: NET=<iface> bash sim2real.sh
net=${NET:-enxf44dad0705a2}
# cpu or cuda, override with: DEVICE=cuda bash sim2real.sh
device=${DEVICE:-cpu}

cd ${SCRIPT_DIR}/deploy_real

# always start from the default standing pose
python set_default_pose.py

python server_low_level_g1_real.py \
    --policy ${ckpt_path} \
    --net ${net} \
    --device ${device} \
    # --use_hand \  (only supports Unitree Dex3; BrainCo hands not supported yet)
    # --smooth_body 0.5
    # --record_proprio \
