# Clutch
Interface binding for Transmission (Mac)

Hi guys, for several years I've been using this horrible app called Vuze because it was the only app for Mac that offered "connection binding," where I could send traffic over my VPN connection only.

I finally wrote an app called Clutch to add this feature to Transmission! It is a separate app so you don't have to worry about patching, and it will continue to work when new updates to Transmission are released.

## How does it work?

Transmission has a hidden option in its preferences file called "BindAddressIPv4" (and IPv6), which allows you to bind Transmission to an IP address. This is a nice feature, but it's a major inconvenience to have to update this address every time you start a new VPN connection. Clutch takes care of this for you!

The app has 2 parts:

* Clutch is the GUI part of the app and allows you to select the interface you want to bind Transmission to.
* Clutch Agent runs in the background (it has an icon in the menu bar) and monitors the IP address of the binding interface. When the IP address changes, it will update the binding IP address in Transmission's preferences and restart Transmission if it was running. There is also an option to start Clutch Agent automatically when you log in.[/list]

## Download

Please note that this is new software and may have bugs!

You can download the app here (move it to your Applications folder):
https://mega.nz/#!PYoQHKpY!ID4wO3XDzjfmsGqFws1AdiOT3PVkyRw7fbn3h7ZQXpc

Let's ditch Vuze once and for all.
