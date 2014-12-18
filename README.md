# DarkBoot
This script enables the black boot screen + white Apple logo on "unsupported" Macs.

![Preview](example.png)

### Information:
**Note**: This may break in the future.

Confirmed working on:    
**10.10.0** (14A389)    
**10.10.1** (14B25)    
**10.10.2** (14C81f)    

### How to use:
**If you want dark the boot screen:**    
Download and run DarkBoot.command then restart twice.

**If you want gray the boot screen:**    
Download and run DarkBoot.command    
	If you're prompted that your ID already exists in boot.efi    
		Enter 'y' to remove your ID then run Darkboot a 2nd time to add your ID back then run Darkboot a 3rd time to remove your ID again. To finish restart twice.    
	If your ID doesn't already exist in boot.efi    
		After Darkboot adds your ID run Darkboot again to remove your ID. To finish restart twice.

**If you have the gray boot screen but DarkBoot says your ID is already present:**    
	Enter 'y' to remove your ID then run Darkboot a 2nd time to add your ID back. To finish restart twice.
	
### License:
Pretty much the BSD license, just don't repackage it and call it your own please!

Also if you do make some changes, feel free to make a pull request and help make things more awesome!