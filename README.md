# D-Video

A system to pump digital video out of vintage home computers.

While there are many mods available to make the video quality of old home computers and consoles
look better on modern displays, most of them are using analog technology (S-Video or RGB or such).
Analog signals are always prone distortion and some rest of static noise always remains.

To overcome this problem and to get pixel-perfect quality identical to what an emulator could do, 
I am working on a system that extracts the video information directly at the pins of the video chip
and transfer this signals to an external converter device that can generate crisp clear HDMI from it.
This converter is pluggable to any device with an D-Video interface and is only needed once for a whole set
of different computers with an D-Video mod.

Clearly for every computer model there is a different way how to extract video information from the
video chip, and so the converter device must support all different signal types needed. The exact 
specification of the signals for any type of computer needs to be defined when such a mod is invented
and implemented in the converter device. 

To make usage easier, the converter can detect the type of computer in use and will work for every 
computer that meets its D-Video specification without further configuration.

D-Video is intended to be something like a kind of poor man's DVI just for the purpose of getting 
video data out of existing machines with inexpensive modifications. 

Currently supported devices:
	Atari 800 XL PAL   (probably every 8-bit Atari PAL)
	