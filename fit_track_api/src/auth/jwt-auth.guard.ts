/** Reexporta el guard Firebase bajo el nombre histórico JwtAuthGuard. */
export {
  FirebaseAuthGuard,
  FirebaseAuthGuard as JwtAuthGuard,
  type AuthPayload,
  type JwtPayload,
  type AuthenticatedRequest,
} from './firebase-auth.guard';
