import { Router, type IRouter } from "express";
import { VISION_POST_PATHS } from "../lib/visionClient.js";

const router: IRouter = Router();

router.get("/healthz", (_req, res) => {
  res.json({
    status: "ok",
    routes: {
      get: ["/api/healthz"],
      post: [...VISION_POST_PATHS, "/api/review-calculation"],
    },
  });
});

export default router;
