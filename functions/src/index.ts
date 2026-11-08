import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

interface HouseholdMember {
  name: string;
  fcmToken?: string | null;
}

interface HouseholdDoc {
  petName?: string;
  members?: Record<string, HouseholdMember>;
}

interface FeedingDoc {
  mealPeriod: "breakfast" | "dinner";
  windowDate: string;
  fedByUid: string;
  fedByName: string;
  fedAt: admin.firestore.Timestamp | string;
  isExtraMeal?: boolean;
}

/**
 * Triggered whenever Keni or Ashley logs a meal in
 * `/households/{householdId}/feedings/{feedingId}`.
 *
 * Dispatches an instant high-priority FCM push notification to all other
 * members of the household.
 */
export const onMealLogged = onDocumentCreated(
  "households/{householdId}/feedings/{feedingId}",
  async (event) => {
    const feeding = event.data?.data() as FeedingDoc | undefined;
    if (!feeding) return;

    const { householdId } = event.params;
    const householdSnap = await admin
      .firestore()
      .collection("households")
      .doc(householdId)
      .get();

    if (!householdSnap.exists) return;

    const household = householdSnap.data() as HouseholdDoc;
    const petName = household.petName || "Snoop";
    const members = household.members || {};

    // Collect FCM tokens for all household members EXCEPT the person who tapped the button.
    const recipientTokens: string[] = [];
    for (const [uid, member] of Object.entries(members)) {
      if (uid !== feeding.fedByUid && member.fcmToken) {
        recipientTokens.push(member.fcmToken);
      }
    }

    if (recipientTokens.length === 0) return;

    const mealLabel =
      feeding.mealPeriod === "dinner" ? "Dinner" : "Breakfast";

    await admin.messaging().sendEachForMulticast({
      tokens: recipientTokens,
      notification: {
        title: `🐾 ${petName} is fed!`,
        body: `${feeding.fedByName} fed ${petName} ${mealLabel}.`,
      },
      data: {
        householdId,
        mealPeriod: feeding.mealPeriod,
        windowDate: feeding.windowDate,
        fedByName: feeding.fedByName,
        deepLink: `https://whofedsnoop.com/tap/${householdId}`,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "snoop_feedings_high",
        },
      },
    });
  }
);

