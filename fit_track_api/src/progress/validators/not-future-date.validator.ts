import { registerDecorator, type ValidationOptions } from 'class-validator';

export function isFutureDate(date: Date, now: Date = new Date()): boolean {
  return date.getTime() > now.getTime();
}

export function IsNotFutureDate(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string): void {
    registerDecorator({
      name: 'isNotFutureDate',
      target: object.constructor,
      propertyName,
      options: {
        message: `${propertyName} no puede ser una fecha futura`,
        ...validationOptions,
      },
      validator: {
        validate(value: unknown): boolean {
          if (typeof value !== 'string') {
            return false;
          }
          const parsed = new Date(value);
          if (Number.isNaN(parsed.getTime())) {
            return false;
          }
          return !isFutureDate(parsed);
        },
      },
    });
  };
}
