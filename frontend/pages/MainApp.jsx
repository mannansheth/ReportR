"use client"

import { SafeAreaProvider } from "react-native-safe-area-context"
import CameraScreen from "./CameraScreen"
import { View, Text, StyleSheet, Dimensions, TouchableOpacity } from "react-native"
import { LinearGradient } from "expo-linear-gradient"
import { TabView, SceneMap } from "react-native-tab-view"
import { BottomNavigation } from "react-native-paper"
import { useEffect, useState } from "react"
import AnimatedIcon from "../component/AnimatedIcon"
import MapScreen from "./MapScreen"
import { useTranslation } from "react-i18next"
import LanguageSwitcher from "../component/LanguageSwitcher"
import { AntDesign, Entypo, Feather, Ionicons, MaterialCommunityIcons, Zocial } from "@expo/vector-icons"

export default function App() {
  const { t, i18n } = useTranslation()
  const layout = Dimensions.get("window")

  const [index, setIndex] = useState(2)
  const [routes, setRoutes] = useState([
    { key: "maps", title: t("navigation.map"), icon: "location", barColor: "#66ff66" },
    { key: "reports", title: t("navigation.reports"), icon: "file-document-outline", barColor: "#66ccff" },
    { key: "home", title: t("navigation.home"), icon: "add-circle", barColor: "#66ccff" },
    { key: "analytics", title: t("navigation.analytics"), icon: "analytics", barColor: "#ff6666" },
    { key: "profile", title: t("navigation.profile"), icon: "person", barColor: "#ffcc66" },
  ])

  useEffect(() => {
    setRoutes([
      { key: "maps", title: t("navigation.map"), icon: "location", barColor: "#66ff66" },
      { key: "reports", title: t("navigation.reports"), icon: "file-document-outline", barColor: "#66ccff" },
      { key: "home", title: t("navigation.home"), icon: "add-circle", barColor: "#66ccff" },
      { key: "analytics", title: t("navigation.analytics"), icon: "analytics", barColor: "#ff6666" },
      { key: "profile", title: t("navigation.profile"), icon: "person", barColor: "#ffcc66" },
    ])
  }, [i18n.language])

  const Home = () => <CameraScreen setIndex={setIndex} />
  const Profile = () => (
    <View style={styles.screen}>
      <Text style={styles.screenText}>{t("navigation.profile")}</Text>
      <View style={styles.languageSwitcherContainer}>
        <LanguageSwitcher />
      </View>
    </View>
  )
  const Analytics = () => (
    <View style={styles.screen}>
      <Text style={styles.screenText}>{t("navigation.analytics")}</Text>
    </View>
  )
  const Maps = () => (
    <View style={{ flex: 1 }}>
      <MapScreen index={index} />
    </View>
  )
  const Reports = () => (
    <View style={styles.screen}>
      <Text style={styles.screenText}>{t("navigation.reports")}</Text>
    </View>
  )
  const renderScene = SceneMap({
    analytics: Analytics,
    maps: Maps,
    profile: Profile,
    home: Home,
    reports: Reports,
  })

  return (
    <SafeAreaProvider>
      <TouchableOpacity style={{position:"absolute", top:115, right:-10, zIndex:99999, flexDirection: "row",
        alignItems: "center",
        backgroundColor: "rgba(26, 25, 25, 1)",
        paddingLeft: 12,
        paddingRight:30,
        paddingVertical: 8,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: "rgba(255, 255, 255, 0.3)",
        gap: 6
        }}>
        <MaterialCommunityIcons name="robot-confused-outline" size={30} color="white"/>
      </TouchableOpacity>
      <TouchableOpacity style={{position:"absolute", top:170, right:-10, zIndex:99999, flexDirection: "row",
        alignItems: "center",
        backgroundColor: "rgba(26, 25, 25, 1)",
        paddingLeft: 12,
        paddingRight:30,
        paddingVertical: 8,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: "rgba(255, 255, 255, 0.3)",
        gap: 6
        }}>
        <MaterialCommunityIcons name="bell-badge-outline" size={30} color="white"/>
      </TouchableOpacity>
      <TabView
        navigationState={{ index, routes }}
        renderScene={renderScene}
        onIndexChange={setIndex}
        initialLayout={{ width: layout.width }}
        renderTabBar={() => null}
        swipeEnabled={routes[index].key != "home" && routes[index].key != "maps"}
      />
      <LinearGradient colors={["#b0edff6a", "#2baaff90", "#000000c8"]} start={{ x: 5, y: 0 }}>
        <BottomNavigation.Bar
          navigationState={{ index, routes }}
          onTabPress={({ route }) => {
            setIndex(routes.indexOf(route))
          }}
          activeIndicatorStyle={{
            backgroundColor: "transparent",
          }}
          renderIcon={({ route, focused, color }) => <AnimatedIcon route={route} focused={focused} color={color} />}
          renderLabel={({ route, focused, color }) => {
            if (route.key === "home") return null // hide only for home
            return (
              <Text
                style={{
                  fontSize: 11,
                  color,
                  textAlign: "center",
                  marginTop: 0,
                }}
              >
                {route.title}
              </Text>
            )
          }}
          activeColor="lightblue"
          inactiveColor="white"
          style={{
            backgroundColor: "#112f4e",
            height: 120,
            borderTopLeftRadius: 15,
            borderTopRightRadius: 15,
            elevation: 5,
            shadowColor: "#000000ff",
            shadowOffset: { width: 0, height: -3 },
            shadowOpacity: 0.1,
            shadowRadius: 3,
          }}
        />
      </LinearGradient>
    </SafeAreaProvider>
  )
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#f5f5f5",
    padding: 20,
  },
  screenText: {
    fontSize: 24,
    fontWeight: "600",
    color: "#333",
    marginBottom: 30,
  },
  languageSwitcherContainer: {
    marginTop: 20,
  },
})
