-- CreateIndex
CREATE INDEX "WorkoutSession_userId_startedAt_idx" ON "WorkoutSession"("userId", "startedAt" DESC);

-- CreateIndex
CREATE INDEX "WorkoutSet_sessionId_idx" ON "WorkoutSet"("sessionId");

-- CreateIndex
CREATE UNIQUE INDEX "WorkoutSet_sessionId_order_key" ON "WorkoutSet"("sessionId", "order");

-- CreateIndex
CREATE INDEX "MealLog_userId_eatenAt_idx" ON "MealLog"("userId", "eatenAt");

-- CreateIndex
CREATE INDEX "MealItem_mealLogId_idx" ON "MealItem"("mealLogId");
