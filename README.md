# TWIST2: Scalable, Portable, and Holistic Humanoid Data Collection System
By Yanjie Ze, Siheng Zhao, Weizhuo Wang, Angjoo Kanazawa†, Rocky Duan†, Pieter Abbeel†, Guanya Shi†, Jiajun Wu†, C. Karen Liu†, 2025 († Equal Advising)


[[Website]](https://yanjieze.com/TWIST2)
[[arXiv]](https://arxiv.org/abs/2511.02832)
[[Video]](https://youtu.be/lTtEvI0kUfo)

![Banner for TWIST](./assets/TWIST2.png)


# News
- **2025-12-02**. 1st successfuly reproducing of TWIST2 appears. Check [his bilibili video](https://www.bilibili.com/video/BV1UbSeBNETw/?share_source=copy_web&vd_source=c76e3ab14ac3f7219a9006b96b4b0f76)
- **2025-12-02**. I will give a video tutorial for TWIST2 next week to show you how to use TWIST2. Please stay tuned.
- **2025-12-02**. TWIST2 is open-sourced now. Give it a star on GitHub!
   - Disclamer 1: with current repo, you should be able to control Unitree G1 via cable connection in both sim and real with a PICO VR headset. 
   - Disclamer 2: I am still working on better documentation and cleaning some onboard streaming and inference code (as the teleop pipeline is complex and requires some hardware setup). Please stay tuned.
   - Disclamer 3: The high-level policy learning part will be released in a separate repo. It is modifed from [iDP3](https://github.com/YanjieZe/Improved-3D-Diffusion-Policy) and I am working on releasing it soon.
- **2025-11-05**. TWIST2 is released. Full code will be released within 1 month (mostly ready and under the internal process). Please stay tuned.




# HP Robotics fork: setup with a Python venv (no conda, no Isaac Gym)

This fork runs **full-body teleoperation of the Unitree G1 with a PICO 4 (Ultra) + 2 PICO Motion Trackers**, in sim (`sim2sim`) and on the real robot (`sim2real`), using a single Python **venv** instead of the two conda environments of the original instructions below.

Tested on **Ubuntu 24.04, Python 3.12, CPU only** (no NVIDIA GPU needed: the provided ONNX policy takes ~0.15 ms per step on CPU).

What is different from upstream:
- One venv (`twist2/`, Python 3.12) holds everything: the low-level controller, GMR retargeting and the PICO SDK.
- **Isaac Gym is not needed** for deployment/teleop (only for training). `server_motion_lib.py` no longer requires it.
- Policies run on CPU by default (`DEVICE=cuda` to use a GPU).
- `sim2real.sh` forces the CycloneDDS bundled with `unitree_sdk2` (fixes `free(): invalid pointer` when ROS 2 is sourced).
- `sim2sim.sh` / `sim2real.sh` write the default standing pose to Redis before starting (`deploy_real/set_default_pose.py`).
- The teleop prints `[WARN] No PICO body tracking data` when the PICO is not streaming body data (before, it silently sent the default pose).
- The teleop emergency stop now really kills `server_low_level_g1_real.py`.
- Hands: only Unitree Dex3 is supported (`--use_hand`); with BrainCo hands leave it disabled (body teleop works, hands stay still).

## 1. Folder layout

Clone everything side by side (the scripts expect `unitree_sdk2_twist2` next to `TWIST2`):
```bash
mkdir -p ~/git_projects && cd ~/git_projects
git clone git@github.com:hproboticshub/TWIST2.git
git clone https://github.com/YanjieZe/GMR.git
git clone https://github.com/YanjieZe/unitree_sdk2.git unitree_sdk2_twist2
git clone https://github.com/YanjieZe/XRoboToolkit-PC-Service-Pybind.git
```

## 2. Python venv

Requires [uv](https://docs.astral.sh/uv/) (or use `python3 -m venv` + `pip`).
```bash
cd ~/git_projects/TWIST2
uv venv --python 3.12 twist2
source twist2/bin/activate

uv pip install torch --index-url https://download.pytorch.org/whl/cpu
uv pip install -r requirements-venv.txt
uv pip install -e ../GMR -e ./pose
```

## 3. Redis

```bash
sudo apt install -y redis-server
sudo systemctl enable --now redis-server
```
With everything running on the laptop, the default config (listen on `localhost`) is enough. Only open it to the network if another machine (e.g. the robot's onboard computer) must connect; in that case prefer binding to the robot network only (e.g. `bind 127.0.0.1 192.168.123.99` in `/etc/redis/redis.conf`), since `protected-mode no` exposes Redis without a password.

## 4. PICO (XRoboToolkit)

1. **PC service**: install the `.deb` from [XRoboToolkit-PC-Service releases](https://github.com/XR-Robotics/XRoboToolkit-PC-Service/releases) (`XRoboToolkit_PC_Service_1.0.0_ubuntu_24.04_amd64.deb` for 24.04) with `sudo apt install ./<file>.deb`. Open the `xrobotoolkit-pc-service` app before teleoperating.
2. **Headset app**: install `XRoboToolkit-PICO-1.1.1.apk` from [XRoboToolkit-Unity-Client releases](https://github.com/XR-Robotics/XRoboToolkit-Unity-Client/releases) (e.g. `adb install`).
3. **Python SDK** (`xrobotoolkit_sdk`), built into the venv:
    ```bash
    cd ~/git_projects/XRoboToolkit-PC-Service-Pybind
    mkdir -p tmp && git clone https://github.com/XR-Robotics/XRoboToolkit-PC-Service.git tmp/XRoboToolkit-PC-Service
    P=tmp/XRoboToolkit-PC-Service/RoboticsService/PXREARobotSDK
    bash $P/build.sh
    mkdir -p lib include
    cp $P/PXREARobotSDK.h include/ && cp -r $P/nlohmann include/ && cp $P/build/libPXREARobotSDK.so lib/
    source ~/git_projects/TWIST2/twist2/bin/activate
    uv pip install --no-build-isolation .
    ```

## 5. Unitree SDK Python binding (only for `sim2real`)

```bash
cd ~/git_projects/unitree_sdk2_twist2/python_binding
source ~/git_projects/TWIST2/twist2/bin/activate
export pybind11_DIR=$(python -c "import pybind11; print(pybind11.get_cmake_dir())")
bash build.sh --sdk-path $(pwd)/..
cp build/lib/unitree_interface.cpython-*-linux-gnu.so $(python -c "import site; print(site.getsitepackages()[0])")/
```

## 6. Check the install

```bash
cd ~/git_projects/TWIST2 && source twist2/bin/activate
cd /tmp && python -c "import torch, mujoco, onnxruntime, redis, general_motion_retargeting, pose, xrobotoolkit_sdk, unitree_interface; print('ok')"
```

## 7. Running

All scripts activate the venv themselves. Overridable variables: `DEVICE` (`cpu`/`cuda`), `NET` (robot network interface), `HUMAN_HEIGHT` (teleop, use a value slightly **below** your real height).

**PICO side (every session):**
1. Wear the 2 Motion Trackers on the ankles and calibrate them in the PICO **Motion Tracker** app (full body).
2. Open XRoboToolkit on the headset, connect to the laptop IP (`PC Service`), enable `Head`, `Controller`, PICO Motion Tracker mode `Full body`, and `Send`.
3. Keep the headset on your head (tracking pauses otherwise).

To check that body data arrives (with `teleop.sh` closed): `python deploy_real/check_pico.py` should show `body_available=True`.

**Sim (always test here first):**
```bash
bash sim2sim.sh     # terminal 1: G1 standing in MuJoCo
bash teleop.sh      # terminal 2: wait for "device found"; the g1_mocap window must follow you
```

**Real robot** (robot on the gantry, laptop on the robot network, e.g. `192.168.123.99/24`, `ping 192.168.123.164` works):
1. Unitree remote: `L2+R2` (dev mode, joints damped).
2. `NET=<your_iface> bash sim2real.sh` → press **START** on the Unitree remote (moves to default pose) → press **A** (`Begin main TWIST2 policy loop`).
3. `bash teleop.sh` in another terminal.

Do not run `sim2sim.sh` and `sim2real.sh` together (they share Redis keys and the CPU).

**PICO controls (teleop):**

| Button | Action |
|---|---|
| A (right) | idle → teleop → pause → teleop ... (stand upright before entering teleop) |
| X (left) | exit `teleop.sh` (interpolates back to default pose) |
| Left stick click | emergency stop: kills `sim2real.sh` |
| Triggers / grips | close / open hands (Dex3 only) |

On the real robot, **Select** on the Unitree remote exits the policy loop. Keep someone with the Unitree remote ready.

**Troubleshooting:**
- `free(): invalid pointer` in `sim2real.sh`: `unitree_interface` is loading ROS 2's CycloneDDS; check that `UNITREE_SDK2_PATH` (default `../unitree_sdk2_twist2`) is correct.
- `sim2real.sh` keeps printing `LowCommandWriter - No motor command available!`: it is waiting for **START** on the Unitree remote.
- Teleop prints `[WARN] No PICO body tracking data` / robot does not follow you after pressing A: the PICO is not streaming body data (trackers not calibrated, `Full body` not selected, or headset not worn).
- `Segmentation fault` when closing `teleop.sh` with Ctrl+C: harmless (PICO SDK teardown); exit with X instead.
- Low FPS (~25 Hz) when running `sim2sim.sh` + `teleop.sh` on a laptop: CPU bound; the real robot setup is lighter.

---

Original upstream instructions follow.

# Content Table

- [Installation](#installation)
- [Usage](#usage)
- [Citation and Contact](#citation-and-contact)


# Installation
We will have two conda environments for TWIST2. One is called `twist2`, which can be used for controller training, controller deployment, and teleop data collection. The other is called `gmr`, which can be used for online motion retargeting. This is because isaacgym requires python 3.8, but newest mujoco requires python 3.10.

**1**. Create conda environment:
```bash
conda env remove -n twist2
conda create -n twist2 python=3.8
conda activate twist2
```

**2**. Install isaacgym. Download from [official link](https://developer.nvidia.com/isaac-gym) and then install it:
```bash
cd isaacgym/python && pip install -e .
```

**3**. Install packages:
```bash
cd rsl_rl && pip install -e . && cd ..
cd legged_gym && pip install -e . && cd ..
cd pose && pip install -e . && cd ..
pip install "numpy==1.23.0" pydelatin wandb tqdm opencv-python ipdb pyfqmr flask dill gdown hydra-core imageio[ffmpeg] mujoco mujoco-python-viewer isaacgym-stubs pytorch-kinematics rich termcolor zmq
pip install redis[hiredis] # for redis communication
pip install pyttsx3 # for voice control
pip install onnx onnxruntime-gpu # for onnx model inference
pip install customtkinter # for gui
```

if this is your first time to use redis, install and start redis server:
```bash
# sudo apt install redis-server
# redis-server --daemonize yes

sudo apt update
sudo apt install -y redis-server

sudo systemctl enable redis-server
sudo systemctl start redis-server
```

edit `/etc/redis/redis.conf`:
```bash
sudo nano /etc/redis/redis.conf
```

modify to the following lines:
```bash
bind 0.0.0.0
protected-mode no
```

then restart redis-server:
```bash
sudo systemctl restart redis-server
```


**4**. if you wanna do sim2real with laptop, you also need to install my modified version of unitree sdk [here](https://github.com/YanjieZe/unitree_sdk2/tree/main/python_binding). (if you wanna do sim2real with onboard robot computer, no need to install unitree sdk on your laptop.)
```bash
# Clone the Unitree SDK2 repository
cd ..
git clone https://github.com/YanjieZe/unitree_sdk2.git
cd unitree_sdk2

# Install system dependencies
sudo apt-get update
sudo apt-get install build-essential cmake python3-dev python3-pip pybind11-dev

# Install Python dependencies
pip install pybind11 pybind11-stubgen numpy

# Build Python SDK binding
cd python_binding
export UNITREE_SDK2_PATH=$(pwd)/..
bash build.sh --sdk-path $UNITREE_SDK2_PATH

# Install the compiled module to your conda environment
# Get the site-packages path for your current conda environment
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
echo "Installing to: $SITE_PACKAGES"

# Copy the compiled module (rename to remove version-specific suffix)
sudo cp build/lib/unitree_interface.cpython-*-linux-gnu.so $SITE_PACKAGES/unitree_interface.so

# Verify installation
python -c "import unitree_interface; print('✓ Unitree SDK Python binding installed successfully')"
python -c "import unitree_interface; print('Available robot types:', list(unitree_interface.RobotType.__members__.keys()))"

cd ../..
```


**4**. [If you want to train your own controller, download data; otherwise, skip this step] Download TWIST2 dataset from [my google drive](https://drive.google.com/file/d/1JbW_InVD0ji5fvsR5kz7nbsXSXZQQXpd/view?usp=sharing) [Small note: if you use this dataset in your project, please also add proper citation to this work]. Unzip it to anywhere you like, and specify the `root_path` in `legged_gym/motion_data_configs/twist2_dataset.yaml` to the unzipped folder.

**Note**: we also provide a small set of example motions in `assets/example_motions`. You can use them to test the system. It is recorded by myself so no license issue.

**Note**: We also provide our controller ckpt `assets/ckpts/twist2_1017_20k.onnx` for you to test the system directly.


**5**. Install GMR for online retargeting and teleop. We use a separate conda environment for GMR/online retargeting due to requiring python 3.10+.
```bash
conda create -n gmr python=3.10 -y
conda activate gmr

git clone https://github.com/YanjieZe/GMR.git

cd GMR

# install GMR
pip install -e .
cd ..

conda install -c conda-forge libstdcxx-ng -y

```

**6**. Install PICO SDK:
1. On your PICO, install PICO SDK: see [here](https://github.com/XR-Robotics/XRoboToolkit-Unity-Client/releases/).
2. On your own PC, 
    - Download [deb package for ubuntu 22.04](https://github.com/XR-Robotics/XRoboToolkit-PC-Service/releases/download/v1.0.0/XRoboToolkit_PC_Service_1.0.0_ubuntu_22.04_amd64.deb), or build from the [repo source](https://github.com/XR-Robotics/XRoboToolkit-PC-Service).
    - To install, use command
        ```bash
        sudo dpkg -i XRoboToolkit_PC_Service_1.0.0_ubuntu_22.04_amd64.deb
        ```
        then you should see `xrobotoolkit-pc-service` in your APPs. remember to start this app before you do teleopperation.
    - Build PICO PC Service SDK and Python SDK for PICO streaming:
        ```bash
        conda activate gmr

        git clone https://github.com/YanjieZe/XRoboToolkit-PC-Service-Pybind.git
        cd XRoboToolkit-PC-Service-Pybind

        mkdir -p tmp
        cd tmp
        git clone https://github.com/XR-Robotics/XRoboToolkit-PC-Service.git
        cd XRoboToolkit-PC-Service/RoboticsService/PXREARobotSDK 
        bash build.sh
        cd ../../../..
        

        mkdir -p lib
        mkdir -p include
        cp tmp/XRoboToolkit-PC-Service/RoboticsService/PXREARobotSDK/PXREARobotSDK.h include/
        cp -r tmp/XRoboToolkit-PC-Service/RoboticsService/PXREARobotSDK/nlohmann include/nlohmann/
        cp tmp/XRoboToolkit-PC-Service/RoboticsService/PXREARobotSDK/build/libPXREARobotSDK.so lib/
        # rm -rf tmp

        # Build the project
        conda install -c conda-forge pybind11
        pip uninstall -y xrobotoolkit_sdk
        python setup.py install
        ```


**7**. Ready for training & deployment!

# Usage
We have provided the trained student ckpt in `assets/ckpts/twist2_1017_20k.onnx`. You can directly use it for deployment. If you want to deploy our ckpt directly, go to **4** directly.

And we have also provided full motion datasets to ensure you can successfully train our teacher & student policy.


**1**. Training TWIST2 general motion tracker:
```bash
bash train.sh 1021_twist2 cuda:0
```
- arg 1: policy expid
- arg 2: cuda device id

**2**. Export policy to onnx model:
```bash
bash to_onnx.sh $YOUR_POLICY_PATH
```
- arg 1: your policy path. you should find the `.pt` file's path.


**3**. Sim2sim verification:

[If this is your first time to run this script] you need to warm up the redis server by running the high-level motion server.
```bash
bash run_motion_server.sh
```
You can also just select one motion file from our motion dataset by modifying the `motion_file` in `run_motion_server.sh`.

Then, you can run the low-level controller server in simulation.
```bash
bash sim2sim.sh
```
- This will start a simulation that runs the low-level controller only.
- This is because we separate the high-level control (i.e., teleop) from the low-level control (i.e., RL policy).
- You should now be able to see the robot stand still. The robot is standing still because we make redis server send stand pose by default.

You can also see the policy execution FPS in the terminal. It should be around 50 Hz. If your laptop's GPU/CPU is not strong enough, the FPS may be lower and hurts the policy execution.
```bash
=== Policy Execution FPS Results (steps 1-1000) ===
Average Policy FPS: 38.88
Max Policy FPS: 41.55
Min Policy FPS: 24.72
Std Policy FPS: 1.92
Expected FPS (from decimation): 50.00
```

And now you can control the robot via high-level motion streaming.

**Note**: you need to open another terminal to run the high-level motion streaming.

We have provided two choices for you:

1) for offline motion streaming:
```bash
bash run_motion_server.sh
```


2) for online PICO teleop:
```bash
bash teleop.sh
```



 

**4**. Sim2real verification. If you are not familiar with the deployment on physical robot, you can refer to [unitree_g1.md](./unitree_g1.md) or [unitree_g1.zh.md](./unitree_g1.zh.md) for more details.

More specifically, the pipeline for sim2real deploy is:
1. start the robot and connect the robot and your laptop via an Ethernet cable.
2. config the corresponding net interface on your laptop, by setting the IP address as `192.168.123.222` and the netmask as `255.255.255.0`.
3. now you should be able to ping the robot via `ping 192.168.123.164`.
4. then use Unitree G1's remote control to enter dev mode, i.e., press the `L2+R2` key combination.
5. now you should be able to see the robot joints in the damping state.
6. then you can run the low-level controller by:
```bash
bash sim2real.sh
```
- please set the network interface name to your own that connects to the robot in `sim2real.sh`.




Similarly, you run the low-level controller first and then control the robot via high-level motion server, i.e.,
1) offline motion streaming:
```bash
bash run_motion_server.sh
```
2) or online PICO teleop:
```bash
bash teleop.sh
```


**5**. GUI interface for everything. Check `gui.sh` for more details.
```bash
bash gui.sh
```
You should be able to
1) run the low-level controller in simulation
2) run the low-level controller on physical robot
3) run the high-level motion streaming in offline mode
4) run the high-level motion streaming in online PICO teleop mode
5) run the data collection script
6) run the neck controller script
7) run the ZED streaming script
all in this GUI. This GUI is also what I use for data collection and teleoperation.


# Citation and Contact
If you find this work useful, please cite:
```bibtex
@article{ze2025twist2,
title={TWIST2: Scalable, Portable, and Holistic Humanoid Data Collection System},
author= {Yanjie Ze and Siheng Zhao and Weizhuo Wang and Angjoo Kanazawa and Rocky Duan and Pieter Abbeel and Guanya Shi and Jiajun Wuand C. Karen Liu},
year= {2025},
journal= {arXiv preprint arXiv:2511.02832}
}
```
And also consider citing the related works:
```bibtex
@article{ze2025twist,
title={TWIST: Teleoperated Whole-Body Imitation System},
author= {Yanjie Ze and Zixuan Chen and João Pedro Araújo and Zi-ang Cao and Xue Bin Peng and Jiajun Wu and C. Karen Liu},
year= {2025},
journal= {arXiv preprint arXiv:2505.02833}
}

@article{joao2025gmr,
title={Retargeting Matters: General Motion Retargeting for Humanoid Motion Tracking},
author= {Joao Pedro Araujo and Yanjie Ze and Pei Xu and Jiajun Wu and C. Karen Liu},
year= {2025},
journal= {arXiv preprint arXiv:2510.02252}
}
```
If you have any questions, please contact me at `yanjieze@stanford.edu`.


# Acknowledgments
We use [AMASS](https://amass.is.tue.mpg.de/) and [OMOMO](https://arxiv.org/abs/2309.16237) motion datasets for research purposes only. Our code is built upon the [TWIST](https://github.com/YanjieZe/TWIST) repository.
