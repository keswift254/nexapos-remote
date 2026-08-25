/// Outcome of a domain use case: either a value, or a human-readable
/// failure message meant to be shown directly to the cashier (e.g.
/// "Only 3 Envelope in stock."), mirroring how the PHP backend throws
/// RuntimeException with a user-facing message that the UI surfaces as-is.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.failure(String message) = Failure<T>;

  bool get isOk => this is Ok<T>;

  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(String message) failure,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    if (self is Failure<T>) return failure(self.message);
    throw StateError('Unreachable: unknown Result subtype $runtimeType');
  }
}

final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

final class Failure<T> extends Result<T> {
  final String message;

  const Failure(this.message);
}
