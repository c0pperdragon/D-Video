# D-Video

A system to pump digital video out of vintage home computers.

While there are many mods available to make the video quality of old home computers and consoles
look better on modern displays, most of them are using analog technology (S-Video or RGB or such).
Analog signals are always prone to distortion and some rest of static noise always remains.

To overcome this problem and to get pixel-perfect quality identical to what an emulator could do, 
I have created a system that extracts the video information directly at the pins of the video chip
and transfer this signals to a converter that can generate crisp clear HDMI from it.
Clearly for every computer model there is a different way how to extract video information from the
video chip, and so the converter device must support all different signal types needed. 

That is done by using an FPGA that can be programmed to the meet the specific requirements 
of the system. For this I have designed my on FPGA board which I called the 
D-Video board that is based on a MAX 10 which is a pretty cheap device in comparison
with more powerful chips. With 8K elements and about 380kBit of memory, it just
covers what I need for my projects.

To feed the data into this FPGA, an additional modification board for each computer is needed
that converts the voltages from the pins to 3.3V levels. 

Currently supported devices:
	Atari 800 XL PAL   (probably every 8-bit Atari PAL)

