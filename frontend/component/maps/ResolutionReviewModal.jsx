import React, { useState } from "react";
import { Modal, View, Text, TouchableOpacity, TextInput, Alert } from "react-native";

export default function ResolutionReviewModal({setHasContributed}) {
  const [rating, setRating] = useState(0);
  const [feedback, setFeedback] = useState("");

  const submitReview = () => {
    if (rating === 0) {
      Alert.alert("Error", "Please select a star rating.");
      return;
    }
    Alert.alert("Thank you for your contribution!", `Your feedback helps us resolve issues faster.`);
    setRating(0);
    setFeedback("");
    setHasContributed(false);
  };

  return (
    <Modal  transparent animationType="slide">
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: "rgba(0,0,0,0.5)" }}>
        <View style={{ backgroundColor: "white", borderRadius: 10, padding: 20, width: "80%" }}>
          <Text style={{ fontSize: 18, fontWeight: "bold", marginBottom: 10 }}>Rate Resolution</Text>

          {/* Star Rating */}
          <View style={{ flexDirection: "row", marginBottom: 15 }}>
            {[1, 2, 3, 4, 5].map((star) => (
              <TouchableOpacity key={star} onPress={() => setRating(star)}>
                <Text style={{ fontSize: 30, marginHorizontal: 5 }}>
                  {star <= rating ? "⭐" : "☆"}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Feedback Input */}
          <TextInput
            placeholder="Additional feedback (optional)"
            value={feedback}
            onChangeText={setFeedback}
            style={{
              borderWidth: 1,
              borderColor: "#ccc",
              borderRadius: 5,
              padding: 8,
              marginBottom: 15,
            }}
            multiline
          />

          {/* Buttons */}
          <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
            <TouchableOpacity
              onPress={() => setHasContributed(false)}
              style={{ padding: 10, backgroundColor: "#ddd", borderRadius: 5 }}
            >
              <Text>Cancel</Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={submitReview}
              style={{ padding: 10, backgroundColor: "#007AFF", borderRadius: 5 }}
            >
              <Text style={{ color: "white" }}>Submit</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}
