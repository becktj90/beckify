import { Router, type IRouter } from "express";
import analyzeTdrRouter from "./analyze-tdr.js";
import healthRouter from "./health.js";
import reviewCalculationRouter from "./review-calculation.js";

const router: IRouter = Router();

router.use(analyzeTdrRouter);
router.use(healthRouter);
router.use(reviewCalculationRouter);

export default router;
