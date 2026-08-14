sealed class Result<T, F> {
  const Result();

  bool get isSuccess => this is Success<T, F>;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(F failure) onFailure,
  });
}

final class Success<T, F> extends Result<T, F> {
  const Success(this.value);

  final T value;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(F failure) onFailure,
  }) => onSuccess(value);
}

final class FailureResult<T, F> extends Result<T, F> {
  const FailureResult(this.failure);

  final F failure;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(F failure) onFailure,
  }) => onFailure(failure);
}
