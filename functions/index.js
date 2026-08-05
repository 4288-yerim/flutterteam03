const admin = require("firebase-admin");

admin.initializeApp();

Object.assign(
  exports,
  require("./auth/otp"),
  require("./auth/social"),
  require("./subscription/subscription"),
  require("./certification/certification"),
  require("./question/question"),
  require("./material/material"),
  require("./studyPlan/rebalance"),
  require("./studyPlan/passRisk"),
  require("./admin"),
  require("./notifications"),
);

const { chatbotReply } = require("./chat/chatbotReply");
exports.chatbotReply = chatbotReply;