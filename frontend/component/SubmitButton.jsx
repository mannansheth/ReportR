import React, { useRef, useState } from "react";
import { Text, TouchableOpacity, Animated, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";


export default function SubmitButton( { handleReportSubmit, isSubmitLoading }) {
  const scaleAnim = useRef(new Animated.Value(1)).current;
  const handlePressIn = () => {
    Animated.spring(scaleAnim, {
      toValue: 0.95,
      useNativeDriver: true,
    }).start();
  };

  const handlePressOut = () => {
    Animated.spring(scaleAnim, {
      toValue: 1,
      friction: 3,
      tension: 40,
      useNativeDriver: true,
    }).start();
  };

  return (
    <>
      {isSubmitLoading ?
        <View
        activeOpacity={0.9}
        onPress={handleReportSubmit}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        style={{ alignSelf: "center",
          width: "35%", marginTop: 30,  }}
      >
        <Animated.View style={{ transform: [{ scale: scaleAnim }] }}>
          <LinearGradient
            colors={["#b0edff6a", "#2baaff90", "#000000c8"]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={{
              borderRadius: 25,
              paddingVertical: 3,
              paddingHorizontal: 2,
            }}
          >
            <View style={{backgroundColor:"rgba(219, 243, 255, 0.52)", borderRadius: 25,
              paddingVertical: 8,
              alignSelf:"center",
              paddingHorizontal: 2, width:"97%"}}>
              <Text style={{ textAlign: "center", color: "rgba(48, 48, 48, 1)", fontWeight: "500", fontSize: 16 }}>
                {isSubmitLoading ? "Submitting..." : "Submit"}
              </Text>

            </View>
          </LinearGradient>
        </Animated.View>
      </View>
      :
      <TouchableOpacity
        activeOpacity={0.9}
        onPress={handleReportSubmit}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        style={{ alignSelf: "center",
          width: "35%", marginTop: 30,  }}
      >
        <Animated.View style={{ transform: [{ scale: scaleAnim }] }}>
          <LinearGradient
            colors={["#b0edff6a", "#2baaff90", "#000000c8"]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={{
              borderRadius: 25,
              paddingVertical: 3,
              paddingHorizontal: 2,
            }}
          >
            <View style={{backgroundColor:"rgba(219, 243, 255, 0.52)", borderRadius: 25,
              paddingVertical: 8,
              alignSelf:"center",
              paddingHorizontal: 2, width:"97%"}}>
              <Text style={{ textAlign: "center", color: "rgba(48, 48, 48, 1)", fontWeight: "500", fontSize: 16 }}>
                {isSubmitLoading ? "Submitting..." : "Submit"}
              </Text>

            </View>
          </LinearGradient>
        </Animated.View>
      </TouchableOpacity>

      }
    </>
  );
}
