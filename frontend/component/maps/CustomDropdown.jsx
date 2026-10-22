import { MaterialIcons } from "@expo/vector-icons";
import React, { useState, useRef, useEffect } from "react";
import { View, Text, TouchableOpacity, FlatList, StyleSheet, Animated, Modal } from "react-native";
import * as SecureStore from 'expo-secure-store'
const options =  [
  {"color": "rgba(255, 255, 255, 1)", "label": "My reports"},
  {"color": "rgba(9, 255, 0, 1)", "label": "Resolved"},
  {"color": "rgba(255, 187, 0, 1)", "label": "In Progress"},
  {"color": "rgba(40, 0, 121, 1)", "label": "Issue Raised"},
  {"color": "rgba(0, 0, 0, 1)", "label": "Verification pending"},
  {"color": "rgba(197, 0, 0, 1)", "label": "Invalid Report"}, 
]

export default function CustomDropdown( {selected, setFilter}) {
  const [open, setOpen] = useState(false);
  const dropdownAnim = useRef(new Animated.Value(0)).current; // initial height 0

  const toggleDropdown = () => {
    if (!open) {
      setOpen(true);
      Animated.timing(dropdownAnim, {
        toValue: 220, // height of dropdown
        duration: 300,
        useNativeDriver: false,
      }).start();
    } else {
      Animated.timing(dropdownAnim, {
        toValue: 0,
        duration: 150,
        useNativeDriver: false,
      }).start(() => setOpen(false));
    }
  };

  const handleSelect = (option) => {
    setFilter(option);

    Animated.timing(dropdownAnim, {
      toValue: 0,
      duration: 150,
      useNativeDriver: false,
    }).start(() => setOpen(false));
  };

  return (
    <View style={styles.container}>
      {/* Selected Item */}
      <View style={{display:"flex", flexDirection:"row", alignItems:"center"}}>
        <TouchableOpacity style={styles.selector} onPress={toggleDropdown}>
          <View style={[styles.colorBox, { backgroundColor: selected?.color || "#ccc" }]} />
          <Text style={styles.selectorText}>
            {selected ? selected.label : "Filter"}{" "}
            <MaterialIcons name={open ? "keyboard-arrow-up" : "keyboard-arrow-down"} />
          </Text>
        </TouchableOpacity>
          {selected && 
            <TouchableOpacity style={{backgroundColor:"white", padding:6}} onPress={() => {
              setFilter(null);
            }}>
              <MaterialIcons name="close" size={20} />

            </TouchableOpacity>
          }

      </View>

      {/* Animated Dropdown Modal */}
      {open && (
        <Modal transparent animationType="none">
          <TouchableOpacity style={styles.overlay} onPress={toggleDropdown}>
            <Animated.View style={[styles.dropdownContainer, { height: dropdownAnim }]}>
              <FlatList
                data={options}
                keyExtractor={(item) => item.label}
                renderItem={({ item }) => ( 
                  <TouchableOpacity onPress={() => handleSelect(item)} style={styles.option}>
                    <View style={[styles.colorBox, { backgroundColor: item.color }]} />
                    <Text style={styles.optionText}>{item.label}</Text>
                  </TouchableOpacity>
                )}
              />
            </Animated.View>
          </TouchableOpacity>
        </Modal>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { width: "100%" },
  selector: {
    flexDirection: "row",
    alignItems: "center",
    padding: 8,
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 8,
    backgroundColor: "#fff",
  },
  selectorText: { marginLeft: 10, fontSize: 13, color: "#333" },
  colorBox: { width: 16, height: 16, borderRadius: 4 },
  overlay: { flex: 1, backgroundColor: "rgba(0,0,0,0.1)", justifyContent: "flex-start" },
  dropdownContainer: {
    width: 200,
    backgroundColor: "#fff",
    borderRadius: 8,
    marginTop: 160, // same as original
    marginLeft: 50, // same as original
    overflow: "hidden",
  },
  option: { flexDirection: "row", alignItems: "center", padding: 12, borderBottomWidth: 1, borderBottomColor: "#eee" },
  optionText: { marginLeft: 10 },
});
