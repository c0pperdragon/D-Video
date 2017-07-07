# D-Video board

This is the heart of the whole project. A multi-purpose FPGA board with 
a HDMI transmitter that is capable of generating full HD.
In my research if found many cheap FPGA boards, but 
only one was able to actually generate full HD images (the Cyclone 5 GX Starter Kit),
and this was not actually that cheap. Also it was a full-blown experimental board
with tons of features that would never fit into a vintage computer.
So I decided to create my own bare-bone FPGA board with an HTMI transmitter.

Using a device of the MAX 10 series seemed to be quite the right choice, mainly because
it is available as a TQFP package which can still be somehow handled by a hobbyist
(still, it took some attempts until I actually managed so assemble a working board).

Next to the MAX 10 is a ADV7513 HDMI transmitter that takes care of the real 
high-frequency signal generation. The data path from the FPGA to the transmitter
is is very short and the parallel 145Mhz signals seem to be running just fine.

The board has a 31-bin GPIO connector for any sort of digital communication, its main
purpose for my general project is to sniff the various pins in a vintage computer
system to compute a digital live image of the video output.
