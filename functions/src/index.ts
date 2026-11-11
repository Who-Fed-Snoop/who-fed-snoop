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
  mealPeriod: string;
  windowId?: string | null;
  windowLabel?: string | null;
  windowEmoji?: string | null;
  windowDate: string;
  fedByUid: string;
  fedByName: string;
  fedAt: admin.firestore.Timestamp | string;
  isExtraMeal?: boolean;
}

interface TreatDoc {
  preset: string;
  label: string;
  emoji?: string | null;
  quantity?: number;
  caloriesPerUnit?: number;
  logicalDate: string;
  givenByUid: string;
  givenByName: string;
  givenAt: admin.firestore.Timestamp | string;
  note?: string | null;
}

/**
 * Formats a human-readable meal label from `windowLabel` if present,
 * falling back to title-casing `mealPeriod` (e.g. "lateSnack" / "late_snack" -> "Late Snack").
 */
function resolveMealLabel(feeding: FeedingDoc): string {
  const explicitLabel = feeding.windowLabel?.trim();
  if (explicitLabel) {
    return explicitLabel;
  }

  const raw = (feeding.mealPeriod || "Meal").trim();
  if (!raw) return "Meal";

  const spaced = raw
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .trim();

  return spaced
    .split(/\s+/)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

/**
 * Collects unique FCM tokens for all household members EXCEPT the actor who triggered the event
 * (excluding both the actor's UID and the actor's own device FCM token).
 */
function collectRecipientTokens(
  members: Record<string, HouseholdMember>,
  actorUid: string
): string[] {
  const actorToken = members[actorUid]?.fcmToken ?? null;
  const tokens = new Set<string>();
  for (const [uid, member] of Object.entries(members)) {
    if (uid !== actorUid && member.fcmToken && member.fcmToken !== actorToken) {
      tokens.add(member.fcmToken);
    }
  }
  return Array.from(tokens);
}

/**
 * Triggered whenever a household member logs a meal (regular or bonus scoop) in
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

    const recipientTokens = collectRecipientTokens(members, feeding.fedByUid);
    if (recipientTokens.length === 0) return;

    const mealLabel = resolveMealLabel(feeding);
    const isExtraMeal = feeding.isExtraMeal === true;
    const fedByName = feeding.fedByName || "Someone";

    const title = isExtraMeal
      ? `🥣 Bonus scoop for ${petName}!`
      : `🐾 ${petName} is fed!`;
    const body = isExtraMeal
      ? `${fedByName} logged a bonus scoop for ${petName} (${mealLabel}).`
      : `${fedByName} fed ${petName} ${mealLabel}.`;

    await admin.messaging().sendEachForMulticast({
      tokens: recipientTokens,
      notification: {
        title,
        body,
      },
      data: {
        kind: "meal",
        householdId,
        mealPeriod: feeding.mealPeriod || "breakfast",
        windowId: feeding.windowId || feeding.mealPeriod || "breakfast",
        windowLabel: mealLabel,
        windowDate: feeding.windowDate || "",
        fedByName,
        isExtraMeal: String(isExtraMeal),
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

/**
 * Triggered whenever a household member logs a treat in
 * `/households/{householdId}/treats/{treatId}`.
 *
 * Dispatches an instant FCM push notification to all other members of the household
 * without conflating treats with full meals.
 */
export const onTreatLogged = onDocumentCreated(
  "households/{householdId}/treats/{treatId}",
  async (event) => {
    const treat = event.data?.data() as TreatDoc | undefined;
    if (!treat) return;

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

    const recipientTokens = collectRecipientTokens(members, treat.givenByUid);
    if (recipientTokens.length === 0) return;

    const qty =
      typeof treat.quantity === "number" && treat.quantity > 1
        ? Math.floor(treat.quantity)
        : 1;
    const label = (treat.label || "a treat").trim();
    const givenByName = (treat.givenByName || "Someone").trim();

    await admin.messaging().sendEachForMulticast({
      tokens: recipientTokens,
      notification: {
        title: `🦴 Treat for ${petName}!`,
        body: `${givenByName} gave ${petName} ${qty > 1 ? `${qty}x ` : ""}${label}.`,
      },
      data: {
        kind: "treat",
        householdId,
        preset: treat.preset || "custom",
        label,
        quantity: String(qty),
        logicalDate: treat.logicalDate || "",
        givenByName,
        deepLink: "https://whofedsnoop.com",
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
