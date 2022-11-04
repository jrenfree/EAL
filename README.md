# EK80 Adaptive Logger (EAL)

The EK80 Adaptive Logger (EAL) interfaces with the Simrad EK80 software to modulate the ping interval and logging and display ranges based on the seabed depth. For example, as the seabed becomes shallower, the echosounder can accordingly record to a shallower range, which in turn allows for a shorter ping interval (or faster ping rate). Additionally, the EAL has the option to modulate the ping interval to avoid aliased seabed echoes (aka false bottoms), which occur when the seabed reflection from a prior ping reaches the transducer during a subsequent ping recording.

<img src="../master/Figures/EAL_GUI.png" alt="Image of EAL GUI" width=600/>

## Installation

To install the EAL with Internet access, download and run the following executable:

[https://github.com/jrenfree/EAL/blob/master/EAL_App/for_redistribution/EAL_installer_web.exe](https://github.com/jrenfree/EAL/blob/master/EAL_App/for_redistribution/EAL_installer_web.exe)

Follow the prompts to install the application. The default directory is **C:\Program Files\EAL**. If not already installed, the EAL installer will additionally download and install the Matlab Compiler Runtime, which is required to run the EAL.

### Allow through firewall

After the installation is complete, it will be necessary to add the application (EAL_App.exe) to the firewall exemption list in order for the EAL to communicate with the EK80 software. To do so, complete the following:

1. Click in the taskbar search menu (or press the Windows logo button on the keyboard), then search for and select **Allow an app through Windows Firewall**
2. Select **Change settings**  
   <img src="../master/Figures/firewall_changeSettings.png" width=400/>  
3. Select **Allow another app...**
4. Select **Browse**
5. Browse to the directory where the EAL application was installed (default is C:\Program Files\EAL), then to the **application** subdirectory, then select the file **EAL_App.exe** (e.g., C:\Program Files\EAL\application\EAL_app.exe)
6. Select **Open**
