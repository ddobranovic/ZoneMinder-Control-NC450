# ZoneMinder camera control script

## TP-Link NC450 v2
* tested with firmware **1.5.0 Build 181022 Rel.3A033D**


## Install instruction
### Add protocol file NC450.pm to ZoneMinder
```
cd /usr/share/perl5/ZoneMinder/Control/
wget https://raw.githubusercontent.com/ddobranovic/ZoneMinder-Control-NC450/master/NC450.pm
chmod +x ./NC450.pm
```

### Enable PTZ Support on ZoneMinder (if not enabled)
```
Options -> System -> OPT_CONTROL: Check
```
### Add the Control Type
* Click on any camera "source" column. That will bring up your configuration window for that camera
* Click on tab Control and then click "Edit" next to Control Type.
* Click on "Add New Control"

**Main**
```
Name:TP-Link NC450
Type:Ffmpeg
Protocol:NC450
Can Wake:Uncheck
Can Sleep:Uncheck
Can Reset:Uncheck
```

**Move**
```
Can Move:Check
Can Move Diagonally:Check
Can Move Continuous:Check
```

**Pan**
```
Can Pan:Check
```

**Tilt**
```
Can Tilt:Check
```

**Zoom**
```
Can Zoom:Uncheck
```

**Focus**
```
Can Focus:Uncheck
```

**White**
```
Can White Balance:Check
Can White Bal.Absolute:Check
Min White Bal.Range:0
Max White Bal.Range:128
Min White Bal.Step:1
Max White Bal.Step:1
```

**Iris**
```
Can Iris:Check
Can Iris Absolute:Check
Min Iris Range:0
Max Iris Range:128
Min Iris Step:1
Max Iris Step:1
```

**Preset**
```
Has Presets:Check
Num Presets:0
Has Home Preset:Check
Can Set Presets:Uncheck
```

### Add camera or edit existing
** General **
```
Source Type: Ffmpeg
```
** Source **

```
Source Path: rtsp://username:password@IP_CAM_ADDRESS:554/h264_hd.sdp
Method: TCP
Target colorspace: 24 bit colour
Capture Width (pixels): 1280
Capture Height (pixels): 720
```

** Control **

```
Controllable: Check
Control Type: TP-Link NC450
Control Device:
Control Address:username:password@IP_CAM_ADDRESS:2020
Auto Stop Timeout:1.0
```
