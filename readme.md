Crazyflie 2 iOS client
======================

Crazyflie 2 client for iPhone.

Functionalities:

 - Can connect and control a Crazyflie 2 via Bluetooth Smart
 - Choice of control mode and sensitivity
 - Can update Crazyflie with the latest firmware version (not released yet)

 This app requires iOS 8 or higher.

## How to compile

This project is using [cocoapods](https://cocoapods.org/) to import dependencies.
It means that you need to have cocoapods installed on your system and install
the pods to open the project:

```
~ $ cd path/to/crazyflie2-ios-client
crazyflie2-ios-client $ pod install
Updating local specs repositories
Analyzing dependencies
Downloading dependencies
Installing zipzap (8.0.4)
Generating Pods project
Integrating client project

[!] Please close any current Xcode sessions and use `Crazyflie client.xcworkspace` for this project from now on.
crazyflie2-ios-client $ open Crazyflie\ client.xcworkspace
```

You can then compile and run the app from XCode.

See the [Bitcraze wiki](https://wiki.bitcraze.io) for more information about
Crazyflie and the communication protocols.
