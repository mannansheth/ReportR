import { SafeAreaProvider } from "react-native-safe-area-context";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";

import LoginScreen from "./pages/LoginScreen";

import MainApp from "./pages/MainApp";
import { useEffect, useState } from "react";
import Login from "./pages/Login";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { PermissionsAndroid, Platform, View } from "react-native";
import * as Notifications from 'expo-notifications';
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from 'expo-secure-store';
import './i18n'
import LanguageSwitcher from "./component/LanguageSwitcher";
let messaging;
if (Platform.OS === 'android') {
  messaging = require('@react-native-firebase/messaging').default;
}
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,  // Show in system tray
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});
const Stack = createNativeStackNavigator();

export default function App() {
  useEffect(() => {
      //SecureStore.deleteItemAsync("userDetails")
      if (Platform.OS === 'android') {
        registerFCMToken();
        Notifications.setNotificationChannelAsync('default', {
          name: 'Default',
          importance: Notifications.AndroidImportance.HIGH,
        });

      const unsubscribeForeground = messaging().onMessage(async remoteMessage => {
        console.log('[FCM] Foreground message:', remoteMessage);
  
        await Notifications.scheduleNotificationAsync({
          content: {
            title: remoteMessage.notification?.title || 'OTP',
            body: remoteMessage.notification?.body || 'Your OTP has arrived',
          },
          trigger: null, // show immediately
        });
      });
  
      // Background handler
      messaging().setBackgroundMessageHandler(async remoteMessage => {
        console.log('[FCM] Background message:', remoteMessage);
      });
  
      return () => unsubscribeForeground();
    }}, []);

    const registerFCMToken = async () => {
      try {
        const authStatus = await messaging().requestPermission();
        const enabled = authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
                        authStatus === messaging.AuthorizationStatus.PROVISIONAL;

        if (!enabled) return Alert.alert('Push notification permission denied');

        if (Platform.Version >= 33) {
          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS
          );
          if (granted !== PermissionsAndroid.RESULTS.GRANTED) {
            return Alert.alert('Push notification permission denied');
          }
        }

        const token = await messaging().getToken();
        console.log('FCM Token:', token);
        
        AsyncStorage.setItem("token", token)

        messaging().onTokenRefresh(newToken => setFcmToken(newToken));
      } catch (err) {
        console.error('FCM registration failed:', err);
      }
    };

  const [loggedIn, setLoggedIn] = useState(false);
  const [userToken, setUserToken] = useState(null);

  const handleLoginSuccess = (token) => {
    setUserToken(token);
    setLoggedIn(true);
  };
  return (
    <SafeAreaProvider>
      <GestureHandlerRootView>
        <View style={{position:"absolute", top:60, right:-10, zIndex:99999}}>
                <LanguageSwitcher />
        </View>
        <NavigationContainer>
          <Stack.Navigator screenOptions={{ headerShown: false }}>
            <Stack.Screen name="Login" component={LoginScreen} />
            {/* <Stack.Screen name="Login" component={Login} /> */}
            
            <Stack.Screen name="Home" component={MainApp} />
          </Stack.Navigator>
        </NavigationContainer>
      </GestureHandlerRootView>
    </SafeAreaProvider>
  );
}
