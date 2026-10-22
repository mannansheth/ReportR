import React, { useRef, useState } from "react";
import { View, Text, TouchableOpacity, Animated, StyleSheet, Alert } from "react-native";
import { Ionicons, MaterialCommunityIcons, MaterialIcons } from '@expo/vector-icons';

export default function AnimatedButton({disabled, setHasContributed}) {
  const [clicked, setClicked] = useState(false);
  
  const textOpacity = useRef(new Animated.Value(1)).current;
  const iconTranslateX = useRef(new Animated.Value(0)).current;
  const iconScale = useRef(new Animated.Value(1)).current;

  const handlePress = () => {
    if (clicked) return;
    setClicked(true);

    // Animate text fade out
    Animated.timing(textOpacity, {
      toValue: 0,
      duration: 300,
      useNativeDriver: true,
    }).start();

    // Animate icon sliding and scaling
    Animated.timing(iconTranslateX, {
      toValue: -95, // move right
      duration: 500,
      useNativeDriver: true,
    }).start(() => {
      // Optional: change icon after sliding
      Animated.timing(iconScale, {
        toValue: 1.75, // grow a bit
        duration: 400,
        useNativeDriver: true,
      }).start(() => {
        Animated.timing(iconScale, {
        toValue: 1.25, // grow a bit
        duration: 500,
        useNativeDriver: true,
      }).start(() => {
        setHasContributed(true);
      })

      });
    });
  };

  return (
    <>
    {!disabled ? 
      <TouchableOpacity onPress={handlePress} style={styles.button}>
        <Animated.Text style={[styles.text, { opacity: textOpacity }]}>
          Is this issue resolved?
        </Animated.Text>
        <Animated.View style={{ transform: [{ translateX: iconTranslateX }, { scale: iconScale }] }}>
          <Ionicons name={clicked ? "checkmark-circle" : "arrow-forward-circle"} size={24} color="white" />
        </Animated.View>
      </TouchableOpacity>
    
    :
      <View onPress={handlePress} style={styles.button}>
        <Animated.Text style={[styles.text, { opacity: textOpacity }]}>
          Is this issue resolved?
        </Animated.Text>
        <Animated.View style={{ transform: [{ translateX: iconTranslateX }, { scale: iconScale }] }}>
          <Ionicons name={clicked ? "checkmark-circle" : "arrow-forward-circle"} size={24} color="white" />
        </Animated.View>
      </View>
    }
    </>
  );
}

const styles = StyleSheet.create({
  button: {
    width: "70%",
    padding: 8,
    backgroundColor: "#00d23fff",
    borderRadius: 5,
    marginVertical: 5,
    alignItems: "center",
    justifyContent:"center",
    display:"flex",
    flexDirection:"row",
    alignSelf:"center"
  },
  text: {
    color: "white",
    fontSize: 14,
    fontWeight:600,
    marginRight: 10,
  },
});
