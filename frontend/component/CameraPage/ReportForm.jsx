"use client"

import { useState, useEffect } from "react"
import {
  View,
  StyleSheet,
  Text,
  TextInput,
  ActivityIndicator,
  TouchableOpacity,
  Alert,
  Animated,
  Modal,
} from "react-native"
import { Ionicons, MaterialCommunityIcons, MaterialIcons } from "@expo/vector-icons"
import { Audio } from "expo-av"
import { transcribeDesc } from "../../services/transcription"
import * as SecureStore from "expo-secure-store"
import SubmitButton from "../SubmitButton"
import uuid from "react-native-uuid"
import * as FileSystem from "expo-file-system/legacy"
import * as Sharing from "expo-sharing"
import AsyncStorage from "@react-native-async-storage/async-storage"
import { generatePDF } from "../../services/pdfGeneration"
import { sendNotification } from "../../services/messagingService"
import { submitReport } from "../../services/gemini"
import { useTranslation } from "react-i18next"
import { getReportByLocation } from "../../services/mapServices"

const ReportForm = ({ coordinates, showLocationMessage, showImagePreview, predictions, image, setIndex }) => {
  const { t } = useTranslation()

  const [isSubmitLoading, setIsSubmitLoading] = useState(false)
  const [category, setCategory] = useState("")
  const [recording, setRecording] = useState(null)
  const [isRecording, setIsRecording] = useState(false)
  const [audioUri, setAudioUri] = useState(null)
  const [sound, setSound] = useState(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [playbackStatus, setPlaybackStatus] = useState(null)
  const [duration, setDuration] = useState(0)
  const [position, setPosition] = useState(0)
  const [isTranscribing, setIsTranscribing] = useState(false)
  const [number, setNumber] = useState(JSON.parse(SecureStore.getItem("userDetails")).number || "1234567890")
  const [description, setDescription] = useState("")
  const [name, setName] = useState(JSON.parse(SecureStore.getItem("userDetails")).name || "Umang")
  const progressAnim = useState(new Animated.Value(0))[0]
  const [showDownloadModal, setShowDownloadModal] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [pdf, setPdf] = useState(null)
  const userId = JSON.parse(SecureStore.getItem("userDetails")).id
  const [isConnected, setIsConnected] = useState(true);
  const locInWords = [
    coordinates.readableLoc?.name,
    coordinates.readableLoc?.street,
    coordinates.readableLoc?.city,
    coordinates.readableLoc?.region,
    coordinates.readableLoc?.postalCode,
    coordinates.readableLoc?.country,
  ]
    .filter(Boolean)
    .join(", ")
  const rId = `Rid_${new Date().getFullYear()}${uuid.v4().replaceAll("-", "").slice(0, 4)}`

  useEffect(() => {
    const getNearbyReports = async () => {
      const nearbyReports = await getReportByLocation(coordinates.latitude, coordinates.longitude);
      if (nearbyReports.length > 0) {
        Alert.alert(`An issue has already been reported near this location`, `${nearbyReports[0]?.issue} was reported here`,
          [
            {
              text: "View report ->",
              onPress: () => {
                // only runs when user closes the alert
                setIndex(0);
              },
            },
          ]
        );
      }
    }
    if (coordinates) {
      getNearbyReports();
    }
  }, [coordinates])
  const createAndStoreReportData = async (reportData) => {
    const reportFolder = `${FileSystem.documentDirectory}reports/${reportData.reportID}/`
    await FileSystem.makeDirectoryAsync(reportFolder, { intermediates: true })

    await FileSystem.copyAsync({ from: image.uri, to: `${reportFolder}image.jpeg` })

    if (audioUri) await FileSystem.copyAsync({ from: audioUri, to: `${reportFolder}audio.m4a` })

    await FileSystem.writeAsStringAsync(`${reportFolder}data.json`, JSON.stringify(reportData), {
      encoding: FileSystem.EncodingType.UTF8,
    })

    const pendingReports = JSON.parse(await AsyncStorage.getItem("pendingReports")) || []
    pendingReports.push(reportData.reportID)
    await AsyncStorage.setItem("pendingReports", JSON.stringify(pendingReports))
  }

  const handleReportSubmit = async () => {
    if (!category) {
      Alert.alert(t("report.requiredField"))
      return
    }
    if (!name) {
      Alert.alert(t("report.requiredField"))
      return
    }
    setIsSubmitLoading(true)
    const reportData = {
      reportID: rId,
      userID: userId,
      name: name,
      number: number,
      category: category,
      description: description,
      location: { lat: coordinates.latitude, lng: coordinates.longitude, loc: locInWords },
      createdDate: new Date().toISOString(),
    }
    await createAndStoreReportData(reportData)

    const pdfUri = await generatePDF(reportData, image.uri)
    setPdf(pdfUri)
    try {
      await sendNotification(rId, name, userId)
      submitReport({
        ...reportData,
        image: image.uri,
        base64: image.base64,
        audio: audioUri,
        pdf: pdfUri,
      })
      setShowDownloadModal((prev) => !prev);
      setIsSubmitLoading(false);

    } catch (err) {
      setIsConnected(false);
      Alert.alert(
          t("report.reportFailed"),
          t("report.noNetwork"),
          [
            {
              text: "OK",
              onPress: () => {
                // only runs when user closes the alert
                setShowDownloadModal((prev) => !prev);
                setIsSubmitLoading(false);
              },
            },
          ]
        );
    }
  }

  const handleShare = async () => {
    try {
      setIsLoading(true)
      await Sharing.shareAsync(pdf)
    } catch (err) {
      console.error("Share error:", err)
    } finally {
      setIsLoading(false)
    }
  }

  const startRecording = async () => {
    try {
      const { status } = await Audio.requestPermissionsAsync()
      if (status !== "granted") {
        Alert.alert(t("camera.cameraPermission"), t("camera.cameraPermission"))
        return
      }
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      })
      const { recording } = await Audio.Recording.createAsync(Audio.RecordingOptionsPresets.HIGH_QUALITY)
      setIsRecording(true)
      setRecording(recording)
    } catch (error) {
      console.error("Failed to start recording", error)
      Alert.alert(t("common.error"), t("common.error"))
    }
  }

  const stopRecording = async () => {
    try {
      if (!recording) return

      await recording.stopAndUnloadAsync()
      setIsRecording(false)
      const uri = recording.getURI()
      setAudioUri(uri)
      setRecording(null)
      transcribe(uri)
    } catch (error) {
      console.error("Failed to stop recording", error)
      Alert.alert(t("common.error"))
    }
  }

  const transcribe = async (uri) => {
    try {
      setIsTranscribing(true)
      const result = await transcribeDesc(uri)
      setIsTranscribing(false)
      if (result.success) {
        setDescription(result.result.text) // ✅ result.result.text
      } else {
        Alert.alert(t("report.transcriptionFailed"))
      }
    } catch (err) {
      console.error(err)
      setIsTranscribing(false)
      Alert.alert(t("report.transcriptionFailed"), err.message)
    }
  }

  const playSound = async () => {
    try {
      if (!audioUri) return

      // If sound is already loaded and paused, just resume
      // if (sound && !isPlaying) {
      //   await sound.playAsync();
      //   setIsPlaying(true);
      //   return;
      // }

      // Create new sound instance
      if (sound) {
        await sound.unloadAsync()
        setSound(null)
      }

      const { sound: newSound } = await Audio.Sound.createAsync({ uri: audioUri }, { shouldPlay: true })

      setSound(newSound)
      setIsPlaying(true)

      newSound.setOnPlaybackStatusUpdate((status) => {
        setPlaybackStatus(status)
        if (status.isLoaded) {
          setDuration(status.durationMillis || 0)
          setPosition(status.positionMillis || 0)
          setIsPlaying(status.isPlaying)

          if (status.durationMillis > 0) {
            const progress = status.positionMillis / status.durationMillis
            progressAnim.setValue(progress)
          }

          // Auto-stop when finished
          if (status.didJustFinish) {
            setIsPlaying(false)
            progressAnim.setValue(0)
          }
        }
      })
    } catch (error) {
      console.error("Failed to play sound", error)
      Alert.alert(t("common.error"))
    }
  }

  const pauseSound = async () => {
    try {
      if (sound && isPlaying) {
        await sound.pauseAsync()
        setIsPlaying(false)
      }
    } catch (error) {
      console.error("Failed to pause sound", error)
    }
  }

  const deleteAudio = async () => {
    try {
      Alert.alert(t("common.delete"), t("common.delete"), [
        { text: t("common.cancel"), style: "cancel" },
        {
          text: t("common.delete"),
          style: "destructive",
          onPress: async () => {
            if (sound) {
              await sound.unloadAsync()
              setSound(null)
            }
            setAudioUri(null)
            setDescription("")
            setIsPlaying(false)
            setPosition(0)
            setDuration(0)
            progressAnim.setValue(0)
          },
        },
      ])
    } catch (error) {
      console.error("Failed to delete audio", error)
    }
  }

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (sound) {
        sound.unloadAsync()
      }
      if (recording) {
        recording.stopAndUnloadAsync()
      }
    }
  }, [sound, recording])

  // Progress circle component
  const ProgressCircle = ({ progress }) => {
    const circumference = 2 * Math.PI * 18 // radius = 18
    const strokeDashoffset = circumference - progress * circumference

    return (
      <View style={styles.progressContainer}>
        <View style={styles.progressCircle}>
          <View
            style={[
              styles.progressBackground,
              {
                borderColor: "rgba(255,255,255,0.3)",
                borderWidth: 2,
              },
            ]}
          />
          <Animated.View
            style={[
              styles.progressForeground,
              {
                borderColor: "#4CAF50",
                borderWidth: 2,
                transform: [
                  {
                    rotate: progressAnim.interpolate({
                      inputRange: [0, 1],
                      outputRange: ["0deg", "360deg"],
                    }),
                  },
                ],
              },
            ]}
          />
        </View>
      </View>
    )
  }

  // Get the appropriate icon and action based on current state
  const getMainButtonConfig = () => {
    if (isRecording) {
      return {
        icon: "stop",
        iconSet: MaterialCommunityIcons,
        action: stopRecording,
        color: "#f44336",
      }
    }

    if (audioUri) {
      if (isPlaying) {
        return {
          icon: "pause",
          iconSet: MaterialCommunityIcons,
          action: pauseSound,
          color: "#FF9800",
        }
      } else {
        return {
          icon: "play",
          iconSet: MaterialCommunityIcons,
          action: playSound,
          color: "#4CAF50",
        }
      }
    }

    return {
      icon: "microphone",
      iconSet: MaterialCommunityIcons,
      action: startRecording,
      color: "#2196F3",
    }
  }

  const mainButton = getMainButtonConfig()
  const IconComponent = mainButton.iconSet

  return (
    <>
      <View style={[styles.formContainer, { marginTop: !showImagePreview ? 120 : 0 }]}>
        <Text style={styles.label}>{t("report.location")}</Text>
        {coordinates.latitude ? (
          <>
            {showLocationMessage && coordinates.message ? (
              <Text style={{ fontSize: 12, color: "white" }}>{coordinates.message}</Text>
            ) : (
              <TextInput
                placeholder={t("report.currentLocation")}
                style={[styles.input, { backgroundColor: "rgba(255, 255, 255, 0.7)" }]}
                value={`${coordinates.latitude}, ${coordinates.longitude} \n(${locInWords})`}
                multiline
                editable={false}
              />
            )}
          </>
        ) : (
          <Text style={{ color: "white" }}>{t("common.loading")}</Text>
        )}

        <Text style={styles.label}>
          {t("auth.enterName")} <Text style={{ color: "red", fontSize: 23 }}>*</Text>
        </Text>
        <TextInput
          placeholder={t("auth.enterName")}
          style={[styles.input, { paddingLeft: 12, backgroundColor: "rgba(255, 255, 255, 0.7)" }]}
          placeholderTextColor={"grey"}
          value={name}
          onChangeText={setName}
          editable={false}
        />
        <Text style={styles.label}>
          {t("auth.phoneNumber")}{" "}
          {/* <Text style={{ color: "rgba(179, 188, 0, 1)", fontSize: 10 }}>({t("auth.phoneNumber")})</Text> */}
        </Text>
        <TextInput
          placeholder={t("auth.phoneNumber")}
          style={[styles.input, { paddingLeft: 12, backgroundColor: "rgba(255, 255, 255, 0.7)" }]}
          placeholderTextColor={"grey"}
          value={number}
          onChangeText={setNumber}
          editable={false}
        />

        <Text style={styles.label}>
          {t("report.selectCategory")} <Text style={{ color: "red", fontSize: 23 }}>*</Text>
        </Text>
        <TextInput
          placeholder={t("report.selectCategory")}
          style={[styles.input, { paddingLeft: 12 }]}
          placeholderTextColor={"grey"}
          value={category}
          onChangeText={setCategory}
          autoComplete="yes"
        />

        <View
          style={{
            display: "flex",
            flexDirection: "row",
            flexWrap: "wrap",
            gap: 4,
            alignItems: "center",
            marginBottom: 10,
          }}
        >
          {predictions ? (
            predictions.length > 0 ? (
              predictions.map((p, i) => (
                <Text
                  key={i}
                  onPress={() =>
                    setCategory((prev) => {
                      if (!prev) return p.issue
                      const items = prev.split(", ").filter(Boolean)

                      return items.includes(p.issue)
                        ? items.filter((item) => item !== p.issue).join(", ")
                        : [...items, p.issue].join(", ")
                    })
                  }
                  style={{
                    backgroundColor: "rgba(255, 255, 255, 0.43)",
                    borderRadius: 100,
                    padding: 8,
                    paddingHorizontal: 12,
                    color: "white",
                    fontSize: 10,
                    justifyContent: "center",
                    borderWidth: category.includes(p.issue) ? 2 : 0,
                    borderColor: category.includes(p.issue) ? "blue" : "",
                  }}
                >
                  {p.issue}
                </Text>
              ))
            ) : (
              <>
                <Ionicons name="warning" color="red" size={22} />
                <Text style={{ color: "rgba(255, 65, 65, 1)" }}>{t("map.noReports")}</Text>
              </>
            )
          ) : (
            <View style={{ display: "flex", alignItems: "center", flexDirection: "row", gap: 5 }}>
              <ActivityIndicator size="large" color="#b9bc00ff" />
              <Text style={{ color: "rgba(207, 207, 207, 1)" }}>{t("report.detecting")}</Text>
            </View>
          )}
        </View>

        <Text style={styles.label}>
          {t("report.description")}{" "}
          <Text style={{ fontStyle: "italic", color: "grey" }}>({t("report.optional")})</Text>{" "}
        </Text>
        <View style={{ display: "flex", flexDirection: "row", alignItems: "center", gap: 12 }}>
          {isTranscribing ? (
            <View
              style={{
                width: "80%",
                height: 80,
                paddingRight: 40,
                borderWidth: "1px",
                borderColor: "white",
              }}
            >
              <ActivityIndicator />
              <Text style={{ color: "rgba(194, 194, 194, 1)", textAlign: "center" }}>{t("common.loading")}</Text>
            </View>
          ) : (
            <TextInput
              placeholder={t("report.enterDescription")}
              placeholderTextColor={"grey"}
              multiline
              value={description}
              onChangeText={setDescription}
              style={[styles.input, { height: 120, paddingRight: 40, width: "80%" }]}
            />
          )}

          <View style={styles.buttonContainer}>
            <TouchableOpacity
              style={[styles.mainButton, { backgroundColor: mainButton.color }]}
              onPress={mainButton.action}
            >
              <IconComponent name={mainButton.icon} size={30} color="white" />
              {(isPlaying || (audioUri && position > 0)) && (
                <ProgressCircle progress={duration > 0 ? position / duration : 0} />
              )}
            </TouchableOpacity>

            {/* Recording indicator */}
            {isRecording && (
              <View style={styles.recordingIndicator}>
                <View style={styles.recordingDot} />
              </View>
            )}
            {audioUri && (
              <TouchableOpacity
                style={styles.deleteButton}
                onPress={() => {
                  isTranscribing ? Alert.alert(t("common.error")) : deleteAudio()
                }}
              >
                <MaterialCommunityIcons name={isTranscribing ? "delete-off" : "delete"} size={24} color="#f44336" />
              </TouchableOpacity>
            )}
          </View>
        </View>

        <SubmitButton handleReportSubmit={handleReportSubmit} isSubmitLoading={isSubmitLoading} />
        {showDownloadModal && (
          <Modal
            animationType="slide"
            transparent
            visible={showDownloadModal}
            onRequestClose={() => {
              setShowDownloadModal(false)
              setIndex(4);
            }}
          >
            <View style={styles.overlay}>
              <View style={styles.modal}>
                <Text style={styles.title}>{ isConnected ? t("report.reportSubmitted") : t("report.reportSaved")}</Text>

                <TouchableOpacity style={styles.button} onPress={handleShare}>
                  {!isLoading ? (
                    <>
                      <Text style={styles.buttonText}>{t("common.save")}</Text>
                      <MaterialIcons name="share" size={18} color="white" />
                    </>
                  ) : (
                    <ActivityIndicator size="large" />
                  )}
                </TouchableOpacity>

                <TouchableOpacity
                  style={[styles.button, styles.close]}
                  onPress={() => {
                    setShowDownloadModal(false);
                    setIndex(4)
                  }}
                >
                  <Text style={[styles.buttonText, { color: "red" }]}>{t("common.close")}</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        )}
      </View>
    </>
  )
}

const styles = StyleSheet.create({
  formContainer: {
    padding: 30,
    color: "white",
  },
  label: {
    fontSize: 16,
    marginBottom: 8,
    fontWeight: "500",
    color: "rgba(231, 231, 231, 1)",
  },
  input: {
    borderWidth: 1,
    color: "rgba(0, 0, 0, 1)",
    backgroundColor: "white",
    borderColor: "#00e2f6ff",
    padding: 12,
    borderRadius: 8,
    marginBottom: 5,
    elevation: 10,
  },
  buttonContainer: {
    position: "relative",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
  },
  mainButton: {
    padding: 12,
    borderRadius: 50,
    alignItems: "center",
    justifyContent: "center",
    width: 56,
    height: 56,
  },
  deleteButton: {
    padding: 8,
    borderRadius: 25,
    backgroundColor: "rgba(244, 67, 54, 0.1)",
    alignItems: "center",
    justifyContent: "center",
    width: 40,
    height: 40,
  },
  progressContainer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: "center",
    justifyContent: "center",
  },
  progressCircle: {
    width: 56,
    height: 56,
    alignItems: "center",
    justifyContent: "center",
  },
  progressBackground: {
    position: "absolute",
    width: 52,
    height: 52,
    borderRadius: 26,
    borderColor: "rgba(255,255,255,0.3)",
  },
  progressForeground: {
    position: "absolute",
    width: 52,
    height: 52,
    borderRadius: 26,
    borderColor: "#4CAF50",
    borderTopColor: "transparent",
    borderLeftColor: "transparent",
  },
  recordingIndicator: {
    position: "absolute",
    top: -5,
    right: -5,
    backgroundColor: "#f44336",
    borderRadius: 10,
    width: 20,
    height: 20,
    alignItems: "center",
    justifyContent: "center",
  },
  recordingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "white",
  },
  audioInfo: {
    marginTop: 8,
    alignItems: "center",
  },
  audioInfoText: {
    color: "rgba(231, 231, 231, 0.8)",
    fontSize: 12,
    fontFamily: "monospace",
  },
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.5)",
    justifyContent: "center",
    alignItems: "center",
  },
  modal: {
    width: "90%",
    padding: 20,
    backgroundColor: "white",
    borderRadius: 10,
    elevation: 5,
    alignItems: "center",
  },
  title: {
    fontSize: 16,
    fontWeight: 700,
    paddingBottom: 20,
    marginBottom: 15,
    borderBottomWidth: 1,
    borderBottomColor: "black",
    textAlign: "center",
  },
  button: {
    width: "70%",
    padding: 8,
    backgroundColor: "#112f4e",
    borderRadius: 5,
    marginVertical: 5,
    alignItems: "center",
    justifyContent: "center",
    display: "flex",
    flexDirection: "row",
  },
  close: {
    backgroundColor: "#eee",
  },
  buttonText: {
    color: "white",
    fontWeight: "bold",
    marginRight: 10,
  },
})

export default ReportForm
