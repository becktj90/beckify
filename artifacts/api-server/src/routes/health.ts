import { Router, type IRouter } from "express";
import { VISION_POST_PATHS } from "../lib/visionClient.js";

const router: IRouter = Router();

router.get("/healthz", (_req, res) => {
  res.json({
    status: "ok",
    routes: {
      get: ["/api/healthz", "/api/share/:token", "/api/rooms/:code/events"],
      post: [...VISION_POST_PATHS, "/api/review-calculation", "/api/translate", "/api/speak", "/api/share", "/api/rooms", "/api/rooms/:code/join", "/api/rooms/:code/messages", "/api/rooms/:code/leave"],
    },
  });
});

export default router;
