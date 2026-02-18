import { getMetaContent } from "./utils";
import { FullStory, init as initFullStory } from "@fullstory/browser";

// FullStory
const fullStoryOrgId = getMetaContent("fullStoryOrgId");
const userEmail = getMetaContent("userEmail");
if (fullStoryOrgId !== null && userEmail !== null) {
  initFullStory({ orgId: fullStoryOrgId });
  FullStory("setIdentity", {
    uid: userEmail,
    properties: {
      displayName: userName,
      email: userEmail,
    },
  });
}
