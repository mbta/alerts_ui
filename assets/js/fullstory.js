import { getMetaContent } from "./utils";
import { FullStory, init as initFullStory } from "@fullstory/browser";

// FullStory
if (fullStoryOrgId !== null && userEmail !== null) {
  const fullStoryOrgId = getMetaContent("fullStoryOrgId");
  
  initFullStory({ orgId: fullStoryOrgId });
  FullStory("setIdentity", {
    uid: userEmail,
    properties: {
      displayName: userName,
      email: userEmail,
    },
  });
}
