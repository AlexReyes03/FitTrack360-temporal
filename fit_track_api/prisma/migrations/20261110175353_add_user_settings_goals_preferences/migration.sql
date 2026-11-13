-- CreateEnum
CREATE TYPE "WeightUnit" AS ENUM ('kg', 'lb');

-- CreateEnum
CREATE TYPE "DistanceUnit" AS ENUM ('km', 'mi');

-- CreateTable
CREATE TABLE "UserSettings" (
    "userId" TEXT NOT NULL,
    "dailyCalorieGoal" INTEGER NOT NULL DEFAULT 2000,
    "proteinGoalG" INTEGER NOT NULL DEFAULT 150,
    "carbsGoalG" INTEGER NOT NULL DEFAULT 250,
    "fatGoalG" INTEGER NOT NULL DEFAULT 65,
    "weightUnit" "WeightUnit" NOT NULL DEFAULT 'kg',
    "distanceUnit" "DistanceUnit" NOT NULL DEFAULT 'km',
    "restSeconds" INTEGER NOT NULL DEFAULT 90,
    "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true,
    "biometricEnabled" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("userId")
);

-- AddForeignKey
ALTER TABLE "UserSettings" ADD CONSTRAINT "UserSettings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
