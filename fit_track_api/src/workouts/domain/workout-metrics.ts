/** Serie ya persistida, con el nombre del ejercicio cuando el catálogo lo trae. */
export interface WorkoutSetSnapshot {
  id: string;
  sessionId: string;
  exerciseId: string;
  exerciseName: string | null;
  order: number;
  weight: number;
  reps: number;
  rpe: number | null;
  rir: number | null;
  createdAt: Date;
  updatedAt: Date;
}

/** Sesión con sus series, tal como se usa para volumen, duración y comparación. */
export interface WorkoutSessionSnapshot {
  id: string;
  userId: string;
  startedAt: Date;
  endedAt: Date | null;
  location: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
  sets: WorkoutSetSnapshot[];
}

export interface LastMark {
  exerciseId: string;
  exerciseName: string | null;
  sessionId: string;
  startedAt: Date;
  order: number;
  weight: number;
  reps: number;
  volume: number;
}

export interface SessionComparison {
  previousSessionId: string;
  previousStartedAt: Date;
  volume: number;
  previousVolume: number;
  volumeDelta: number;
  durationSeconds: number | null;
  previousDurationSeconds: number | null;
  durationDeltaSeconds: number | null;
  setCount: number;
  previousSetCount: number;
  setCountDelta: number;
}

export function roundVolume(value: number): number {
  return Math.round(value * 100) / 100;
}

export function setVolume(weight: number, reps: number): number {
  return roundVolume(weight * reps);
}

export function sessionVolume(
  sets: Array<{ weight: number; reps: number }>,
): number {
  return roundVolume(
    sets.reduce((total, set) => total + set.weight * set.reps, 0),
  );
}

/** Segundos entre inicio y fin. Null mientras la sesión no ha terminado. */
export function durationSeconds(
  startedAt: Date,
  endedAt: Date | null,
): number | null {
  if (!endedAt) {
    return null;
  }
  return Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000);
}

function isEarlierSameUser(
  candidate: WorkoutSessionSnapshot,
  current: WorkoutSessionSnapshot,
): boolean {
  if (candidate.userId !== current.userId) {
    return false;
  }
  if (candidate.id === current.id) {
    return false;
  }
  const startedDelta =
    candidate.startedAt.getTime() - current.startedAt.getTime();
  if (startedDelta < 0) {
    return true;
  }
  if (startedDelta > 0) {
    return false;
  }
  return candidate.createdAt.getTime() < current.createdAt.getTime();
}

function isMoreRecent(
  candidate: WorkoutSessionSnapshot,
  currentBest: WorkoutSessionSnapshot,
): boolean {
  const startedDelta =
    candidate.startedAt.getTime() - currentBest.startedAt.getTime();
  if (startedDelta !== 0) {
    return startedDelta > 0;
  }
  return candidate.createdAt.getTime() > currentBest.createdAt.getTime();
}

/** Sesión anterior del mismo usuario. Ignora sesiones ajenas y posteriores. */
export function findPreviousSession(
  history: WorkoutSessionSnapshot[],
  current: WorkoutSessionSnapshot,
): WorkoutSessionSnapshot | null {
  let previous: WorkoutSessionSnapshot | null = null;
  for (const session of history) {
    if (!isEarlierSameUser(session, current)) {
      continue;
    }
    if (!previous || isMoreRecent(session, previous)) {
      previous = session;
    }
  }
  return previous;
}

/**
 * Última serie de un ejercicio en el historial anterior del mismo usuario.
 * Si esa sesión tiene varias series del ejercicio, se toma la de mayor orden.
 */
export function findLastMark(
  history: WorkoutSessionSnapshot[],
  current: WorkoutSessionSnapshot,
  exerciseId: string,
): LastMark | null {
  let source: WorkoutSessionSnapshot | null = null;
  for (const session of history) {
    if (!isEarlierSameUser(session, current)) {
      continue;
    }
    if (!session.sets.some((set) => set.exerciseId === exerciseId)) {
      continue;
    }
    if (!source || isMoreRecent(session, source)) {
      source = session;
    }
  }
  if (!source) {
    return null;
  }

  const matching = source.sets
    .filter((set) => set.exerciseId === exerciseId)
    .sort((a, b) => a.order - b.order);
  const set = matching[matching.length - 1];
  if (!set) {
    return null;
  }

  return {
    exerciseId: set.exerciseId,
    exerciseName: set.exerciseName,
    sessionId: source.id,
    startedAt: source.startedAt,
    order: set.order,
    weight: set.weight,
    reps: set.reps,
    volume: setVolume(set.weight, set.reps),
  };
}

export function lastMarksForSession(
  history: WorkoutSessionSnapshot[],
  current: WorkoutSessionSnapshot,
): LastMark[] {
  const exerciseIds: string[] = [];
  for (const set of [...current.sets].sort((a, b) => a.order - b.order)) {
    if (!exerciseIds.includes(set.exerciseId)) {
      exerciseIds.push(set.exerciseId);
    }
  }

  const marks: LastMark[] = [];
  for (const exerciseId of exerciseIds) {
    const mark = findLastMark(history, current, exerciseId);
    if (mark) {
      marks.push(mark);
    }
  }
  return marks;
}

export function compareWithPrevious(
  history: WorkoutSessionSnapshot[],
  current: WorkoutSessionSnapshot,
): SessionComparison | null {
  const previous = findPreviousSession(history, current);
  if (!previous) {
    return null;
  }

  const volume = sessionVolume(current.sets);
  const previousVolume = sessionVolume(previous.sets);
  const currentDuration = durationSeconds(current.startedAt, current.endedAt);
  const previousDuration = durationSeconds(
    previous.startedAt,
    previous.endedAt,
  );

  return {
    previousSessionId: previous.id,
    previousStartedAt: previous.startedAt,
    volume,
    previousVolume,
    volumeDelta: roundVolume(volume - previousVolume),
    durationSeconds: currentDuration,
    previousDurationSeconds: previousDuration,
    durationDeltaSeconds:
      currentDuration === null || previousDuration === null
        ? null
        : currentDuration - previousDuration,
    setCount: current.sets.length,
    previousSetCount: previous.sets.length,
    setCountDelta: current.sets.length - previous.sets.length,
  };
}
