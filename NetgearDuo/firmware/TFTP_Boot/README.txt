NETGEAR ReadyNAS TFTP Boot Recovery Instruction
===============================================

In case of boot problems perhaps due to a flash corruption on the
ReadyNAS, the TFTP Boot Recovery Instruction allows you to rewrite the
boot image on flash and restore your ReadyNAS to a known good firmware
image.

Before continuing, if you haven't done so, unzip the content of the
TFTP_Boot.zip onto your hard disk.  You should see a TFTP_Boot folder.

-----------------------------------------------------------------------
Follow the instructions here to upload and install the TFTP boot image.
-----------------------------------------------------------------------

1.  Connect your PC directly to the ReadyNAS and set the IP address of
    the PC to 192.168.125.1 with subnet mask 255.255.255.0.  Make sure
    the ReadyNAS is powered off.

2.  Start TFTPD32.exe.

3.  Set the TFTPD32 timeout to 10 seconds in Settings.

4.  Make sure that the current directory of TFTPD is set to where you 
    have downloaded the files, and the server interface is showing 
    192.168.125.1.

5.  Close all other window applications including RAIDar and your browser.

    IMPORTANT: Disable any firewall software. It will prevent the NAS to
    communicate with the PC.

6.  Press power button on the front of the ReadyNAS and keep it depressed
    for about 10 seconds, and release when all disk LEDs flash for the 2nd
    time.  The disk LEDs will flash at 5 secs and again at 10 secs. When the
    unit first powers up, there is a very quick flash of the LEDs (less then
    a second), ignore this power on flash, only looking for the +1 second
    longer flashes.

7.  Disk LED 1 and 4 will stay lit.  If these LEDs are not lit, you must 
    go back to step 6 and try again. 

8.  Monitor the TFTPD window as it should show uploading kernel_conf and 
    initrd_conf.

9.  Lastly TFTPD will upload the RAIDiator image to the ReadyNAS. The image
    is about 45 MB, so it will take several minutes.  It's possible that
    the transfer will fail several times due to timeouts.  In that case,
    you may need to try connecting the ReadyNAS and the PC via a
    router/switch and increase the timeout value in the TFTPD setting.

10. If the transfer is successful, your system should come up shortly 
    after.  To complete the firmware installation, perform the 5-sec reset 
    by holding the hidden System Reset Switch on the back of the ReadyNAS
    for about 5 seconds, until you see the 4 disk LEDs blink once, while 
    powering on the system.

Please be aware that the TFTP protocol is not robust and you may encounter
timeout issues.  Try again if you encounter a timeout.


If you require more assistance, please contact NETGEAR Support:
 Phone: http://kb.netgear.com/app/answers/detail/a_id/984
   Web: http://my.netgear.com/myNETGEAR/support.asp
 Forum: http://www.readynas.com/forum/
