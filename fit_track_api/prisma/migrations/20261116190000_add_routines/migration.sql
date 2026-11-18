CREATE TABLE "Routine" (
  "id" TEXT NOT NULL, "userId" TEXT NOT NULL, "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Routine_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "RoutineExercise" (
  "id" TEXT NOT NULL, "routineId" TEXT NOT NULL, "exerciseId" TEXT NOT NULL,
  "position" INTEGER NOT NULL, "targetSets" INTEGER NOT NULL, "targetReps" INTEGER NOT NULL,
  CONSTRAINT "RoutineExercise_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "RoutineExercise_positive" CHECK ("position" > 0 AND "targetSets" > 0 AND "targetReps" > 0)
);
ALTER TABLE "WorkoutSession" ADD COLUMN "routineId" TEXT;
CREATE INDEX "Routine_userId_idx" ON "Routine"("userId");
CREATE UNIQUE INDEX "RoutineExercise_routineId_position_key" ON "RoutineExercise"("routineId", "position");
ALTER TABLE "Routine" ADD CONSTRAINT "Routine_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoutineExercise" ADD CONSTRAINT "RoutineExercise_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "Routine"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoutineExercise" ADD CONSTRAINT "RoutineExercise_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "WorkoutSession" ADD CONSTRAINT "WorkoutSession_routineId_fkey" FOREIGN KEY ("routineId") REFERENCES "Routine"("id") ON DELETE SET NULL ON UPDATE CASCADE;
