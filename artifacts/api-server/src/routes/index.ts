import { Router, type IRouter } from "express";
import analyzeTdrRouter from "./analyze-tdr";
import healthRouter from "./health";
import reviewCalculationRouter from "./review-calculation";

const router: IRouter = Router();

router.use(analyzeTdrRouter);
router.use(healthRouter);
router.use(reviewCalculationRouter);

export default router;
