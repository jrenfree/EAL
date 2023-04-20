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
7. Select **Add**
8. Click **OK**

## EAL Interface

Once installed, run the EAL by opening the EAL_app.exe application. The following GUI interface should appear:

<img src="../master/Figures/EAL_GUI.png" alt="Image of EAL GUI" width=600/>

The Input panel contains a number of checkboxes that toggle the following options:
   - **Measure noise**: If selected, the EAL will periodically place the transceivers into passive mode and record a number of transmissions. The interval between noise measurements, the number of passive transmissions, and the desired recording range are specified in the "Noise Measurement Settings" section of the EAL's settings file (see section below).
   - **Correct false bottom**: If selected, the EAL will attempt to eliminate false bottom echoes by placing the EK80 in "Interval" mode and strategically setting the ping interval. Choosing this option also enables the ability to load a bathymetry database, which can be used to estimate the current seabed depth in areas where the depth is greater than the maximum logging range. If opting to not correct false bottoms, the EAL will place the EK80s in "Maximum" ping rate mode.
   - **Check Deep Bottom** (currently depecrated): This option allows the EAL to periodically have the EK80 record a small number of pings to a long range, in order to empirically measure the seabed depth to try and avoid false bottoms when in areas where the seabed is deeper than the maximum logging range. It is recommended to use either a bathymetry database or an external depth sensor over this option.
   - **Unlock display range**: If selected, the EAL will set the EK80 echogram display ranges to those specified in the "Display Settings" section of the EAL's settings file, as long as they are shallower than the maximum logging range. This is useful when in deep water but desiring to zoom in on a shallow portion of an echogram. If the desired display range is deeper than the maximum logging range, the echogram display will be limited to the maximum logging range.
   - **Set ping interval** (currently depecrated): This option allows the user to manually specify a ping interval that they desire the EK80 to use for a set period of time, as specified by the "Manual Ping Interval Override Time" parameters in the EAL's settings file. This is typically used when the EAL is unable to correctly avoid false bottoms and the user wants to override the ping interval to achieve better results. This option will likely be removed in future releases.
   - **K-Sync**: If selected, the EAL will send the desired ping interval (converted into a pseudo "depth" value) to a K-Sync trigger system. The K-Sync can then read this external depth value and use it to adjust the timing of trigger groups. This is useful for when using a K-Sync system to synchronize transmissions between multiple sounders.

## Setting up the EAL

The main settings for the EAL are specified in the text file "C:\ProgramData\EAL\EAL_Settings.txt". This file can be opened by clicking the "Open Settings" button on the EAL interface. It is recommended to delete this file when updating to a new release of the EAL so that a new version of the settings file can be generated to apply any changes.

## Running the EAL

Operation of the EAL is typically performed by the following:

   1. Open the EK80 software and begin pinging the transceivers in their desired operation
   2. Open the EAL application
   3. Choose the desired options, as specified in the EAL Interface section
   4. Define the appropriate settings in the EAL's Settings.txt file
   5. Click the **START** button
