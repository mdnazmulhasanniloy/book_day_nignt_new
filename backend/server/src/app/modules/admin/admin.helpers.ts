/**
 * Returns a copy of a user-like record without its `password` field.
 *
 * WHY: second layer behind the query-level `omit`, so a password hash can never
 * be serialized into an admin response (BUG-S17).
 */
export const omitPassword = <T extends object>(
  user: T
): Omit<T, 'password'> => {
  const { password: _password, ...rest } = user as T & { password?: unknown };
  return rest as Omit<T, 'password'>;
};
