"use client"

import { Camera } from "expo-camera"
import { useState, useEffect, useRef } from "react"

import { Ionicons, MaterialIcons } from "@expo/vector-icons"
import { View, StyleSheet, Text, KeyboardAvoidingView, TouchableOpacity, Platform } from "react-native"
import { Gesture } from "react-native-gesture-handler"
import Animated, {
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from "react-native-reanimated"
import * as Location from "expo-location"
import { detectIssues } from "../services/gemini.js"
import CameraUI from "../component/CameraPage/CameraUI.jsx"
import ReportForm from "../component/CameraPage/ReportForm.jsx"
import ImagePreview from "../component/CameraPage/ImagePreview.jsx"
import { LinearGradient } from "expo-linear-gradient"
import * as DocumentPicker from "expo-document-picker"
import * as FileSystem from "expo-file-system/legacy"
import piexif from "piexifjs"
import { normalizeExif } from "../helpers/ExifHelper.js"
import { useTranslation } from "react-i18next"

const CameraScreen = ({ setIndex }) => {
  const { t } = useTranslation()

  const [type, setType] = useState("back")
  const cameraRef = useRef(null)
  const [image, setImage] = useState(null)
  const [showImagePreview, setShowImagePreview] = useState(false)
  const [zoom, setZoom] = useState(0)
  const [flash, setFlash] = useState("off")
  const [predictions, setPredictions] = useState(null)
  const [showLocationMessage, setShowLocationMessage] = useState(true)
  const [coordinates, setCoordinates] = useState({})
  const [hasPermission, setHasPermission] = useState(null)

  const scrollY = useSharedValue(0)

  const onScroll = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollY.value = event.contentOffset.y
    },
  })

  const arrowOffset = useSharedValue(0)

  const animatedArrowStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: arrowOffset.value }],
  }))
  useEffect(() => {
    arrowOffset.value = withRepeat(
      withSequence(withTiming(-20, { duration: 600 }), withTiming(0, { duration: 600 })),
      -1, // infinite
      true,
    )
  }, [])

  useEffect(() => {
    ;(async () => {
      const { status } = await Camera.requestCameraPermissionsAsync()
      setHasPermission(status === "granted")
    })()
  }, [])

  useEffect(() => {
    if (coordinates.latitude) {
      const timer = setTimeout(() => {
        setShowLocationMessage(false)
      }, 5000)

      return () => clearTimeout(timer)
    }
  }, [coordinates])

  const getReportLocation = async (exif) => {
    if (
      typeof exif?.GPSLatitude === "number" &&
      exif?.GPSLatitude !== 0 &&
      typeof exif?.GPSLongitude === "number" &&
      exif?.GPSLongitude !== 0
    ) {
      const location = await Location.reverseGeocodeAsync({
        latitude: exif.GPSLatitude,
        longitude: exif.GPSLongitude,
      })

      setCoordinates({
        latitude: exif.GPSLatitude,
        longitude: exif.GPSLongitude,
        readableLoc: location[0],
      })
      return;
    }
    const { status } = await Location.requestForegroundPermissionsAsync()
    if (status !== "granted") {
      alert(t("report.locationRequired"))
      return null
    }
    const loc = await Location.getCurrentPositionAsync({})

    const location = await Location.reverseGeocodeAsync({
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
    })

    setCoordinates({
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
      readableLoc: location[0],
      message: exif && exif?.GPSLatitude && t("report.locationRequired"),
    })
  }

  const pickImage = async () => {
    const result = await DocumentPicker.getDocumentAsync({
      type: ["image/*"],
      copyToCacheDirectory: true,
    })

    if (result.type === "cancel") return

    try {
      // Copy file to FileSystem cache dir (ensures it's readable)
      const destUri = FileSystem.cacheDirectory + result.assets[0].name
      await FileSystem.copyAsync({
        from: result.assets[0].uri,
        to: destUri,
      })

      // Read base64
      const base64 = await FileSystem.readAsStringAsync(destUri, {
        encoding: FileSystem.EncodingType.Base64,
      })

      // Parse EXIF
      const dataUri = "data:image/jpeg;base64," + base64
      let exifData = {}
      try {
        const exif = piexif.load(dataUri)
        exifData = normalizeExif(exif)
      } catch (e) {
        console.log("No EXIF data found:", e)
      }

      getReportLocation(exifData)
      setImage({ uri: destUri, base64, mimeType: result.mimeType })
      setShowImagePreview(true)

      const predictions = await detectIssues(base64, result.mimeType || "image/jpeg")
      predictions.sort((a, b) => b.probability - a.probability)
      setPredictions(predictions)
    } catch (error) {
      console.error("Error handling document:", error)
    }
  }

  const takePicture = async () => {
    if (!cameraRef.current) return
    const photo = await cameraRef.current.takePictureAsync({
      base64: true,
    })
    getReportLocation()
    setImage(photo)
    setShowImagePreview(true)
    const predictions = await detectIssues(photo.base64, photo.mimeType || "image/jpeg")
    predictions.sort((a, b) => b.probability - a.probability)
    setPredictions(predictions)
  }

  const pinchGesture = Gesture.Pinch()
    .onUpdate((event) => {
      setZoom((prev) => {
        const newZoom = prev + event.scaleChange * 0.2
        return Math.max(0, Math.min(1, newZoom))
      })
    })
    .runOnJS(true)

  const cleanUpOnCancel = () => {
    setImage(null)
    setPredictions(null)
    setCoordinates({})
    setShowLocationMessage(true)
  }
  if (hasPermission === null) return <Text style={{ color: "white" }}>{t("common.loading")}</Text>
  if (hasPermission === false) return <Text style={{ color: "white" }}>{t("camera.permissionDenied")}</Text>

  return (
    <View style={styles.container}>
      {image ? (
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          keyboardVerticalOffset={Platform.OS === "ios" ? 80 : 0}
        >
          <LinearGradient
            colors={["#185795ff", "rgba(0, 59, 79, 0.52)", "#112f4e"]}
            start={{ x: 100, y: 0 }}
            style={{ flexGrow: 1, paddingVertical: 20 }}
          >
            <Animated.ScrollView
              // style={{ flex: 1, position: "relative" }}
              contentContainerStyle={{ flexGrow: 1, paddingBottom: 100 }}
              showsVerticalScrollIndicator={true}
              alwaysBounceVertical={false}
              onScroll={onScroll}
              scrollEventThrottle={16}
              stickyHeaderIndices={[0]}
              keyboardShouldPersistTaps="handled"
              bounces={false}
              overScrollMode="never"
            >
              <TouchableOpacity onPress={cleanUpOnCancel} style={[styles.closeBtn]}>
                <Ionicons name="close" size={30} color="white" />
              </TouchableOpacity>
              <TouchableOpacity style={[styles.collapseBtn]} onPress={() => setShowImagePreview(!showImagePreview)}>
                <MaterialIcons
                  name={!showImagePreview ? "keyboard-arrow-down" : "keyboard-arrow-up"}
                  size={30}
                  color="white"
                />
              </TouchableOpacity>
              {showImagePreview && (
                <>
                  <ImagePreview
                    image={image.uri}
                    predictions={predictions}
                    scrollY={scrollY}
                    setShowImagePreview={setShowImagePreview}
                  />

                  <Animated.View style={[styles.arrowContainer, animatedArrowStyle]}>
                    <Ionicons name="arrow-down-circle" size={40} color="#ffffffff" />
                    {/* <Text style={{ color: "#444", marginTop: 4 }}>
                            Scroll to fill details
                        </Text> */}
                  </Animated.View>
                </>
              )}
              <ReportForm
                coordinates={coordinates}
                showLocationMessage={showLocationMessage}
                showImagePreview={showImagePreview}
                predictions={predictions}
                image={image}
                setIndex={setIndex}
              />
            </Animated.ScrollView>
          </LinearGradient>
        </KeyboardAvoidingView>
      ) : (
        <CameraUI
          flash={flash}
          setFlash={setFlash}
          zoom={zoom}
          setZoom={setZoom}
          pinchGesture={pinchGesture}
          CameraType={type}
          setCameraType={setType}
          cameraRef={cameraRef}
          takePicture={takePicture}
          pickImage={pickImage}
        />
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  closeBtn: {
    width: 50,
    height: 50,
    padding: 5,
    borderRadius: 40,
    borderWidth: 5,
    borderColor: "rgba(255,255,255,1)",
    backgroundColor: "transparent",
    position: "absolute",
    top: 50,
    left: 20,

    alignItems: "center",
    justifyContent: "center",
    zIndex:9999
  },
  collapseBtn: {
    width: 50,
    height: 50,
    borderRadius: 40,
    borderWidth: 5,
    zIndex: 999999,
    borderColor: "rgba(255,255,255,1)",
    backgroundColor: "transparent",
    position: "absolute",
    top: 110,
    left: 20,
    alignItems: "center",
    justifyContent: "center",
  },
  arrowContainer: {
    alignItems: "center",
  },
})

export default CameraScreen
