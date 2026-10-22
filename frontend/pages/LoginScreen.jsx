"use client"

import { useEffect, useState } from "react"
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Alert,
  StyleSheet,
  ActivityIndicator,
  Platform,
  Image,
} from "react-native"
import * as SecureStore from "expo-secure-store"
import * as LocalAuthentication from "expo-local-authentication"
import axios from "axios"
import { LinearGradient } from "expo-linear-gradient"
import AsyncStorage from "@react-native-async-storage/async-storage"
import { useTranslation } from "react-i18next"

const backendURL = process.env.EXPO_PUBLIC_BACKEND_URL

export default function LoginScreen({ navigation }) {
  const { t } = useTranslation()

  const [name, setName] = useState("")
  const [phone, setPhone] = useState("")
  const [otp, setOTP] = useState("")
  const [loading, setLoading] = useState(false)
  const [otpSent, setOTPSent] = useState(false)
  const [fcmToken, setFcmToken] = useState(null)

  useEffect(() => {
    //SecureStore.deleteItemAsync("userDetails")
    checkExistingUser()
    const getToken = async () => {
      const token = await AsyncStorage.getItem("token")
      setFcmToken(token)
    }
    getToken()
  }, [])

  const checkExistingUser = async () => {
    const userId = await SecureStore.getItemAsync("userDetails")
    if (!userId) return

    if (Platform.OS === "ios") {
      console.log("hello ios")
      // iOS → biometric required
      const bio = await LocalAuthentication.hasHardwareAsync()
      const enrolled = await LocalAuthentication.isEnrolledAsync()
      if (bio && enrolled) {
        const result = await LocalAuthentication.authenticateAsync({
          promptMessage: t("auth.biometricPrompt"),
          fallbackLabel: t("auth.biometricFallback"),
        })
        if (result.success) {
          navigation.replace("Home")
        } else {
          Alert.alert(t("auth.biometricError"))
        }
      } else {
        navigation.replace("Home")
      }
    } else {
      // Android → OTP login already verified once
      navigation.replace("Home")
    }
  }

  const handleSendOTP = async () => {
    if (!phone || !name) return Alert.alert(t("auth.invalidPhone"))
    setLoading(true)
    try {
      await axios.post(`${backendURL}api/user/sendOTP`, {
        name,
        phone,
        token: Platform.OS === "android" ? fcmToken : null,
      })
      setOTPSent(true)
      Alert.alert(t("auth.otpSent"))
    } catch (err) {
      console.error(err)
      Alert.alert(t("auth.loginFailed"))
    }
    setLoading(false)
  }

  const handleVerifyOTP = async () => {
    if (!otp) return Alert.alert(t("auth.invalidOTP"))
    setLoading(true)
    try {
      const res = await axios.post(`${backendURL}api/user/verifyOTP`, {
        name,
        phone,
        otp,
        token: Platform.OS === "android" ? fcmToken : null,
      })

      if (res.data.success) {
        await SecureStore.setItemAsync(
          "userDetails",
          JSON.stringify({ id: res.data.user.id.toString(), name: res.data.user.name, number: res.data.user.phone }),
        )
        Alert.alert(t("auth.loginSuccess"))
        navigation.replace("Home")
      } else {
        Alert.alert(res.data.message || t("auth.invalidOTP"))
      }
    } catch (err) {
      console.error(err)
      Alert.alert(t("auth.loginFailed"))
    }
    setLoading(false)
  }

  if (loading) return <ActivityIndicator size="large" style={{ flex: 1 }} />

  return (
    <View style={styles.container}>
      <Image
        source={require("../assets/logo.png")}
        style={{
          width: 150,
          height: 200,
          backgroundColor: "rgba(0,0,0,0)",
          position: "absolute",
          top: "17%",
          left: "9%",
        }}
      />
      <Image
        source={require("../assets/loginBG.png")}
        style={{
          width: 555,
          height: 165,
          backgroundColor: "rgba(0,0,0,0)",
          position: "absolute",
          bottom: 0,
          alignSelf: "center",
        }}
      />
      <Image
        source={require("../assets/ReportR.png")}
        style={{
          width: 165,
          height: 42,
          backgroundColor: "rgba(0,0,0,0)",
          position: "absolute",
          top: "26%",
          left: "48%",
        }}
      />
      <Image
        source={require("../assets/tagline.png")}
        style={{
          width: 160,
          height: 12,
          backgroundColor: "rgba(0,0,0,0)",
          position: "absolute",
          top: "31%",
          left: "48%",
        }}
      />
      {/* <View style={{position:"absolute", top:"25%", left:"55%"}}>
        <Text style={{fontSize:24, fontFamily:"Times New Roman"}}>ReportR</Text>
      </View> */}
      <Image
        source={require("../assets/flagIND.png")}
        style={{
          width: 555,
          height: 165,
          backgroundColor: "rgba(0,0,0,0)",
          position: "absolute",
          top: 0,
          alignSelf: "center",
        }}
      />

      {Platform.OS === "ios" ? (
        <>
          <TextInput
            placeholder={t("auth.enterName")}
            value={name}
            onChangeText={setName}
            style={styles.input}
            placeholderTextColor="grey"
          />
          <TextInput
            placeholder={t("auth.enterPhone")}
            value={phone}
            onChangeText={setPhone}
            keyboardType="phone-pad"
            style={styles.input}
            placeholderTextColor="grey"
          />
          <TouchableOpacity
            activeOpacity={0.9}
            onPress={async () => {
              if (!name || !phone) return Alert.alert(t("auth.invalidPhone"))
              await SecureStore.setItemAsync(
                "userDetails",
                JSON.stringify({ id: Date.now(), name: name, number: phone }),
              )
              navigation.replace("Home")
            }}
            style={{ alignSelf: "center", width: "50%", marginTop: 30 }}
          >
            <View>
              <LinearGradient
                colors={["#0088b16a", "#001bb390", "#000000c8"]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={{
                  borderRadius: 25,
                  paddingVertical: 3,
                  paddingHorizontal: 2,
                }}
              >
                <View
                  style={{
                    backgroundColor: "rgba(2, 50, 75, 0.52)",
                    borderRadius: 25,
                    paddingVertical: 8,
                    alignSelf: "center",
                    paddingHorizontal: 2,
                    width: "97%",
                  }}
                >
                  <Text
                    style={{ textAlign: "center", color: "rgba(255, 255, 255, 1)", fontWeight: "500", fontSize: 16 }}
                  >
                    {t("common.ok")}
                  </Text>
                </View>
              </LinearGradient>
            </View>
          </TouchableOpacity>
        </>
      ) : (
        <>
          {!otpSent ? (
            <>
              <TextInput
                placeholder={t("auth.enterName")}
                value={name}
                onChangeText={setName}
                style={styles.input}
                placeholderTextColor="grey"
              />
              <TextInput
                placeholder={t("auth.enterPhone")}
                value={phone}
                onChangeText={setPhone}
                keyboardType="phone-pad"
                style={styles.input}
                placeholderTextColor="grey"
              />
              <TouchableOpacity
                activeOpacity={0.9}
                onPress={handleSendOTP}
                style={{ alignSelf: "center", width: "50%", marginTop: 30 }}
              >
                <View>
                  <LinearGradient
                    colors={["#0088b16a", "#001bb390", "#000000c8"]}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={{
                      borderRadius: 25,
                      paddingVertical: 3,
                      paddingHorizontal: 2,
                    }}
                  >
                    <View
                      style={{
                        backgroundColor: "rgba(2, 50, 75, 0.52)",
                        borderRadius: 25,
                        paddingVertical: 8,
                        alignSelf: "center",
                        paddingHorizontal: 2,
                        width: "97%",
                      }}
                    >
                      <Text
                        style={{
                          textAlign: "center",
                          color: "rgba(255, 255, 255, 1)",
                          fontWeight: "500",
                          fontSize: 16,
                        }}
                      >
                        {t("auth.sendOTP")}
                      </Text>
                    </View>
                  </LinearGradient>
                </View>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <TextInput
                placeholder={t("auth.enterOTP")}
                value={otp}
                onChangeText={setOTP}
                keyboardType="number-pad"
                style={styles.input}
                placeholderTextColor="grey"
              />
              <TouchableOpacity
                activeOpacity={0.9}
                onPress={handleVerifyOTP}
                style={{ alignSelf: "center", width: "50%", marginTop: 30 }}
              >
                <View>
                  <LinearGradient
                    colors={["#0088b16a", "#001bb390", "#000000c8"]}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={{
                      borderRadius: 25,
                      paddingVertical: 3,
                      paddingHorizontal: 2,
                    }}
                  >
                    <View
                      style={{
                        backgroundColor: "rgba(2, 50, 75, 0.52)",
                        borderRadius: 25,
                        paddingVertical: 8,
                        alignSelf: "center",
                        paddingHorizontal: 2,
                        width: "97%",
                      }}
                    >
                      <Text
                        style={{
                          textAlign: "center",
                          color: "rgba(255, 255, 255, 1)",
                          fontWeight: "500",
                          fontSize: 16,
                        }}
                      >
                        {t("auth.verifyOTP")}
                      </Text>
                    </View>
                  </LinearGradient>
                </View>
              </TouchableOpacity>
            </>
          )}
        </>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: "center", padding: 20, backgroundColor: "white", position: "relative" },
  title: { fontSize: 24, marginBottom: 20, textAlign: "center" },
  input: {
    borderWidth: 1,
    borderColor: "#aaa",
    padding: 10,
    marginBottom: 15,
    borderRadius: 5,
    width: "80%",
    alignSelf: "center",
  },
})
