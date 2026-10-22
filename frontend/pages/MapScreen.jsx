"use client"

import { useEffect, useRef, useState } from "react"
import {
  View,
  ActivityIndicator,
  StyleSheet,
  Text,
  ScrollView,
  TextInput,
  Modal,
  TouchableOpacity,
  Image,
} from "react-native"
import { Asset } from "expo-asset"
import * as FileSystem from "expo-file-system/legacy"
import { WebView } from "react-native-webview"
import { Ionicons, MaterialCommunityIcons } from "@expo/vector-icons"
import CustomDropdown from "../component/maps/CustomDropdown"
import * as Location from "expo-location"
import { getAllReports, getReportData } from "../services/mapServices"
import { getDistanceMeters } from "../helpers/MapHelper"
import AnimatedButton from "../component/maps/AnimatedButton"
import { useTranslation } from "react-i18next";
import * as SecureStore from 'expo-secure-store';
import ResolutionReviewModal from "../component/maps/ResolutionReviewModal"

export default function MapScreen({ index }) {
  const { t } = useTranslation()

  const [htmlContent, setHtmlContent] = useState(null)
  const webviewRef = useRef(null)
  const [userLoc, setUserLoc] = useState(null)
  const [markers, setMarkers] = useState([])
  const [allMarkers, setAllMarkers] = useState([])
  const [selectedReportData, setSelectedReportData] = useState(null)
  const [showResolutionModal, setShowResolutionModal] = useState(false)
  const [hasContributed, setHasContributed] = useState(false);
  const [filter, setFilter]= useState(null);
  const mapItems = [
    { color: "blue", label: t("report.categories.pothole") },
    { color: "red", label: t("report.categories.emergency") },
    { color: "green", label: t("report.categories.garbage") },
    { color: "purple", label: t("report.categories.other") },
  ]
  useEffect(() => {
  const applyFilter = () => {
    if (!filter) {
      setMarkers(
          userLoc
            ? [userLoc, ...allMarkers.filter((r) => r.status !== "Invalid Report")]
            : allMarkers.filter((r) => r.status !== "Invalid Report")
        );
    } else if (filter.label === "My reports") {
      const userId = parseInt(JSON.parse(SecureStore.getItem("userDetails")).id);
      setMarkers(userLoc ? [userLoc, ...allMarkers.filter(m => m.userID === userId)]
                         : allMarkers.filter(m => m.userID === userId));
    } else {
      setMarkers(userLoc ? [userLoc, ...allMarkers.filter(m => m.status === filter.label)]
                         : allMarkers.filter(m => m.status === filter.label));
    }
  };
  applyFilter();
}, [filter, allMarkers, userLoc]);

  const getLocation = async () => {
    const { status } = await Location.requestForegroundPermissionsAsync()
    if (status !== "granted") {
      alert(t("report.locationRequired"))
      return null
    }
    const loc = await Location.getCurrentPositionAsync({})
    setUserLoc({
      lat: loc.coords.latitude,
      lng: loc.coords.longitude,
      color: "rgb(50,150,255)",
      isUser: true,
    })
  }
  const loadHtml = async () => {
    const asset = Asset.fromModule(require("../assets/leaflet.html"))
    await asset.downloadAsync()
    const content = await FileSystem.readAsStringAsync(asset.localUri, {
      encoding: FileSystem.EncodingType.UTF8,
    })
    setHtmlContent(content)
  }
  useEffect(() => {
  getLocation();

  if (index === 0) {
    const getReports = async () => {
      try {
        const response = await getAllReports();
        setAllMarkers(Array.isArray(response) ? response : []);
        // setMarkers(
        //   userLoc
        //     ? [userLoc, ...response.filter((r) => r.status !== "Invalid Report")]
        //     : response.filter((r) => r.status !== "Invalid Report")
        // );
      } catch (error) {
        console.error("Error fetching reports:", error);
      }
    };

    // run immediately once
    getReports();
    loadHtml();

    // then poll every second
    const interval = setInterval(getReports, 5000);

    // cleanup
    return () => clearInterval(interval);
  }
}, [index, userLoc]);


  // Inject markers directly via JS
  useEffect(() => {
    if (userLoc) {
      setMarkers((prev) => [...prev, userLoc])
    }
  }, [userLoc])
  useEffect(() => {
    if (webviewRef.current && markers) {
      webviewRef.current.postMessage(JSON.stringify({ type: "loadMarkers", markers }))
    }
  }, [markers])

  const handleMessage = async (event) => {
    const data = JSON.parse(event.nativeEvent.data)
    if (data.type === "markerClick") {
      const reportData = await getReportData(data.Rid)
      if (userLoc) {
        reportData.canResolve = getDistanceMeters(userLoc.lat, userLoc.lng, data.lat, data.lng) < 200
      }
      setSelectedReportData({ ...reportData, color: data.color })

      setShowResolutionModal(true)
    }
  }
  if (!htmlContent) return <ActivityIndicator size="large" style={{ flex: 1 }} />
  return (
    <View style={styles.container}>
      <WebView
        ref={webviewRef}
        originWhitelist={["*"]}
        source={{ html: htmlContent }}
        // injectedJavaScript={injectedJS}
        style={{ flex: 1, marginTop: 10 }}
        onMessage={handleMessage}
        onLoadEnd={() => {
          // when the HTML is ready, push the markers
          if (markers) {
            webviewRef.current.postMessage(JSON.stringify({ type: "loadMarkers", markers }))
          }
        }}
      />
      {!userLoc && (
        <View
          style={{
            position: "absolute",
            paddingHorizontal: 15,
            paddingVertical: 4,
            top: 175,
            backgroundColor: "#11304ed4",
            alignSelf: "center",
            disply: "flex",
            flexDirection: "row",
            gap: 12,
            borderRadius: 30,
          }}
        >
          <ActivityIndicator />
          <Text style={{ color: "white" }}>{t("map.gettingLOC")}</Text>
        </View>
      )}

      {/* Search bar */}
      <View
        style={{
          position: "absolute",
          width: "71%",
          left: 50,
          borderRadius: 25,
          height: 50,
          top: 60,
          backgroundColor: "white",
          borderColor: "black",
          borderWidth: 1,
          paddingLeft: 10,
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "space-between",
        }}
      >
        <TextInput placeholder={t("map.searchLocation")} placeholderTextColor={"rgba(83, 83, 83, 1)"} />
        <View style={{ backgroundColor: "#112f4e", borderRadius: 45, padding: 10, borderWidth: 1 }}>
          <Ionicons name="search" size={28} color="white" />
        </View>
      </View>

      <TouchableOpacity
        style={{
          position: "absolute",
          bottom: 50,
          right: 10,
          backgroundColor: "white",
          padding: 8,
          borderRadius: 50,
          borderWidth: 1,
          borderColor: "black",
        }}
        onPress={() => {
          if (webviewRef.current && userLoc) {
            webviewRef.current.postMessage(JSON.stringify({ type: "setView", userLoc }))
          }
        }}
      >
        <MaterialCommunityIcons name="target" size={40} />
      </TouchableOpacity>
      {/* Settings button */}
      {/* <TouchableOpacity
        style={{
          position: "absolute",
          alignSelf: "center",
          borderRadius: 10,
          height: 50,
          right: 10,
          top: 60,
          backgroundColor: "white",
          borderColor: "black",
          borderWidth: 1,
          paddingHorizontal: 10,
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "space-between",
        }}
      >
        <Ionicons name="settings" size={30} />
      </TouchableOpacity> */}

      {/* Dropdown */}
      <ScrollView
        horizontal
        style={{ position: "absolute", top: 115, height: 50, width: "75%", overflow: "scroll", alignSelf: "center" }}
      >
        <CustomDropdown selected={filter} setFilter={setFilter} />
      </ScrollView>

      {showResolutionModal && selectedReportData && (
        <Modal
          animationType="slide"
          transparent
          visible={showResolutionModal}
          onRequestClose={() => setShowResolutionModal(false)}
        >
          <View style={styles.overlay}>
            <View style={styles.modal}>
              <View
                style={{ flexDirection: "row", justifyContent: "space-between", width: "100%", paddingHorizontal: 10 }}
              >
                <Text style={{ fontSize: 11 }}>
                  {selectedReportData.createdAt.split(",")[1]} {/* Time */}
                </Text>
                <Text style={{ fontSize: 11 }}>
                  {selectedReportData.createdAt.split(",")[0]} {/* Date */}
                </Text>
              </View>
              <View
                style={{
                  position: "absolute",
                  top: "2%",
                  backgroundColor: selectedReportData.color,
                  paddingHorizontal: 8,
                  paddingVertical: 5,
                  borderRadius: 12,
                }}
              >
                <Text style={{ fontSize: 10, color: "white" }}>{selectedReportData.status}</Text>
              </View>

              <Text style={styles.title}>{selectedReportData.issue}</Text>
              <View
                style={{
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  width: "100%",
                  borderTopColor: "black",
                  borderTopWidth: 1,
                  paddingTop: 15,
                }}
              >
                <Image source={{ uri: selectedReportData?.imageURL }} style={{ width: 200, height: 200 }} />

                {selectedReportData.canResolve && <AnimatedButton disabled={false} setHasContributed={setHasContributed}/>}

                <TouchableOpacity
                  style={[styles.button, styles.close]}
                  onPress={() => {
                    setShowResolutionModal(false)
                  }}
                >
                  <Text style={[styles.buttonText, { color: "white" }]}>{t("common.close")}</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </Modal>
      )}
      {hasContributed && <ResolutionReviewModal setHasContributed={setHasContributed} />}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.1)",

    alignItems: "center",
  },
  modal: {
    width: "90%",
    marginTop: 500,
    padding: 15,
    backgroundColor: "white",
    borderRadius: 10,
    elevation: 5,
    alignItems: "center",
  },
  title: {
    fontSize: 16,
    fontWeight: 700,
    paddingTop: 10,
    marginBottom: 10,
    textAlign:"center"
  },
  button: {
    width: "70%",
    padding: 8,
    backgroundColor: "#00d23fff",
    borderRadius: 5,
    marginVertical: 5,
    alignItems: "center",
    justifyContent: "center",
    display: "flex",
    flexDirection: "row",
    alignSelf: "center",
  },
  close: {
    backgroundColor: "#ff0000ff",
  },
  buttonText: {
    color: "white",
    fontWeight: "bold",
    marginRight: 10,
    alignSelf: "center",
  },
})
