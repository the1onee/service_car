# Android
افتح android/app/src/main/AndroidManifest.xml بعد `flutter create .` وأضف داخل <application>:

<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_KEY"/>

وصلاحيات داخل <manifest>:
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

minSdk: 21 على الأقل (Google Maps).

# iOS
في Info.plist:
NSLocationWhenInUseUsageDescription = نحتاج موقعك لطلب الفني وتتبع الوصول
NSLocationAlwaysAndWhenInUseUsageDescription = تحديث موقع الفني أثناء التوفر
