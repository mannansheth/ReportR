"use client"

import { useState } from "react"
import { View, Text, TouchableOpacity, Modal, StyleSheet } from "react-native"
import { useTranslation } from "react-i18next"
import { Ionicons } from "@expo/vector-icons"

const LanguageSwitcher = () => {
  const { t, i18n } = useTranslation()
  const [showLanguageModal, setShowLanguageModal] = useState(false)

  const languages = [
    { code: "en", name: t("settings.english"), flag: "🇺🇸" },
    { code: "hi", name: t("settings.hindi"), flag: "🇮🇳" },
    // { code: "mr", name: t("settings.marathi"), flag: "🇮🇳" },
  ]

  const changeLanguage = async (languageCode) => {
    try {
      await i18n.changeLanguage(languageCode)
      setShowLanguageModal(false)
    } catch (error) {
      console.error("Error changing language:", error)
    }
  }

  const getCurrentLanguageName = () => {
    const currentLang = languages.find((lang) => lang.code === i18n.language)
    return currentLang ? currentLang.name : t("settings.english")
  }

  return (
    <>
      <TouchableOpacity style={styles.languageButton} onPress={() => setShowLanguageModal(true)}>
        <Ionicons name="language" size={24} color="white" />
        {/* <Text style={styles.languageButtonText}>{getCurrentLanguageName()}</Text> */}
        <Ionicons name="chevron-down" size={16} color="white" />
      </TouchableOpacity>

      <Modal
        animationType="slide"
        transparent={true}
        visible={showLanguageModal}
        onRequestClose={() => setShowLanguageModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{t("settings.selectLanguage")}</Text>
              <TouchableOpacity onPress={() => setShowLanguageModal(false)} style={styles.closeButton}>
                <Ionicons name="close" size={24} color="#333" />
              </TouchableOpacity>
            </View>

            {languages.map((language) => (
              <TouchableOpacity
                key={language.code}
                style={[styles.languageOption, i18n.language === language.code && styles.selectedLanguage]}
                onPress={() => changeLanguage(language.code)}
              >
                <Text style={styles.flagText}>{language.flag}</Text>
                <Text style={[styles.languageText, i18n.language === language.code && styles.selectedLanguageText]}>
                  {language.name}
                </Text>
                {i18n.language === language.code && <Ionicons name="checkmark" size={20} color="#112f4e" />}
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </Modal>
    </>
  )
}

const styles = StyleSheet.create({
  languageButton: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(26, 25, 25, 1)",
    paddingHorizontal: 13,
    paddingVertical: 12,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.3)",
    gap: 5,
  },
  languageButtonText: {
    color: "white",
    fontSize: 14,
    fontWeight: "500",
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    justifyContent: "center",
    alignItems: "center",
  },
  modalContent: {
    backgroundColor: "white",
    borderRadius: 15,
    padding: 20,
    width: "80%",
    maxWidth: 300,
    elevation: 5,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 20,
    paddingBottom: 15,
    borderBottomWidth: 1,
    borderBottomColor: "#eee",
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#333",
  },
  closeButton: {
    padding: 4,
  },
  languageOption: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 15,
    paddingHorizontal: 10,
    borderRadius: 10,
    marginVertical: 2,
    gap: 12,
  },
  selectedLanguage: {
    backgroundColor: "#f0f8ff",
    borderWidth: 1,
    borderColor: "#112f4e",
  },
  flagText: {
    fontSize: 24,
  },
  languageText: {
    fontSize: 16,
    color: "#333",
    flex: 1,
  },
  selectedLanguageText: {
    color: "#112f4e",
    fontWeight: "600",
  },
})

export default LanguageSwitcher
