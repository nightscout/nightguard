[![Join the chat at https://gitter.im/nightscout/nightguard](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/nightscout/nightguard)

# Nightguard

[![Join the chat at https://gitter.im/nightscout/nightguard](https://badges.gitter.im/nightscout/nightguard.svg)](https://gitter.im/nightscout/nightguard?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
This is an iPhone and Apple Watch application to display blood glucose values stored at your nightscout server.

# Description

Disclaimer!
Don't use this App for medical decisions. It comes without absolutely no warranty. Use it at your own risk!

Nightguard is an app that displays your blood glucose values from the Nightscout backend.

It is a native iOS App with support for the Apple Watch.
Features are:
- Define a range of acceptable blood glucose values.
- Whenever your values are out of range you will be alerted.
- You can snooze the alerts all the time and for a defined time period.
- You can reactivate the alerts all the time.
- You can activate alerts if the values are rising or falling too fast.
- The app displays yesterdays values as an overlay chart. This way you have a hint about how your values could behave in the future.
- Tune your basal rates with the statistics function to overlay different days

For the alarms to work the app has to be active. So you can enable a screen lock that keeps the app running all night long.

Have a look at https://nightscout.github.io for more information about how to setup your own Nightscout backend.

![Nightguard App](https://github.com/nightscout/nightguard/blob/master/images/nightguard24.jpg)

The dark gray region in the chart marks the values that are between 80 and 180.

<img src="https://github.com/nightscout/nightguard/blob/master/images/watch.jpg" width="40%"/> <img src="https://github.com/nightscout/nightguard/blob/master/images/watch-complication.jpg" width="40%"/>

This small video shows how to check the configuration and demonstrates the available Apple Watch Complication:
http://youtu.be/CEcqNyyv_kA

# Developer Hints

First install cocoapods and do a 
```
pod install
```
afterwards.

Then simply open the Nightguard folder "nightguard" in xcode.
If no scheme "nightguard" is existing, select "new Scheme" from the "Product|Scheme" Menu.

I had to modify the Eureka SliderRow. If you would like to compile the project of your own, you will have to modify
the SliderRow in the following way:

```
public final class SliderRow: Row<SliderCell>, RowType {

    public var steps: UInt = 20
    public var shouldHideValue = false
    public var lastSelectedValue : Float?

    required public init(tag: String?) {
        super.init(tag: tag)
    }
}
```

Now you should be able to launch the app in the simulator. Happy Coding!

## Environment Configuration

The app uses a `.env` file to manage secrets (like the App Store Shared Secret) without committing them to the repository.

1.  **Create your `.env` file:**
    Copy the example file to create your local configuration:
    ```bash
    cp .env.example .env
    ```

2.  **Edit `.env`:**
    Open `.env` and replace the placeholder values with your actual secrets.
    ```
    SHARED_SECRET=your_actual_secret_from_app_store_connect
    BASE_URI=https://your-nightscout-url.herokuapp.com
    ```

3.  **Add to Xcode Project:**
    **Crucial:** You must manually add the `.env` file to the Xcode project for it to be accessible at runtime.
    *   Open the project in Xcode.
    *   Drag and drop the `.env` file into the Project Navigator (e.g., inside the `nightguard` folder).
    *   In the dialog that appears, ensure **"Add to targets"** is checked for **both** the **nightguard** app target AND the **nightguardTests** target.

## Uploading the app

If you would like to run a local compiled version, you might wan't to disable the critical notification entitlement.
This can be done in File nightguard/scoutwatch.entitlements by changing the value to false:

```
    <key>com.apple.developer.usernotifications.critical-alerts</key>
    <false/>
```

# License

[agpl-3]: http://www.gnu.org/licenses/agpl-3.0.txt

    nightguard app to display cgm readings on your ios and watchos device
    Copyright (C) 2018 Nightguard contributors.
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
    
    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
