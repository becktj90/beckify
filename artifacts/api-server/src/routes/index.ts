import { Router, type IRouter } from "express";
import analyzeTdrRouter from "./analyze-tdr.js";
import analyzeNameplateRouter from "./analyze-nameplate.js";
import analyzePanelRouter from "./analyze-panel.js";
import analyzeLookRouter from "./analyze-look.js";
import healthRouter from "./health.js";
import reviewCalculationRouter from "./review-calculation.js";
import translateRouter from "./translate.js";
import speakRouter from "./speak.js";

const router: IRouter = Router();

router.use(analyzeTdrRouter);
router.use(analyzeNameplateRouter);
router.use(analyzePanelRouter);
router.use(analyzeLookRouter);
router.use(healthRouter);
router.use(reviewCalculationRouter);
router.use(translateRouter);
router.use(speakRouter);

export default router;
