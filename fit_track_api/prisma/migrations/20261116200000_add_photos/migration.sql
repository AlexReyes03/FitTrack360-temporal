CREATE TABLE "BodyMetric" (
  "id" TEXT NOT NULL, "userId" TEXT NOT NULL, "measuredAt" TIMESTAMP(3) NOT NULL,
  "weightKg" DOUBLE PRECISION, "bodyFatPercent" DOUBLE PRECISION, "waistCm" DOUBLE PRECISION,
  CONSTRAINT "BodyMetric_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "Photo" (
  "id" TEXT NOT NULL, "userId" TEXT NOT NULL, "storageKey" TEXT NOT NULL, "mimeType" TEXT NOT NULL,
  "sizeBytes" INTEGER NOT NULL, "width" INTEGER NOT NULL, "height" INTEGER NOT NULL,
  "mealId" TEXT, "metricId" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Photo_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Photo_one_association" CHECK ("mealId" IS NULL OR "metricId" IS NULL)
);
CREATE INDEX "BodyMetric_userId_idx" ON "BodyMetric"("userId");
CREATE INDEX "Photo_userId_idx" ON "Photo"("userId");
ALTER TABLE "BodyMetric" ADD CONSTRAINT "BodyMetric_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Photo" ADD CONSTRAINT "Photo_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Photo" ADD CONSTRAINT "Photo_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "MealLog"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Photo" ADD CONSTRAINT "Photo_metricId_fkey" FOREIGN KEY ("metricId") REFERENCES "BodyMetric"("id") ON DELETE SET NULL ON UPDATE CASCADE;
