-- CreateTable
CREATE TABLE "Exercise" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bodyPart" TEXT NOT NULL,
    "equipment" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "muscleGroup" TEXT NOT NULL,
    "secondaryMuscles" TEXT[],
    "instructionsEs" TEXT NOT NULL,
    "instructionStepsEs" TEXT[],
    "imageFile" TEXT NOT NULL,
    "gifFile" TEXT NOT NULL,
    "attribution" TEXT NOT NULL,

    CONSTRAINT "Exercise_pkey" PRIMARY KEY ("id")
);
