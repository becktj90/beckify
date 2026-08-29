import { Router, type IRouter } from "express";
import analyzeTdrRouter from "./analyze-tdr";
import healthRouter from "./health";

const router: IRouter = Router();

router.use(analyzeTdrRouter);
router.use(healthRouter);

export default router;
