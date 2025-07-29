const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteUserById = functions.https.onCall(async (data, context) => {
  // Solo permitir admins autenticados
  const uidCaller = context.auth && context.auth.uid;
  if (!uidCaller) {
    throw new functions.https.HttpsError("unauthenticated", "No autenticado");
  }

  const userDoc = await admin.firestore().doc(`usuarios/${uidCaller}`).get();
  if (!userDoc.exists || userDoc.data().rol !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Acceso denegado");
  }

  const uidToDelete = data.uid;
  if (!uidToDelete) {
    throw new functions.https.HttpsError("invalid-argument", "Falta UID");
  }

  try {
    // Eliminar usuario de Auth
    await admin.auth().deleteUser(uidToDelete);
    // Eliminar documento Firestore
    await admin.firestore().doc(`usuarios/${uidToDelete}`).delete();

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError("unknown", "Error al eliminar", error);
  }
});
