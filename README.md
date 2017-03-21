# D-Video

A system to pump digital video out of vintage home computers.

While there are many mods available to make the video quality of old home computers and consoles
look better on modern displays, most of them are using analog technology (S-Video or RGB or such).
Analog signals are always prone to distortion and some rest of static noise always remains.

To overcome this problem and to get pixel-perfect quality identical to what an emulator could do, 
I am working on a system that extracts the video information directly at the pins of the video chip
and transfer this signals to a converter that can generate crisp clear HDMI from it.
Clearly for every computer model there is a different way how to extract video information from the
video chip, and so the converter device must support all different signal types needed. 

That will be done by using an FPGA that can be programmed to the meet the specific requirements 
of the system. In the first step I am using an external FPGA board (specifically the 
Cylcone V GX starter kit), but I am planning to design and build a small fpga board that can be 
fit into each vintage computer in question.

Currently supported devices:
	Atari 800 XL PAL   (probably every 8-bit Atari PAL)
	